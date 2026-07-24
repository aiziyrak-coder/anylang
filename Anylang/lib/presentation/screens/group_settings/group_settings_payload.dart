class GroupSettingsPayload {
  final int chatId;
  final String title;
  final String? avatarUrl;
  final String? myRole;
  final bool isSuper;
  final String? inviteLink;
  final int? memberLimit;

  const GroupSettingsPayload({
    required this.chatId,
    required this.title,
    this.avatarUrl,
    this.myRole,
    this.isSuper = false,
    this.inviteLink,
    this.memberLimit,
  });
}
