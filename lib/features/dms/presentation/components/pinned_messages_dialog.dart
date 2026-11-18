import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Opens the pinned messages of a channel or DM (Ziki #17).
Future<void> showPinnedMessages(
  BuildContext context,
  WidgetRef ref, {
  required String channelId,
  required String title,
}) {
  final repository = ref.read(dmRepositoryProvider);
  return showDialog<void>(
    context: context,
    builder: (context) => PinnedMessagesDialog(
      title: title,
      load: () => repository.getPinnedMessages(channelId),
    ),
  );
}

/// The pin button in a chat header, beside the Buzz call button. It opens
/// the conversation's pinned messages.
class PinnedMessagesButton extends ConsumerWidget {
  const PinnedMessagesButton({
    super.key,
    required this.channelId,
    required this.title,
  });

  final String channelId;

  /// The dialog's title, such as "# general pinned messages".
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Tooltip(
      message: 'Pinned messages',
      child: InkWell(
        onTap: () => showPinnedMessages(
          context,
          ref,
          channelId: channelId,
          title: title,
        ),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            border: Border.all(color: colors.divider),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.push_pin_outlined,
            size: 18,
            color: colors.textPrimary,
            semanticLabel: 'Pinned messages',
          ),
        ),
      ),
    );
  }
}

/// Lists a conversation's pinned messages, newest first, as the server
/// reports them: who wrote each one, when, and its text.
class PinnedMessagesDialog extends StatefulWidget {
  const PinnedMessagesDialog({
    super.key,
    required this.title,
    required this.load,
  });

  final String title;

  /// Fetches the pinned messages; called again by Retry.
  final Future<List<Map<String, dynamic>>> Function() load;

  @override
  State<PinnedMessagesDialog> createState() => _PinnedMessagesDialogState();
}

class _PinnedMessagesDialogState extends State<PinnedMessagesDialog> {
  late Future<List<Map<String, dynamic>>> _pinned;

  @override
  void initState() {
    super.initState();
    _pinned = _loadNewestFirst();
  }

  Future<List<Map<String, dynamic>>> _loadNewestFirst() async {
    final pinned = [...await widget.load()];
    pinned.sort((a, b) => _createdAt(b).compareTo(_createdAt(a)));
    return pinned;
  }

  void _retry() {
    final reload = _loadNewestFirst();
    setState(() {
      _pinned = reload;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _pinned,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Couldn't load the pinned messages."),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _retry, child: const Text('Retry')),
                  ],
                ),
              );
            }
            final pinned = snapshot.data ?? const [];
            if (pinned.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No pinned messages yet.')),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              itemCount: pinned.length,
              separatorBuilder: (_, _) => Divider(color: colors.divider),
              itemBuilder: (context, index) {
                final message = pinned[index];
                final createdAt = _createdAt(message);
                return ListTile(
                  leading: Icon(
                    Icons.push_pin_outlined,
                    size: 18,
                    color: colors.textHint,
                  ),
                  title: Text(_author(message)),
                  subtitle: Text(
                    channelMessagePlainText(
                      message['message']?.toString() ?? '',
                    ),
                  ),
                  trailing: createdAt == _unknownDate
                      ? null
                      : Text(
                          _formatDate(createdAt),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: colors.textHint,
                          ),
                        ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

final _unknownDate = DateTime.fromMillisecondsSinceEpoch(0);

DateTime _createdAt(Map<String, dynamic> message) =>
    DateTime.tryParse(message['created_at']?.toString() ?? '')?.toLocal() ??
    _unknownDate;

String _author(Map<String, dynamic> message) {
  for (final key in const ['full_name', 'username']) {
    final value = message[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return 'Someone';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';
