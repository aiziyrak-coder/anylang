import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ui/app_empty_state.dart';
import '../ui/buttons/primary_button.dart';
import '../ui/items/user_search_item.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';
import 'profile_people_item.dart';

class ProfilePeopleLoadResult {
  final bool locked;
  final int totalCount;
  final List<ProfilePeopleItem> items;
  final bool failed;

  const ProfilePeopleLoadResult({
    this.locked = false,
    this.totalCount = 0,
    this.items = const [],
    this.failed = false,
  });

  static const failedResult = ProfilePeopleLoadResult(failed: true);
}

/// Profil statistikasi — odamlar ro‘yxati (ko‘rishlar / kuzatuvchilar / layklar).
Future<void> showProfilePeopleBottomSheet(
  BuildContext context, {
  required String title,
  required String emptyTitle,
  String? emptySubtitle,
  required Future<ProfilePeopleLoadResult> Function() loader,
  required Future<void> Function(ProfilePeopleItem item) onOpenUser,
  Future<void> Function()? onUnlockPremium,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProfilePeopleSheet(
      title: title,
      emptyTitle: emptyTitle,
      emptySubtitle: emptySubtitle,
      loader: loader,
      onOpenUser: onOpenUser,
      onUnlockPremium: onUnlockPremium,
    ),
  );
}

class _ProfilePeopleSheet extends StatefulWidget {
  final String title;
  final String emptyTitle;
  final String? emptySubtitle;
  final Future<ProfilePeopleLoadResult> Function() loader;
  final Future<void> Function(ProfilePeopleItem item) onOpenUser;
  final Future<void> Function()? onUnlockPremium;

  const _ProfilePeopleSheet({
    required this.title,
    required this.emptyTitle,
    required this.loader,
    required this.onOpenUser,
    this.emptySubtitle,
    this.onUnlockPremium,
  });

  @override
  State<_ProfilePeopleSheet> createState() => _ProfilePeopleSheetState();
}

class _ProfilePeopleSheetState extends State<_ProfilePeopleSheet> {
  bool _loading = true;
  ProfilePeopleLoadResult _result = const ProfilePeopleLoadResult();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final next = await widget.loader();
    if (!mounted) return;
    setState(() {
      _result = next;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final maxH = MediaQuery.sizeOf(context).height * 0.78;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
        border: Border(top: BorderSide(color: c.surfaceBorder, width: 0.7)),
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
                color: c.outline,
                borderRadius: BorderRadius.circular(99.dp),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.dp, 16.dp, 20.dp, 8.dp),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (!_loading && !_result.failed && _result.totalCount > 0)
                    Text(
                      '${_result.totalCount}',
                      style: TextStyle(
                        color: c.textFaint,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            Flexible(child: _body(c)),
          ],
        ),
      ),
    );
  }

  Widget _body(AppColors c) {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 48.dp),
        child: Center(
          child: SizedBox(
            width: 28.dp,
            height: 28.dp,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: c.accent,
            ),
          ),
        ),
      );
    }
    if (_result.failed) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20.dp, 24.dp, 20.dp, 28.dp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'profile_stat_load_failed'.tr,
            ),
            SizedBox(height: 12.dp),
            PrimaryButton(
              text: 'common_retry'.tr,
              onTap: _reload,
            ),
          ],
        ),
      );
    }
    if (_result.locked) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20.dp, 8.dp, 20.dp, 24.dp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'profile_viewers_locked_banner'.trParams({
                'n': '${_result.totalCount}',
              }),
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8.dp),
            Text(
              'profile_viewers_premium_cta'.tr,
              style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
            ),
            if (widget.onUnlockPremium != null) ...[
              SizedBox(height: 16.dp),
              PrimaryButton(
                text: 'profile_view_plans'.tr,
                onTap: () async {
                  Navigator.pop(context);
                  await widget.onUnlockPremium!();
                },
              ),
            ],
          ],
        ),
      );
    }
    if (_result.items.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 28.dp),
        child: AppEmptyState(
          icon: Icons.people_outline_rounded,
          title: widget.emptyTitle,
          subtitle: widget.emptySubtitle,
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(12.dp, 0, 12.dp, 20.dp),
      itemCount: _result.items.length,
      separatorBuilder: (_, _) => Divider(height: 1.dp, color: c.outline),
      itemBuilder: (_, i) {
        final item = _result.items[i];
        return UserSearchItem(
          initial: item.initial,
          avatarGradient: item.avatarGradient,
          avatarUrl: item.avatarUrl,
          name: item.name,
          subtitle: item.subtitle,
          onTap: () async {
            Navigator.pop(context);
            await widget.onOpenUser(item);
          },
        );
      },
    );
  }
}
