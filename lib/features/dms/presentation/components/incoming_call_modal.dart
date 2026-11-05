import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class IncomingCallModal extends ConsumerWidget {
  const IncomingCallModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCall = ref.watch(activeCallProvider);

    // Only show if incoming
    if (activeCall.state.status != CallStatus.incoming) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;

    return Positioned(
      top: 24,
      right: 24,
      child: Material(
        color: Colors.transparent,
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: colors.primary,
                    backgroundImage:
                        activeCall.state.remoteAvatarUrl != null &&
                            activeCall.state.remoteAvatarUrl!.isNotEmpty
                        ? NetworkImage(activeCall.state.remoteAvatarUrl!)
                        : null,
                    child:
                        activeCall.state.remoteAvatarUrl == null ||
                            activeCall.state.remoteAvatarUrl!.isEmpty
                        ? Text(
                            avatarInitial(activeCall.state.remoteUserName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Incoming Buzz Call',
                          style: TextStyle(
                            color: colors.textHint,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          activeCall.state.remoteUserName ?? 'Unknown User',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      ref.read(activeCallProvider.notifier).declineCall();
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Decline'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(activeCallProvider.notifier).acceptCall();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Accept'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
