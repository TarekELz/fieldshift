// The proxy that holds the API keys (see proxy/README.md). When the app is built with --dart-define=PROXY_URL=https://..., voice and language calls go to the proxy
// first and the app carries NO keys. Direct keys from assets/secrets/secrets.json still work as an extra (team test builds); without either, the app uses fixed text
// and the phone's voice. The proxy address is public by design; it is not a secret.
const kProxyUrl = String.fromEnvironment('PROXY_URL');

/// Optional shared header value (not a secret once it is inside an APK; it only keeps casual scrapers away).
const kProxyToken = String.fromEnvironment('PROXY_TOKEN');

/// Stands in the key list where the proxy goes, so the existing "try each key in turn" loops cover it.
const kProxyKey = '__proxy__';

bool get hasProxy => kProxyUrl.isNotEmpty;

Map<String, String> get proxyHeaders => {'Content-Type': 'application/json', if (kProxyToken.isNotEmpty) 'x-fs-app': kProxyToken};
