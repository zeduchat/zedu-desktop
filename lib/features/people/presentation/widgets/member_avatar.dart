import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// A member's photo, or their initial, with an optional online dot.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.member,
    this.size = 32,
    this.radius = 7,
    this.showPresence = true,
  });

  final OrgMember member;
  final double size;
  final double radius;
  final bool showPresence;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final initial = Center(
      child: Text(
        member.initial,
        style: context.textTheme.titleSmall?.copyWith(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: colors.primary,
        ),
      ),
    );
    final photo = member.photoUrl;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Container(
              width: size,
              height: size,
              color: colors.primaryBg,
              child: photo.isEmpty
                  ? initial
                  : Image.network(
                      photo,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => initial,
                    ),
            ),
          ),
          if (showPresence && !member.deactivated)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: member.online
                      ? colors.presenceActive
                      : colors.presenceAway,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.onPrimary, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
