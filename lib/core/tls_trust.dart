import 'dart:convert';
import 'dart:io';

/// 补充信任锚：TrustAsia TLS RSA Root CA（自签根）。
///
/// 背景：API 服务器证书链为
///   leaf -> LiteSSL RSA CA 2025 -> TrustAsia TLS RSA Root CA（Certum 交叉签名）。
/// Dart 在 Windows 上只从系统证书库（ROOT/CA store）读取「已存在」的信任根，
/// 不会像浏览器那样经 Windows Update 在线补根；若机器根证书库较旧
/// （缺少 2024 年才进入微软根计划的 TrustAsia TLS RSA Root CA），
/// 登录拉二维码等 HTTPS 请求会报：
///   HandshakeException: CERTIFICATE_VERIFY_FAILED:
///   unable to get local issuer certificate
/// 这里把该根证书内置为额外信任锚（取自 Mozilla 信任库）。
/// SHA-256: 06:C0:8D:7D:AF:D8:76:97:1E:B1:12:4F:E6:7F:84:7E:
///          C0:C7:A1:58:D3:EA:53:CB:E9:40:E2:EA:97:91:F4:C3
/// 有效期 2024-05-15 ~ 2044-05-15。
/// 仅「追加」信任，不关闭、不放宽任何证书校验。
const String _extraRootPem = '''
-----BEGIN CERTIFICATE-----
MIIFgDCCA2igAwIBAgIUHBjYz+VTPyI1RlNUJDxsR9FcSpwwDQYJKoZIhvcNAQEM
BQAwWDELMAkGA1UEBhMCQ04xJTAjBgNVBAoTHFRydXN0QXNpYSBUZWNobm9sb2dp
ZXMsIEluYy4xIjAgBgNVBAMTGVRydXN0QXNpYSBUTFMgUlNBIFJvb3QgQ0EwHhcN
MjQwNTE1MDU0MTU3WhcNNDQwNTE1MDU0MTU2WjBYMQswCQYDVQQGEwJDTjElMCMG
A1UEChMcVHJ1c3RBc2lhIFRlY2hub2xvZ2llcywgSW5jLjEiMCAGA1UEAxMZVHJ1
c3RBc2lhIFRMUyBSU0EgUm9vdCBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCC
AgoCggIBAMMWuBtqpERz5dZO9LnPWwvB0ZqB9WOwj0PBuwhaGnrhB3YmH49pVr7+
NmDQDIPNlOrnxS1cLwUWAp4KqC/lYCZUlviYQB2srp10Zy9U+5RjmOMmSoPGlbYJ
Q1DNDX3eRA5gEk9bNb2/mThtfWza4mhzH/kxpRkQcwUqwzIZheo0qt1CHjCNP561
HmHVb70AcnKtEj+qpklz8oYVlQwQX1Fkzv93uMltrOXVmPGZLmzjyUT5tUMnCE32
ft5EebuyjBza00tsLtbDeLdM1aTk2tyKjg7/D8OmYCYozza/+lcK7Fs/6TAWe8Tb
xNRkoDD75f0dcZLdKY9BWN4ArTr9PXwaqLEX8E40eFgl1oUh63kd0Nyrz2I8sMeX
i9bQn9P+PN7F4/w6g3CEIR0JwqH8uyghZVNgepBtljhb//HXeltt08lwSUq6HTrQ
UNoyIBnkiz/r1RYmNzz7dZ6wB3C4FGB33PYPXFIKvF1tjVEK2sUYyJtt3LCDs3+j
TnhMmCWr8n4uIF6CFabW2I+s5c0yhsj55NqJ4js+k8UTav/H9xj8Z7XvGCxUq0DT
bE3txci3OE9kxJRMT6DNrqXGJyV1J23G2pyOsAWZ1SgRxSHUuPzHlqtKZFlhaxP8
S8ySpg+kUb8OWJDZgoM5pl+z+m6Ss80zDoWo8SnTq1mt1tve1CuBAgMBAAGjQjBA
MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFLgHkXlcBvRG/XtZylomkadFK/hT
MA4GA1UdDwEB/wQEAwIBBjANBgkqhkiG9w0BAQwFAAOCAgEAIZtqBSBdGBanEqT3
Rz/NyjuujsCCztxIJXgXbODgcMTWltnZ9r96nBO7U5WS/8+S4PPFJzVXqDuiGev4
iqME3mmL5Dw8veWv0BIb5Ylrc5tvJQJLkIKvQMKtuppgJFqBTQUYo+IzeXoLH5Pt
7DlK9RME7I10nYEKqG/odv6LTytpEoYKNDbdgptvT+Bz3Ul/KD7JO6NXBNiT2Twp
2xIQaOHEibgGIOcberyxk2GaGUARtWqFVwHxtlotJnMnlvm5P1vQiJ3koP26TpUJ
g3933FEFlJ0gcXax7PqJtZwuhfG5WyRasQmr2soaB82G39tp27RIGAAtvKLEiUUj
pQ7hRGU+isFqMB3iYPg6qocJQrmBktwliJiJ8Xw18WLK7nn4GS/+X/jbh87qqA8M
pugLoDzga5SYnH+tBuYc6kIQX+ImFTw3OffXvO645e8D7r0i+yiGNFjEWn9hongP
XvPKnbwbPKfILfanIhHKA9jnZwqKDss1jjQ52MjqjZ9k4DewbNfFj8GQYSbbJIwe
SsCI3zWQzj8C9GRh3sfIB5XeMhg6j6JCQCTl1jNdfK7vsU1P1FeQNWrcrgSXSYk0
ly4wBOeY99sLAZDBHwo/+ML+TvrbmnNzFrwFuHnYWa8G5z9nODmxfKuU4CkUpijy
323imttUQ/hHWKNddBWcwauwxzQ=
-----END CERTIFICATE-----
''';

SecurityContext? _cachedContext;

SecurityContext _contextWithExtraRoots() {
  final cached = _cachedContext;
  if (cached != null) return cached;
  final ctx = SecurityContext(withTrustedRoots: true);
  ctx.setTrustedCertificatesBytes(utf8.encode(_extraRootPem.trim()));
  _cachedContext = ctx;
  return ctx;
}

/// 让 http / dio 等基于 dart:io HttpClient 的请求都带上补充信任锚。
class ExtraRootHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context ?? _contextWithExtraRoots());
  }
}

/// 在 main() 最早处调用一次。
void installExtraRootTrust() {
  HttpOverrides.global = ExtraRootHttpOverrides();
}
