class MediaMetadata {
  final String url;
  final String resolvedUrl;
  final String suggestedFileName;
  final int totalBytes;
  final String mimeType;
  final bool acceptsRanges;
  final bool isDirectMedia;
  final String? unsupportedReason;
  final String? eTag;

  MediaMetadata({
    required this.url,
    required this.resolvedUrl,
    required this.suggestedFileName,
    required this.totalBytes,
    required this.mimeType,
    required this.acceptsRanges,
    required this.isDirectMedia,
    this.unsupportedReason,
    this.eTag,
  });

  String get formattedSize {
    if (totalBytes <= 0) return 'Stream (Unknown size)';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double bytes = totalBytes.toDouble();
    while (bytes >= 1024 && i < suffixes.length - 1) {
      bytes /= 1024;
      i++;
    }
    return '${bytes.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
