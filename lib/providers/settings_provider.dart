import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localization.dart';

class SettingsProvider extends ChangeNotifier {
  String _languageCode = 'en';
  ThemeType _themeType = ThemeType.darkViolet;
  bool _blockPrivateIps = true;
  bool _enforceHttps = true;
  bool _autoSanitizeFileNames = true;
  String _gitHubRepo = 'MEYYYNASH/LINKDROP';
  String? _customDownloadPath;
  static const String appVersion = '1.0.0';

  String get languageCode => _languageCode;
  ThemeType get themeType => _themeType;
  bool get blockPrivateIps => _blockPrivateIps;
  bool get enforceHttps => _enforceHttps;
  bool get autoSanitizeFileNames => _autoSanitizeFileNames;
  String get gitHubRepo => _gitHubRepo;
  String? get customDownloadPath => _customDownloadPath;

  AppLocalization get l10n => AppLocalization(_languageCode);

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
