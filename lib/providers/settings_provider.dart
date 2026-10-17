import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localization.dart';
import '../models/update_info.dart';
import '../services/update_service.dart';

class SettingsProvider extends ChangeNotifier {
  String _languageCode = 'en';
  ThemeType _themeType = ThemeType.darkViolet;
  bool _blockPrivateIps = true;
  bool _enforceHttps = true;
  bool _autoSanitizeFileNames = true;
  String _gitHubRepo = 'MEYYYNASH/linkdrop';
  String? _customDownloadPath;
  static const String appVersion = '1.1.2';

  UpdateInfo? _latestRelease;
  String? _latestVersionOnGitHub;
  bool _isCheckingUpdate = false;

  String get languageCode => _languageCode;
  ThemeType get themeType => _themeType;
  bool get blockPrivateIps => _blockPrivateIps;
  bool get enforceHttps => _enforceHttps;
  bool get autoSanitizeFileNames => _autoSanitizeFileNames;
  String get gitHubRepo => _gitHubRepo;
  String? get customDownloadPath => _customDownloadPath;
  UpdateInfo? get latestRelease => _latestRelease;
  String? get latestVersionOnGitHub => _latestVersionOnGitHub;
  bool get hasUpdateAvailable => _latestRelease?.isUpdateAvailable ?? false;
  bool get isCheckingUpdate => _isCheckingUpdate;

  AppLocalization get l10n => AppLocalization(_languageCode);

  Future<UpdateInfo?> checkGitHubUpdate() async {
    _isCheckingUpdate = true;
    notifyListeners();

    try {
      final updater = UpdateService();
      final info = await updater.checkForUpdate(
        repoOwnerAndName: _gitHubRepo,
        currentVersion: appVersion,
      );

      _latestRelease = info;
      if (info != null) {
        _latestVersionOnGitHub = info.version;
      }
      return info;
    } catch (_) {
      return null;
    } finally {
      _isCheckingUpdate = false;
      notifyListeners();
    }
  }

  void setLatestRelease(UpdateInfo? info) {
    _latestRelease = info;
    if (info != null) {
      _latestVersionOnGitHub = info.version;
    }
    notifyListeners();
  }

  void setLanguage(String code) {
    if (_languageCode != code) {
      _languageCode = code;
      notifyListeners();
    }
  }

  void setTheme(ThemeType type) {
    if (_themeType != type) {
      _themeType = type;
      notifyListeners();
    }
  }

  void setBlockPrivateIps(bool value) {
    _blockPrivateIps = value;
    notifyListeners();
  }

  void setEnforceHttps(bool value) {
    _enforceHttps = value;
    notifyListeners();
  }

  void setAutoSanitize(bool value) {
    _autoSanitizeFileNames = value;
    notifyListeners();
  }

  void setGitHubRepo(String repo) {
    _gitHubRepo = repo.trim();
    notifyListeners();
  }

  void setCustomDownloadPath(String? path) {
    _customDownloadPath = path;
    notifyListeners();
  }
}
