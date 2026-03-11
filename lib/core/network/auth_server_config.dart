import 'package:flutter/foundation.dart';

String resolveAuthServerBaseUrl({String? configuredBaseUrl}) {
  final configured = configuredBaseUrl?.trim() ?? '';
  final baseUrl = configured.isNotEmpty ? configured : _defaultAuthServerBaseUrl();
  return normalizeAuthServerBaseUrl(baseUrl);
}

String normalizeAuthServerBaseUrl(String rawBaseUrl) {
  final trimmed = rawBaseUrl.trim();
  if (trimmed.isEmpty) {
    return rawBaseUrl;
  }

  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return trimmed;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.host.isEmpty) {
    return trimmed;
  }

  if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
    return uri.replace(host: '10.0.2.2').toString();
  }

  return trimmed;
}

String _defaultAuthServerBaseUrl() {
  if (kIsWeb) {
    return 'http://localhost:3000';
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3000';
  }

  return 'http://localhost:3000';
}

