enum DownloadStatus {
  queued,
  analyzing,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

class DownloadTask {
  final String id;
  final String url;
  String fileName;
  String savePath;
  int totalBytes;
  int downloadedBytes;
  double speedBytesPerSec;
  int etaSeconds;
  DownloadStatus status;
  String? errorMessage;
  String mimeType;
  String? sha256Checksum;
  final DateTime createdAt;
  DateTime? completedAt;
  bool acceptsRanges;

  DownloadTask({
    required this.id,
    required this.url,
    required this.fileName,
    required this.savePath,
    this.totalBytes = -1,
    this.downloadedBytes = 0,
    this.speedBytesPerSec = 0.0,
    this.etaSeconds = 0,
    this.status = DownloadStatus.queued,
    this.errorMessage,
    this.mimeType = 'video/mp4',
    this.sha256Checksum,
    required this.createdAt,
    this.completedAt,
    this.acceptsRanges = false,
  });

  double get progressPercentage {
    if (totalBytes <= 0) return 0.0;
    final pct = (downloadedBytes / totalBytes) * 100.0;
    return pct.clamp(0.0, 100.0);
  }

  String get formattedSpeed {
    if (speedBytesPerSec <= 0) return '0 KB/s';
    if (speedBytesPerSec >= 1024 * 1024) {
      return '${(speedBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(speedBytesPerSec / 1024).toStringAsFixed(1)} KB/s';
  }

  String get formattedEta {
    if (etaSeconds <= 0 || status != DownloadStatus.downloading) return '--';
    if (etaSeconds >= 3600) {
      final hours = etaSeconds ~/ 3600;
      final mins = (etaSeconds % 3600) ~/ 60;
      return '${hours}h ${mins}m';
    }
    if (etaSeconds >= 60) {
      final mins = etaSeconds ~/ 60;
      final secs = etaSeconds % 60;
      return '${mins}m ${secs}s';
    }
    return '${etaSeconds}s';
  }

  String get formattedProgress {
    final cur = _formatBytes(downloadedBytes);
    if (totalBytes <= 0) {
      return '$cur downloaded';
    }
    final tot = _formatBytes(totalBytes);
    return '$cur / $tot';
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'fileName': fileName,
    'savePath': savePath,
    'totalBytes': totalBytes,
    'downloadedBytes': downloadedBytes,
    'status': status.name,
    'mimeType': mimeType,
    'sha256Checksum': sha256Checksum,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'acceptsRanges': acceptsRanges,
  };

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'],
      url: json['url'],
      fileName: json['fileName'],
      savePath: json['savePath'],
      totalBytes: json['totalBytes'] ?? -1,
      downloadedBytes: json['downloadedBytes'] ?? 0,
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.failed,
      ),
      mimeType: json['mimeType'] ?? 'video/mp4',
      sha256Checksum: json['sha256Checksum'],
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      acceptsRanges: json['acceptsRanges'] ?? false,
    );
  }
}
