import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../models/download_task.dart';

class StorageService {
  static const String _historyFileName = 'linkdrop_history.json';
  String? _customDownloadPath;

  void setCustomPath(String? path) {
    _customDownloadPath = path;
  }

  /// Get the standard download directory for the platform
  Future<String> getDownloadDirectory() async {
    if (_customDownloadPath != null && Directory(_customDownloadPath!).existsSync()) {
      return _customDownloadPath!;
    }

    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final winDownloads = p.join(userProfile, 'Downloads', 'LINKDROP');
        final dir = Directory(winDownloads);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return winDownloads;
      }
    }

    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final linkdropDir = Directory(p.join(extDir.path, 'LINKDROP'));
        if (!linkdropDir.existsSync()) {
          linkdropDir.createSync(recursive: true);
        }
        return linkdropDir.path;
      }
    } catch (_) {}

    final appDocDir = await getApplicationDocumentsDirectory();
    final fallback = Directory(p.join(appDocDir.path, 'LINKDROP'));
    if (!fallback.existsSync()) {
      fallback.createSync(recursive: true);
    }
    return fallback.path;
  }

  /// Saves the list of tasks to local JSON history
  Future<void> saveHistory(List<DownloadTask> tasks) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final file = File(p.join(appDocDir.path, _historyFileName));
      final list = tasks.map((t) => t.toJson()).toList();
      await file.writeAsString(jsonEncode(list));
    } catch (e) {
      // ignore
    }
  }

  /// Loads tasks from local JSON history
  Future<List<DownloadTask>> loadHistory() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final file = File(p.join(appDocDir.path, _historyFileName));
      if (!file.existsSync()) return [];

      final content = await file.readAsString();
      final list = jsonDecode(content) as List;
      return list.map((item) => DownloadTask.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Generates a unique file path avoiding collision
  Future<String> getUniqueFilePath(String directory, String fileName) async {
    var baseName = p.basenameWithoutExtension(fileName);
    var extension = p.extension(fileName);
    var targetPath = p.join(directory, fileName);
    var counter = 1;

    while (File(targetPath).existsSync()) {
      targetPath = p.join(directory, '${baseName}_$counter$extension');
      counter++;
    }
    return targetPath;
  }

  /// Calculates SHA-256 hash of a file on disk
  static Future<String> calculateSha256(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return '';
    final stream = file.openRead();
    final digest = await sha256.bind(stream).first;
    return digest.toString();
  }

  /// Opens the file using the platform's default application
  static Future<OpenResult> openFile(String filePath) async {
    return await OpenFilex.open(filePath);
  }

  /// Shares the file using platform share sheet
  static Future<void> shareFile(String filePath, {String? text}) async {
    if (await File(filePath).exists()) {
      await Share.shareXFiles([XFile(filePath)], text: text ?? 'Shared from LINKDROP');
    }
  }

  /// Deletes a file from disk
  static Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Renames a file on disk
  static Future<String?> renameFile(String oldPath, String newName) async {
    try {
      final file = File(oldPath);
      if (await file.exists()) {
        final dir = p.dirname(oldPath);
        final newPath = p.join(dir, newName);
        await file.rename(newPath);
        return newPath;
      }
    } catch (_) {}
    return null;
  }
}
