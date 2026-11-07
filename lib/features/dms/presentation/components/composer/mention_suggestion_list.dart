import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MentionSuggestionList extends StatelessWidget {
  final List<DmParticipant> suggestions;
  final String query;
  final AppPalette colors;
  final ValueChanged<DmParticipant> onSelect;

  const MentionSuggestionList({
    super.key,
    required this.suggestions,
    required this.query,
    required this.colors,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 4),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.divider),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              'People',
              style: TextStyle(
                color: colors.textHint,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 6),
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final p = suggestions[index];
                final initial = avatarInitial(p.username);
                // One announced, actionable item per person (Ziki #590).
                return Semantics(
                  button: true,
                  label: 'Mention @${p.username}',
                  excludeSemantics: true,
                  onTap: () => onSelect(p),
                  child: InkWell(
                    onTap: () => onSelect(p),
                    hoverColor: colors.primary.withValues(alpha: 0.07),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: colors.primary,
                            backgroundImage:
                                p.avatarUrl != null && p.avatarUrl!.isNotEmpty
                                ? NetworkImage(p.avatarUrl!)
                                : null,
                            child: p.avatarUrl == null || p.avatarUrl!.isEmpty
                                ? Text(
                                    initial,
                                    style: TextStyle(
                                      color: colors.onPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          // Long usernames and emails are ellipsized instead
                          // of overflowing the row.
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  p.username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                if (p.email.isNotEmpty)
                                  Text(
                                    p.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textHint,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
