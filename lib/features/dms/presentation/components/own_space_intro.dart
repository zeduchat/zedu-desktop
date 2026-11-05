import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class OwnSpaceIntro extends StatelessWidget {
  const OwnSpaceIntro({
    super.key,
    required this.conversation,
    required this.onEditProfile,
  });

  final DmConversation conversation;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = conversation.displayName;
    final avatarUrl = conversation.effectiveAvatarUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 76, 40, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 39,
            backgroundColor: colors.primary,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
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
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
              children: [
                TextSpan(text: name),
                TextSpan(
                  text: ' (you)',
                  style: TextStyle(
                    color: colors.textHint,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 14, color: colors.textPrimary),
              children: const [
                TextSpan(
                  text: 'Only you can see this. ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text:
                      'Save resources from class, keep track of your tasks, or draft a message here before you post it to a channel.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onEditProfile,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit profile'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.textPrimary,
              side: BorderSide(color: colors.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
