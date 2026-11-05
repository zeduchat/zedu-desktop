import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  test('uses the singular for exactly one credit', () {
    expect(aiCreditsLabel(1), '1 AI credit');
  });

  test('uses the plural for zero and many credits', () {
    expect(aiCreditsLabel(0), '0 AI credits');
    expect(aiCreditsLabel(25), '25 AI credits');
  });
}
