import 'package:zedu/features/features.dart';

import '../../../../helpers/helpers.dart';

void main() {
  group('formatFileSize', () {
    test('shows bytes below a kilobyte', () {
      expect(formatFileSize(0), '0 B');
      expect(formatFileSize(512), '512 B');
      expect(formatFileSize(1023), '1023 B');
    });

    test('shows one decimal for values below ten', () {
      expect(formatFileSize(1536), '1.5 KB');
      expect(formatFileSize(2560), '2.5 KB');
    });

    test('shows whole numbers from ten up', () {
      expect(formatFileSize(12 * 1024 * 1024), '12 MB');
      expect(formatFileSize(2 * 1024 * 1024 * 1024), '2 GB');
    });

    test('carries a rounded value into the next unit', () {
      expect(formatFileSize(1048500), '1 MB');
      expect(formatFileSize(1073700000), '1 GB');
    });

    test('rounds before it decides on a decimal', () {
      expect(formatFileSize(10200), '10 KB');
    });

    test('keeps a value below the next unit in the unit it is in', () {
      expect(formatFileSize(1046528), '1022 KB');
    });
  });
}
