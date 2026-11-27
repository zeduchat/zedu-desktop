import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('LoginAuditEntryModel.fromJson (Ziki #2725)', () {
    test('reads a login-audit row from zedu-be', () {
      final entry = LoginAuditEntryModel.fromJson(const {
        'id': 'a1',
        'user_id': 'u1',
        'access_token_id': 't1',
        'login_at': '2026-05-08T13:07:00Z',
        'ip_address': '102.89.1.2',
        'location': 'Lagos, Nigeria',
        'device': 'Chrome on Windows',
        'created_at': '2026-05-08T13:07:05Z',
        'is_live': true,
      });

      expect(entry.id, 'a1');
      expect(entry.device, 'Chrome on Windows');
      expect(entry.location, 'Lagos, Nigeria');
      expect(entry.ipAddress, '102.89.1.2');
      expect(entry.loginAt, DateTime.utc(2026, 5, 8, 13, 7));
      expect(entry.createdAt, DateTime.utc(2026, 5, 8, 13, 7, 5));
      expect(entry.isLive, isTrue);
    });

    test('tolerates missing and null values', () {
      final entry = LoginAuditEntryModel.fromJson(const {
        'id': null,
        'device': null,
        'login_at': null,
      });

      expect(entry.id, '');
      expect(entry.device, '');
      expect(entry.location, '');
      expect(entry.ipAddress, '');
      expect(entry.loginAt, isNull);
      expect(entry.createdAt, isNull);
      expect(entry.isLive, isFalse);
    });

    test('tolerates numbers and strings in place of other types', () {
      final entry = LoginAuditEntryModel.fromJson(const {
        'id': 42,
        'ip_address': 127001,
        'login_at': 'not a date',
        'created_at': 1715173620,
        'is_live': 'true',
      });

      expect(entry.id, '42');
      expect(entry.ipAddress, '127001');
      expect(entry.loginAt, isNull);
      expect(entry.createdAt, isNull);
      expect(entry.isLive, isTrue);
      expect(LoginAuditEntryModel.fromJson(const {'is_live': 1}).isLive, true);
      expect(LoginAuditEntryModel.fromJson(const {'is_live': 0}).isLive, false);
      expect(
        LoginAuditEntryModel.fromJson(const {'is_live': 'false'}).isLive,
        false,
      );
    });

    test("treats Go's zero time as no time", () {
      final entry = LoginAuditEntryModel.fromJson(const {
        'login_at': '0001-01-01T00:00:00Z',
      });

      expect(entry.loginAt, isNull);
    });
  });
}
