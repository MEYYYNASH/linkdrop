import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/download_provider.dart';
import '../providers/settings_provider.dart';
import '../models/download_task.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import 'video_player_screen.dart';

enum SortMode {
  dateDesc,
  dateAsc,
  sizeDesc,
  nameAsc,
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  SortMode _sortMode = SortMode.dateDesc;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showRenameDialog(DownloadTask task) {
    final controller = TextEditingController(text: task.fileName);
    final downloadProvider = Provider.of<DownloadProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename File', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter new file name',
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryViolet),
            child: const Text('Rename'),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                downloadProvider.renameTaskFile(task.id, newName);
                Navigator.of(ctx).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(DownloadTask task) {
    final downloadProvider = Provider.of<DownloadProvider>(context, listen: false);
    final l10n = Provider.of<SettingsProvider>(context, listen: false).l10n;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.get('delete_confirm_title'), style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          l10n.get('delete_confirm_desc'),
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            child: const Text('Delete'),
            onPressed: () {
              downloadProvider.deleteDownload(task.id, deleteFileFromDisk: true);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showFileInfo(DownloadTask task) {
    final l10n = Provider.of<SettingsProvider>(context, listen: false).l10n;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppTheme.primaryVioletLight),
                const SizedBox(width: 10),
                const Text(
                  'Media File Details',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _infoRow('Name', task.fileName),
            _infoRow('Size', task.formattedProgress),
            _infoRow('Path', task.savePath),
            _infoRow('Format', task.mimeType),
            if (task.sha256Checksum != null) ...[
              const SizedBox(height: 8),
              const Text('SHA-256 Checksum:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.sha256Checksum!,
                      style: const TextStyle(color: AppTheme.cyanGlow, fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: task.sha256Checksum!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.get('copied_sha256'))),
                      );
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final downloads = Provider.of<DownloadProvider>(context);
    final l10n = settings.l10n;

    // Filter by search query
    final query = _searchController.text.trim().toLowerCase();
    var list = downloads.completedTasks.where((t) {
      if (query.isEmpty) return true;
      return t.fileName.toLowerCase().contains(query);
    }).toList();

    // Sort list
    list.sort((a, b) {
      switch (_sortMode) {
        case SortMode.dateDesc:
          final aDate = a.completedAt ?? a.createdAt;
          final bDate = b.completedAt ?? b.createdAt;
          return bDate.compareTo(aDate);
        case SortMode.dateAsc:
          final aDate = a.completedAt ?? a.createdAt;
          final bDate = b.completedAt ?? b.createdAt;
          return aDate.compareTo(bDate);
        case SortMode.sizeDesc:
          return b.downloadedBytes.compareTo(a.downloadedBytes);
        case SortMode.nameAsc:
          return a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          l10n.get('history_title'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          PopupMenuButton<SortMode>(
            icon: const Icon(Icons.sort_rounded, color: AppTheme.primaryVioletLight),
            tooltip: l10n.get('sort_by'),
            onSelected: (mode) {
              setState(() {
                _sortMode = mode;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: SortMode.dateDesc,
                child: Text(l10n.get('sort_date_desc')),
              ),
              PopupMenuItem(
                value: SortMode.dateAsc,
                child: Text(l10n.get('sort_date_asc')),
              ),
              PopupMenuItem(
                value: SortMode.sizeDesc,
                child: Text(l10n.get('sort_size_desc')),
              ),
              PopupMenuItem(
                value: SortMode.nameAsc,
                child: Text(l10n.get('sort_name_asc')),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: l10n.get('search_hint'),
                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.darkCard,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // File List
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.video_library_outlined, color: Color(0xFF333355), size: 56),
                        const SizedBox(height: 16),
                        Text(
                          l10n.get('no_history'),
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final task = list[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF222245)),
                        ),
                        child: Row(
                          children: [
                            // Thumbnail / Video Play Action
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => VideoPlayerScreen(
                                      filePath: task.savePath,
                                      title: task.fileName,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryVioletDark.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.primaryViolet.withOpacity(0.4)),
                                ),
                                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // File Details
                            Expanded(
                              child: InkWell(
                                onTap: () => _showFileInfo(task),
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
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      task.formattedProgress,
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Actions Popup Menu
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
                              onSelected: (val) {
                                switch (val) {
                                  case 'play':
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => VideoPlayerScreen(
                                          filePath: task.savePath,
                                          title: task.fileName,
                                        ),
                                      ),
                                    );
                                    break;
                                  case 'open':
                                    StorageService.openFile(task.savePath);
                                    break;
                                  case 'share':
                                    StorageService.shareFile(task.savePath);
                                    break;
                                  case 'rename':
                                    _showRenameDialog(task);
                                    break;
                                  case 'info':
                                    _showFileInfo(task);
                                    break;
                                  case 'delete':
                                    _showDeleteDialog(task);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(value: 'play', child: Text(l10n.get('play_offline'))),
                                PopupMenuItem(value: 'open', child: Text(l10n.get('action_open'))),
                                PopupMenuItem(value: 'share', child: Text(l10n.get('share_file'))),
                                PopupMenuItem(value: 'rename', child: Text(l10n.get('rename_file'))),
                                const PopupMenuItem(value: 'info', child: Text('File Info & Hash')),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(l10n.get('delete_file'), style: const TextStyle(color: AppTheme.dangerRed)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
