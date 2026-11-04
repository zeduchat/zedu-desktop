enum TaskRole {
  contributor,
  reviewer,
  triager,
  observer;

  String get displayName {
    switch (this) {
      case TaskRole.contributor:
        return 'Contributor';
      case TaskRole.reviewer:
        return 'Reviewer';
      case TaskRole.triager:
        return 'Triager';
      case TaskRole.observer:
        return 'Observer';
    }
  }
}

enum TaskChecklistBadge {
  required,
  recommended,
  automated,
  readOnly;

  String get label {
    switch (this) {
      case TaskChecklistBadge.required:
        return 'Required';
      case TaskChecklistBadge.recommended:
        return 'Recommended';
      case TaskChecklistBadge.automated:
        return 'Automated';
      case TaskChecklistBadge.readOnly:
        return 'Read-only';
    }
  }
}

class TaskChecklistItem {
  final String id;
  final String title;
  final String description;
  final TaskChecklistBadge badge;
  final bool isCompleted;
  final bool isBlocked;
  final String? blockedReason;

  const TaskChecklistItem({
    required this.id,
    required this.title,
    required this.description,
    required this.badge,
    this.isCompleted = false,
    this.isBlocked = false,
    this.blockedReason,
  });

  TaskChecklistItem copyWith({
    String? id,
    String? title,
    String? description,
    TaskChecklistBadge? badge,
    bool? isCompleted,
    bool? isBlocked,
    String? blockedReason,
  }) {
    return TaskChecklistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      badge: badge ?? this.badge,
      isCompleted: isCompleted ?? this.isCompleted,
      isBlocked: isBlocked ?? this.isBlocked,
      blockedReason: blockedReason ?? this.blockedReason,
    );
  }
}
