import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/core/mappers.dart';
import '../ui/market_analytics.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

Future<void> showMarketAnalyticsBottomSheet(
  BuildContext context, {
  required MarketAnalyticsResult result,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MarketAnalyticsSheet(result: result),
  );
}

class _MarketAnalyticsSheet extends StatelessWidget {
  final MarketAnalyticsResult result;

  const _MarketAnalyticsSheet({required this.result});

  IconData _trendIcon(String trend) {
    switch (trend) {
      case 'import_up':
        return Icons.local_shipping_outlined;
      case 'demand_down':
        return Icons.trending_down_rounded;
      default:
        return Icons.trending_up_rounded;
    }
  }

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
                    'market_analytics_title'.tr,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6.dp),
                  Text(
                    'market_analytics_desc'.tr,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 13.sp,
                      height: 1.4,
                    ),
                  ),
                  if (result.focusSummary.isNotEmpty) ...[
                    SizedBox(height: 10.dp),
                    Text(
                      '${'market_analytics_focus'.tr}: ${result.focusSummary}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textFaint,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Flexible(
              child: result.items.isEmpty
                  ? Padding(
                      padding: EdgeInsets.all(24.dp),
                      child: Text(
                        'market_analytics_empty'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.textSecondary, fontSize: 14.sp),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(16.dp, 8.dp, 16.dp, 20.dp),
                      itemCount: result.items.length,
                      separatorBuilder: (_, _) => SizedBox(height: 12.dp),
                      itemBuilder: (context, i) {
                        final item = result.items[i];
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
                                  Icon(
                                    _trendIcon(item.trend),
                                    color: c.accent,
                                    size: 20.dp,
                                  ),
                                  SizedBox(width: 8.dp),
                                  Expanded(
                                    child: Text(
                                      formatCountryName(item.country),
                                      style: TextStyle(
                                        color: c.textPrimary,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (item.topic.isNotEmpty)
                                    Flexible(
                                      child: Text(
                                        item.topic,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                          color: c.textSecondary,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 10.dp),
                              Text(
                                item.message,
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
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
