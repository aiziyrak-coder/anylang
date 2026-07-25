class MarketplaceGroup {
  final int id;
  final String slug;
  final String emoji;
  final String title;
  final String blurb;
  final int memberCount;
  final bool joined;
  final int rfqToday;
  final String? myRole;
  final bool verifiedOnly;
  final bool canJoin;

  const MarketplaceGroup({
    required this.id,
    required this.slug,
    required this.emoji,
    required this.title,
    required this.blurb,
    required this.memberCount,
    required this.joined,
    required this.rfqToday,
    this.myRole,
    this.verifiedOnly = false,
    this.canJoin = true,
  });

  factory MarketplaceGroup.fromApi(Map<String, dynamic> json) {
    return MarketplaceGroup(
      id: (json['id'] as num?)?.toInt() ?? 0,
      slug: json['slug']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '🏪',
      title: json['title']?.toString() ?? '',
      blurb: json['blurb']?.toString() ?? '',
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      joined: json['joined'] == true,
      rfqToday: (json['rfq_today'] as num?)?.toInt() ?? 0,
      myRole: json['my_role']?.toString(),
      verifiedOnly: json['verified_only'] == true,
      canJoin: json['can_join'] != false,
    );
  }

  MarketplaceGroup copyWith({
    int? id,
    String? slug,
    String? emoji,
    String? title,
    String? blurb,
    int? memberCount,
    bool? joined,
    int? rfqToday,
    String? myRole,
    bool? verifiedOnly,
    bool? canJoin,
  }) {
    return MarketplaceGroup(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      emoji: emoji ?? this.emoji,
      title: title ?? this.title,
      blurb: blurb ?? this.blurb,
      memberCount: memberCount ?? this.memberCount,
      joined: joined ?? this.joined,
      rfqToday: rfqToday ?? this.rfqToday,
      myRole: myRole ?? this.myRole,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      canJoin: canJoin ?? this.canJoin,
    );
  }
}
