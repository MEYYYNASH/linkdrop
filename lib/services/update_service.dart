import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/update_info.dart';
import 'storage_service.dart';

class UpdateService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 10),
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'LINKDROP-App-Updater',
      },
    ),
  );

  CancelToken? _downloadCancelToken;

  /// Compares semantic versions (e.g. "1.0.0" vs "1.0.1")
  /// Returns true if remoteVersion is strictly newer than currentVersion
  static bool isNewerVersion(String currentVersion, String remoteVersion) {
    try {
      final cleanCurrent = currentVersion.trim().replaceAll(RegExp(r'^v'), '').split('+').first;
      final cleanRemote = remoteVersion.trim().replaceAll(RegExp(r'^v'), '').split('+').first;

      final currentParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final remoteParts = cleanRemote.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      while (currentParts.length < 3) {
        currentParts.add(0);
      }
      while (remoteParts.length < 3) {
        remoteParts.add(0);
      }

      for (var i = 0; i < 3; i++) {
        if (remoteParts[i] > currentParts[i]) return true;
        if (remoteParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Checks the configured GitHub repository for the latest release and returns UpdateInfo
  Future<UpdateInfo?> checkForUpdate({
    required String repoOwnerAndName,
    required String currentVersion,
  }) async {
    final cleanRepo = repoOwnerAndName.trim().replaceAll(RegExp(r'^https?://github\.com/'), '');
    if (!cleanRepo.contains('/')) return null;

    final url = 'https://api.github.com/repos/$cleanRepo/releases/latest';

    try {
      final response = await _dio.get(url);
      if (response.statusCode != 200 || response.data == null) {
        return null;
      }

      final data = response.data as Map<String, dynamic>;
      final tagName = data['tag_name']?.toString() ?? '';
      final remoteVersion = tagName.replaceAll(RegExp(r'^v'), '');

      // Check whether remote version is newer than current version
      final hasUpdate = isNewerVersion(currentVersion, remoteVersion);

      final releaseNotes = data['body']?.toString() ?? 'No release notes provided.';
      final assets = (data['assets'] as List?) ?? [];

      String? apkUrl;
      String? exeUrl;
      String? latestJsonUrl;

      for (final asset in assets) {
        final name = (asset['name']?.toString() ?? '').toLowerCase();
        final downloadUrl = asset['browser_download_url']?.toString();

        if (name.endsWith('.apk')) {
          apkUrl = downloadUrl;
        } else if (name.endsWith('.exe') || name.endsWith('-windows.zip') || name.endsWith('.msix')) {
          exeUrl = downloadUrl;
        } else if (name == 'latest.json') {
          latestJsonUrl = downloadUrl;
        }
      }

      String? sha256Apk;
      String? sha256Exe;

      // If latest.json exists in release assets, fetch it to get precalculated SHA-256
      if (latestJsonUrl != null) {
        try {
          final jsonResp = await _dio.get(latestJsonUrl);
          if (jsonResp.statusCode == 200 && jsonResp.data != null) {
            final manifest = jsonResp.data is String ? jsonDecode(jsonResp.data) : jsonResp.data;
            sha256Apk = manifest['sha256_apk'];
            sha256Exe = manifest['sha256_exe'];
            apkUrl = manifest['apk_url'] ?? apkUrl;
            exeUrl = manifest['exe_url'] ?? exeUrl;
          }
        } catch (_) {}
      }

      return UpdateInfo(
        version: remoteVersion,
        releaseNotes: releaseNotes,
        apkUrl: apkUrl,
        exeUrl: exeUrl,
        sha256Apk: sha256Apk,
        sha256Exe: sha256Exe,
        publishedAt: data['published_at'] != null ? DateTime.tryParse(data['published_at']) : null,
        isUpdateAvailable: hasUpdate,
      );
    } catch (e) {
      return null;
    }
  }

  /// Returns saved update file if it exists in the downloads directory
  Future<File?> getExistingSavedUpdate(String fileName) async {
    try {
      final storageService = StorageService();
      final downloadDir = await storageService.getDownloadDirectory();
      final targetFile = File(p.join(downloadDir, fileName));
      if (await targetFile.exists() && (await targetFile.length()) > 0) {
        return targetFile;
      }
    } catch (_) {}
    return null;
  }

  /// Downloads update asset with live progress directly to persistent storage with binary headers & validation
  Future<File> downloadUpdate({
    required String downloadUrl,
    required String fileName,
    required void Function(int received, int total) onProgress,
  }) async {
    _downloadCancelToken = CancelToken();

    final storageService = StorageService();
    final downloadDir = await storageService.getDownloadDirectory();
    final savePath = p.join(downloadDir, fileName);
    final targetFile = File(savePath);

    if (targetFile.existsSync()) {
      try {
        targetFile.deleteSync();
      } catch (_) {}
    }

    final downloadDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 15),
        followRedirects: true,
        maxRedirects: 8,
        headers: {
          'Accept': '*/*',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        },
      ),
    );

    await downloadDio.download(
      downloadUrl,
      savePath,
      cancelToken: _downloadCancelToken,
      onReceiveProgress: onProgress,
    );

    // Validate that the file is not empty and is a valid archive
    if (!targetFile.existsSync() || targetFile.lengthSync() < 10000) {
      throw Exception('Downloaded update package is invalid or incomplete. Please check your network.');
    }

    // Verify it starts with standard ZIP/APK header (PK..)
    if (fileName.endsWith('.apk')) {
      final header = await targetFile.openRead(0, 4).first;
      if (header.length < 4 || header[0] != 0x50 || header[1] != 0x4B) {
        try { targetFile.deleteSync(); } catch (_) {}
        throw Exception('The server returned an invalid file instead of an APK. Please download directly from GitHub.');
      }
    }

    return targetFile;
  }

  /// Verifies SHA-256 of downloaded file
  static Future<bool> verifyChecksum(File file, String expectedSha256) async {
    if (!await file.exists()) return false;
    final stream = file.openRead();
    final digest = await sha256.bind(stream).first;
    return digest.toString().toLowerCase() == expectedSha256.trim().toLowerCase();
  }

  /// Triggers platform package installer
  static Future<bool> installUpdate(File updateFile) async {
    if (!updateFile.existsSync()) return false;

    if (Platform.isAndroid) {
      final result = await OpenFilex.open(
        updateFile.path,
        type: 'application/vnd.android.package-archive',
      );
      return result.type == ResultType.done;
    } else if (Platform.isWindows) {
      final result = await OpenFilex.open(updateFile.path);
      return result.type == ResultType.done;
    }
    return false;
  }

  /// Cancels in-progress update download
  void cancelDownload() {
    _downloadCancelToken?.cancel('Cancelled by user');
    _downloadCancelToken = null;
  }
}
