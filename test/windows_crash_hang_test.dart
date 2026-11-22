import 'dart:async';
import 'dart:convert';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kgka_music_hl/controllers/auth_controller.dart';
import 'package:kgka_music_hl/controllers/player_controller.dart';
import 'package:kgka_music_hl/controllers/theme_controller.dart';
import 'package:kgka_music_hl/models/music_models.dart';
import 'package:kgka_music_hl/services/music_api.dart';
import 'package:kgka_music_hl/services/music_audio_handler.dart';
import 'package:kgka_music_hl/ui/pages/playback_history_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Windows 二次启动竞态回归测试。
///
/// 背景：崩溃日志显示 Windows.Media.dll 访问违例 + flutter_windows.dll 固定偏移
/// 访问违例；假死时仅 app 窗口消息循环停摆而音频继续。根因之一是启动恢复预加载
/// 在原生 MediaPlayer 就绪前就在平台线程发起 load；之二是随播放进度高频重建的
/// 列表行未隔离语义树（Windows AXTree 竞态）。
class _P extends Fake implements AudioPlayer {
  final states = StreamController<PlayerState>.broadcast(sync: true);
  final processing = StreamController<ProcessingState>.broadcast(sync: true);
  bool _playing = false;
  double _volume = 1;

  @override
  double get volume => _volume;
  @override
  Future<void> setVolume(double value) async => _volume = value;
  @override
  bool get playing => _playing;
  void setPlaying(bool value) {
    _playing = value;
    states.add(PlayerState(value, ProcessingState.ready));
  }

  @override
  Stream<PlayerState> get playerStateStream => states.stream;
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<ProcessingState> get processingStateStream => processing.stream;
  @override
  Stream<int?> get androidAudioSessionIdStream => const Stream.empty();
  @override
  Duration get position => Duration.zero;
  @override
  int? get androidAudioSessionId => null;
  @override
  ProcessingState get processingState => ProcessingState.ready;
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> dispose() async {}
}

class _H extends Fake implements MusicAudioHandler {
  @override
  final _P audioPlayer = _P();
  int loadCalls = 0;

  @override
  Song? get loadedSong => null;

  @override
  Future<void> loadSong({
    required Song song,
    required String url,
    required List<Song> queueSongs,
    required int queueIndex,
  }) async {
    loadCalls++;
  }

  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> play({bool userInitiated = true}) async =>
      audioPlayer.setPlaying(true);
  @override
  Future<void> pause({bool userInitiated = true}) async =>
      audioPlayer.setPlaying(false);
  @override
  void attachTransportControls({
    required Future<void> Function() onNext,
    required Future<void> Function() onPrevious,
    void Function()? onPause,
    void Function()? onPlay,
  }) {}
  @override
  void detachTransportControls() {}
  @override
  void setBluetoothLyricsTitleSync(bool enabled) {}
  @override
  Future<void> close() async {}
  @override
  Future<void> dispose() async {}
}

class _A extends Fake implements MusicApi {
  @override
  Future<PlayUrl> songUrl(
    Song song, {
    AudioQuality quality = AudioQuality.standard,
    bool hashOnly = false,
  }) async =>
      PlayUrl(url: 'https://example.com/a.mp3', hash: song.hash);
}

class _Auth extends ChangeNotifier implements AuthController {
  @override
  bool isLiked(Song song) => false;
}

class _Session extends Fake implements AudioSession {
  final interruptions = StreamController<AudioInterruptionEvent>.broadcast();
  final noisy = StreamController<void>.broadcast();
  final devices = StreamController<Set<AudioDevice>>.broadcast();
  @override
  Stream<AudioInterruptionEvent> get interruptionEventStream =>
      interruptions.stream;
  @override
  Stream<void> get becomingNoisyEventStream => noisy.stream;
  @override
  Stream<Set<AudioDevice>> get devicesStream => devices.stream;
  @override
  Future<void> configure(AudioSessionConfiguration configuration) async {}
  @override
  Future<Set<AudioDevice>> getDevices({
    bool includeInputs = true,
    bool includeOutputs = true,
  }) async => {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const song = Song(
    id: '1',
    title: 'HistSong',
    artist: 'Artist',
    hash: 'HASH1',
    source: SongSource.netease,
  );

  late _H handler;
  late _A api;
  late _Session session;
  late ThemeController theme;
  late PlayerController player;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    handler = _H();
    api = _A();
    session = _Session();
    theme = ThemeController();
    player = PlayerController(
      api,
      handler,
      audioSessionProvider: () async => session,
    );
  });

  tearDown(() async {
    await Future<void>.delayed(Duration.zero);
    player.dispose();
    theme.dispose();
    await session.interruptions.close();
    await session.noisy.close();
    await session.devices.close();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Windows 启动恢复预加载须等原生就绪门控后才 load', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    player.currentSong = song;

    await tester.pumpWidget(const SizedBox.shrink()); // 触发首帧回调
    await tester.runAsync(() async {
      unawaited(player.prepareRestoredSong());
      await Future<void>.delayed(const Duration(milliseconds: 50)); // 门控期内
      expect(handler.loadCalls, 0, reason: '原生就绪门控期内不得发起 load');
      await Future<void>.delayed(const Duration(milliseconds: 400)); // 门控释放
      expect(handler.loadCalls, 1);
    });
  });

  testWidgets('Windows 下播放历史歌曲行随 player 重建但被语义树隔离', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({
      'playback_history': jsonEncode([song.toCache()]),
    });
    await tester.pumpWidget(MaterialApp(
      home: PlaybackHistoryPage(api: api, auth: _Auth(), player: player),
    ));
    await tester.pumpAndSettle();

    expect(
      find.ancestor(
        of: find.text('HistSong'),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
      reason: '随播放进度重建的历史行必须隔离语义树以规避 Windows AXTree 竞态',
    );
  });

  testWidgets('非 Windows 平台保留历史行语义（无障碍不回归）', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({
      'playback_history': jsonEncode([song.toCache()]),
    });
    await tester.pumpWidget(MaterialApp(
      home: PlaybackHistoryPage(api: api, auth: _Auth(), player: player),
    ));
    await tester.pumpAndSettle();

    expect(
      find.ancestor(
        of: find.text('HistSong'),
        matching: find.byType(ExcludeSemantics),
      ),
      findsNothing,
    );
  });
}
