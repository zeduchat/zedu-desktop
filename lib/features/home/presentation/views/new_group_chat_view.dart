import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class NewGroupChatView extends ConsumerStatefulWidget {
  const NewGroupChatView({super.key});

  @override
  ConsumerState<NewGroupChatView> createState() => _NewGroupChatViewState();
}

class _NewGroupChatViewState extends ConsumerState<NewGroupChatView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<TeamMember> _selectedMembers = [];
  bool _isLoading = false;
  String? _errorMessage;

  /// Set once the person changes the selection, so the helper stays neutral
  /// until then and only turns red for an incomplete selection afterwards.
  bool _touched = false;

  /// The search sent to the server, set once typing pauses. '' lists everyone.
  String _query = '';
  Timer? _searchDebounce;
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _focusNode.removeListener(_onFocusChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    _searchDebounce?.cancel();
    if (query == _query) return;
    if (query.isEmpty) {
      setState(() => _query = '');
      return;
    }
    // Members are searched on the server, as on the People page.
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = query);
    });
  }

  void _onFocusChanged() {
    setState(() {
      _showDropdown = _focusNode.hasFocus;
    });
  }

  /// The group DM and the chips work with [TeamMember]s.
  static TeamMember _teamMemberFrom(OrgMember member) {
    final name = member.name.isNotEmpty ? member.name : member.username;
    return TeamMember(
      id: member.id,
      email: member.email,
      role: 'member',
      dateJoined: '',
      status: member.deactivated
          ? TeamMemberStatus.inactive
          : TeamMemberStatus.active,
      name: name.isEmpty ? null : name,
      avatarUrl: member.photoUrl.isEmpty ? null : member.photoUrl,
    );
  }

  void _toggleMemberSelection(TeamMember member) {
    setState(() {
      _touched = true;
      if (_selectedMembers.any((m) => m.id == member.id)) {
        _selectedMembers.removeWhere((m) => m.id == member.id);
      } else {
        _selectedMembers.add(member);
      }
      _searchController.clear();
    });
  }

  String _getMemberDisplayName(TeamMember member) {
    final name = member.name?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final emailPrefix = member.email.split('@').first.trim();
    if (emailPrefix.isNotEmpty) {
      return emailPrefix;
    }
    return 'Member';
  }

  String _getComposerPlaceholder() {
    if (_selectedMembers.isEmpty) {
      return 'Select a recipient above to start messaging...';
    }
    if (_selectedMembers.length == 1) {
      final name = _getMemberDisplayName(_selectedMembers.first);
      return 'Message @$name';
    }
    return 'Message group (${_selectedMembers.length} members)...';
  }

  String _getMemberInitials(String displayName) {
    return avatarInitials(displayName);
  }

  Future<void> _handleCreate() async {
    if (_selectedMembers.length < 2) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ref
        .read(groupDmProvider.notifier)
        .createGroupDm(_selectedMembers);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    switch (result) {
      case Success<GroupDM>():
        final newGroup = result.value;
        // Check if this was a duplicate group that already existed
        final selectedIds = _selectedMembers.map((m) => m.id).toSet();
        final groupIds = newGroup.members.map((m) => m.id).toSet();
        final isDuplicate =
            groupIds.length == selectedIds.length &&
            groupIds.containsAll(selectedIds);

        if (isDuplicate &&
            ref.read(groupDmProvider).any((g) => g.id == newGroup.id)) {
          // If the group DM was already in the sidebar list, we show a SnackBar and open it
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Opening existing conversation with ${newGroup.name}...',
                  ),
                ],
              ),
              backgroundColor: context.colors.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Group DM "${newGroup.name}" created successfully!'),
                ],
              ),
              backgroundColor: context.colors.success,
            ),
          );
        }

        // Navigate to the newly created/existing Group DM!
        ref.read(activeChatProvider.notifier).selectGroupDm(newGroup.id);

      case Failure<GroupDM>():
        setState(() {
          _errorMessage = result.error.friendlyMessage;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Watched from the start so the members load as the page opens.
    final members = ref.watch(peopleListProvider(_query));

    return Container(
      color: colors.background,
      child: Stack(
        children: [
          Column(
            children: [
              // 1. Header
              _buildHeader(colors),

              // 2. Main Search and Chips Section
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Input container
                            _buildSearchInputContainer(colors),
                            const SizedBox(height: 12),

                            // Selected Member Chips
                            if (_selectedMembers.isNotEmpty) ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _selectedMembers.map((member) {
                                  final name = _getMemberDisplayName(member);
                                  final initials = _getMemberInitials(name);
                                  return Chip(
                                    avatar: CircleAvatar(
                                      backgroundColor: colors.primary
                                          .withValues(alpha: 0.15),
                                      child: Text(
                                        initials,
                                        style: TextStyle(
                                          color: colors.primary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    label: Text(
                                      name,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    deleteIcon: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: colors.textHint,
                                    ),
                                    onDeleted: () =>
                                        _toggleMemberSelection(member),
                                    backgroundColor: colors.divider.withValues(
                                      alpha: 0.5,
                                    ),
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Validation Helper Text
                            _buildValidationHelper(colors),

                            const SizedBox(
                              height: 120,
                            ), // Spacer so the suggestion box isn't clipped
                          ],
                        ),

                        // Suggestions Dropdown Card (Inline Layer overlay)
                        if (_showDropdown)
                          Positioned(
                            top: 60,
                            left: 0,
                            right: 0,
                            // Inside the field's tap region so pressing a row
                            // doesn't unfocus the field (and hide the list)
                            // before the tap completes.
                            child: TextFieldTapRegion(
                              child: Material(
                                elevation: 8,
                                shadowColor: colors.textPrimary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxHeight: 250,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: colors.divider),
                                  ),
                                  child: _buildSuggestions(colors, members),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Bottom Message Editor (Mock UI replicating home message editor)
              _buildBottomMessageEditor(colors),
            ],
          ),

          // 4. Loading/Saving Spinner Overlay
          if (_isLoading)
            Container(
              color: Colors.white.withValues(alpha: 0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: colors.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Creating private group conversation...',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 5. Error & Retry Full Overlay
          if (_errorMessage != null)
            Container(
              color: Colors.white.withValues(alpha: 0.95),
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: colors.error.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: colors.textPrimary.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: colors.error),
                      const SizedBox(height: 16),
                      Text(
                        'Creation Failed',
                        style: TextStyle(
                          color: colors.error,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _errorMessage = null;
                              });
                            },
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: colors.textHint),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _errorMessage = null;
                              });
                              _handleCreate();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Workspace members matching [_query], without yourself or anyone already
  /// selected, paged in as the list scrolls.
  Widget _buildSuggestions(
    AppPalette colors,
    AsyncValue<PeopleListState> members,
  ) {
    return members.when(
      loading: () => _buildSuggestionMessage(
        colors,
        'Loading members...',
        leading: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colors.primary,
          ),
        ),
      ),
      error: (_, _) => _buildSuggestionMessage(
        colors,
        'Could not load members',
        action: TextButton(
          onPressed: () => ref.invalidate(peopleListProvider(_query)),
          child: const Text('Retry'),
        ),
      ),
      data: (list) {
        final currentUserId = ref.read(authNotifierProvider).user?.id;
        final visible = [
          for (final m in list.members)
            if (m.id != currentUserId &&
                !_selectedMembers.any((s) => s.id == m.id))
              m,
        ];
        final showFooter = list.hasMore || list.isLoadingMore;
        if (visible.isEmpty && !showFooter) {
          return _buildSuggestionMessage(colors, 'No members found');
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.extentAfter < 200) {
              ref.read(peopleListProvider(_query).notifier).loadMore();
            }
            return false;
          },
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: visible.length + (showFooter ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == visible.length) {
                return _buildSuggestionsFooter(colors, list);
              }
              return _buildMemberRow(colors, visible[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildSuggestionsFooter(AppPalette colors, PeopleListState list) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: list.isLoadingMore
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.primary,
                ),
              )
            // Scrolling near the end loads more; the button also covers a
            // page too short to scroll.
            : TextButton(
                onPressed: () =>
                    ref.read(peopleListProvider(_query).notifier).loadMore(),
                child: Text(
                  list.loadMoreFailed
                      ? 'Could not load more. Retry'
                      : 'Load more',
                ),
              ),
      ),
    );
  }

  Widget _buildSuggestionMessage(
    AppPalette colors,
    String text, {
    Widget? leading,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 12)],
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          ),
          ?action,
        ],
      ),
    );
  }

  Widget _buildMemberRow(AppPalette colors, OrgMember orgMember) {
    final member = _teamMemberFrom(orgMember);
    final name = _getMemberDisplayName(member);
    final initials = _getMemberInitials(name);
    return InkWell(
      onTap: () => _toggleMemberSelection(member),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.divider, width: 0.5)),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 16,
              backgroundColor: colors.primary.withValues(alpha: 0.1),
              child: Text(
                initials,
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member.email,
                    style: TextStyle(color: colors.textHint, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Checkbox / Add icon
            Icon(Icons.add_circle_outline, color: colors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppPalette colors) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          Text(
            'New message',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildSearchInputContainer(AppPalette colors) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            'To: ',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: '#a-channel, @somebody, or somebody',
                hintStyle: TextStyle(color: colors.textHint),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              style: TextStyle(color: colors.textPrimary, fontSize: 15),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _selectedMembers.length >= 2 ? _handleCreate : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: colors.divider,
              disabledForegroundColor: colors.textHint,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationHelper(AppPalette colors) {
    final count = _selectedMembers.length;
    final isReady = count >= 2;

    final IconData icon;
    final Color color;
    final String text;

    if (isReady) {
      icon = Icons.check_circle;
      color = colors.success;
      text = 'Ready to create conversation! (Selected: $count members)';
    } else {
      icon = Icons.info_outline;
      color = (_touched || _errorMessage != null)
          ? colors.error
          : colors.textSecondary;
      text =
          'Select at least 2 members to start a group DM (Selected: $count/2)';
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomMessageEditor(AppPalette colors) {
    final placeholder = _getComposerPlaceholder();
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      decoration: BoxDecoration(color: colors.onPrimary),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.onPrimary,
          border: Border.all(color: colors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.format_bold, size: 20, color: colors.textHint),
                const SizedBox(width: 16),
                Icon(Icons.format_italic, size: 20, color: colors.textHint),
                const SizedBox(width: 16),
                Icon(Icons.link, size: 20, color: colors.textHint),
                const SizedBox(width: 16),
                Icon(Icons.list, size: 20, color: colors.textHint),
                const SizedBox(width: 16),
                Icon(Icons.code, size: 20, color: colors.textHint),
              ],
            ),
            Divider(height: 24, color: colors.divider),
            TextField(
              enabled: false, // Disabled during creation screen
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: TextStyle(color: colors.textHint),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.add, color: colors.textHint.withValues(alpha: 0.75)),
                const SizedBox(width: 12),
                Icon(
                  Icons.emoji_emotions_outlined,
                  color: colors.textHint.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.alternate_email,
                  color: colors.textHint.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.videocam_outlined,
                  color: colors.textHint.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.mic_none_outlined,
                  color: colors.textHint.withValues(alpha: 0.75),
                ),
                const Spacer(),
                Icon(
                  Icons.send_rounded,
                  color: colors.textHint.withValues(alpha: 0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
