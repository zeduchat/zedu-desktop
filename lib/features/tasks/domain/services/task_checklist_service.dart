import 'package:zedu/features/tasks/domain/entities/entities.dart';

class TaskChecklistStateInput {
  final String status;
  final String? substatus;
  final bool isClaimHolder;
  final bool isOwnAgent;
  final DateTime? deliverBy;
  final String? pullRequestUrl;
  final bool hasTestVerdict;

  const TaskChecklistStateInput({
    required this.status,
    this.substatus,
    this.isClaimHolder = false,
    this.isOwnAgent = false,
    this.deliverBy,
    this.pullRequestUrl,
    this.hasTestVerdict = false,
  });
}

abstract final class TaskChecklistService {
  static List<TaskChecklistItem> generateItems({
    required TaskRole role,
    required TaskChecklistStateInput input,
  }) {
    switch (role) {
      case TaskRole.contributor:
        return _generateContributorItems(input);
      case TaskRole.reviewer:
        return _generateReviewerItems(input);
      case TaskRole.triager:
        return _generateTriagerItems(input);
      case TaskRole.observer:
        return _generateObserverItems(input);
    }
  }

  static List<TaskChecklistItem> _generateContributorItems(
    TaskChecklistStateInput input,
  ) {
    final hasPr =
        input.pullRequestUrl != null && input.pullRequestUrl!.trim().isNotEmpty;
    final isOffered = input.substatus == 'offered';

    final items = <TaskChecklistItem>[];

    if (isOffered) {
      items.add(
        const TaskChecklistItem(
          id: 'contrib-ack-offer',
          title: 'Acknowledge Actionable Offer',
          description:
              'Accept the task offer via POST /api/v1/offers/{id}/accept to secure the claim.',
          badge: TaskChecklistBadge.required,
          isCompleted: false,
        ),
      );
    }

    items.addAll([
      const TaskChecklistItem(
        id: 'contrib-heartbeat',
        title: 'Maintain Claim Heartbeat',
        description:
            'Send periodic heartbeat ping within 240 minutes to keep the active claim alive.',
        badge: TaskChecklistBadge.required,
        isCompleted: true,
      ),
      TaskChecklistItem(
        id: 'contrib-link-pr',
        title: 'Link Open Pull Request',
        description:
            'Push changes to fork and deliver pull request in the project repository.',
        badge: TaskChecklistBadge.required,
        isCompleted: hasPr,
      ),
      TaskChecklistItem(
        id: 'contrib-report-checks',
        title: 'Report CI and Test Checks',
        description:
            'Ensure CI pipelines, linters, and unit tests pass cleanly before review.',
        badge: TaskChecklistBadge.recommended,
        isCompleted: hasPr,
      ),
    ]);

    return items;
  }

  static List<TaskChecklistItem> _generateReviewerItems(
    TaskChecklistStateInput input,
  ) {
    if (input.isOwnAgent) {
      return const [
        TaskChecklistItem(
          id: 'review-blocked-independence',
          title: 'Review Blocked (Owner Independence)',
          description:
              'Owner-independence rule prevents agents from reviewing tickets or fixes claimed by agents owned by the same user.',
          badge: TaskChecklistBadge.required,
          isCompleted: false,
          isBlocked: true,
          blockedReason:
              'Owner-independence exclusion: You cannot review or submit test verdicts for your own agents.',
        ),
      ];
    }

    final hasPr =
        input.pullRequestUrl != null && input.pullRequestUrl!.trim().isNotEmpty;

    return [
      TaskChecklistItem(
        id: 'review-inspect-pr',
        title: 'Inspect Pull Request & Changes',
        description:
            'Review code diffs, branch health, and ensure no regression or breaking change.',
        badge: TaskChecklistBadge.required,
        isCompleted: hasPr,
      ),
      const TaskChecklistItem(
        id: 'review-record-evidence',
        title: 'Record Test Scope & Limitations',
        description:
            'Document exact test reproduction commands, environment details, and limits.',
        badge: TaskChecklistBadge.required,
        isCompleted: false,
      ),
      TaskChecklistItem(
        id: 'review-submit-verdict',
        title: 'Submit Test Verdict',
        description:
            'Deliver formal test-results verdict (passed/failed) with confidence score.',
        badge: TaskChecklistBadge.required,
        isCompleted: input.hasTestVerdict,
      ),
    ];
  }

  static List<TaskChecklistItem> _generateTriagerItems(
    TaskChecklistStateInput input,
  ) {
    final isConfirmed =
        input.status != 'open' || input.substatus != 'requires_confirmation';

    return [
      const TaskChecklistItem(
        id: 'triage-duplicate-search',
        title: 'Scan Backlog for Duplicates',
        description:
            'Search project issue catalog against duplicate similarity threshold (0.82).',
        badge: TaskChecklistBadge.required,
        isCompleted: true,
      ),
      const TaskChecklistItem(
        id: 'triage-compare-scope',
        title: 'Compare Scope & Reproduction',
        description:
            'Confirm defect details match reported behavior and specify impacted platforms.',
        badge: TaskChecklistBadge.required,
        isCompleted: true,
      ),
      TaskChecklistItem(
        id: 'triage-confirm-report',
        title: 'Submit Confirmation or Duplicate Clearance',
        description:
            'Cast confirm verdict or mark duplicate to transition issue into the open queue.',
        badge: TaskChecklistBadge.required,
        isCompleted: isConfirmed,
      ),
    ];
  }

  static List<TaskChecklistItem> _generateObserverItems(
    TaskChecklistStateInput input,
  ) {
    return const [
      TaskChecklistItem(
        id: 'observer-monitor-feed',
        title: 'Monitor Project Work Feed',
        description:
            'Track incoming issues, offers, and unassigned backlog items via GET /work.',
        badge: TaskChecklistBadge.readOnly,
        isCompleted: true,
      ),
      TaskChecklistItem(
        id: 'observer-read-only',
        title: 'Read-Only Mode Active',
        description:
            'Direct write mutations, bidding, and delivery are restricted for observer role.',
        badge: TaskChecklistBadge.readOnly,
        isCompleted: true,
      ),
    ];
  }
}
