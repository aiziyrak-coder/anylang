import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/core/mappers.dart';
import '../ui/ai_matching.dart';
import '../ui/profile_avatar.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

/// AI Matching insight'larini ko‘rsatish sheet.
Future<void> showAiMatchingBottomSheet(
  BuildContext context, {
  required AiMatchingResult result,
  required void Function(AiMatchCompany company) onOpenCompany,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AiMatchingSheet(
      result: result,
      onOpenCompany: onOpenCompany,
    ),
  );
}

class _AiMatchingSheet extends StatelessWidget {
  final AiMatchingResult result;
  final void Function(AiMatchCompany company) onOpenCompany;

  const _AiMatchingSheet({
    required this.result,
    required this.onOpenCompany,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final maxH = MediaQuery.sizeOf(context).height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10.dp),
            Container(
              width: 40.dp,
              height: 4.dp,
              decoration: BoxDecoration(
                color: c.textFaint,
                borderRadius: BorderRadius.circular(2.dp),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.dp, 16.dp, 20.dp, 8.dp),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ai_matching_title'.tr,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6.dp),
                  Text(
                    'ai_matching_desc'.tr,
                    style: TextStyle(color: c.textSecondary, fontSize: 13.sp, height: 1.4),
                  ),
                ],
              ),
            ),
            Flexible(
              child: result.items.isEmpty
                  ? Padding(
                      padding: EdgeInsets.all(24.dp),
                      child: Text(
                        'ai_matching_empty'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.textSecondary, fontSize: 14.sp),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(16.dp, 8.dp, 16.dp, 20.dp),
                      itemCount: result.items.length,
                      separatorBuilder: (_, __) => SizedBox(height: 12.dp),
                      itemBuilder: (context, i) {
                        final item = result.items[i];
                        return _InsightCard(
                          insight: item,
                          onOpenCompany: (company) {
                            Navigator.pop(context);
                            onOpenCompany(company);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final AiMatchInsight insight;
  final void Function(AiMatchCompany company) onOpenCompany;

  const _InsightCard({
    required this.insight,
    required this.onOpenCompany,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16.dp),
        border: Border.all(color: c.outline),
      ),
      padding: EdgeInsets.all(14.dp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.travel_explore_rounded, color: c.accent, size: 20.dp),
              SizedBox(width: 8.dp),
              Expanded(
                child: Text(
                  formatCountryName(insight.country),
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 4.dp),
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(99.dp),
                ),
                child: Text(
                  '${insight.count}',
                  style: TextStyle(
                    color: c.accentText,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.dp),
          Text(
            insight.message,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (insight.sampleCompanies.isNotEmpty) ...[
            SizedBox(height: 12.dp),
            Text(
              'ai_matching_samples'.tr,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.dp),
            for (final company in insight.sampleCompanies.take(3)) ...[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12.dp),
                  onTap: () => onOpenCompany(company),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6.dp),
                    child: Row(
                      children: [
                        ProfileAvatar(
                          initial: initialsOf(company.name),
                          gradient: avatarGradientFor(company.id),
                          imageUrl: company.logoUrl,
                          size: 32,
                        ),
                        SizedBox(width: 10.dp),
                        Expanded(
                          child: Text(
                            company.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: c.textFaint, size: 18.dp),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
