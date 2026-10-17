import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import '../models/media_metadata.dart';

class UrlValidator {
  static final RegExp _privateIpRegExp = RegExp(
    r'^(localhost|127\.\d+\.\d+\.\d+|10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+|172\.(1[6-9]|2\d|3[01])\.\d+\.\d+|169\.254\.\d+\.\d+|0\.0\.0\.0|::1)$',
    caseSensitive: false,
  );

  static final List<String> _mediaExtensions = [
    '.mp4', '.webm', '.mkv', '.mov', '.avi', '.flv', '.wmv',
    '.m4v', '.3gp', '.ts', '.m3u8', '.mp3', '.aac', '.wav', '.ogg'
  ];

  /// Checks if URL points to a dangerous localhost or private network (anti-SSRF)
  static bool isPrivateNetworkUrl(Uri uri) {
    final host = uri.host.trim().toLowerCase();
    if (host.isEmpty) return true;
    if (_privateIpRegExp.hasMatch(host)) return true;
    if (host.endsWith('.local') || host.endsWith('.internal')) return true;
    return false;
  }

  /// Sanitizes filename to prevent directory traversal and illegal Windows/Android characters
  static String sanitizeFileName(String name, {String fallbackExt = '.mp4'}) {
    var clean = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
    clean = clean.replaceAll(RegExp(r'^\.+'), '');
    if (clean.isEmpty) {
      clean = 'video_${DateTime.now().millisecondsSinceEpoch}';
    }
    if (clean.length > 100) {
      clean = clean.substring(0, 100);
    }
    if (!clean.contains('.')) {
      clean += fallbackExt;
    }
    return clean;
  }

  /// Analyzes any URL (direct stream or website link) and prepares it for downloading
  static Future<MediaMetadata> inspectUrl(
    String rawUrl, {
    bool blockPrivateNetwork = true,
  }) async {
    final trimmed = rawUrl.trim();
    final uri = Uri.tryParse(trimmed);

    if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return MediaMetadata(
        url: trimmed,
        resolvedUrl: trimmed,
        suggestedFileName: 'download.mp4',
        totalBytes: -1,
        mimeType: 'video/mp4',
        acceptsRanges: true,
        isDirectMedia: true,
      );
    }

    if (blockPrivateNetwork && isPrivateNetworkUrl(uri)) {
      return MediaMetadata(
        url: trimmed,
        resolvedUrl: trimmed,
        suggestedFileName: 'blocked_private_ip.mp4',
        totalBytes: -1,
        mimeType: 'unknown',
        acceptsRanges: false,
        isDirectMedia: false,
        unsupportedReason: 'Private network URL blocked (anti-SSRF security rule).',
      );
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 15),
        followRedirects: true,
        maxRedirects: 5,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': '*/*',
        },
      ),
    );

    try {
      Response response;
      try {
        response = await dio.head(trimmed);
      } catch (_) {
        response = await dio.get(
          trimmed,
          options: Options(
            headers: {'Range': 'bytes=0-1024'},
            responseType: ResponseType.stream,
          ),
        );
      }

      final headers = response.headers;
      final contentType = headers.value('content-type')?.toLowerCase() ?? 'video/mp4';
      final acceptRanges = headers.value('accept-ranges')?.toLowerCase() == 'bytes' ||
          headers.value('content-range') != null;

      int totalBytes = -1;
      final contentLengthStr = headers.value('content-length');
      if (contentLengthStr != null) {
        totalBytes = int.tryParse(contentLengthStr) ?? -1;
      }
      final contentRangeStr = headers.value('content-range');
      if (contentRangeStr != null && contentRangeStr.contains('/')) {
        final totalStr = contentRangeStr.split('/').last.trim();
        totalBytes = int.tryParse(totalStr) ?? totalBytes;
      }

      String resolvedUrl = response.realUri.toString();

      // Check if it's an HTML page — try to extract embedded video stream
      final isHtml = contentType.contains('text/html') || contentType.contains('application/xhtml');
      if (isHtml) {
        try {
          final pageResp = await dio.get<String>(
            trimmed,
            options: Options(responseType: ResponseType.plain),
          );
          if (pageResp.data != null) {
            final html = pageResp.data!;
            // Look for open graph video or video src
            final ogMatch = RegExp(r'<meta\s+property=["\x27]og:video(?:[:\w]+)?["\x27]\s+content=["\x27](https?://[^"\x27]+)["\x27]', caseSensitive: false).firstMatch(html);
            final videoSrcMatch = RegExp(r'<video[^>]+src=["\x27](https?://[^"\x27]+)["\x27]', caseSensitive: false).firstMatch(html);
            final sourceSrcMatch = RegExp(r'<source[^>]+src=["\x27](https?://[^"\x27]+)["\x27]', caseSensitive: false).firstMatch(html);

            final extracted = ogMatch?.group(1) ?? videoSrcMatch?.group(1) ?? sourceSrcMatch?.group(1);
            if (extracted != null && extracted.isNotEmpty) {
              resolvedUrl = extracted;
            }
          }
        } catch (_) {}
      }

      // Extract filename from Content-Disposition if present
      String? fileName;
      final disposition = headers.value('content-disposition');
      if (disposition != null && disposition.contains('filename')) {
        final match = RegExp(r'filename\*?=(?:UTF-8)?["\x27]?([^";\x27]+)', caseSensitive: false).firstMatch(disposition);
        if (match != null) {
          fileName = Uri.decodeComponent(match.group(1)?.replaceAll('"', '').replaceAll("'", '').trim() ?? '');
        }
      }

      // Fallback filename from URL path
      if (fileName == null || fileName.isEmpty) {
        final parsed = Uri.tryParse(resolvedUrl) ?? uri;
        final lastSegment = p.basename(parsed.path);
        if (lastSegment.isNotEmpty && lastSegment.contains('.') && !lastSegment.endsWith('.html')) {
          fileName = lastSegment;
        } else {
          final ext = _guessExtensionFromMime(contentType);
          fileName = 'video_${DateTime.now().millisecondsSinceEpoch}$ext';
        }
      }

      fileName = sanitizeFileName(fileName);

      return MediaMetadata(
        url: trimmed,
        resolvedUrl: resolvedUrl,
        suggestedFileName: fileName,
        totalBytes: totalBytes,
        mimeType: isHtml ? 'video/mp4' : contentType,
        acceptsRanges: acceptRanges,
        isDirectMedia: true,
        eTag: headers.value('etag'),
      );
    } catch (e) {
      // Always allow downloading even if HEAD fails
      final fileName = sanitizeFileName(p.basename(uri.path).isEmpty ? 'video_${DateTime.now().millisecondsSinceEpoch}.mp4' : p.basename(uri.path));
      return MediaMetadata(
        url: trimmed,
        resolvedUrl: trimmed,
        suggestedFileName: fileName,
        totalBytes: -1,
        mimeType: 'video/mp4',
        acceptsRanges: true,
        isDirectMedia: true,
      );
    }
  }

  static String _guessExtensionFromMime(String mime) {
    if (mime.contains('mp4')) return '.mp4';
    if (mime.contains('webm')) return '.webm';
    if (mime.contains('matroska') || mime.contains('mkv')) return '.mkv';
    if (mime.contains('quicktime') || mime.contains('mov')) return '.mov';
    if (mime.contains('x-msvideo') || mime.contains('avi')) return '.avi';
    if (mime.contains('mpegurl') || mime.contains('m3u8')) return '.m3u8';
    if (mime.contains('audio/mpeg') || mime.contains('mp3')) return '.mp3';
    return '.mp4';
  }
}
