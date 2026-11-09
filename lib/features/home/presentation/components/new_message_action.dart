import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Opens the new-message page, the flow the compose buttons in the workspace
/// header and the Direct messages section start. It clears the open DM first,
/// so the new page replaces it instead of showing beside it.
void openNewMessage(WidgetRef ref) {
  ref.read(selectedDmProvider.notifier).select(null);
  ref.read(activeChatProvider.notifier).selectNewGroupChat();
}
