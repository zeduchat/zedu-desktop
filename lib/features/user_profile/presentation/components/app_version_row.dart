import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Shows the app version at the foot of the Settings navigation, with a button
/// that copies it for bug reports. Shows nothing if the version can't be read.
class AppVersionRow extends ConsumerWidget {
  const AppVersionRow({super.key});

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    AppToastService.show(
      context,
      type: AppToastType.success,
      message: 'Version copied',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).value;
    if (version == null) return const SizedBox.shrink();

    final text = 'Version $version';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copy version',
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            color: Colors.white70,
            icon: const Icon(Icons.copy),
            onPressed: () => _copy(context, text),
          ),
        ],
      ),
    );
  }
}
