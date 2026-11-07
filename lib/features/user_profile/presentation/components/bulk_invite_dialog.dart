import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class BulkInviteDialog extends ConsumerStatefulWidget {
  const BulkInviteDialog({super.key});
  @override
  ConsumerState<BulkInviteDialog> createState() => _BulkInviteDialogState();
}

class _BulkInviteDialogState extends ConsumerState<BulkInviteDialog> {
  final _emails = TextEditingController();
  String? _orgId;
  String? _userId;
  String _role = 'User';
  bool _busy = false;
  Map<String, String?> _outcomes = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _orgId = ref.read(workspaceProvider).selectedWorkspace?.id;
    _userId = ref.read(authNotifierProvider).user?.id;
  }

  @override
  void dispose() {
    _emails.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) {
      return;
    }
    final orgId = _orgId;
    if (orgId == null ||
        ref.read(workspaceProvider).selectedWorkspace?.id != orgId ||
        ref.read(authNotifierProvider).user?.id != _userId) {
      setState(
        () => _error = 'Workspace changed. Close and reopen this dialog.',
      );
      return;
    }
    final addresses = BulkInvitation.addresses(_emails.text);
    if (addresses.isEmpty ||
        addresses.length > 100 ||
        addresses.any((e) => !BulkInvitation.valid(e))) {
      setState(
        () => _error =
            'Enter 1–100 valid email addresses, separated by commas, semicolons, or whitespace.',
      );
      return;
    }
    final known = ref
        .read(userProfileNotifierProvider)
        .teamMembers
        .map((m) => m.email.toLowerCase())
        .toSet();
    final pending = addresses
        .where((e) => !_outcomes.containsKey(e) || _outcomes[e] != null)
        .toList();
    final send = pending.where((e) => !known.contains(e)).toList();
    setState(() {
      _busy = true;
      _error = null;
      for (final email in pending.where(known.contains)) {
        _outcomes[email] =
            'Already a member or invited. Refresh the list to check.';
      }
    });
    try {
      final results = await ref
          .read(userProfileNotifierProvider.notifier)
          .inviteMembers(emails: send, role: _role, orgId: orgId);
      if (!mounted) {
        return;
      }
      if (ref.read(workspaceProvider).selectedWorkspace?.id != orgId ||
          ref.read(authNotifierProvider).user?.id != _userId) {
        setState(() {
          _outcomes = {};
          _error =
              'Workspace changed. Reopen invitations for the selected workspace.';
        });
        return;
      }
      setState(() => _outcomes.addAll(results));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not complete invitations. Refresh the member list before retrying.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final changed =
        ref.watch(workspaceProvider).selectedWorkspace?.id != _orgId ||
        ref.watch(authNotifierProvider).user?.id != _userId;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Invite multiple people'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _emails,
                  enabled: !_busy && !changed,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Email addresses',
                    helperText:
                        'Separate with commas, semicolons, or whitespace. Maximum 100.',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: [
                    for (final role in ['Administrator', 'Manager', 'User'])
                      DropdownMenuItem(value: role, child: Text(role)),
                  ],
                  onChanged: _busy || changed
                      ? null
                      : (value) => setState(() => _role = value ?? 'User'),
                ),
                if (changed)
                  const Text(
                    'Workspace changed. Close and reopen this dialog.',
                  ),
                if (_error != null)
                  Text(_error!, style: TextStyle(color: context.colors.error)),
                if (!changed)
                  ..._outcomes.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('${e.key}: ${e.value ?? "Invitation sent"}'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: _busy || changed ? null : _send,
            child: Text(
              _busy
                  ? 'Sending…'
                  : _outcomes.isEmpty
                  ? 'Send invitations'
                  : 'Retry unsent addresses',
            ),
          ),
        ],
      ),
    );
  }
}
