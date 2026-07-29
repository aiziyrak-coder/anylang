/// `/me` → `profile_insights` payload.
class ProfileAnalytics7d {
  final int views;
  final int profileVisits;
  final int listingClicks;
  final List<int> viewsSeries;

  const ProfileAnalytics7d({
    this.views = 0,
    this.profileVisits = 0,
    this.listingClicks = 0,
    this.viewsSeries = const [],
  });

  factory ProfileAnalytics7d.fromApi(Map<String, dynamic>? json) {
    if (json == null) return const ProfileAnalytics7d();
    final series = <int>[];
    final raw = json['views_series'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          series.add((e['views'] as num?)?.toInt() ?? 0);
        }
      }
    }
    return ProfileAnalytics7d(
      views: (json['views'] as num?)?.toInt() ?? 0,
      profileVisits: (json['profile_visits'] as num?)?.toInt() ?? 0,
      listingClicks: (json['listing_clicks'] as num?)?.toInt() ?? 0,
      viewsSeries: series,
    );
  }
}

class ProfileInsights {
  final int followers;
  final int likes;
  final int translationsCount;
  final int languagesUsed;
  final int? trustPercent;
  final int listingsCount;
  final int totalViews;
  final double? rating;
  final int profileVisitsTotal;
  final ProfileAnalytics7d analytics7d;

  const ProfileInsights({
    this.followers = 0,
    this.likes = 0,
    this.translationsCount = 0,
    this.languagesUsed = 0,
    this.trustPercent,
    this.listingsCount = 0,
    this.totalViews = 0,
    this.rating,
    this.profileVisitsTotal = 0,
    this.analytics7d = const ProfileAnalytics7d(),
  });

  factory ProfileInsights.fromApi(Map<String, dynamic>? json) {
    if (json == null) return const ProfileInsights();
    final a7 = json['analytics_7d'];
    return ProfileInsights(
      followers: (json['followers'] as num?)?.toInt() ?? 0,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      translationsCount: (json['translations_count'] as num?)?.toInt() ?? 0,
      languagesUsed: (json['languages_used'] as num?)?.toInt() ?? 0,
      trustPercent: (json['trust_percent'] as num?)?.toInt(),
      listingsCount: (json['listings_count'] as num?)?.toInt() ?? 0,
      totalViews: (json['total_views'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble(),
      profileVisitsTotal: (json['profile_visits_total'] as num?)?.toInt() ?? 0,
      analytics7d: ProfileAnalytics7d.fromApi(
        a7 is Map ? Map<String, dynamic>.from(a7) : null,
      ),
    );
  }
}
