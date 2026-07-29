import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/buttons/danger_button.dart';
import '../../ui/gradient_background.dart';
import '../../ui/items/group_catalog_item.dart';
import '../../ui/profile_avatar.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme/gradients.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'group_settings_action.dart';
import 'group_settings_state.dart';

class GroupSettingsContent extends ScreenContent<GroupSettingsState> {
  late final PageController _pageController;
  Worker? _tabWorker;

  @override
  void initContent() {
    _pageController = PageController();
  }

  @override
  void uiBuildFinished(GroupSettingsState state) {
    _tabWorker?.dispose();
    _tabWorker = ever(state.tabIndex, (int i) {
      if (!_pageController.hasClients) return;
      final current = _pageController.page?.round() ?? 0;
      if (current != i) {
        _pageController.animateToPage(
          i,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void onClose() {
    _tabWorker?.dispose();
    _pageController.dispose();
    super.onClose();
  }

  @override
  Widget build(
    BuildContext context,
    GroupSettingsState state,
    FutureOr<void> Function(MyAction action) sendAction,
  ) {
    final c = context.appColors;
    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.dp, 4.dp, 16.dp, 0),
              child: AppTopBar(
                title: 'group_settings_title'.tr,
                onBack: () => sendAction(Back()),
              ),
            ),
            Expanded(
              child: Obx(() {
                if (state.loading.value && state.members.isEmpty) {
                  return const Center(child: AppLoading());
                }
                final role = state.myRole.value;
                final isAdmin = role == 'owner' || role == 'admin';
                final isOwner = role == 'owner';
                final tab = state.tabIndex.value;

                return Column(
                  children: [
                    SizedBox(height: 10.dp),
                    Center(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: isAdmin
                              ? () => sendAction(PickGroupAvatar())
                              : null,
                          child: ProfileAvatar(
                            initial: state.title.value.isNotEmpty
                                ? state.title.value[0].toUpperCase()
                                : 'G',
                            gradient: avatarTealGradient,
                            size: 88,
                            imageUrl: state.avatarUrl.value,
                          ),
                        ),
                      ),
                    ),
                    if (state.isSuper.value) ...[
                      SizedBox(height: 8.dp),
                      Text(
                        'group_settings_super_badge'.tr,
                        style: TextStyle(
                          color: c.accentText,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                    SizedBox(height: 6.dp),
                    Text(
                      '${state.members.length}'
                      '${state.memberLimit.value != null ? ' / ${state.memberLimit.value}' : ''}'
                      ' ${'group_settings_members'.tr}',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 14.dp),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.dp),
                      child: Row(
                        children: [
                          Expanded(
                            child: _BubbleButton(
                              c: c,
                              icon: Icons.edit_rounded,
                              showIcon: isAdmin,
                              label: state.title.value.trim().isEmpty
                                  ? 'group_settings_name'.tr
                                  : state.title.value.trim(),
                              onTap: isAdmin
                                  ? () => sendAction(EditGroupNameTap())
                                  : null,
                            ),
                          ),
                          SizedBox(width: 8.dp),
                          Expanded(
                            child: _BubbleButton(
                              c: c,
                              icon: Icons.person_add_alt_1_rounded,
                              label: 'group_settings_add_members'.tr,
                              onTap: () => sendAction(AddGroupMembers()),
                            ),
                          ),
                          SizedBox(width: 8.dp),
                          Expanded(
                            child: _BubbleButton(
                              c: c,
                              icon: Icons.link_rounded,
                              label: 'group_settings_copy_link'.tr,
                              onTap: () => sendAction(CopyInviteLink()),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.dp),
                    _TabStrip(
                      c: c,
                      selected: tab,
                      onSelect: (i) => sendAction(SelectGroupSettingsTab(i)),
                    ),
                    SizedBox(height: 4.dp),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (i) =>
                            sendAction(SelectGroupSettingsTab(i)),
                        children: [
                          _MembersPage(
                            c: c,
                            state: state,
                            isAdmin: isAdmin,
                            isOwner: isOwner,
                            sendAction: sendAction,
                          ),
                          _MediaPage(
                            c: c,
                            state: state,
                            sendAction: sendAction,
                          ),
                          _ProductsPage(
                            c: c,
                            state: state,
                            sendAction: sendAction,
                          ),
                          _DocumentsPage(
                            c: c,
                            state: state,
                            sendAction: sendAction,
                          ),
                          _CompaniesPage(
                            c: c,
                            state: state,
                            sendAction: sendAction,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _BubbleButton extends StatelessWidget {
  final AppColors c;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool showIcon;

  const _BubbleButton({
    required this.c,
    required this.icon,
    required this.label,
    this.onTap,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18.dp);
    final enabled = onTap != null;
    return Material(
      color: c.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8.dp, vertical: 12.dp),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: c.surfaceBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIcon) ...[
                Icon(
                  icon,
                  size: 22.dp,
                  color: enabled ? c.accent : c.textFaint,
                ),
                SizedBox(height: 6.dp),
              ],
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  final AppColors c;
  final int selected;
  final ValueChanged<int> onSelect;

  const _TabStrip({
    required this.c,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final labels = [
      'group_settings_tab_members'.tr,
      'group_settings_tab_media'.tr,
      'group_settings_tab_products'.tr,
      'group_settings_tab_documents'.tr,
      'group_settings_tab_companies'.tr,
    ];
    return SizedBox(
      height: 42.dp,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.dp),
        itemCount: labels.length,
        separatorBuilder: (_, __) => SizedBox(width: 4.dp),
        itemBuilder: (ctx, i) {
          final active = selected == i;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10.dp),
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(i);
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.dp),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      labels[i],
                      style: TextStyle(
                        color: active ? c.accentText : c.textSecondary,
                        fontSize: 13.sp,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8.dp),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      height: 3.dp,
                      width: active ? 28.dp : 0,
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: BorderRadius.circular(99.dp),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String _roleLabel(String role) {
  return switch (role) {
    'owner' => 'group_settings_role_owner'.tr,
    'admin' => 'group_settings_role_admin'.tr,
    _ => 'group_settings_role_member'.tr,
  };
}

class _MembersPage extends StatelessWidget {
  final AppColors c;
  final GroupSettingsState state;
  final bool isAdmin;
  final bool isOwner;
  final FutureOr<void> Function(MyAction) sendAction;

  const _MembersPage({
    required this.c,
    required this.state,
    required this.isAdmin,
    required this.isOwner,
    required this.sendAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16.dp, 8.dp, 16.dp, 24.dp),
      children: [
        if (isOwner && !state.isSuper.value) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.star_outline, color: c.accentText),
            title: Text('group_settings_super'.tr),
            subtitle: Text('group_settings_super_desc'.tr),
            trailing: TextButton(
              onPressed: () => sendAction(UpgradeSuperGroup()),
              child: Text(r'$10'),
            ),
          ),
          SizedBox(height: 8.dp),
        ],
        if (isAdmin) ...[
          Row(
            children: [
              TextButton(
                onPressed: () => sendAction(RegenerateInviteLink()),
                child: Text('group_settings_invite_renew'.tr),
              ),
              TextButton(
                onPressed: () => sendAction(DisableInviteLink()),
                child: Text('group_settings_invite_disable'.tr),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => sendAction(OpenGroupStatsFromSettings()),
                child: Text('group_stats_title'.tr),
              ),
            ],
          ),
          SizedBox(height: 4.dp),
        ],
        for (final m in state.members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ProfileAvatar(
              initial: m.fullName.isNotEmpty
                  ? m.fullName[0].toUpperCase()
                  : '?',
              gradient: avatarTealGradient,
              size: 40,
              imageUrl: m.avatarUrl,
            ),
            title: Text(
              m.fullName,
              style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              _roleLabel(m.role),
              style: TextStyle(color: c.textSecondary, fontSize: 12.sp),
            ),
            trailing: isAdmin && m.role != 'owner'
                ? PopupMenuButton<String>(
                    onSelected: (v) {
                      switch (v) {
                        case 'remove':
                          sendAction(RemoveGroupMember(m.userId));
                        case 'promote':
                          sendAction(PromoteGroupAdmin(m.userId));
                        case 'demote':
                          sendAction(DemoteGroupAdmin(m.userId));
                        case 'transfer':
                          sendAction(TransferOwnershipAction(m.userId));
                      }
                    },
                    itemBuilder: (_) => [
                      if (isOwner && m.role == 'member')
                        PopupMenuItem(
                          value: 'promote',
                          child: Text('group_settings_promote'.tr),
                        ),
                      if (isOwner && m.role == 'admin')
                        PopupMenuItem(
                          value: 'demote',
                          child: Text('group_settings_demote'.tr),
                        ),
                      if (isOwner)
                        PopupMenuItem(
                          value: 'transfer',
                          child: Text('group_settings_transfer'.tr),
                        ),
                      PopupMenuItem(
                        value: 'remove',
                        child: Text('group_settings_remove_member'.tr),
                      ),
                    ],
                  )
                : null,
          ),
        SizedBox(height: 20.dp),
        if (!isOwner)
          DangerButton(
            text: 'group_settings_leave'.tr,
            onTap: () => sendAction(LeaveGroupAction()),
          ),
        if (isOwner)
          DangerButton(
            text: 'group_settings_delete'.tr,
            onTap: () => sendAction(DeleteGroupAction()),
          ),
      ],
    );
  }
}

class _MediaPage extends StatelessWidget {
  final AppColors c;
  final GroupSettingsState state;
  final FutureOr<void> Function(MyAction) sendAction;

  const _MediaPage({
    required this.c,
    required this.state,
    required this.sendAction,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (state.mediaLoading.value && !state.mediaLoaded.value) {
        return const Center(child: AppLoading());
      }
      final items = state.mediaItems;
      final counts = state.mediaCounts;
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.dp, 8.dp, 16.dp, 8.dp),
              child: Wrap(
                spacing: 8.dp,
                runSpacing: 8.dp,
                children: [
                  _CountChip(
                    c: c,
                    label: 'shared_media_photos'.tr,
                    count: counts['photos'] ?? 0,
                  ),
                  _CountChip(
                    c: c,
                    label: 'shared_media_videos'.tr,
                    count: counts['videos'] ?? 0,
                  ),
                  _CountChip(
                    c: c,
                    label: 'shared_media_files'.tr,
                    count: counts['files'] ?? 0,
                  ),
                ],
              ),
            ),
          ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.photo_library_outlined,
                title: 'group_settings_media_empty'.tr,
                subtitle: 'group_settings_media_empty_hint'.tr,
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16.dp, 0, 16.dp, 24.dp),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 6.dp,
                  crossAxisSpacing: 6.dp,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final item = items[i];
                    final url = item['thumb_url']?.toString() ??
                        item['url']?.toString() ??
                        '';
                    final type = item['type']?.toString() ?? '';
                    return Material(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(10.dp),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10.dp),
                        onTap: () =>
                            sendAction(OpenGroupSettingsMediaItem(item)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10.dp),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (url.isNotEmpty)
                                Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.broken_image_outlined,
                                    color: c.textFaint,
                                  ),
                                )
                              else
                                Icon(Icons.insert_drive_file_outlined,
                                    color: c.textFaint),
                              if (type == 'video')
                                Align(
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.play_circle_fill_rounded,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    size: 28.dp,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: items.length,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.dp, 0, 16.dp, 24.dp),
              child: TextButton(
                onPressed: () => sendAction(OpenFullSharedMedia()),
                child: Text('chat_overflow_shared_media'.tr),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _CountChip extends StatelessWidget {
  final AppColors c;
  final String label;
  final int count;

  const _CountChip({
    required this.c,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 6.dp),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(99.dp),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          color: c.accentText,
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProductsPage extends StatelessWidget {
  final AppColors c;
  final GroupSettingsState state;
  final FutureOr<void> Function(MyAction) sendAction;

  const _ProductsPage({
    required this.c,
    required this.state,
    required this.sendAction,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (state.catalogLoading.value && !state.catalogLoaded.value) {
        return const Center(child: AppLoading());
      }
      if (state.products.isEmpty) {
        return AppEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'group_catalog_products_empty'.tr,
          subtitle: 'group_catalog_products_empty_hint'.tr,
        );
      }
      return ListView.separated(
        padding: EdgeInsets.fromLTRB(16.dp, 8.dp, 16.dp, 24.dp),
        itemCount: state.products.length,
        separatorBuilder: (_, __) => SizedBox(height: 10.dp),
        itemBuilder: (context, i) {
          final item = state.products[i];
          return GroupCatalogProductItem(
            item: item,
            onTap: () => sendAction(OpenGroupSettingsCatalogProduct(item)),
          );
        },
      );
    });
  }
}

class _DocumentsPage extends StatelessWidget {
  final AppColors c;
  final GroupSettingsState state;
  final FutureOr<void> Function(MyAction) sendAction;

  const _DocumentsPage({
    required this.c,
    required this.state,
    required this.sendAction,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (state.catalogLoading.value && !state.catalogLoaded.value) {
        return const Center(child: AppLoading());
      }
      if (state.documents.isEmpty) {
        return AppEmptyState(
          icon: Icons.description_outlined,
          title: 'group_catalog_documents_empty'.tr,
          subtitle: 'group_catalog_documents_empty_hint'.tr,
        );
      }
      return ListView.separated(
        padding: EdgeInsets.fromLTRB(16.dp, 8.dp, 16.dp, 24.dp),
        itemCount: state.documents.length,
        separatorBuilder: (_, __) => SizedBox(height: 10.dp),
        itemBuilder: (context, i) {
          final item = state.documents[i];
          return GroupCatalogDocumentItem(
            item: item,
            onTap: () => sendAction(OpenGroupSettingsCatalogDocument(item)),
          );
        },
      );
    });
  }
}

class _CompaniesPage extends StatelessWidget {
  final AppColors c;
  final GroupSettingsState state;
  final FutureOr<void> Function(MyAction) sendAction;

  const _CompaniesPage({
    required this.c,
    required this.state,
    required this.sendAction,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (state.catalogLoading.value && !state.catalogLoaded.value) {
        return const Center(child: AppLoading());
      }
      if (state.companies.isEmpty) {
        return AppEmptyState(
          icon: Icons.factory_outlined,
          title: 'group_catalog_companies_empty'.tr,
          subtitle: 'group_catalog_companies_empty_hint'.tr,
        );
      }
      return ListView.separated(
        padding: EdgeInsets.fromLTRB(16.dp, 8.dp, 16.dp, 24.dp),
        itemCount: state.companies.length,
        separatorBuilder: (_, __) => SizedBox(height: 10.dp),
        itemBuilder: (context, i) {
          final item = state.companies[i];
          return GroupCatalogCompanyItem(
            item: item,
            onTap: () => sendAction(OpenGroupSettingsCatalogCompany(item)),
          );
        },
      );
    });
  }
}
