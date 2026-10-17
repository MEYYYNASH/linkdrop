import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/download_provider.dart';
import '../providers/settings_provider.dart';
import '../models/media_metadata.dart';
import '../services/clipboard_service.dart';
import '../theme/app_theme.dart';
import '../widgets/video_preview_card.dart';
import '../widgets/batch_download_dialog.dart';
import 'video_player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _urlController = TextEditingController();
  MediaMetadata? _analyzedMeta;
  bool _isAnalyzing = false;
  String? _detectedClipboardUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkClipboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  Future<void> _checkClipboard() async {
    final clip = await ClipboardService.checkClipboardForVideoUrl();
    if (clip != null && clip != _urlController.text.trim()) {
      if (mounted) {
        setState(() {
          _detectedClipboardUrl = clip;
        });
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        _urlController.text = data!.text!.trim();
        _detectedClipboardUrl = null;
      });
      _analyzeCurrentUrl();
    }
  }

  Future<void> _analyzeCurrentUrl() async {
    final text = _urlController.text.trim();
    if (text.isEmpty) return;

    final downloadProvider = Provider.of<DownloadProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    setState(() {
      _isAnalyzing = true;
      _analyzedMeta = null;
    });

    final meta = await downloadProvider.analyzeUrl(
      text,
      blockPrivateIps: settingsProvider.blockPrivateIps,
    );

    if (mounted) {
      setState(() {
        _analyzedMeta = meta;
        _isAnalyzing = false;
      });
    }
  }

  void _startDownload() {
    if (_analyzedMeta == null || !_analyzedMeta!.isDirectMedia) return;

    final downloadProvider = Provider.of<DownloadProvider>(context, listen: false);
    final fileName = _analyzedMeta!.suggestedFileName;
    final downloadUrl = _analyzedMeta!.resolvedUrl;

    downloadProvider.addDownload(
      url: downloadUrl,
      suggestedName: fileName,
      totalBytes: _analyzedMeta!.totalBytes,
      acceptsRanges: _analyzedMeta!.acceptsRanges,
      mimeType: _analyzedMeta!.mimeType,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.downloading_rounded, color: AppTheme.accentNeon, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Downloading: $fileName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1428),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );

    setState(() {
      _analyzedMeta = null;
      _urlController.clear();
    });
  }

  void _openBatchDialog() {
    final l10n = Provider.of<SettingsProvider>(context, listen: false).l10n;
    final downloadProvider = Provider.of<DownloadProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => BatchDownloadDialog(
        l10n: l10n,
        onStartBatch: (urls) {
          downloadProvider.addBatchDownloads(urls);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Queued ${urls.length} links for download'),
              backgroundColor: AppTheme.primaryVioletDark,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final downloads = Provider.of<DownloadProvider>(context);
    final l10n = settings.l10n;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryViolet, AppTheme.accentNeon],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.get('app_title'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                Text(
                  l10n.get('app_tagline'),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.get('btn_batch_download'),
            icon: const Icon(Icons.playlist_add_rounded, color: AppTheme.primaryVioletLight),
            onPressed: _openBatchDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 18, right: 18, top: 12, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Clipboard Auto-detect pill
            if (_detectedClipboardUrl != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryVioletDark.withOpacity(0.5),
                      const Color(0xFF1E1428).withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryViolet.withOpacity(0.6), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryViolet.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.content_paste_go_rounded, color: AppTheme.primaryVioletLight, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.get('clipboard_detected'),
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryViolet,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        setState(() {
                          _urlController.text = _detectedClipboardUrl!;
                          _detectedClipboardUrl = null;
                        });
                        _analyzeCurrentUrl();
                      },
                      child: Text(l10n.get('clipboard_action'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],

            // Input card with Paste, Clear and Analyze
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF13132B).withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.primaryViolet.withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryViolet.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.white, fontSize: 14.5),
                    decoration: InputDecoration(
                      hintText: l10n.get('paste_url_hint'),
                      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      prefixIcon: const Icon(Icons.link_rounded, color: AppTheme.primaryVioletLight),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_urlController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 20),
                              onPressed: () {
                                setState(() {
                                  _urlController.clear();
                                  _analyzedMeta = null;
                                });
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.paste_rounded, color: AppTheme.primaryVioletLight, size: 20),
                            onPressed: _pasteFromClipboard,
                          ),
                        ],
                      ),
                    ),
                    onSubmitted: (_) => _analyzeCurrentUrl(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryViolet,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isAnalyzing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.radar_rounded, size: 20),
                      label: Text(
                        _isAnalyzing ? l10n.get('analyzing_media') : l10n.get('btn_analyze'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _isAnalyzing ? null : _analyzeCurrentUrl,
                    ),
                  ),
                ],
              ),
            ),

            // Video Preview Card (Live player + metadata)
            if (_analyzedMeta != null)
              VideoPreviewCard(
                metadata: _analyzedMeta!,
                onStartDownload: _startDownload,
                l10n: l10n,
              ),

            // Privacy and Direct URL disclaimer
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF101024),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E1E38)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppTheme.cyanGlow, size: 22),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Supports direct media URLs and authorized downloadable content. Never bypasses DRM or password protected sites.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            // Recent Downloads Header
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.get('recent_downloads'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${downloads.completedTasks.length} saved',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Recent downloads list
            if (downloads.recentDownloads.isEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    l10n.get('no_recent_downloads'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ),
              ),
            ] else ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: downloads.recentDownloads.length,
                itemBuilder: (context, index) {
                  final task = downloads.recentDownloads[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF222245)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.play_circle_fill_rounded, color: AppTheme.primaryVioletLight, size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                task.formattedProgress,
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.fullscreen_rounded, color: Colors.white70),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => VideoPlayerScreen(
                                  filePath: task.savePath,
                                  title: task.fileName,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
