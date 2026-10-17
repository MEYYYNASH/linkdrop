import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/media_metadata.dart';
import '../l10n/app_localization.dart';
import '../theme/app_theme.dart';

class VideoPreviewCard extends StatefulWidget {
  final MediaMetadata metadata;
  final VoidCallback onStartDownload;
  final AppLocalization l10n;

  const VideoPreviewCard({
    super.key,
    required this.metadata,
    required this.onStartDownload,
    required this.l10n,
  });

  @override
  State<VideoPreviewCard> createState() => _VideoPreviewCardState();
}

class _VideoPreviewCardState extends State<VideoPreviewCard> {
  VideoPlayerController? _controller;
  bool _isPlayerInitialized = false;
  bool _hasPlayerError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(VideoPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metadata.resolvedUrl != widget.metadata.resolvedUrl) {
      _disposePlayer();
      _initializePlayer();
    }
  }

  void _initializePlayer() {
    if (!widget.metadata.isDirectMedia) return;

    try {
      final uri = Uri.parse(widget.metadata.resolvedUrl);
      _controller = VideoPlayerController.networkUrl(uri)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isPlayerInitialized = true;
            });
          }
        }).catchError((_) {
          if (mounted) {
            setState(() {
              _hasPlayerError = true;
            });
          }
        });
    } catch (_) {
      _hasPlayerError = true;
    }
  }

  void _disposePlayer() {
    _controller?.dispose();
    _controller = null;
    _isPlayerInitialized = false;
    _hasPlayerError = false;
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.metadata;
    final l10n = widget.l10n;

    if (!meta.isDirectMedia) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1428),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.dangerRed.withOpacity(0.5), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.warningAmber, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    meta.unsupportedReason?.contains('Private network') == true
                        ? l10n.get('security_blocked_title')
                        : l10n.get('unsupported_url_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              meta.unsupportedReason ?? l10n.get('unsupported_url_desc'),
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13.5, height: 1.5),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(20),
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
          // Live Video Preview Container
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            child: Container(
              height: 200,
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isPlayerInitialized && _controller != null) ...[
                    AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio > 0 ? _controller!.value.aspectRatio : 16 / 9,
                      child: VideoPlayer(_controller!),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(_controller!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        onPressed: () {
                          setState(() {
                            _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                          });
                        },
                      ),
                    ),
                  ] else if (_hasPlayerError) ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 40),
                            const SizedBox(height: 8),
                            Text(
                              l10n.get('player_error'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: AppTheme.primaryViolet),
                          const SizedBox(height: 12),
                          Text(
                            l10n.get('player_buffering'),
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Format Badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryVioletDark.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        meta.mimeType.split('/').last.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Metadata Info Section
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.movie_creation_outlined, color: AppTheme.primaryViolet, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meta.suggestedFileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.get('preview_sub'),
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF222245), height: 1),
                const SizedBox(height: 16),

                // Metrics Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetricItem(
                      label: l10n.get('file_size'),
                      value: meta.formattedSize,
                      icon: Icons.data_usage_rounded,
                    ),
                    _buildMetricItem(
                      label: l10n.get('range_support'),
                      value: meta.acceptsRanges ? l10n.get('range_yes') : l10n.get('range_no'),
                      icon: meta.acceptsRanges ? Icons.check_circle_outline : Icons.info_outline,
                      valueColor: meta.acceptsRanges ? AppTheme.successGreen : AppTheme.warningAmber,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Start Download Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryViolet,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.download_rounded, size: 22),
                    label: Text(
                      l10n.get('btn_download_now'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: widget.onStartDownload,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
