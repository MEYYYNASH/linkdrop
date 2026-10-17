import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/download_task.dart';
import '../l10n/app_localization.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';

class DownloadTile extends StatelessWidget {
  final DownloadTask task;
  final AppLocalization l10n;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  final VoidCallback onDelete;
  final VoidCallback? onOpen;

  const DownloadTile({
    super.key,
    required this.task,
    required this.l10n,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onRetry,
    required this.onDelete,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloading = task.status == DownloadStatus.downloading;
    final isPaused = task.status == DownloadStatus.paused;
    final isCompleted = task.status == DownloadStatus.completed;
    final isFailed = task.status == DownloadStatus.failed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDownloading
              ? AppTheme.primaryViolet.withOpacity(0.5)
              : const Color(0xFF222245),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon, File Name & Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppTheme.successGreen.withOpacity(0.15)
                      : isFailed
                          ? AppTheme.dangerRed.withOpacity(0.15)
                          : AppTheme.primaryViolet.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : isFailed
                          ? Icons.error_outline_rounded
                          : Icons.video_file_rounded,
                  color: isCompleted
                      ? AppTheme.successGreen
                      : isFailed
                          ? AppTheme.dangerRed
                          : AppTheme.primaryVioletLight,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.formattedProgress,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(),
            ],
          ),

          // Progress Bar (if not completed or failed)
          if (!isCompleted && !isFailed) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: task.totalBytes > 0 ? (task.downloadedBytes / task.totalBytes) : null,
                minHeight: 6,
                backgroundColor: const Color(0xFF1E1E38),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isPaused ? AppTheme.warningAmber : AppTheme.primaryViolet,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Live Metrics Row: Speed, ETA, Percentage
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.speed_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      isDownloading ? task.formattedSpeed : '--',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      isDownloading ? task.formattedEta : '--',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                Text(
                  task.totalBytes > 0 ? '${task.progressPercentage.toStringAsFixed(1)}%' : '--%',
                  style: TextStyle(
                    color: isPaused ? AppTheme.warningAmber : AppTheme.primaryVioletLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ],

          if (isFailed && task.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              task.errorMessage!,
              style: const TextStyle(color: AppTheme.dangerRed, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Action Controls Row
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF1F1F3D), height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isDownloading)
                IconButton(
                  tooltip: l10n.get('action_pause'),
                  icon: const Icon(Icons.pause_circle_outline, color: AppTheme.warningAmber),
                  onPressed: onPause,
                ),
              if (isPaused)
                IconButton(
                  tooltip: l10n.get('action_resume'),
                  icon: const Icon(Icons.play_circle_outline, color: AppTheme.primaryViolet),
                  onPressed: onResume,
                ),
              if (isFailed)
                IconButton(
                  tooltip: l10n.get('action_retry'),
                  icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryVioletLight),
                  onPressed: onRetry,
                ),
              if (isCompleted) ...[
                if (task.sha256Checksum != null)
                  IconButton(
                    tooltip: l10n.get('sha256_hash'),
                    icon: const Icon(Icons.verified_outlined, color: AppTheme.cyanGlow, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: task.sha256Checksum!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.get('copied_sha256'))),
                      );
                    },
                  ),
                IconButton(
                  tooltip: l10n.get('share_file'),
                  icon: const Icon(Icons.share_outlined, color: Colors.white70, size: 20),
                  onPressed: () => StorageService.shareFile(task.savePath),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                  label: Text(l10n.get('action_open'), style: const TextStyle(color: Colors.white)),
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.primaryVioletDark,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  onPressed: onOpen ?? () => StorageService.openFile(task.savePath),
                ),
              ] else
                IconButton(
                  tooltip: l10n.get('action_cancel'),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                  onPressed: onCancel,
                ),
              IconButton(
                tooltip: l10n.get('action_delete'),
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.dangerRed, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color bg;
    Color fg;
    String text;

    switch (task.status) {
      case DownloadStatus.downloading:
        bg = AppTheme.primaryViolet.withOpacity(0.2);
        fg = AppTheme.primaryVioletLight;
        text = l10n.get('status_downloading');
        break;
      case DownloadStatus.paused:
        bg = AppTheme.warningAmber.withOpacity(0.2);
        fg = AppTheme.warningAmber;
        text = l10n.get('status_paused');
        break;
      case DownloadStatus.completed:
        bg = AppTheme.successGreen.withOpacity(0.2);
        fg = AppTheme.successGreen;
        text = l10n.get('status_completed');
        break;
      case DownloadStatus.failed:
        bg = AppTheme.dangerRed.withOpacity(0.2);
        fg = AppTheme.dangerRed;
        text = l10n.get('status_failed');
        break;
      default:
        bg = Colors.white10;
        fg = Colors.white70;
        text = l10n.get('status_queued');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
