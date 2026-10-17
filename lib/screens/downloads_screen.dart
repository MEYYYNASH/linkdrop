import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/download_provider.dart';
import '../providers/settings_provider.dart';
import '../models/download_task.dart';
import '../theme/app_theme.dart';
import '../widgets/download_tile.dart';
import '../widgets/batch_download_dialog.dart';
import 'video_player_screen.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final downloads = Provider.of<DownloadProvider>(context);
    final l10n = settings.l10n;

    final activeTasks = downloads.activeTasks;

    // Aggregate download speed
    double totalSpeedBytes = 0;
    for (final t in activeTasks) {
      if (t.status == DownloadStatus.downloading) {
        totalSpeedBytes += t.speedBytesPerSec;
      }
    }

    String formattedTotalSpeed;
    if (totalSpeedBytes >= 1024 * 1024) {
      formattedTotalSpeed = '${(totalSpeedBytes / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else {
      formattedTotalSpeed = '${(totalSpeedBytes / 1024).toStringAsFixed(1)} KB/s';
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          l10n.get('downloads_title'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: l10n.get('btn_batch_download'),
            icon: const Icon(Icons.playlist_add_rounded, color: AppTheme.primaryVioletLight),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => BatchDownloadDialog(
                  l10n: l10n,
                  onStartBatch: (urls) {
                    downloads.addBatchDownloads(urls);
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Aggregate Speed Banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryVioletDark.withOpacity(0.4),
                  const Color(0xFF131326),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryViolet.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${activeTasks.length} ${l10n.get('active_downloads')}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'HTTP/HTTPS chunked native stream',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryViolet.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryVioletLight.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.speed_rounded, color: AppTheme.primaryVioletLight, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        formattedTotalSpeed,
                        style: const TextStyle(
                          color: AppTheme.primaryVioletLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Active Downloads List
          Expanded(
            child: activeTasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.download_done_rounded, color: Color(0xFF333355), size: 56),
                        const SizedBox(height: 16),
                        Text(
                          l10n.get('no_active_downloads'),
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
                    itemCount: activeTasks.length,
                    itemBuilder: (context, index) {
                      final task = activeTasks[index];
                      return DownloadTile(
                        task: task,
                        l10n: l10n,
                        onPause: () => downloads.pauseDownload(task.id),
                        onResume: () => downloads.resumeDownload(task.id),
                        onCancel: () => downloads.cancelDownload(task.id),
                        onRetry: () => downloads.retryDownload(task.id),
                        onDelete: () => downloads.deleteDownload(task.id),
                        onOpen: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => VideoPlayerScreen(
                                filePath: task.savePath,
                                title: task.fileName,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
