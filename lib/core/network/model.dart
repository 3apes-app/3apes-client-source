final class DownloadRequestHeaders {
  const DownloadRequestHeaders({
    this.agePublicKey,
    this.hwid,
    this.device = const {},
  });

  final String? agePublicKey;
  final String? hwid;

  /// 3 APES: OS and model, sent only together with [hwid].
  final Map<String, String> device;

  Map<String, String>? toHttpHeaders() {
    final publicKey = agePublicKey?.trim();
    final headers = <String, String>{
      if (publicKey != null && publicKey.isNotEmpty)
        'X-Age-Public-Key': publicKey,
      'x-hwid': ?hwid,
      if (hwid != null) ...device,
    };
    return headers.isEmpty ? null : headers;
  }
}
