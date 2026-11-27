import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

void main() {
  test('reads the edited flags the API may send', () {
    expect(messageWasEdited({'edited': true}), isTrue);
    expect(messageWasEdited({'is_edited': true}), isTrue);
    expect(messageWasEdited({'isEdited': 'true'}), isTrue);
    expect(messageWasEdited({'edited_at': '2026-11-20T10:00:00Z'}), isTrue);
  });

  test('an unedited message is not marked', () {
    expect(messageWasEdited({}), isFalse);
    expect(messageWasEdited({'edited': false}), isFalse);
    expect(messageWasEdited({'edited_at': null}), isFalse);
    expect(messageWasEdited({'edited_at': ''}), isFalse);
    // Go's zero time, for an edited_at that was never set.
    expect(messageWasEdited({'edited_at': '0001-01-01T00:00:00Z'}), isFalse);
  });
}
