import '../../../data/core/mappers.dart';

class FeedAuthor {
  final int id;
  final String companyName;
  final String? logoUrl;
  final bool verifiedBadge;
  final bool factoryVerified;
  final String? country;

  const FeedAuthor({
    required this.id,
    required this.companyName,
    this.logoUrl,
    this.verifiedBadge = false,
    this.factoryVerified = false,
    this.country,
  });

  factory FeedAuthor.fromApi(Map<String, dynamic>? json) {
    if (json == null) {
      return const FeedAuthor(id: 0, companyName: '');
    }
    return FeedAuthor(
      id: (json['id'] as num?)?.toInt() ?? 0,
      companyName: (json['company_name'] as String?)?.trim() ?? '',
      logoUrl: (json['logo_url'] as String?)?.trim(),
      verifiedBadge: json['verified_badge'] == true,
      factoryVerified: json['factory_verified'] == true,
      country: (json['country'] as String?)?.trim(),
    );
  }
}

class FeedPost {
  final int id;
  final String postType;
  final String title;
  final String body;
  final String? imageUrl;
  final Map<String, dynamic> meta;
  final DateTime? createdAt;
  final FeedAuthor author;
  final bool isMine;

  const FeedPost({
    required this.id,
    required this.postType,
    required this.title,
    this.body = '',
    this.imageUrl,
    this.meta = const {},
    this.createdAt,
    required this.author,
    this.isMine = false,
  });

  factory FeedPost.fromApi(Map<String, dynamic> json) {
    DateTime? created;
    final raw = json['created_at']?.toString();
    if (raw != null && raw.isNotEmpty) {
      created = DateTime.tryParse(raw)?.toLocal();
    }
    final authorRaw = json['author'];
    return FeedPost(
      id: (json['id'] as num?)?.toInt() ?? 0,
      postType: (json['post_type'] as String?) ?? 'new_product',
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      imageUrl: (json['image_url'] as String?)?.trim(),
      meta: asMap(json['meta']) ?? const {},
      createdAt: created,
      author: FeedAuthor.fromApi(
        authorRaw is Map ? Map<String, dynamic>.from(authorRaw) : null,
      ),
      isMine: json['is_mine'] == true,
    );
  }
}

const List<String> kFeedPostTypes = [
  'new_product',
  'new_factory',
  'new_certificate',
  'exhibition',
  'discount',
];

String feedTypeLabelKey(String type) => 'feed_type_$type';
