import 'package:flutter/material.dart';
import '../../ui/items/friend_result_item.dart';
import '../../ui/theme/gradients.dart';

/// "Do'st qo'shish" qidiruv natijasi. Hozircha mock — keyin backenddan.
class AddFriendResult {
  final String initial;
  final LinearGradient avatarGradient;
  final String name;

  /// "@username · Davlat" (do'st bo'lsa e'tiborsiz — o'rniga status ko'rsatiladi).
  final String subtitle;
  final bool online;
  final FriendActionState action;

  const AddFriendResult({
    required this.initial,
    required this.avatarGradient,
    required this.name,
    required this.subtitle,
    required this.action,
    this.online = false,
  });
}

/// Namuna natijalar (dizayndagi holat). Keyinchalik so'rov bilan almashtiriladi.
const List<AddFriendResult> kMockAddFriendResults = [
  AddFriendResult(
    initial: 'C',
    avatarGradient: avatarGreenGradient,
    name: 'Chen Long',
    subtitle: '@chenlong · Xitoy',
    action: FriendActionState.add,
  ),
  AddFriendResult(
    initial: 'H',
    avatarGradient: avatarOliveGradient,
    name: 'Hans Weber',
    subtitle: '@hansw · Nemis',
    action: FriendActionState.add,
  ),
  AddFriendResult(
    initial: 'Y',
    avatarGradient: avatarGreenGradient,
    name: 'Yuki Tanaka',
    subtitle: '',
    action: FriendActionState.message,
    online: true,
  ),
  AddFriendResult(
    initial: 'A',
    avatarGradient: avatarSlateGradient,
    name: 'Ahmad Karimov',
    subtitle: '@ahmadk · O‘zbek',
    action: FriendActionState.requested,
  ),
  AddFriendResult(
    initial: 'E',
    avatarGradient: avatarMaroonGradient,
    name: 'Elena Novak',
    subtitle: '@elena_n · Chex',
    action: FriendActionState.add,
  ),
];
