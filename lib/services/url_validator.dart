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
    // Remove invalid characters for Windows and Unix filesystems
    var clean = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
    // Prevent directory traversal
    clean = clean.replaceAll(RegExp(r'^\.+'), '');
    if (clean.isEmpty) {
      clean = 'linkdrop_video_${DateTime.now().millisecondsSinceEpoch}';
    }
    // Limit length
    if (clean.length > 100) {
      clean = clean.substring(0, 100);
    }
    // Ensure it has an extension
    if (!clean.contains('.')) {
      clean += fallbackExt;
    }
    return clean;
  }

  /// Analyzes a URL directly via HTTP HEAD or partial GET to extract metadata and verify it is a direct video stream
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
        suggestedFileName: 'invalid_url.mp4',
        totalBytes: -1,
        mimeType: 'unknown',
        acceptsRanges: false,
        isDirectMedia: false,
        unsupportedReason: 'Invalid URL format. URL must start with http:// or https://.',
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
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        followRedirects: true,
        maxRedirects: 5,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) LINKDROP/1.0',
        },
      ),
    );

    try {
      Response response;
      try {
        // First try HTTP HEAD request
        response = await dio.head(trimmed);
      } catch (_) {
        // If HEAD is rejected (some CDNs reject HEAD), try GET with Range 0-0
        response = await dio.get(
          trimmed,
          options: Options(
            headers: {'Range': 'bytes=0-0'},
            responseType: ResponseType.stream,
          ),
        );
      }

      final headers = response.headers;
      final contentType = headers.value('content-type')?.toLowerCase() ?? 'application/octet-stream';
      final acceptRanges = headers.value('accept-ranges')?.toLowerCase() == 'bytes' ||
          headers.value('content-range') != null;

      // Extract content length
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

      // Check if it's an unsupported HTML webpage
      final isHtml = contentType.contains('text/html') || contentType.contains('application/xhtml');
      final path = uri.path.toLowerCase();
      final hasMediaExt = _mediaExtensions.any((ext) => path.endsWith(ext));

      if (isHtml && !hasMediaExt) {
        return MediaMetadata(
          url: trimmed,
          resolvedUrl: response.realUri.toString(),
          suggestedFileName: 'webpage.html',
          totalBytes: totalBytes,
          mimeType: contentType,
          acceptsRanges: acceptRanges,
          isDirectMedia: false,
          unsupportedReason: 'Webpage detected ($contentType). LINKDROP only downloads direct video streams (e.g. .mp4, .webm). DRM or webpage players cannot be directly streamed.',
        );
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
        final lastSegment = p.basename(uri.path);
        if (lastSegment.isNotEmpty && lastSegment.contains('.')) {
          fileName = lastSegment;
        } else {
          final ext = _guessExtensionFromMime(contentType);
          fileName = 'video_${DateTime.now().millisecondsSinceEpoch}$ext';
        }
      }

      fileName = sanitizeFileName(fileName);

      return MediaMetadata(
        url: trimmed,
        resolvedUrl: response.realUri.toString(),
        suggestedFileName: fileName,
        totalBytes: totalBytes,
        mimeType: contentType,
        acceptsRanges: acceptRanges,
        isDirectMedia: true,
        eTag: headers.value('etag'),
      );
    } catch (e) {
      // If server failed or timeout, check if URL extension looks like direct video
      final path = uri.path.toLowerCase();
      final hasMediaExt = _mediaExtensions.any((ext) => path.endsWith(ext));

      if (hasMediaExt) {
        final name = sanitizeFileName(p.basename(uri.path));
        return MediaMetadata(
          url: trimmed,
          resolvedUrl: trimmed,
          suggestedFileName: name,
          totalBytes: -1,
          mimeType: 'video/mp4',
          acceptsRanges: true,
          isDirectMedia: true,
        );
      }

      return MediaMetadata(
        url: trimmed,
        resolvedUrl: trimmed,
        suggestedFileName: 'unknown_media.mp4',
        totalBytes: -1,
        mimeType: 'unknown',
        acceptsRanges: false,
        isDirectMedia: false,
        unsupportedReason: 'Unable to reach video server: ${e.toString().split('\n').first}',
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
