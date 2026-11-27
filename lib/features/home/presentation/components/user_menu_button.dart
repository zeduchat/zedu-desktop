import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The signed-in user the rail button shows. The session is always set up
/// before the rail appears; when it can't be (isolated widget tests, where
/// the app's services aren't registered) the button falls back to no user
/// instead of failing to build.
final _railUserProvider = Provider.autoDispose<User?>((ref) {
  try {
    return ref.watch(authNotifierProvider).user;
  } on Object {
    return null;
  }
});

class UserMenuButton extends ConsumerWidget {
  const UserMenuButton({super.key});

  static const double _size = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final menuState = ref.watch<UserMenuState>(userMenuStateProvider);
    final notificationsPaused = ref.watch(
      notificationSettingsProvider.select((settings) => settings.isDndActive),
    );
    final user = ref.watch(_railUserProvider);

    return GestureDetector(
      onTap: () {
        showDialog<void>(
          context: context,
          // The card is anchored beside the rail, so it must not dim the whole
          // window: a transparent barrier still closes it on an outside tap.
          barrierColor: Colors.transparent,
          builder: (context) => const UserMenuDialog(),
        );
      },
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              key: const ValueKey('user_menu_button_avatar'),
              // Fits inside the 50 px rail (less its 1 px border) with room
              // to spare, so the button never overflows the rail.
              width: _size,
              height: _size,
              color: colors.sidebar,
              child: _RailAvatar(
                avatarUrl: user?.avatarUrl ?? '',
                name: user?.fullname ?? '',
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: menuState.isAway ? colors.textHint : colors.success,
                shape: BoxShape.circle,
                border: Border.all(color: colors.sidebar, width: 2),
              ),
            ),
          ),
          if (notificationsPaused)
            Positioned(
              top: 0,
              right: 0,
              child: Tooltip(
                message: 'Notifications paused',
                child: Container(
                  key: const ValueKey('user_menu_paused_badge'),
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    color: colors.background,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.sidebar, width: 1.5),
                  ),
                  child: Icon(
                    Icons.notifications_off_outlined,
                    size: 11,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The signed-in user's photo, their initials when there is none, or a
/// person icon when the name is unknown too.
class _RailAvatar extends StatelessWidget {
  const _RailAvatar({required this.avatarUrl, required this.name});

  final String avatarUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2);
    final fallback = parts.isEmpty
        ? Icon(Icons.person, color: colors.onPrimary, size: 28)
        : Center(
            child: Text(
              parts.map((part) => part.characters.first.toUpperCase()).join(),
              style: TextStyle(
                color: colors.onPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
    final url = avatarUrl.trim();
    if (url.isEmpty) return fallback;
    return Image.network(
      url,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
