import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../models/download_task.dart';
import '../models/media_metadata.dart';
import '../services/download_engine.dart';
import '../services/storage_service.dart';
import '../services/url_validator.dart';

class DownloadProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final DownloadEngine _downloadEngine = DownloadEngine();

  final List<DownloadTask> _tasks = [];
  bool _isInitialized = false;
  int _maxConcurrentDownloads = 3;

  List<DownloadTask> get allTasks => UnmodifiableListView(_tasks);

  List<DownloadTask> get activeTasks =>
      _tasks.where((t) => t.status == DownloadStatus.downloading ||
          t.status == DownloadStatus.queued ||
          t.status == DownloadStatus.analyzing ||
          t.status == DownloadStatus.paused).toList();

  List<DownloadTask> get completedTasks =>
      _tasks.where((t) => t.status == DownloadStatus.completed).toList();

  List<DownloadTask> get recentDownloads =>
      _tasks.reversed.take(5).toList();

  bool get isInitialized => _isInitialized;

  DownloadProvider() {
    init();
  }

  Future<void> init() async {
    if (_isInitialized) return;
    final saved = await _storageService.loadHistory();
    _tasks.clear();
    _tasks.addAll(saved);
    _isInitialized = true;
    notifyListeners();
  }

  /// Inspects a video URL
  Future<MediaMetadata> analyzeUrl(String url, {bool blockPrivateIps = true}) async {
    return await UrlValidator.inspectUrl(url, blockPrivateNetwork: blockPrivateIps);
  }

  /// Adds a new download task
  Future<DownloadTask> addDownload({
    required String url,
    required String suggestedName,
    int totalBytes = -1,
    bool acceptsRanges = true,
    String mimeType = 'video/mp4',
  }) async {
    final downloadDir = await _storageService.getDownloadDirectory();
    final sanitizedName = UrlValidator.sanitizeFileName(suggestedName);
    final finalPath = await _storageService.getUniqueFilePath(downloadDir, sanitizedName);

    final task = DownloadTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: url,
      fileName: p.basename(finalPath),
      savePath: finalPath,
      totalBytes: totalBytes,
      acceptsRanges: acceptsRanges,
      mimeType: mimeType,
      createdAt: DateTime.now(),
      status: DownloadStatus.queued,
    );

    _tasks.insert(0, task);
    _persistTasks();
    notifyListeners();

    _triggerNextDownloads();
    return task;
  }

  /// Adds multiple batch downloads
  Future<void> addBatchDownloads(List<String> urls) async {
    for (final rawUrl in urls) {
      final url = rawUrl.trim();
      if (url.isEmpty) continue;
      final meta = await analyzeUrl(url);
      if (meta.isDirectMedia) {
        await addDownload(
          url: meta.resolvedUrl,
          suggestedName: meta.suggestedFileName,
          totalBytes: meta.totalBytes,
          acceptsRanges: meta.acceptsRanges,
          mimeType: meta.mimeType,
        );
      }
    }
  }

  void _triggerNextDownloads() {
    final currentRunning = _tasks.where((t) => t.status == DownloadStatus.downloading).length;
    if (currentRunning >= _maxConcurrentDownloads) return;

    final nextInQueue = _tasks.firstWhere(
      (t) => t.status == DownloadStatus.queued,
      orElse: () => DownloadTask(
        id: '',
        url: '',
        fileName: '',
        savePath: '',
        createdAt: DateTime.now(),
      ),
    );

    if (nextInQueue.id.isNotEmpty) {
      _executeDownload(nextInQueue);
    }
  }

  void _executeDownload(DownloadTask task) {
    _downloadEngine.startDownload(
      task: task,
      onProgress: (updatedTask) {
        notifyListeners();
      },
      onComplete: (updatedTask) {
        _persistTasks();
        notifyListeners();
        _triggerNextDownloads();
      },
      onError: (updatedTask, error) {
        _persistTasks();
        notifyListeners();
        _triggerNextDownloads();
      },
    );
  }

  void pauseDownload(String taskId) {
    final task = _findTask(taskId);
    if (task != null && task.status == DownloadStatus.downloading) {
      _downloadEngine.pause(task);
      _persistTasks();
      notifyListeners();
      _triggerNextDownloads();
    }
  }

  void resumeDownload(String taskId) {
    final task = _findTask(taskId);
    if (task != null && (task.status == DownloadStatus.paused || task.status == DownloadStatus.failed)) {
      task.status = DownloadStatus.queued;
      notifyListeners();
      _triggerNextDownloads();
    }
  }

  void cancelDownload(String taskId, {bool deletePartialFile = true}) {
    final task = _findTask(taskId);
    if (task != null) {
      _downloadEngine.cancel(task, deletePartialFile: deletePartialFile);
      _persistTasks();
      notifyListeners();
      _triggerNextDownloads();
    }
  }

  void retryDownload(String taskId) {
    resumeDownload(taskId);
  }

  Future<void> deleteDownload(String taskId, {bool deleteFileFromDisk = true}) async {
    final task = _findTask(taskId);
    if (task != null) {
      if (task.status == DownloadStatus.downloading) {
        _downloadEngine.cancel(task, deletePartialFile: true);
      }
      if (deleteFileFromDisk) {
        await StorageService.deleteFile(task.savePath);
      }
      _tasks.removeWhere((t) => t.id == taskId);
      await _persistTasks();
      notifyListeners();
      _triggerNextDownloads();
    }
  }

  Future<void> renameTaskFile(String taskId, String newName) async {
    final task = _findTask(taskId);
    if (task != null && task.status == DownloadStatus.completed) {
      final sanitized = UrlValidator.sanitizeFileName(newName);
      final newPath = await StorageService.renameFile(task.savePath, sanitized);
      if (newPath != null) {
        task.savePath = newPath;
        task.fileName = sanitized;
        await _persistTasks();
        notifyListeners();
      }
    }
  }

  DownloadTask? _findTask(String id) {
    try {
      return _tasks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistTasks() async {
    await _storageService.saveHistory(_tasks);
  }
}
