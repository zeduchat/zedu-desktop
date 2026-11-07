import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The Buzz tab: start a meeting now, create one for later, or join one by
/// code or link. Meetings run in the web app, so they open in the browser,
/// as the web Buzz page opens them in a new tab.
class BuzzView extends ConsumerStatefulWidget {
  const BuzzView({super.key});

  @override
  ConsumerState<BuzzView> createState() => _BuzzViewState();
}

class _BuzzViewState extends ConsumerState<BuzzView> {
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _toast(String message, {AppToastType type = AppToastType.error}) =>
      AppToastService.show(context, type: type, message: message);

  Future<void> _open(Uri link) async {
    final opened = await canLaunchUrl(link) && await launchUrl(link);
    if (!opened && mounted) {
      _toast("Couldn't open the meeting in your browser.");
    }
  }

  Future<void> _create({required bool startNow}) async {
    final result = await ref
        .read(buzzMeetingsProvider.notifier)
        .create(startNow: startNow);
    if (!mounted) return;
    switch (result) {
      case Success<Uri>(:final value):
        if (startNow) {
          await _open(value);
        } else {
          await BuzzMeetingLinkDialog.show(context, value.toString());
        }
      case Failure<Uri>(:final error):
        _toast(error.message);
    }
  }

  Future<void> _join() async {
    final code = buzzMeetingCode(_codeController.text);
    if (code.isEmpty) return;
    final result = ref.read(buzzMeetingsProvider.notifier).joinLink(code);
    switch (result) {
      case Success<Uri>(:final value):
        await _open(value);
      case Failure<Uri>(:final error):
        _toast(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final action = ref.watch(buzzMeetingsProvider);
    final isBusy = action != BuzzMeetingAction.none;
    final canJoin = buzzMeetingCode(_codeController.text).isNotEmpty;

    return Container(
      color: colors.onPrimary,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colors.primaryBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.videocam_outlined,
                    size: 34,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Seamless video calls and meetings for every learning '
                  'community.',
                  textAlign: TextAlign.center,
                  style: context.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Connect classrooms, cohorts, and teams in one shared space',
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: colors.textHint,
                  ),
                ),
                const SizedBox(height: 40),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _NewMeetingButton(
                      isBusy: isBusy,
                      onCreateForLater: () => _create(startNow: false),
                      onStartNow: () => _create(startNow: true),
                    ),
                    SizedBox(
                      width: 280,
                      height: 48,
                      child: TextField(
                        controller: _codeController,
                        onSubmitted: (_) => _join(),
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter a code or link',
                          hintStyle: context.textTheme.bodyMedium?.copyWith(
                            color: colors.textHint,
                          ),
                          prefixIcon: Icon(
                            Icons.keyboard_outlined,
                            color: colors.textHint,
                            size: 20,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: colors.divider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: colors.primary),
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: canJoin ? _join : null,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.primary,
                        textStyle: context.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Join'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Meetings open in your browser.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewMeetingButton extends StatelessWidget {
  const _NewMeetingButton({
    required this.isBusy,
    required this.onCreateForLater,
    required this.onStartNow,
  });

  final bool isBusy;
  final VoidCallback onCreateForLater;
  final VoidCallback onStartNow;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final itemStyle = context.textTheme.bodyMedium?.copyWith(
      color: colors.textPrimary,
    );

    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.onPrimary),
      ),
      menuChildren: [
        MenuItemButton(
          leadingIcon: Icon(Icons.link, size: 18, color: colors.textSecondary),
          onPressed: onCreateForLater,
          child: Text('Create a meeting for later', style: itemStyle),
        ),
        MenuItemButton(
          leadingIcon: Icon(Icons.add, size: 18, color: colors.textSecondary),
          onPressed: onStartNow,
          child: Text('Start an instant meeting', style: itemStyle),
        ),
      ],
      builder: (context, controller, _) => FilledButton.icon(
        onPressed: isBusy
            ? null
            : () => controller.isOpen ? controller.close() : controller.open(),
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.primary.withValues(alpha: 0.6),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: isBusy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.onPrimary,
                ),
              )
            : const Icon(Icons.video_call_outlined, size: 20),
        label: const Text('New meeting'),
      ),
    );
  }
}
