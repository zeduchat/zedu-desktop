import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class UserMenuButton extends ConsumerWidget {
  const UserMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final menuState = ref.watch<UserMenuState>(userMenuStateProvider);

    return GestureDetector(
      onTap: () {
        showDialog<void>(
          context: context,
          barrierColor: Colors.transparent,
          builder: (context) => const UserMenuDialog(),
        );
      },
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 48,
              height: 48,
              color: colors.sidebar,
              child: Icon(Icons.person, color: colors.onPrimary, size: 32),
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
        ],
      ),
    );
  }
}
