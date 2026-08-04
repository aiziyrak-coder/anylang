import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/marketplace_groups_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../modal/business_verification_bottom_sheet.dart';
import '../../modal/trust_score_bottom_sheet.dart';
import '../../ui/trust_score.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/auth_validators.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../chat/chat_payload.dart';
import '../chat/chat_screen.dart';
import '../edit_business_info/edit_business_info_screen.dart';
import '../main/main_state.dart';
import 'marketplace_verified_group_action.dart';
import 'marketplace_verified_group_content.dart';
import 'marketplace_verified_group_models.dart';
import 'marketplace_verified_group_payload.dart';
import 'marketplace_verified_group_state.dart';

class MarketplaceVerifiedGroupScreen
    extends Screen<MarketplaceVerifiedGroupState, MarketplaceVerifiedGroupPayload> {
  MarketplaceVerifiedGroupScreen()
      : super(mobileContent: MarketplaceVerifiedGroupContent());

  @override
  void initState(MarketplaceVerifiedGroupPayload? payload) {
    final p = payload;
    if (p == null) {
      Future.microtask(() {
        showAppError('screen_payload_missing'.tr);
        popBackNavigate();
      });
      return;
    }
    final g = p.group;
    state.slug.value = g.slug;
    state.emoji.value = g.emoji;
    state.title.value = g.title;
    state.blurb.value = g.blurb;
    state.memberCount.value = g.memberCount;
    state.rfqToday.value = g.rfqToday;
    _load();
  }

  Future<void> _load({bool fromRefresh = false}) async {
    final slug = state.slug.value;
    if (slug.isEmpty) return;
    if (!fromRefresh) state.loading.value = true;
    try {
      final result =
          await Get.find<MarketplaceGroupsRepository>().preview(slug);
      result.when(
        success: (data) {
          state.loadError.value = null;
          final map = asMap(data);
          if (map == null) {
            state.loadError.value = 'marketplace_verified_info_load_failed'.tr;
            return;
          }
          final preview = MarketplaceVerifiedGroupPreview.fromApi(map);
          state.preview.value = preview;
          state.emoji.value = preview.emoji;
          state.title.value = preview.title;
          state.blurb.value = preview.blurb;
          state.memberCount.value = preview.memberCount;
          state.rfqToday.value = preview.rfqToday;
        },
        failure: (err) {
          final msg = AuthValidators.safeError(
            err,
            fallbackKey: 'marketplace_verified_info_load_failed',
          );
          if (fromRefresh && state.preview.value != null) {
            showAppError(msg);
          } else {
            state.loadError.value = msg;
          }
        },
      );
    } finally {
      state.loading.value = false;
    }
  }

  Future<void> _openDocs() async {
    final snap = await showBusinessVerificationBottomSheet(context);
    await _load(fromRefresh: true);
    final preview = state.preview.value;
    if (snap != null &&
        (snap.isApproved || preview?.canJoin == true) &&
        preview != null &&
        !preview.joined) {
      showAppMessage('marketplace_verified_trust_ready'.tr);
    }
  }

  Future<void> _joinOrOpen() async {
    final preview = state.preview.value;
    if (preview == null || state.joining.value) return;

    if (!preview.canJoin && !preview.joined) {
      await _openDocs();
      return;
    }

    state.joining.value = true;
    try {
      final result =
          await Get.find<MarketplaceGroupsRepository>().join(preview.slug);
      final map = asMap(result.dataOrNull);
      if (map == null) {
        showAppError(result.errorOrNull ?? 'error'.tr);
        return;
      }
      final chatId = (map['chat_id'] as num?)?.toInt() ??
          (map['id'] as num?)?.toInt() ??
          preview.id;
      if (chatId <= 0) {
        showAppError('marketplace_join_no_chat'.tr);
        return;
      }
      final title = (map['title'] as String?)?.trim().isNotEmpty == true
          ? map['title'] as String
          : preview.title;
      final emoji = map['marketplace_emoji']?.toString() ?? preview.emoji;
      state.preview.value = MarketplaceVerifiedGroupPreview(
        id: preview.id,
        slug: preview.slug,
        emoji: preview.emoji,
        title: preview.title,
        blurb: preview.blurb,
        memberCount: preview.joined
            ? preview.memberCount
            : preview.memberCount + 1,
        rfqToday: preview.rfqToday,
        verifiedOnly: preview.verifiedOnly,
        joined: true,
        canJoin: true,
        viewerVerified: true,
        trustScore: preview.trustScore,
        trustLevel: preview.trustLevel,
        documentsVerified: preview.documentsVerified,
        members: preview.members,
        membersShown: preview.membersShown,
      );
      await navigate(
        ChatScreen(),
        payload: ChatPayload(
          chatId: chatId,
          peerId: 0,
          name: '$emoji $title',
          initial: initialsOf(title),
          avatarGradient: avatarGradientFor(chatId),
          isGroup: true,
          myRole: map['my_role']?.toString(),
          isSuper: map['is_super'] == true,
          inviteLink: map['invite_link']?.toString(),
          isMarketplace: true,
          marketplaceSlug: preview.slug,
        ),
      );
    } finally {
      state.joining.value = false;
    }
  }

  @override
  Future<void> actionHandler(
    MarketplaceVerifiedGroupState state,
    MyAction action,
  ) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case MarketplaceVerifiedGroupRefresh _:
        await _load(fromRefresh: true);
      case MarketplaceVerifiedGroupUploadDocs _:
        await _openDocs();
      case MarketplaceVerifiedGroupShowTrust _:
        await _showOwnTrust();
      case MarketplaceVerifiedGroupJoin _:
        await _joinOrOpen();
    }
  }

  Future<void> _showOwnTrust() async {
    final result = await Get.find<ProfileRepository>().getMe();
    final map = asMap(result.dataOrNull);
    if (map == null) {
      showAppError(result.errorOrNull ?? 'unknown_error'.tr);
      return;
    }
    final biz = map['business'];
    TrustScore? trust;
    if (biz is Map && biz['trust_score'] != null) {
      trust = TrustScore.fromApi(biz['trust_score']);
    }
    if (trust == null || trust.breakdown.isEmpty) {
      // Fallback — faqat foiz.
      final pct = state.preview.value?.trustScore ?? 0;
      trust = TrustScore(score: pct, level: pct >= 75 ? 'good' : 'fair');
    }
    if (!context.mounted) return;
    await showTrustScoreBottomSheet(
      context,
      trust: trust,
      showActions: true,
      onAction: (a) async {
        switch (a) {
          case 'verify_documents':
            await _openDocs();
          case 'add_certificates':
            await navigate(EditBusinessInfoScreen());
          case 'reply_faster':
          case 'send_invoices':
            if (Get.isRegistered<MainState>()) {
              Get.find<MainState>().currentTab.value = 0;
            }
            popBackNavigate();
          default:
            break;
        }
      },
    );
  }
}
