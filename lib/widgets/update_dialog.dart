import 'dart:io';
import 'package:flutter/material.dart';
import '../models/update_info.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localization.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  final String currentVersion;
  final AppLocalization l10n;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    required this.currentVersion,
    required this.l10n,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  final UpdateService _updateService = UpdateService();
  bool _isDownloading = false;
  bool _isVerifying = false;
  bool _isReadyToInstall = false;
  int _receivedBytes = 0;
  int _totalBytes = -1;
  String? _errorMessage;
  File? _downloadedFile;

  @override
  void initState() {
    super.initState();
    _checkExistingFile();
  }

  Future<void> _checkExistingFile() async {
    final fileName = Platform.isAndroid
        ? 'LINKDROP-v${widget.updateInfo.version}.apk'
        : 'LINKDROP-v${widget.updateInfo.version}.exe';
    final existing = await _updateService.getExistingSavedUpdate(fileName);
    if (existing != null && mounted) {
      setState(() {
        _downloadedFile = existing;
        _isReadyToInstall = true;
      });
    }
  }

  double get _progress {
    if (_totalBytes <= 0) return 0.0;
    return (_receivedBytes / _totalBytes).clamp(0.0, 1.0);
  }

  Future<void> _startUpdateDownload() async {
    final info = widget.updateInfo;
    String? downloadUrl;
    String fileName;

    if (Platform.isAndroid) {
      downloadUrl = info.apkUrl;
      fileName = 'LINKDROP-v${info.version}.apk';
    } else {
      downloadUrl = info.exeUrl;
      fileName = 'LINKDROP-v${info.version}.exe';
    }

    if (downloadUrl == null) {
      setState(() {
        _errorMessage = 'No compatible release artifact found for this platform.';
      });
      return;
    }

    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });

    try {
      final file = await _updateService.downloadUpdate(
        downloadUrl: downloadUrl,
        fileName: fileName,
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              _receivedBytes = received;
              _totalBytes = total;
            });
          }
        },
      );

      // Verify SHA-256 if available in manifest
      final expectedHash = Platform.isAndroid ? info.sha256Apk : info.sha256Exe;
      if (expectedHash != null && expectedHash.isNotEmpty) {
        setState(() {
          _isVerifying = true;
        });

        final isValid = await UpdateService.verifyChecksum(file, expectedHash);
        if (!isValid) {
          await file.delete();
          if (mounted) {
            setState(() {
              _isDownloading = false;
              _isVerifying = false;
              _errorMessage = 'SHA-256 Checksum mismatch! Update package may be corrupted or tampered with.';
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isVerifying = false;
          _isReadyToInstall = true;
          _downloadedFile = file;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isVerifying = false;
          _errorMessage = 'Update download failed: ${e.toString().split('\n').first}';
        });
      }
    }
  }

  Future<void> _triggerInstallation() async {
    if (_downloadedFile != null && _downloadedFile!.existsSync()) {
      await UpdateService.installUpdate(_downloadedFile!);
    }
  }

  @override
  void dispose() {
    _updateService.cancelDownload();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final info = widget.updateInfo;

    return AlertDialog(
      backgroundColor: AppTheme.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.primaryVioletDark, width: 1.5),
      ),
      title: Row(
        children: [
          const Icon(Icons.system_update_rounded, color: AppTheme.primaryVioletLight, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              info.isUpdateAvailable
                  ? '${l10n.get('update_available')} (v${info.version})'
                  : 'Latest Release (v${info.version})',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${l10n.get('current_version')}: v${widget.currentVersion} → v${info.version}',
              style: const TextStyle(color: AppTheme.cyanGlow, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'Release Notes:',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF222245)),
              ),
              child: Text(
                info.releaseNotes,
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, height: 1.4),
              ),
            ),
            if (_isDownloading) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: const Color(0xFF1E1E38),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryViolet),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isVerifying ? l10n.get('update_verifying') : l10n.get('update_installing'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '${(_progress * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(color: AppTheme.primaryVioletLight, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ],
            if (_isReadyToInstall) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.get('update_success_ready'),
                      style: const TextStyle(color: AppTheme.successGreen, fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (_downloadedFile != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Saved permanently in: ${_downloadedFile!.path}',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppTheme.dangerRed, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Close', style: TextStyle(color: Colors.white60)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (!_isDownloading && !_isReadyToInstall)
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryViolet),
            onPressed: _startUpdateDownload,
            child: Text(info.isUpdateAvailable ? l10n.get('update_download_btn') : 'Re-download Package'),
          ),
        if (_isReadyToInstall) ...[
          TextButton(
            onPressed: _isDownloading ? null : _startUpdateDownload,
            child: const Text('Re-download', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen),
            onPressed: _triggerInstallation,
            child: const Text('Install Now'),
          ),
        ],
      ],
    );
  }
}
