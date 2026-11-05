import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

ProfileAccount _account(String name) =>
    ProfileAccount(name: name, email: 'a@example.com', timezone: 'UTC');

OrganizationProfile _org(String name) => OrganizationProfile(
  id: 'org-1',
  name: name,
  natureOfBusiness: '',
  country: '',
);

void main() {
  group('ProfileAccount.initials', () {
    test('first and last initials, upper-cased', () {
      expect(_account('ada lovelace').initials, 'AL');
      expect(_account('Ada').initials, 'A');
    });

    test('keeps emoji and flags whole', () {
      expect(_account('😀 Ada').initials, '😀A');
      expect(_account('🇳🇬').initials, '🇳🇬');
      expect(_account('Ada 👩‍💻').initials, 'A👩‍💻');
    });

    test('falls back when there is no name', () {
      expect(_account('   ').initials, 'ZU');
    });
  });

  group('OrganizationProfile.initials', () {
    test('first and last initials, upper-cased', () {
      expect(_org('zedu team').initials, 'ZT');
    });

    test('keeps emoji whole', () {
      expect(_org('🚀 Rocket').initials, '🚀R');
      expect(_org('🚀').initials, '🚀');
    });

    test('falls back when there is no name', () {
      expect(_org('').initials, 'ZO');
    });
  });
}
