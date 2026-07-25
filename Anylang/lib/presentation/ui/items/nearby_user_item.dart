import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../screens/nearby/nearby_person.dart';
import '../profile_avatar.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';

/// Yaqin foydalanuvchi qatori — masalan: "English speaker · 300 m".
class NearbyUserItem extends StatelessWidget {
  final NearbyPerson person;
  final VoidCallback? onTap;
  final VoidCallback? onMessage;

  const NearbyUserItem({
    super.key,
    required this.person,
    this.onTap,
    this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final langName = formatLanguageName(person.languageCode);
    final subtitle = 'nearby_speaker_distance'.trParams({
      'lang': langName.isEmpty ? person.languageCode.toUpperCase() : langName,
      'distance': person.distanceLabel,
    });

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16.dp),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.dp),
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 12.dp),
          decoration: BoxDecoration(
            color: c.isDark ? const Color(0x99152A42) : const Color(0xCCFFFFFF),
            borderRadius: BorderRadius.circular(16.dp),
            border: Border.all(color: c.surfaceBorder, width: 0.7),
            boxShadow: c.glassShadow,
          ),
          child: Row(
            children: [
              ProfileAvatar(
                initial: person.initial,
                gradient: avatarGradientFor(person.id),
                imageUrl: person.avatarUrl,
                size: 48,
              ),
              SizedBox(width: 12.dp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            person.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (person.verified) ...[
                          SizedBox(width: 4.dp),
                          Icon(
                            Icons.verified_rounded,
                            size: 16.dp,
                            color: c.accentText,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 3.dp),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.dp),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.dp, vertical: 5.dp),
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(999.dp),
                ),
                child: Text(
                  person.distanceLabel,
                  style: TextStyle(
                    color: c.accentText,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onMessage != null) ...[
                SizedBox(width: 6.dp),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onMessage,
                    borderRadius: BorderRadius.circular(12.dp),
                    child: Padding(
                      padding: EdgeInsets.all(8.dp),
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 20.dp,
                        color: c.accentText,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
