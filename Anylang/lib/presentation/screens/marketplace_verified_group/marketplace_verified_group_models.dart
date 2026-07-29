class MarketplaceVerifiedMember {
  final int userId;
  final String fullName;
  final String? avatarUrl;
  final bool isOnline;
  final bool verifiedBadge;
  final String? role;

  const MarketplaceVerifiedMember({
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    this.isOnline = false,
    this.verifiedBadge = false,
    this.role,
  });

  factory MarketplaceVerifiedMember.fromApi(Map<String, dynamic> json) {
    return MarketplaceVerifiedMember(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      fullName: json['full_name']?.toString() ?? 'User',
      avatarUrl: json['avatar_url']?.toString(),
      isOnline: json['is_online'] == true,
      verifiedBadge: json['verified_badge'] == true,
      role: json['role']?.toString(),
    );
  }

  String get initial {
    final t = fullName.trim();
    if (t.isEmpty) return '?';
    return t.substring(0, 1).toUpperCase();
  }
}

class MarketplaceVerifiedGroupPreview {
  final int id;
  final String slug;
  final String emoji;
  final String title;
  final String blurb;
  final int memberCount;
  final int rfqToday;
  final bool verifiedOnly;
  final bool joined;
  final bool canJoin;
  final bool viewerVerified;
  final int trustScore;
  final String trustLevel;
  final bool documentsVerified;
  final List<MarketplaceVerifiedMember> members;
  final int membersShown;

  const MarketplaceVerifiedGroupPreview({
    required this.id,
    required this.slug,
    required this.emoji,
    required this.title,
    required this.blurb,
    required this.memberCount,
    required this.rfqToday,
    required this.verifiedOnly,
    required this.joined,
    required this.canJoin,
    required this.viewerVerified,
    required this.trustScore,
    required this.trustLevel,
    required this.documentsVerified,
    required this.members,
    required this.membersShown,
  });

  factory MarketplaceVerifiedGroupPreview.fromApi(Map<String, dynamic> json) {
    final raw = json['members'];
    final members = <MarketplaceVerifiedMember>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          members.add(
            MarketplaceVerifiedMember.fromApi(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    return MarketplaceVerifiedGroupPreview(
      id: (json['id'] as num?)?.toInt() ?? 0,
      slug: json['slug']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '🏪',
      title: json['title']?.toString() ?? '',
      blurb: json['blurb']?.toString() ?? '',
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      rfqToday: (json['rfq_today'] as num?)?.toInt() ?? 0,
      verifiedOnly: json['verified_only'] != false,
      joined: json['joined'] == true,
      canJoin: json['can_join'] == true,
      viewerVerified: json['viewer_verified'] == true,
      trustScore: ((json['trust_score'] as num?)?.toInt() ?? 0).clamp(0, 100),
      trustLevel: json['trust_level']?.toString() ?? 'low',
      documentsVerified: json['documents_verified'] == true,
      members: members,
      membersShown: (json['members_shown'] as num?)?.toInt() ?? members.length,
    );
  }
}
