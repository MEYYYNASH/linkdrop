import 'package:flutter_test/flutter_test.dart';
import 'package:linkdrop/services/update_service.dart';

void main() {
  group('Semantic Version Comparison Tests', () {
    test('Detects newer patch version', () {
      expect(UpdateService.isNewerVersion('1.0.0', '1.0.1'), isTrue);
    });

    test('Detects newer minor version', () {
      expect(UpdateService.isNewerVersion('1.0.9', '1.1.0'), isTrue);
    });

    test('Detects newer major version', () {
      expect(UpdateService.isNewerVersion('1.9.9', '2.0.0'), isTrue);
    });

    test('Handles leading "v" prefix correctly', () {
      expect(UpdateService.isNewerVersion('v1.0.0', 'v1.0.1'), isTrue);
      expect(UpdateService.isNewerVersion('1.0.0', 'v1.0.1'), isTrue);
      expect(UpdateService.isNewerVersion('v1.0.1', '1.0.0'), isFalse);
    });

    test('Handles build numbers like +1, +2 correctly', () {
      expect(UpdateService.isNewerVersion('1.0.0+1', '1.0.1+2'), isTrue);
    });

    test('Returns false when version is identical', () {
      expect(UpdateService.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(UpdateService.isNewerVersion('v1.2.3', '1.2.3'), isFalse);
    });

    test('Returns false when installed version is newer than remote', () {
      expect(UpdateService.isNewerVersion('2.0.0', '1.9.9'), isFalse);
    });
  });
}
