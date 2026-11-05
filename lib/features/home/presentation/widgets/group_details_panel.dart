import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class GroupDetailsPanel extends StatefulWidget {
  final GroupDM group;
  final VoidCallback onClose;
  final ValueChanged<String> onRename;
  final VoidCallback onLeave;

  const GroupDetailsPanel({
    super.key,
    required this.group,
    required this.onClose,
    required this.onRename,
    required this.onLeave,
  });

  @override
  State<GroupDetailsPanel> createState() => _GroupDetailsPanelState();
}

class _GroupDetailsPanelState extends State<GroupDetailsPanel> {
  bool _isEditingName = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveName() {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != widget.group.name) {
      widget.onRename(newName);
    }
    setState(() => _isEditingName = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(left: BorderSide(color: colors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Group Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: Icon(Icons.close, color: colors.textHint),
                  splashRadius: 20,
                  tooltip: 'Close group details',
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_isEditingName)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: colors.divider),
                            ),
                          ),
                          onSubmitted: (_) => _saveName(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.check, color: colors.primary),
                        onPressed: _saveName,
                        tooltip: 'Save group name',
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.group.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.edit,
                          size: 18,
                          color: colors.textHint,
                        ),
                        onPressed: () => setState(() => _isEditingName = true),
                        tooltip: 'Edit group name',
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                Text(
                  'Participants (${widget.group.members.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.textHint,
                  ),
                ),
                const SizedBox(height: 8),
                ...widget.group.members.map(
                  (member) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: colors.primary.withValues(
                            alpha: 0.1,
                          ),
                          child: Text(
                            avatarInitial(
                              member.name,
                              fallback: avatarInitial(member.email),
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          member.name ?? member.email,
                          style: TextStyle(color: colors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Pinned Messages',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.textHint,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No pinned messages',
                  style: TextStyle(
                    color: colors.textHint,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: widget.onLeave,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(
                        color: colors.error.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text('Leave Group'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
