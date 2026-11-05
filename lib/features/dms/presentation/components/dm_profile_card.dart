import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class DmProfileCard extends StatelessWidget {
  final DmConversation conversation;

  /// Opens the person's profile, the same as "View profile" in the DM menu.
  final VoidCallback onViewProfile;

  const DmProfileCard({
    super.key,
    required this.conversation,
    required this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = conversation.displayName;
    final nameParts = name.trim().split(RegExp(r'\s+'));
    final handle = nameParts.length > 1
        ? '@${nameParts.first}_${nameParts.last}'
        : '@${nameParts.first}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 76, 40, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 39,
            backgroundColor: colors.primary,
            backgroundImage: conversation.effectiveAvatarUrl != null
                ? NetworkImage(conversation.effectiveAvatarUrl!)
                : null,
            child: conversation.effectiveAvatarUrl == null
                ? Text(
                    avatarInitial(name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 14, color: colors.textPrimary),
              children: [
                const TextSpan(
                  text: 'This conversation is just between you and ',
                ),
                TextSpan(
                  text: handle,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const TextSpan(
                  text: '. Check out their profile to learn about them.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onViewProfile,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: colors.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            child: Text(
              'View Profile',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
