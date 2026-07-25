import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../screens/group_catalog/group_catalog_models.dart';
import '../profile_avatar.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';
import '../../../data/core/mappers.dart';

class GroupCatalogProductItem extends StatelessWidget {
  final GroupCatalogProduct item;
  final VoidCallback onTap;

  const GroupCatalogProductItem({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.dp),
        child: Ink(
          padding: EdgeInsets.all(12.dp),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14.dp),
            border: Border.all(color: c.surfaceBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 52.dp,
                height: 52.dp,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(12.dp),
                  image: item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(item.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: item.imageUrl == null || item.imageUrl!.isEmpty
                    ? Text('📦', style: TextStyle(fontSize: 22.sp))
                    : null,
              ),
              SizedBox(width: 12.dp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((item.price ?? '').isNotEmpty) ...[
                      SizedBox(height: 2.dp),
                      Text(
                        item.price!,
                        style: TextStyle(
                          color: c.accent,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if ((item.subtitle ?? '').isNotEmpty) ...[
                      SizedBox(height: 2.dp),
                      Text(
                        item.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textSecondary, fontSize: 12.sp),
                      ),
                    ],
                    if ((item.senderName ?? '').isNotEmpty) ...[
                      SizedBox(height: 4.dp),
                      Text(
                        item.senderName!,
                        style: TextStyle(color: c.textFaint, fontSize: 11.sp),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.textFaint, size: 20.dp),
            ],
          ),
        ),
      ),
    );
  }
}

class GroupCatalogDocumentItem extends StatelessWidget {
  final GroupCatalogDocument item;
  final VoidCallback onTap;

  const GroupCatalogDocumentItem({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.dp),
        child: Ink(
          padding: EdgeInsets.all(12.dp),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14.dp),
            border: Border.all(color: c.surfaceBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 52.dp,
                height: 52.dp,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(12.dp),
                ),
                child: Text(
                  (item.ext ?? 'DOC').length > 4
                      ? '📄'
                      : (item.ext ?? 'DOC'),
                  style: TextStyle(
                    color: c.accent,
                    fontSize: (item.ext ?? '').length > 4 ? 20.sp : 11.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: 12.dp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.filename,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((item.senderName ?? '').isNotEmpty) ...[
                      SizedBox(height: 4.dp),
                      Text(
                        item.senderName!,
                        style: TextStyle(color: c.textFaint, fontSize: 11.sp),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.open_in_new_rounded, color: c.textFaint, size: 18.dp),
            ],
          ),
        ),
      ),
    );
  }
}

class GroupCatalogCompanyItem extends StatelessWidget {
  final GroupCatalogCompany item;
  final VoidCallback onTap;

  const GroupCatalogCompanyItem({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final roleKey = item.businessRole == null || item.businessRole!.isEmpty
        ? null
        : 'business_role_${item.businessRole}';
    final roleLabel = roleKey == null
        ? null
        : (roleKey.tr == roleKey ? item.businessRole : roleKey.tr);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.dp),
        child: Ink(
          padding: EdgeInsets.all(12.dp),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14.dp),
            border: Border.all(color: c.surfaceBorder),
          ),
          child: Row(
            children: [
              ProfileAvatar(
                initial: initialsOf(item.companyName),
                gradient: avatarGradientFor(item.userId),
                size: 52,
                imageUrl: item.logoUrl,
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
                            item.companyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (item.verifiedBadge) ...[
                          SizedBox(width: 4.dp),
                          Icon(Icons.verified_rounded,
                              color: c.accent, size: 16.dp),
                        ],
                      ],
                    ),
                    if (roleLabel != null) ...[
                      SizedBox(height: 2.dp),
                      Text(
                        roleLabel,
                        style: TextStyle(color: c.textSecondary, fontSize: 12.sp),
                      ),
                    ],
                    if ((item.country ?? '').isNotEmpty) ...[
                      SizedBox(height: 2.dp),
                      Text(
                        item.country!,
                        style: TextStyle(color: c.textFaint, fontSize: 11.sp),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.textFaint, size: 20.dp),
            ],
          ),
        ),
      ),
    );
  }
}
