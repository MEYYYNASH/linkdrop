import 'package:flutter/services.dart';

class ClipboardService {
  static final RegExp _videoUrlPattern = RegExp(
    r'https?://[^\s]+\.(mp4|webm|mkv|mov|avi|flv|m3u8|ts)(\?[^\s]*)?',
    caseSensitive: false,
  );

  static Future<String?> checkClipboardForVideoUrl() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null) {
        final text = data.text!.trim();
        if (text.startsWith('http://') || text.startsWith('https://')) {
          if (_videoUrlPattern.hasMatch(text) || text.contains('/video/') || text.contains('/stream/')) {
            return text;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
