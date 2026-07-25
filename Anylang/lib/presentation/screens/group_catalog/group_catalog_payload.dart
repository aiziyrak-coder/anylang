class GroupCatalogPayload {
  final int chatId;
  final String title;
  /// products | documents | companies
  final String initialSection;

  const GroupCatalogPayload({
    required this.chatId,
    required this.title,
    this.initialSection = 'products',
  });
}
