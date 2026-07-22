import 'package:flutter/material.dart';
import '../../ui/theme/gradients.dart';
import '../../../data/core/mappers.dart';

/// Bitta do'st (Do'stlar ro'yxati elementi).
class Friend {
  final int id;
  final String initial;
  final LinearGradient avatarGradient;
  final String name;
  final String status;
  final bool online;
  final String? avatarUrl;
  final String? nativeLanguage;
  final String? number;

  const Friend({
    required this.id,
    required this.initial,
    required this.avatarGradient,
    required this.name,
    required this.status,
    required this.online,
    this.avatarUrl,
    this.nativeLanguage,
    this.number,
  });

  factory Friend.fromApi(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final name = (json['full_name'] as String?)?.trim().isNotEmpty == true
        ? json['full_name'] as String
        : 'User';
    final online = json['is_online'] == true;
    final lang = (json['native_language'] as String?) ?? '';
    final status = online ? 'Onlayn · $lang' : lang;
    return Friend(
      id: id,
      initial: initialsOf(name),
      avatarGradient: avatarGradientFor(id),
      name: name,
      status: status,
      online: online,
      avatarUrl: json['avatar_url'] as String?,
      nativeLanguage: lang,
      number: json['number'] as String?,
    );
  }

  Friend copyWithOnline(bool online) {
    final lang = nativeLanguage ?? '';
    return Friend(
      id: id,
      initial: initial,
      avatarGradient: avatarGradient,
      name: name,
      status: online ? 'Onlayn · $lang' : lang,
      online: online,
      avatarUrl: avatarUrl,
      nativeLanguage: nativeLanguage,
      number: number,
    );
  }
}
