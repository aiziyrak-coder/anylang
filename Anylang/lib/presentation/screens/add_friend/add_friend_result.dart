import 'package:flutter/material.dart';

import '../../../data/core/mappers.dart';
import '../../ui/items/friend_result_item.dart';

class AddFriendResult {
  final int id;
  final String initial;
  final LinearGradient avatarGradient;
  final String? avatarUrl;
  final String name;
  final String subtitle;
  final bool online;
  final FriendActionState action;
  final int? requestId;
  final String? country;
  final String? businessRole;
  final double? rating;
  final bool verified;
  final List<String> languages;
  final List<String> keywords;
  final bool isBusiness;
  final int productsCount;
  final int countriesCount;

  const AddFriendResult({
    required this.id,
    required this.initial,
    required this.avatarGradient,
    required this.name,
    required this.subtitle,
    required this.action,
    this.avatarUrl,
    this.online = false,
    this.requestId,
    this.country,
    this.businessRole,
    this.rating,
    this.verified = false,
    this.languages = const [],
    this.keywords = const [],
    this.isBusiness = false,
    this.productsCount = 0,
    this.countriesCount = 0,
  });

  AddFriendResult copyWith({
    FriendActionState? action,
    int? requestId,
    String? avatarUrl,
  }) {
    return AddFriendResult(
      id: id,
      initial: initial,
      avatarGradient: avatarGradient,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      name: name,
      subtitle: subtitle,
      online: online,
      action: action ?? this.action,
      requestId: requestId ?? this.requestId,
      country: country,
      businessRole: businessRole,
      rating: rating,
      verified: verified,
      languages: languages,
      keywords: keywords,
      isBusiness: isBusiness,
      productsCount: productsCount,
      countriesCount: countriesCount,
    );
  }

  factory AddFriendResult.fromApi(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final company = (json['company_name'] as String?)?.trim();
    final name = (company != null && company.isNotEmpty)
        ? company
        : ((json['full_name'] as String?) ?? 'User');
    final number = json['number']?.toString() ?? '';
    final country = json['country']?.toString();
    final status = (json['friendship_status'] as String?) ?? 'none';
    final action = switch (status) {
      'friends' || 'accepted' => FriendActionState.message,
      'pending' => FriendActionState.requested,
      _ => FriendActionState.add,
    };
    return AddFriendResult(
      id: id,
      initial: initialsOf(name),
      avatarGradient: avatarGradientFor(id),
      avatarUrl: json['avatar_url'] as String?,
      name: name,
      subtitle: number.isEmpty ? '' : formatNumber(number),
      online: json['is_online'] == true,
      action: action,
      requestId: (json['friendship_request_id'] as num?)?.toInt(),
      country: country,
      businessRole: json['business_role']?.toString(),
      rating: (json['rating'] as num?)?.toDouble(),
      verified: json['verified_badge'] == true,
      languages: languageCodesFromApi(json),
      keywords: _keywordsFromApi(json),
      isBusiness: json['is_business'] == true,
      productsCount: (json['products_count'] as num?)?.toInt() ?? 0,
      countriesCount: (json['countries_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// `GET /friends/requests` elementi (outgoing / include_declined).
  factory AddFriendResult.fromRequestApi(Map<String, dynamic> json) {
    final requestId = (json['id'] as num?)?.toInt();
    final user = Map<String, dynamic>.from(json['user'] as Map? ?? const {});
    final id = (user['id'] as num?)?.toInt() ?? 0;
    final company = (user['company_name'] as String?)?.trim();
    final name = (company != null && company.isNotEmpty)
        ? company
        : ((user['full_name'] as String?) ?? 'User');
    final number = user['number']?.toString() ?? '';
    final status = (json['status'] as String?) ?? 'pending';
    final action = status == 'pending'
        ? FriendActionState.requested
        : FriendActionState.add;
    return AddFriendResult(
      id: id,
      initial: initialsOf(name),
      avatarGradient: avatarGradientFor(id),
      avatarUrl: user['avatar_url'] as String?,
      name: name,
      subtitle: number.isEmpty ? '' : formatNumber(number),
      online: user['is_online'] == true,
      action: action,
      requestId: requestId,
      country: user['country']?.toString(),
      businessRole: user['business_role']?.toString(),
      rating: (user['rating'] as num?)?.toDouble(),
      verified: user['verified_badge'] == true,
      languages: languageCodesFromApi(user),
      keywords: _keywordsFromApi(user),
      isBusiness: user['is_business'] == true,
      productsCount: (user['products_count'] as num?)?.toInt() ?? 0,
      countriesCount: (user['countries_count'] as num?)?.toInt() ?? 0,
    );
  }
}

List<String> _keywordsFromApi(Map<dynamic, dynamic> json) {
  final out = <String>[];
  final raw = json['keywords'];
  if (raw is List) {
    for (final e in raw) {
      final s = e?.toString().trim() ?? '';
      if (s.isNotEmpty) out.add(s);
    }
  }
  return out;
}
