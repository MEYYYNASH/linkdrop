import 'package:flutter_test/flutter_test.dart';
import 'package:linkdrop/models/download_task.dart';

void main() {
  group('DownloadTask Model & Calculation Tests', () {
    test('Calculates progress percentage accurately', () {
      final task = DownloadTask(
        id: '1',
        url: 'https://example.com/video.mp4',
        fileName: 'video.mp4',
        savePath: '/storage/video.mp4',
        totalBytes: 1000,
        downloadedBytes: 742,
        createdAt: DateTime.now(),
      );

      expect(task.progressPercentage, closeTo(74.2, 0.01));
    });

    test('Formats speed in KB/s and MB/s correctly', () {
      final task = DownloadTask(
        id: '1',
        url: 'https://example.com/video.mp4',
        fileName: 'video.mp4',
        savePath: '/storage/video.mp4',
        createdAt: DateTime.now(),
      );

      task.speedBytesPerSec = 512 * 1024; // 512 KB/s
      expect(task.formattedSpeed, '512.0 KB/s');

      task.speedBytesPerSec = 4.5 * 1024 * 1024; // 4.5 MB/s
      expect(task.formattedSpeed, '4.5 MB/s');
    });

    test('Formats ETA seconds into minutes and seconds', () {
      final task = DownloadTask(
        id: '1',
        url: 'https://example.com/video.mp4',
        fileName: 'video.mp4',
        savePath: '/storage/video.mp4',
        status: DownloadStatus.downloading,
        etaSeconds: 85,
        createdAt: DateTime.now(),
      );

      expect(task.formattedEta, '1m 25s');

      task.etaSeconds = 3665;
      expect(task.formattedEta, '1h 1m');
    });

    test('Serializes to and from JSON correctly', () {
      final now = DateTime.now();
      final task = DownloadTask(
        id: 'task_123',
        url: 'https://example.com/sample.mp4',
        fileName: 'sample.mp4',
        savePath: '/storage/sample.mp4',
        totalBytes: 25000000,
        downloadedBytes: 12500000,
        status: DownloadStatus.downloading,
        mimeType: 'video/mp4',
        sha256Checksum: 'abcdef1234567890',
        createdAt: now,
        acceptsRanges: true,
      );

      final json = task.toJson();
      final revived = DownloadTask.fromJson(json);

      expect(revived.id, task.id);
      expect(revived.fileName, task.fileName);
      expect(revived.totalBytes, task.totalBytes);
      expect(revived.downloadedBytes, task.downloadedBytes);
      expect(revived.status, task.status);
      expect(revived.sha256Checksum, task.sha256Checksum);
      expect(revived.acceptsRanges, isTrue);
    });
  });
}
