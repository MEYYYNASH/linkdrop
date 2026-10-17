import 'package:flutter/material.dart';
import '../l10n/app_localization.dart';
import '../theme/app_theme.dart';

class BatchDownloadDialog extends StatefulWidget {
  final AppLocalization l10n;
  final void Function(List<String> urls) onStartBatch;

  const BatchDownloadDialog({
    super.key,
    required this.l10n,
    required this.onStartBatch,
  });

  @override
  State<BatchDownloadDialog> createState() => _BatchDownloadDialogState();
}

class _BatchDownloadDialogState extends State<BatchDownloadDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text;
    final urls = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && (e.startsWith('http://') || e.startsWith('https://')))
        .toList();

    if (urls.isNotEmpty) {
      widget.onStartBatch(urls);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;

    return AlertDialog(
      backgroundColor: AppTheme.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.primaryVioletDark, width: 1.5),
      ),
      title: Row(
        children: [
          const Icon(Icons.playlist_add_rounded, color: AppTheme.primaryVioletLight, size: 26),
          const SizedBox(width: 10),
          Text(
            l10n.get('batch_title'),
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.get('batch_desc'),
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 6,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'https://example.com/video1.mp4\nhttps://example.com/video2.webm\n...',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF0F0F1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF222245)),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryViolet),
          onPressed: _submit,
          child: Text(l10n.get('batch_start')),
        ),
      ],
    );
  }
}
