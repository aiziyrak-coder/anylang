import 'package:flutter/material.dart';
import '../../ui/theme/gradients.dart';

/// Bitta do'st (Do'stlar ro'yxati elementi). Hozircha mock — keyin backenddan.
class Friend {
  final String initial;
  final LinearGradient avatarGradient;
  final String name;

  /// Holat matni: "Onlayn · Nemis" yoki "5 daqiqa oldin · Yapon".
  final String status;
  final bool online;

  const Friend({
    required this.initial,
    required this.avatarGradient,
    required this.name,
    required this.status,
    required this.online,
  });
}

/// Namuna do'stlar (dizayndagi holat). Keyinchalik so'rov bilan almashtiriladi.
const List<Friend> kMockFriends = [
  Friend(
    initial: 'A',
    avatarGradient: avatarTealGradient,
    name: 'Anna Müller',
    status: 'Onlayn · Nemis',
    online: true,
  ),
  Friend(
    initial: 'R',
    avatarGradient: avatarOliveGradient,
    name: 'Ricardo Sánchez',
    status: 'Onlayn · Ispan',
    online: true,
  ),
  Friend(
    initial: 'L',
    avatarGradient: avatarMaroonGradient,
    name: 'Li Wei',
    status: 'Onlayn · Xitoy',
    online: true,
  ),
  Friend(
    initial: 'Y',
    avatarGradient: avatarGreenGradient,
    name: 'Yuki Tanaka',
    status: '5 daqiqa oldin · Yapon',
    online: false,
  ),
  Friend(
    initial: 'S',
    avatarGradient: avatarSlateGradient,
    name: 'Sophie Laurent',
    status: '1 soat oldin · Fransuz',
    online: false,
  ),
  Friend(
    initial: 'M',
    avatarGradient: avatarBrownGradient,
    name: 'Marco Rossi',
    status: 'Kecha · Italyan',
    online: false,
  ),
];
