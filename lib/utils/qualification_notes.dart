String categoryQualificationNotes(Map<String, dynamic> category) {
  return (category['qualification_notes'] ?? '').toString().trim();
}
