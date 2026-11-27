/// Whether a message from the API was edited after it was sent. The backend
/// sends `edited` and `edited_at`; `is_edited` and `isEdited` are accepted
/// too.
bool messageWasEdited(Map<String, dynamic> json) {
  for (final key in const ['edited', 'is_edited', 'isEdited']) {
    final value = json[key];
    if (value == true || value?.toString().toLowerCase() == 'true') {
      return true;
    }
  }
  // Go writes an unset time as year 1.
  final editedAt = DateTime.tryParse(json['edited_at']?.toString() ?? '');
  return editedAt != null && editedAt.year > 1;
}
