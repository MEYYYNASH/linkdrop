import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../services/update_service.dart';
import '../services/storage_service.dart';
import '../widgets/update_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final UpdateService _updateService = UpdateService();
  bool _isCheckingUpdate = false;
  String? _updateStatusMessage;
  String _downloadLocation = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadStorageLocation();
  }

  Future<void> _loadStorageLocation() async {
    final storage = StorageService();
    final loc = await storage.getDownloadDirectory();
    if (mounted) {
      setState(() {
        _downloadLocation = loc;
      });
    }
  }

  Future<void> _checkForUpdate() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final l10n = settings.l10n;

    setState(() {
      _isCheckingUpdate = true;
      _updateStatusMessage = null;
    });

    final info = await _updateService.checkForUpdate(
      repoOwnerAndName: settings.gitHubRepo,
      currentVersion: SettingsProvider.appVersion,
    );

    if (!mounted) return;

    setState(() {
      _isCheckingUpdate = false;
    });

    if (info != null) {
      showDialog(
        context: context,
        builder: (ctx) => UpdateDialog(
          updateInfo: info,
          currentVersion: SettingsProvider.appVersion,
          l10n: l10n,
        ),
      );
    } else {
      setState(() {
        _updateStatusMessage = l10n.get('update_uptodate');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.get('update_uptodate')),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _editGitHubRepo() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final controller = TextEditingController(text: settings.gitHubRepo);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Configure GitHub Repository', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'owner/repository (e.g. MEYYYNASH/LINKDROP)',
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryViolet),
            child: const Text('Save'),
            onPressed: () {
              settings.setGitHubRepo(controller.text);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final l10n = settings.l10n;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          l10n.get('settings_title'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
        children: [
          // General Section
          _buildSectionHeader(l10n.get('section_general')),
          Container(
            decoration: _cardDecoration(),
            child: ListTile(
              leading: const Icon(Icons.language_rounded, color: AppTheme.primaryVioletLight),
              title: Text(l10n.get('language_label'), style: const TextStyle(color: Colors.white, fontSize: 14.5)),
              subtitle: Text(settings.languageCode == 'km' ? 'ភាសាខ្មែរ (Khmer)' : 'English (US)', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              trailing: DropdownButton<String>(
                value: settings.languageCode,
                dropdownColor: AppTheme.darkCard,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'km', child: Text('ភាសាខ្មែរ', style: TextStyle(color: Colors.white))),
                ],
                onChanged: (val) {
                  if (val != null) settings.setLanguage(val);
                },
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Appearance Section
          _buildSectionHeader(l10n.get('section_appearance')),
          Container(
            decoration: _cardDecoration(),
            child: ListTile(
              leading: const Icon(Icons.palette_outlined, color: AppTheme.accentNeon),
              title: Text(l10n.get('theme_label'), style: const TextStyle(color: Colors.white, fontSize: 14.5)),
              subtitle: Text(
                settings.themeType == ThemeType.amoled
                    ? l10n.get('theme_amoled')
                    : settings.themeType == ThemeType.light
                        ? l10n.get('theme_light')
                        : l10n.get('theme_dark_violet'),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              trailing: DropdownButton<ThemeType>(
                value: settings.themeType,
                dropdownColor: AppTheme.darkCard,
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(value: ThemeType.darkViolet, child: Text(l10n.get('theme_dark_violet'), style: const TextStyle(color: Colors.white, fontSize: 13))),
                  DropdownMenuItem(value: ThemeType.amoled, child: Text(l10n.get('theme_amoled'), style: const TextStyle(color: Colors.white, fontSize: 13))),
                  DropdownMenuItem(value: ThemeType.light, child: Text(l10n.get('theme_light'), style: const TextStyle(color: Colors.white, fontSize: 13))),
                ],
                onChanged: (val) {
                  if (val != null) settings.setTheme(val);
                },
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Storage Section
          _buildSectionHeader(l10n.get('section_storage')),
          Container(
            decoration: _cardDecoration(),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_outlined, color: AppTheme.cyanGlow),
                  title: Text(l10n.get('storage_path_label'), style: const TextStyle(color: Colors.white, fontSize: 14.5)),
                  subtitle: Text(_downloadLocation, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                ),
                const Divider(color: Color(0xFF1F1F3D), height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.cleaning_services_rounded, color: AppTheme.primaryVioletLight),
                  title: Text(l10n.get('safe_filenames'), style: const TextStyle(color: Colors.white, fontSize: 14.5)),
                  subtitle: Text(l10n.get('safe_filenames_desc'), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  value: settings.autoSanitizeFileNames,
                  activeColor: AppTheme.primaryViolet,
                  onChanged: (val) => settings.setAutoSanitize(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Privacy & Security Section
          _buildSectionHeader(l10n.get('section_security')),
          Container(
            decoration: _cardDecoration(),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.security_rounded, color: AppTheme.successGreen),
                  title: Text(l10n.get('block_private_ip'), style: const TextStyle(color: Colors.white, fontSize: 14.5)),
                  subtitle: Text(l10n.get('block_private_ip_desc'), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  value: settings.blockPrivateIps,
                  activeColor: AppTheme.primaryViolet,
                  onChanged: (val) => settings.setBlockPrivateIps(val),
                ),
                const Divider(color: Color(0xFF1F1F3D), height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.lock_outline_rounded, color: AppTheme.warningAmber),
                  title: Text(l10n.get('enforce_https'), style: const TextStyle(color: Colors.white, fontSize: 14.5)),
                  subtitle: Text(l10n.get('enforce_https_desc'), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  value: settings.enforceHttps,
                  activeColor: AppTheme.primaryViolet,
                  onChanged: (val) => settings.setEnforceHttps(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // GitHub Software Updates
          _buildSectionHeader(l10n.get('section_updates')),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.autorenew_rounded, color: AppTheme.primaryVioletLight, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${l10n.get('current_version')}: v${SettingsProvider.appVersion}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Repo: ${settings.gitHubRepo}',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryVioletLight),
                      onPressed: _editGitHubRepo,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryViolet,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isCheckingUpdate
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_download_rounded, size: 20),
                  label: Text(
                    _isCheckingUpdate ? 'Checking GitHub...' : l10n.get('btn_check_update'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isCheckingUpdate ? null : _checkForUpdate,
                ),
                if (_updateStatusMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _updateStatusMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.successGreen, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // About Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF101020),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E1E38)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.get('about_app'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.get('about_desc'),
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppTheme.darkCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF222245), width: 1.2),
    );
  }
}
