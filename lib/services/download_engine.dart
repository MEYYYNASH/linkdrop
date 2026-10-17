import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import '../models/download_task.dart';

class DownloadEngine {
  final Dio _dio;
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, StreamSubscription> _subscriptions = {};

  DownloadEngine({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(hours: 2),
                followRedirects: true,
                maxRedirects: 8,
                headers: {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
                  'Accept': '*/*',
                  'Accept-Encoding': 'identity',
                  'Connection': 'keep-alive',
                },
              ),
            );

  /// Starts or resumes a download task using streaming chunks directly to disk
  Future<void> startDownload({
    required DownloadTask task,
    required void Function(DownloadTask task) onProgress,
    required void Function(DownloadTask task) onComplete,
    required void Function(DownloadTask task, String error) onError,
  }) async {
    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;

    final file = File(task.savePath);
    // Ensure parent directories exist
    if (!file.parent.existsSync()) {
      try {
        file.parent.createSync(recursive: true);
      } catch (_) {}
    }

    var existingBytes = 0;

    // Check if resuming an existing partially downloaded file
    if (file.existsSync()) {
      existingBytes = file.lengthSync();
      task.downloadedBytes = existingBytes;
    }

    final headers = <String, dynamic>{
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'Accept': '*/*',
      'Accept-Encoding': 'identity',
    };

    final uri = Uri.tryParse(task.url);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      headers['Referer'] = '${uri.scheme}://${uri.host}/';
      headers['Origin'] = '${uri.scheme}://${uri.host}';
    }

    if (existingBytes > 0 && task.acceptsRanges) {
      headers['Range'] = 'bytes=$existingBytes-';
    } else if (existingBytes > 0 && !task.acceptsRanges) {
      // Server doesn't accept ranges, so restart from byte 0
      existingBytes = 0;
      task.downloadedBytes = 0;
      if (file.existsSync()) {
        try { file.deleteSync(); } catch (_) {}
      }
    }

    task.status = DownloadStatus.downloading;
    task.errorMessage = null;
    onProgress(task);

    final stopwatch = Stopwatch()..start();
    var lastTimeMs = stopwatch.elapsedMilliseconds;
    var bytesSinceLastCalc = 0;
    IOSink? sink;

    try {
      Response<ResponseBody> response;
      try {
        response = await _dio.get<ResponseBody>(
          task.url,
          options: Options(
            responseType: ResponseType.stream,
            headers: headers,
            validateStatus: (status) => status != null && (status >= 200 && status < 400),
          ),
          cancelToken: cancelToken,
        );
      } on DioException catch (dioErr) {
        // If range request was rejected (416 or 400), restart cleanly from byte 0
        if (existingBytes > 0 && (dioErr.response?.statusCode == 416 || dioErr.response?.statusCode == 400)) {
          headers.remove('Range');
          existingBytes = 0;
          task.downloadedBytes = 0;
          if (file.existsSync()) {
            try { file.deleteSync(); } catch (_) {}
          }
          response = await _dio.get<ResponseBody>(
            task.url,
            options: Options(
              responseType: ResponseType.stream,
              headers: headers,
              validateStatus: (status) => status != null && (status >= 200 && status < 400),
            ),
            cancelToken: cancelToken,
          );
        } else {
          rethrow;
        }
      }

      final isPartial = response.statusCode == 206;
      if (!isPartial && existingBytes > 0) {
        // Server responded with 200 OK (ignored Range), write fresh from byte 0
        existingBytes = 0;
        task.downloadedBytes = 0;
        if (file.existsSync()) {
          try { file.deleteSync(); } catch (_) {}
        }
      }

      final respHeaders = response.headers;
      final contentLengthStr = respHeaders.value('content-length');
      if (contentLengthStr != null) {
        final length = int.tryParse(contentLengthStr) ?? -1;
        if (length > 0) {
          if (existingBytes > 0 && isPartial) {
            task.totalBytes = existingBytes + length;
          } else {
            task.totalBytes = length;
          }
        }
      }

      final acceptsRangesHeader = respHeaders.value('accept-ranges')?.toLowerCase() == 'bytes' ||
          respHeaders.value('content-range') != null;
      task.acceptsRanges = acceptsRangesHeader;

      // Open file for streaming chunk writing
      sink = file.openWrite(mode: isPartial ? FileMode.writeOnlyAppend : FileMode.writeOnly);
      final stream = response.data!.stream;

      final completer = Completer<void>();

      final sub = stream.listen(
        (chunk) {
          sink?.add(chunk);
          task.downloadedBytes += chunk.length;
          bytesSinceLastCalc += chunk.length;

          final now = stopwatch.elapsedMilliseconds;
          final timeDiff = now - lastTimeMs;

          // Update speed & ETA every 500ms
          if (timeDiff >= 500) {
            final speed = (bytesSinceLastCalc / (timeDiff / 1000.0));
            // Exponential moving average for smooth display
            task.speedBytesPerSec = task.speedBytesPerSec == 0
                ? speed
                : (task.speedBytesPerSec * 0.7) + (speed * 0.3);

            if (task.totalBytes > 0 && task.speedBytesPerSec > 0) {
              final remainingBytes = task.totalBytes - task.downloadedBytes;
              if (remainingBytes > 0) {
                task.etaSeconds = (remainingBytes / task.speedBytesPerSec).round();
              } else {
                task.etaSeconds = 0;
              }
            }

            bytesSinceLastCalc = 0;
            lastTimeMs = now;
            onProgress(task);
          }
        },
        onDone: () async {
          await sink?.flush();
          await sink?.close();
          sink = null;
          completer.complete();
        },
        onError: (err) {
          completer.completeError(err);
        },
        cancelOnError: true,
      );

      _subscriptions[task.id] = sub;
      await completer.future;

      stopwatch.stop();
      _cancelTokens.remove(task.id);
      _subscriptions.remove(task.id);

      task.status = DownloadStatus.completed;
      task.completedAt = DateTime.now();
      task.speedBytesPerSec = 0;
      task.etaSeconds = 0;

      // Verify SHA-256 after completion
      try {
        final hashStream = file.openRead();
        final digest = await sha256.bind(hashStream).first;
        task.sha256Checksum = digest.toString();
      } catch (_) {}

      onComplete(task);
    } catch (e) {
      stopwatch.stop();
      await sink?.flush();
      await sink?.close();
      _cancelTokens.remove(task.id);
      _subscriptions.remove(task.id);

      if (CancelToken.isCancel(e as dynamic)) {
        if (task.status != DownloadStatus.paused) {
          task.status = DownloadStatus.cancelled;
        }
        task.speedBytesPerSec = 0;
        task.etaSeconds = 0;
        onProgress(task);
      } else {
        task.status = DownloadStatus.failed;
        task.errorMessage = e.toString().split('\n').first;
        task.speedBytesPerSec = 0;
        task.etaSeconds = 0;
        onError(task, task.errorMessage!);
      }
    }
  }

  /// Pauses the active download task
  void pause(DownloadTask task) {
    if (_cancelTokens.containsKey(task.id)) {
      task.status = DownloadStatus.paused;
      task.speedBytesPerSec = 0;
      task.etaSeconds = 0;
      _subscriptions[task.id]?.cancel();
      _subscriptions.remove(task.id);
      _cancelTokens[task.id]?.cancel('Paused by user');
      _cancelTokens.remove(task.id);
    }
  }

  /// Cancels and removes partial data if desired
  void cancel(DownloadTask task, {bool deletePartialFile = false}) {
    if (_cancelTokens.containsKey(task.id)) {
      task.status = DownloadStatus.cancelled;
      task.speedBytesPerSec = 0;
      task.etaSeconds = 0;
      _subscriptions[task.id]?.cancel();
      _subscriptions.remove(task.id);
      _cancelTokens[task.id]?.cancel('Cancelled by user');
      _cancelTokens.remove(task.id);
    }
    if (deletePartialFile) {
      final file = File(task.savePath);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
      task.downloadedBytes = 0;
    }
  }
}
