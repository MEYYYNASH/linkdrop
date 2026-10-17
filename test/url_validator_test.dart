import 'package:flutter_test/flutter_test.dart';
import 'package:linkdrop/services/url_validator.dart';

void main() {
  group('UrlValidator SSRF & Private IP Security Tests', () {
    test('Blocks localhost and loopback addresses', () {
      expect(UrlValidator.isPrivateNetworkUrl(Uri.parse('http://localhost/video.mp4')), isTrue);
      expect(UrlValidator.isPrivateNetworkUrl(Uri.parse('http://127.0.0.1/video.mp4')), isTrue);
      expect(UrlValidator.isPrivateNetworkUrl(Uri.parse('http://127.1.2.3/stream')), isTrue);
    });

    test('Blocks private LAN Class A, B, C addresses', () {
      expect(UrlValidator.isPrivateNetworkUrl(Uri.parse('http://10.0.0.5/video.mp4')), isTrue);
      expect(UrlValidator.isPrivateNetworkUrl(Uri.parse('http://192.168.1.100/video.mp4')), isTrue);
      expect(UrlValidator.isPrivateNetworkUrl(Uri.parse('http://172.16.0.1/video.mp4')), isTrue);
      expect(UrlValidator.isPrivateNetworkUrl(Uri.parse('http://172.31.255.255/video.mp4')), isTrue);
    });

    test('Blocks AWS/Cloud metadata address (169.254.169.254)', () {
      expect(UrlValidator.isPrivateNetworkUrl(Uri.parse('http://169.254.169.254/latest/meta-data/')), isTrue);
    });

    test('Allows public internet video streaming URLs', () {
      expect(UrlValidator.isPrivateNetworkUrl(Uri.parse('https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4')), isFalse);
      expect(UrlValidator.isPrivateNetworkUrl(Uri.parse('https://example.com/videos/stream.webm')), isFalse);
    });
  });

  group('Filename Sanitizer Tests', () {
    test('Removes illegal Windows and Android filesystem characters', () {
      const dangerous = 'my<video>:special*name?"test"|run.mp4';
      final clean = UrlValidator.sanitizeFileName(dangerous);
      expect(clean.contains('<'), isFalse);
      expect(clean.contains('>'), isFalse);
      expect(clean.contains(':'), isFalse);
      expect(clean.contains('*'), isFalse);
      expect(clean.contains('?'), isFalse);
      expect(clean.contains('|'), isFalse);
      expect(clean.endsWith('.mp4'), isTrue);
    });

    test('Prevents directory traversal attacks', () {
      const traversal = '../../../etc/passwd.mp4';
      final clean = UrlValidator.sanitizeFileName(traversal);
      expect(clean.startsWith('..'), isFalse);
      expect(clean.contains('/'), isFalse);
    });

    test('Adds fallback extension when missing', () {
      const noExt = 'my_awesome_video';
      final clean = UrlValidator.sanitizeFileName(noExt);
      expect(clean.endsWith('.mp4'), isTrue);
    });
  });
}
