import 'package:flutter/material.dart';

import '../../../data/core/mappers.dart';
import '../../ui/items/friend_result_item.dart';

class AddFriendResult {
  final int id;
  final String initial;
  final LinearGradient avatarGradient;
  final String name;
  final String subtitle;
  final bool online;
  final FriendActionState action;
  final int? requestId;

  const AddFriendResult({
    required this.id,
    required this.initial,
    required this.avatarGradient,
    required this.name,
    required this.subtitle,
    required this.action,
    this.online = false,
    this.requestId,
  });

  AddFriendResult copyWith({
    FriendActionState? action,
    int? requestId,
  }) {
    return AddFriendResult(
      id: id,
      initial: initial,
      avatarGradient: avatarGradient,
      name: name,
      subtitle: subtitle,
      online: online,
      action: action ?? this.action,
      requestId: requestId ?? this.requestId,
    );
  }

  factory AddFriendResult.fromApi(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final name = (json['full_name'] as String?) ?? 'User';
    final number = json['number']?.toString() ?? '';
    final country = json['country']?.toString() ?? '';
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
      name: name,
      subtitle: number.isEmpty
          ? (country.isEmpty ? '' : country)
          : [
              formatNumber(number),
              if (country.isNotEmpty) country,
            ].join(' · '),
      online: json['is_online'] == true,
      action: action,
      requestId: (json['friendship_request_id'] as num?)?.toInt(),
    );
  }

  /// `GET /friends/requests` elementi (outgoing / include_declined).
  factory AddFriendResult.fromRequestApi(Map<String, dynamic> json) {
    final requestId = (json['id'] as num?)?.toInt();
    final user = Map<String, dynamic>.from(json['user'] as Map? ?? const {});
    final id = (user['id'] as num?)?.toInt() ?? 0;
    final name = (user['full_name'] as String?) ?? 'User';
    final number = user['number']?.toString() ?? '';
    final country = user['country']?.toString() ?? '';
    // pending → So'rov yuborildi; none (rad) → Qo'shish
    final status = (json['status'] as String?) ?? 'pending';
    final action = status == 'pending'
        ? FriendActionState.requested
        : FriendActionState.add;
    return AddFriendResult(
      id: id,
      initial: initialsOf(name),
      avatarGradient: avatarGradientFor(id),
      name: name,
      subtitle: number.isEmpty
          ? (country.isEmpty ? '' : country)
          : [
              formatNumber(number),
              if (country.isNotEmpty) country,
            ].join(' · '),
      online: user['is_online'] == true,
      action: action,
      requestId: requestId,
    );
  }
}
