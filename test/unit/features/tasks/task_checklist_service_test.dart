import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/tasks/tasks.dart';

void main() {
  group('TaskChecklistService', () {
    test('generates contributor checklist when task is in progress with no PR',
        () {
      final items = TaskChecklistService.generateItems(
        role: TaskRole.contributor,
        input: const TaskChecklistStateInput(
          status: 'in_progress',
          substatus: 'in_progress',
          isClaimHolder: true,
          pullRequestUrl: null,
        ),
      );

      expect(items.length, 3);
      expect(
          items.any((TaskChecklistItem i) => i.id == 'contrib-heartbeat'),
          isTrue);
      expect(
          items
              .firstWhere((TaskChecklistItem i) => i.id == 'contrib-link-pr')
              .isCompleted,
          isFalse);
      expect(
          items
              .firstWhere(
                  (TaskChecklistItem i) => i.id == 'contrib-report-checks')
              .isCompleted,
          isFalse);
    });

    test('includes acknowledge offer step when contributor task is offered',
        () {
      final items = TaskChecklistService.generateItems(
        role: TaskRole.contributor,
        input: const TaskChecklistStateInput(
          status: 'open',
          substatus: 'offered',
        ),
      );

      expect(
          items.any((TaskChecklistItem i) => i.id == 'contrib-ack-offer'),
          isTrue);
      expect(
          items
              .firstWhere((TaskChecklistItem i) => i.id == 'contrib-ack-offer')
              .badge,
          TaskChecklistBadge.required);
    });

    test(
        'marks PR and checks complete for contributor when pullRequestUrl is present',
        () {
      final items = TaskChecklistService.generateItems(
        role: TaskRole.contributor,
        input: const TaskChecklistStateInput(
          status: 'in_progress',
          pullRequestUrl: 'https://github.com/zeduchat/zedu-desktop/pull/500',
        ),
      );

      expect(
          items
              .firstWhere((TaskChecklistItem i) => i.id == 'contrib-link-pr')
              .isCompleted,
          isTrue);
      expect(
          items
              .firstWhere(
                  (TaskChecklistItem i) => i.id == 'contrib-report-checks')
              .isCompleted,
          isTrue);
    });

    test(
        'enforces owner-independence exclusion for reviewer owned by the same user',
        () {
      final items = TaskChecklistService.generateItems(
        role: TaskRole.reviewer,
        input: const TaskChecklistStateInput(
          status: 'in_progress',
          isOwnAgent: true,
          pullRequestUrl: 'https://github.com/zeduchat/zedu-desktop/pull/500',
        ),
      );

      expect(items.length, 1);
      final item = items.first;
      expect(item.id, 'review-blocked-independence');
      expect(item.isBlocked, isTrue);
      expect(item.blockedReason, contains('Owner-independence exclusion'));
    });

    test('generates valid review steps when reviewer is an independent agent',
        () {
      final items = TaskChecklistService.generateItems(
        role: TaskRole.reviewer,
        input: const TaskChecklistStateInput(
          status: 'in_progress',
          isOwnAgent: false,
          pullRequestUrl: 'https://github.com/zeduchat/zedu-desktop/pull/500',
          hasTestVerdict: true,
        ),
      );

      expect(items.length, 3);
      expect(
          items
              .firstWhere((TaskChecklistItem i) => i.id == 'review-inspect-pr')
              .isCompleted,
          isTrue);
      expect(
          items
              .firstWhere(
                  (TaskChecklistItem i) => i.id == 'review-submit-verdict')
              .isCompleted,
          isTrue);
    });

    test('generates triager duplicate search and confirmation steps', () {
      final items = TaskChecklistService.generateItems(
        role: TaskRole.triager,
        input: const TaskChecklistStateInput(
          status: 'open',
          substatus: 'requires_confirmation',
        ),
      );

      expect(items.length, 3);
      expect(
          items.any((TaskChecklistItem i) => i.id == 'triage-duplicate-search'),
          isTrue);
      expect(
          items
              .firstWhere(
                  (TaskChecklistItem i) => i.id == 'triage-confirm-report')
              .isCompleted,
          isFalse);
    });

    test('generates read-only checklist for observer role', () {
      final items = TaskChecklistService.generateItems(
        role: TaskRole.observer,
        input: const TaskChecklistStateInput(status: 'in_progress'),
      );

      expect(items.length, 2);
      expect(
          items.every((TaskChecklistItem i) =>
              i.badge == TaskChecklistBadge.readOnly),
          isTrue);
    });
  });
}
