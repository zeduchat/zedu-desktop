import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

void main() {
  const localizations = DefaultMaterialLocalizations();
  final now = DateTime(2026, 11, 6, 12);
  String label(DateTime date, {bool clock24 = false, DateTime? current}) =>
      formatDmMessageTimestamp(
        date,
        now: current ?? now,
        localizations: localizations,
        use24HourFormat: clock24,
      );

  test('today retains a concise clock label', () {
    expect(label(DateTime(2026, 11, 6, 9, 5)), '9:05 AM');
  });
  test('older days show their date and clock time', () {
    expect(label(DateTime(2026, 11, 5, 9, 5)), 'Nov 5, 2026 · 9:05 AM');
  });
  test('same day number in another month is not today', () {
    expect(label(DateTime(2026, 10, 6, 9, 5)), 'Oct 6, 2026 · 9:05 AM');
  });
  test('previous years remain unambiguous', () {
    expect(label(DateTime(2025, 11, 6, 9, 5)), 'Nov 6, 2025 · 9:05 AM');
  });
  test('midnight boundary shows the previous calendar day', () {
    expect(
      label(DateTime(2026, 12, 31, 23, 59), current: DateTime(2027, 1, 1)),
      'Dec 31, 2026 · 11:59 PM',
    );
  });
  test('24-hour preference applies to old and new messages', () {
    expect(label(DateTime(2026, 11, 6, 21, 5), clock24: true), '21:05');
    expect(
      label(DateTime(2026, 11, 5, 21, 5), clock24: true),
      'Nov 5, 2026 · 21:05',
    );
  });
  test('UTC timestamps compare using their local calendar day', () {
    final utc = DateTime.utc(2026, 11, 5, 23, 30);
    final local = utc.toLocal();
    expect(
      label(utc, current: DateTime(local.year, local.month, local.day, 12)),
      localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local)),
    );
  });
}
