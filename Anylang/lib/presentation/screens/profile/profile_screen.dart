import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/core/mappers.dart';
import '../../../data/local/account_store.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/ai_matching_repository.dart';
import '../../../data/network/auth_repository.dart';
import '../../../data/network/friends_repository.dart';
import '../../../data/network/market_analytics_repository.dart';
import '../../../data/network/products_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../../data/network/session_bootstrap.dart';
import '../../../data/network/socket_service.dart';
import '../../modal/account_switcher_bottom_sheet.dart';
import '../../modal/ai_matching_bottom_sheet.dart';
import '../../modal/business_benefits_bottom_sheet.dart';
import '../../modal/business_card_qr_bottom_sheet.dart';
import '../../modal/business_verification_bottom_sheet.dart';
import '../../modal/edit_bio_bottom_sheet.dart';
import '../../modal/full_screen_image_dialog.dart';
import '../../modal/image_picker.dart';
import '../../modal/market_analytics_bottom_sheet.dart';
import '../../modal/profile_people_bottom_sheet.dart';
import '../../modal/profile_people_item.dart';
import '../../modal/profile_rating_bottom_sheet.dart';
import '../../modal/sofiya_ai_bottom_sheet.dart';
import '../../modal/trust_score_bottom_sheet.dart';
import '../../ui/ai_matching.dart';
import '../../ui/business_card_links.dart';
import '../../ui/market_analytics.dart';
import '../../ui/theme/colors.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/auth_validators.dart';
import '../../utils/business_plan_dialog.dart';
import '../../utils/legal_urls.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../../utils/size_controller.dart';
import '../add_product/add_product_payload.dart';
import '../add_product/add_product_screen.dart';
import '../edit_business_info/edit_business_info_screen.dart';
import '../friends/friend.dart';
import '../friends/profile_viewer.dart';
import '../main/main_state.dart';
import '../main/main_screen.dart';
import '../products/own_product_actions_sheet.dart';
import '../products/product.dart';
import '../products/product_info_bottom_sheet.dart';
import '../products/products_state.dart';
import '../profile_edit/profile_edit_screen.dart';
import '../settings/settings_payload.dart';
import '../settings/settings_screen.dart';
import '../subscription/subscription_screen.dart';
import '../numbers/numbers_screen.dart';
import '../login/login_screen.dart';
import '../devices/devices_screen.dart';
import '../support_chat/support_chat_screen.dart';
import '../user_profile/user_profile_payload.dart';
import '../user_profile/user_profile_screen.dart';
import 'profile_account.dart';
import 'profile_action.dart';
import 'profile_content.dart';
import 'profile_state.dart';

class ProfileScreen extends Screen<ProfileState, void> {
  ProfileScreen() : super(mobileContent: ProfileContent());

  @override
  void initState(void payload) {
    state.softRefreshHandler = _softRefresh;
    _load();
  }

  @override
  void dispose() {
    if (identical(state.softRefreshHandler, _softRefresh)) {
      state.softRefreshHandler = null;
    }
    super.dispose();
  }

  Future<void> _load() async {
    state.loading.value = true;
    state.error.value = null;
    final result = await Get.find<ProfileRepository>().getMe();
    result.when(
      success: (data) {
        final map = asMap(data);
        if (map == null) {
          state.error.value = 'profile_load_failed'.tr;
          state.loading.value = false;
          return;
        }
        state.account.value = ProfileAccount.fromApi(map);
        state.error.value = null;
        unawaited(SessionStore.saveUser(Map<String, dynamic>.from(map)));
        if (Get.isRegistered<ProductsState>()) {
          Get.find<ProductsState>().isBusiness.value =
              state.account.value?.isBusiness == true;
        }
      },
      failure: (err) {
        state.error.value = AuthValidators.safeError(
          err,
          fallbackKey: 'profile_load_failed',
        );
        showAppError(err);
      },
    );
    state.loading.value = false;
    await _loadListings();
    await _loadAiMatching();
    await _loadMarketAnalytics();
  }

  String _matchingLocale() {
    final code = SessionStore.appLanguage().toLowerCase();
    if (code.startsWith('ru')) return 'ru';
    if (code.startsWith('en') || code.startsWith('us')) return 'en';
    return 'uz';
  }

  Future<void> _loadAiMatching() async {
    final acc = state.account.value;
    if (acc == null || !acc.isBusiness) {
      state.aiMatching.value = null;
      return;
    }
    state.aiMatchingLoading.value = true;
    state.aiMatchingLoadFailed.value = false;
    final result = await Get.find<AiMatchingRepository>().matches(
      locale: _matchingLocale(),
    );
    state.aiMatchingLoading.value = false;
    result.when(
      success: (data) {
        state.aiMatchingLoadFailed.value = false;
        state.aiMatching.value = AiMatchingResult.fromApi(data);
      },
      failure: (_) {
        state.aiMatchingLoadFailed.value = true;
        state.aiMatching.value = null;
      },
    );
  }

  Future<void> _loadMarketAnalytics() async {
    final acc = state.account.value;
    if (acc == null || !acc.isBusiness) {
      state.marketAnalytics.value = null;
      return;
    }
    state.marketAnalyticsLoading.value = true;
    state.marketAnalyticsLoadFailed.value = false;
    final result = await Get.find<MarketAnalyticsRepository>().insights(
      locale: _matchingLocale(),
    );
    state.marketAnalyticsLoading.value = false;
    result.when(
      success: (data) {
        state.marketAnalyticsLoadFailed.value = false;
        state.marketAnalytics.value = MarketAnalyticsResult.fromApi(data);
      },
      failure: (_) {
        state.marketAnalyticsLoadFailed.value = true;
        state.marketAnalytics.value = null;
      },
    );
  }

  Future<void> _loadListings() async {
    final acc = state.account.value;
    if (acc == null || !acc.isBusiness) return;
    final result = await Get.find<ProductsRepository>().listMine(limit: 40);
    if (result.errorOrNull != null) {
      showAppError(result.errorOrNull);
      final current = state.account.value;
      if (current != null) {
        state.account.value = current.copyWith(listings: const []);
      }
      return;
    }
    final data = result.dataOrNull;
    if (data == null) return;
    final items = asList(data)
        .whereType<Map>()
        .map((e) => Product.fromApi(Map<String, dynamic>.from(e)))
        .map(
          (p) => OwnListing(
            id: p.id,
            tileGradient: productGradientFor(p.id),
            name: p.name,
            price: p.price,
            imageUrl: p.imageUrl,
            status: p.status,
            isTop: p.isTop,
            topRequestStatus: p.topRequestStatus,
          ),
        )
        .toList();
    final current = state.account.value;
    if (current == null) return;
    // API stats.listings_count saqlanadi — faqat ro'yxat yangilanadi.
    state.account.value = current.copyWith(listings: items);
  }

  /// IndexedStack tab qayta ochilganda — loading flashsiz yangilash.
  Future<void> _softRefresh() async {
    final result = await Get.find<ProfileRepository>().getMe();
    final map = asMap(result.dataOrNull);
    if (map == null) {
      if (result.errorOrNull != null) {
        showAppWarning('profile_soft_refresh_failed'.tr);
      }
      return;
    }
    final prevListings = state.account.value?.listings ?? const <OwnListing>[];
    final account = ProfileAccount.fromApi(map);
    state.account.value = account.isBusiness
        ? account.copyWith(listings: prevListings)
        : account;
    state.error.value = null;
    unawaited(SessionStore.saveUser(Map<String, dynamic>.from(map)));
    if (Get.isRegistered<ProductsState>()) {
      Get.find<ProductsState>().isBusiness.value = account.isBusiness;
    }
    if (account.isBusiness) {
      await _loadListings();
      await _loadAiMatching();
      await _loadMarketAnalytics();
    } else {
      state.aiMatching.value = null;
      state.marketAnalytics.value = null;
    }
  }

  Future<void> _openSettings([SettingsFocus focus = SettingsFocus.app]) async {
    await navigate(
      SettingsScreen(),
      payload: SettingsPayload(focus: focus),
    );
    await _load();
  }

  @override
  Future<void> actionHandler(ProfileState state, MyAction action) async {
    switch (action) {
      case OpenSubscription _:
      case OpenWallet _:
      case OpenBusinessAccount _:
        await navigate(SubscriptionScreen());
        await _load();
      case OpenNumbers _:
        await navigate(NumbersScreen());
        await _load();
      case OpenSettings _:
      case OpenAppSettings _:
        await _openSettings(SettingsFocus.app);
      case ProfileLogoutRequested _:
        final uid = SessionStore.userId();
        final logout = await Get.find<AuthRepository>().logout();
        if (logout.errorOrNull != null) {
          showAppWarning('logout_failed'.tr);
        } else {
          showAppMessage('settings_logout_success'.tr);
        }
        if (Get.isRegistered<SocketService>()) {
          Get.find<SocketService>().disconnect();
        }
        // Boshqa saqlangan hisob bo‘lsa — unga o‘tamiz.
        final others = AccountStore.slots()
            .where((s) => s.userId != uid)
            .toList();
        if (others.isNotEmpty) {
          final ok = await AccountStore.activate(others.first.userId);
          if (ok) {
            await connectRealtimeIfNeeded();
            navigateAndRemoveUntil(MainScreen());
            return;
          }
        }
        navigateAndRemoveUntil(LoginScreen());
      case OpenAccountSwitcher _:
        if (!context.mounted) return;
        await showAccountSwitcherBottomSheet(context);
      case OpenSettingsLanguage _:
        await _openSettings(SettingsFocus.language);
      case OpenSettingsTheme _:
        await _openSettings(SettingsFocus.theme);
      case OpenSettingsNotifications _:
        await _openSettings(SettingsFocus.notifications);
      case OpenSettingsTranslation _:
        await _openSettings(SettingsFocus.translation);
      case OpenSettingsPrivacy _:
        await _openSettings(SettingsFocus.privacy);
      case OpenSettingsSecurity _:
        await navigate(DevicesScreen());
      case OpenAccountSettings _:
        await _openSettings(SettingsFocus.account);
      case OpenSettingsAiAssistant _:
        await navigate(SupportChatScreen());
      case OpenSupportFromProfile _:
        await navigate(SupportChatScreen());
      case OpenDevicesFromProfile _:
        await navigate(DevicesScreen());
      case OpenPrivacyPolicyFromProfile _:
        await LegalUrls.openPrivacy();
      case OpenPublicOfferFromProfile _:
        await LegalUrls.openTerms();
      case OpenSofiyaAi _:
        if (!context.mounted) return;
        await showSofiyaAiBottomSheet(context, sendAction: (a) {
          unawaited(actionHandler(state, a));
        });
      case EditPersonalProfile _:
        await navigate(ProfileEditScreen(), payload: state.account.value);
        await _load();
      case EditBusinessInfo _:
        await navigate(EditBusinessInfoScreen());
        await _load();
      case EditProfileBio _:
        final acc = state.account.value;
        if (acc == null) return;
        if (!acc.isBusiness) {
          final goPlans = await Get.dialog<bool>(
            AlertDialog(
              title: Text('profile_bio_business_required_title'.tr),
              content: Text('profile_bio_business_required_body'.tr),
              actions: [
                TextButton(
                  onPressed: () => Get.back(result: false),
                  child: Text('common_cancel'.tr),
                ),
                TextButton(
                  onPressed: () => Get.back(result: true),
                  child: Text('add_product_go_plans'.tr),
                ),
              ],
            ),
          );
          if (goPlans == true) {
            await navigate(SubscriptionScreen());
            await _load();
          }
          return;
        }
        if (!context.mounted) return;
        final edited = await showEditBioBottomSheet(
          context,
          initial: acc.bio ?? '',
        );
        if (edited == null) return;
        final result = await Get.find<ProfileRepository>().updateBusiness({
          'bio': edited,
        });
        result.when(
          success: (_) {
            final current = state.account.value;
            if (current != null) {
              state.account.value = edited.isEmpty
                  ? current.copyWith(clearBio: true)
                  : current.copyWith(bio: edited);
            }
            showAppMessage('profile_bio_saved'.tr);
            unawaited(_load());
          },
          failure: showAppError,
        );
      case AddProductRequested _:
        final isBiz = state.account.value?.isBusiness == true;
        if (!isBiz) {
          final goPlans = await showBusinessPlanRequiredDialog();
          if (!goPlans) return;
          await navigate(SubscriptionScreen());
          await _load();
          if (state.account.value?.isBusiness != true) return;
        }
        await navigate(AddProductScreen());
        await _load();
        await _loadListings();
      case SoftRefreshProfile _:
        await _softRefresh();
      case RetryProfileLoad _:
      case RefreshProfile _:
        await _load();
      case ChangeAvatarQuick _:
        if (!context.mounted) return;
        final file = await pickImage(context);
        if (file == null) return;
        final acc = state.account.value;
        final result = acc != null && acc.isBusiness
            ? await Get.find<ProfileRepository>().uploadBusinessLogo(file.path)
            : await Get.find<ProfileRepository>().uploadAvatar(file.path);
        result.when(
          success: (data) {
            final map = asMap(data);
            final url = map?['avatar_url']?.toString() ??
                map?['logo_url']?.toString();
            final current = state.account.value;
            if (current != null && url != null && url.isNotEmpty) {
              state.account.value = current.copyWith(avatarUrl: url);
            }
            showAppMessage('profile_avatar_updated'.tr);
            unawaited(_load());
          },
          failure: showAppError,
        );
      case CopyAnyLangId _:
        final copyAcc = state.account.value;
        if (copyAcc == null) return;
        final text = (copyAcc.username ?? copyAcc.anylangNumber).trim();
        if (text.isEmpty) return;
        await Clipboard.setData(ClipboardData(text: text));
        showAppMessage('profile_id_copied'.tr);
      case ShareProfile _:
        final shareAcc = state.account.value;
        if (shareAcc == null || shareAcc.id <= 0) return;
        final url = BusinessCardLinks.urlFor(shareAcc.id);
        final idLine = (shareAcc.username ?? shareAcc.anylangNumber).trim();
        final body = [
          shareAcc.name,
          if (idLine.isNotEmpty) idLine,
          url,
        ].join('\n');
        await Share.share(body, subject: shareAcc.name);
      case ShowBusinessBenefits _:
        if (!context.mounted) return;
        await showBusinessBenefitsBottomSheet(
          context,
          sendAction: (a) => actionHandler(state, a),
        );
      case OpenProfileAvatar _:
        final avatarUrl = state.account.value?.avatarUrl?.trim();
        if (avatarUrl == null || avatarUrl.isEmpty) return;
        await showFullScreenImage(context, url: avatarUrl);
      case OpenFactoryMedia a:
        final mediaUrl = a.url.trim();
        if (mediaUrl.isEmpty) return;
        await showFullScreenImage(context, url: mediaUrl);
      case OpenAiMatching _:
        final matching = state.aiMatching.value;
        if (matching == null && !state.aiMatchingLoading.value) {
          await _loadAiMatching();
        }
        final matchingData = state.aiMatching.value;
        if (matchingData == null || matchingData.items.isEmpty) {
          showAppMessage('ai_matching_empty'.tr);
          return;
        }
        if (!context.mounted) return;
        await showAiMatchingBottomSheet(
          context,
          result: matchingData,
          onOpenCompany: (company) async {
            if (company.id <= 0) return;
            final profile =
                await Get.find<ProfileRepository>().getPublicUser(company.id);
            final map = asMap(profile.dataOrNull);
            if (map == null) {
              showAppError(profile.errorOrNull ?? 'error'.tr);
              return;
            }
            await navigate(
              UserProfileScreen(),
              payload: UserProfilePayload.fromApi(map),
            );
          },
        );
      case RetryAiMatching _:
        await _loadAiMatching();
      case OpenMarketAnalytics _:
        final analytics = state.marketAnalytics.value;
        if (analytics == null && !state.marketAnalyticsLoading.value) {
          await _loadMarketAnalytics();
        }
        final analyticsData =
            state.marketAnalytics.value ?? const MarketAnalyticsResult();
        if (!context.mounted) return;
        await showMarketAnalyticsBottomSheet(context, result: analyticsData);
      case RetryMarketAnalytics _:
        await _loadMarketAnalytics();
      case ShowBusinessCardQr _:
        final qrAcc = state.account.value;
        if (qrAcc == null || qrAcc.id <= 0) return;
        if (!context.mounted) return;
        await showBusinessCardQrBottomSheet(
          context,
          userId: qrAcc.id,
          companyName: qrAcc.name,
        );
      case OpenBusinessVerification _:
        if (!context.mounted) return;
        final snap = await showBusinessVerificationBottomSheet(context);
        if (snap != null) {
          await _softRefresh();
        }
      case OpenTrustScoreDetails _:
        final acc = state.account.value;
        final trust = acc?.trustScore;
        if (trust == null || !context.mounted) return;
        await showTrustScoreBottomSheet(
          context,
          trust: trust,
          showActions: true,
          onAction: (a) => sendAction(TrustImproveAction(a)),
        );
      case OpenProfileListingsStat _:
        await actionHandler(state, SeeAllListings());
      case OpenProfileViewsStat _:
        await _openProfileViewersSheet();
      case OpenProfileRatingStat _:
        final acc = state.account.value;
        if (acc == null || !context.mounted) return;
        await showProfileRatingBottomSheet(
          context,
          rating: acc.rating ?? acc.insights.rating,
          reviewsCount: acc.reviewsCount,
        );
      case OpenProfileFollowersStat _:
        await _openProfileFollowersSheet();
      case OpenProfileLikesStat _:
        await _openProfileLikersSheet();
      case TrustImproveAction a:
        switch (a.action) {
          case 'verify_documents':
            await actionHandler(state, OpenBusinessVerification());
          case 'add_certificates':
            await actionHandler(state, EditBusinessInfo());
          case 'reply_faster':
          case 'send_invoices':
            if (Get.isRegistered<MainState>()) {
              Get.find<MainState>().currentTab.value = 0;
            }
            // Leave profile nested stack if any — tab switch is enough on Main.
          default:
            break;
        }
      case SeeAllListings _:
        await _loadListings();
        final items = state.account.value?.listings ?? const [];
        if (items.isEmpty) {
          showAppMessage('profile_listings_empty'.tr);
          return;
        }
        if (!context.mounted) return;
        final c = context.appColors;
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              maxChildSize: 0.92,
              minChildSize: 0.4,
              builder: (_, scroll) => Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20.dp)),
                ),
                child: ListView.separated(
                  controller: scroll,
                  padding: EdgeInsets.fromLTRB(16.dp, 16.dp, 16.dp, 24.dp),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, _) => SizedBox(height: 8.dp),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return Text(
                        'profile_listings_see_all'.tr,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    }
                    final listing = items[i - 1];
                    final img = listing.imageUrl?.trim();
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10.dp),
                          child: SizedBox(
                            width: 48.dp,
                            height: 48.dp,
                            child: img != null && img.isNotEmpty
                                ? Image.network(img, fit: BoxFit.cover)
                                : DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: listing.tileGradient,
                                    ),
                                  ),
                          ),
                        ),
                        title: Text(
                          listing.name,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          listing.price,
                          style: TextStyle(color: c.textSecondary),
                        ),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await actionHandler(state, OpenOwnListing(listing));
                        },
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      case OpenOwnListing a:
        final id = a.listing.id;
        if (id <= 0) {
          showAppMessage(a.listing.name);
          return;
        }
        final detailResult = await Get.find<ProductsRepository>().detail(id);
        final detailMap = asMap(detailResult.dataOrNull);
        if (detailMap == null) {
          showAppError(detailResult.errorOrNull ?? 'product_not_found'.tr);
          return;
        }
        final product = Product.fromApi(detailMap);
        if (!context.mounted) return;
        await showProductInfoBottomSheet(
          context,
          product,
          onOpenBusiness: () {
            Navigator.of(context).maybePop();
          },
          onEdit: () => unawaited(_editOwnProduct(product.id)),
          onManage: () => unawaited(_manageOwnProduct(product)),
        );
        await _loadListings();
    }
  }

  Future<void> _editOwnProduct(int productId) async {
    if (productId <= 0) return;
    final isBiz = state.account.value?.isBusiness == true;
    if (!isBiz) {
      final goPlans = await showBusinessPlanRequiredDialog();
      if (!goPlans) return;
      await navigate(SubscriptionScreen());
      await _load();
      if (state.account.value?.isBusiness != true) return;
    }
    await navigate(
      AddProductScreen(),
      payload: AddProductPayload(editProductId: productId),
    );
    await _load();
    await _loadListings();
  }

  Future<void> _manageOwnProduct(Product product) async {
    final action = await showOwnProductActionsSheet(context, product: product);
    if (action == null) return;
    switch (action) {
      case OwnProductAction.edit:
        await _editOwnProduct(product.id);
      case OwnProductAction.boostTop:
        // TOP to‘lov product info ichida; shu yerda qayta ochamiz.
        await showProductInfoBottomSheet(
          context,
          product,
          onOpenBusiness: () {},
          onEdit: () => unawaited(_editOwnProduct(product.id)),
          onManage: () => unawaited(_manageOwnProduct(product)),
        );
      case OwnProductAction.publish:
      case OwnProductAction.unpublish:
        final status =
            action == OwnProductAction.publish ? 'published' : 'draft';
        final result = await Get.find<ProductsRepository>().update(
          product.id,
          {'status': status},
        );
        if (result.errorOrNull != null) {
          showAppError(result.errorOrNull);
          return;
        }
        showAppMessage(
          status == 'published'
              ? 'my_products_published'.tr
              : 'my_products_unpublished'.tr,
        );
        await _loadListings();
      case OwnProductAction.delete:
        final ok = await Get.dialog<bool>(
              AlertDialog(
                title: Text('my_products_delete_title'.tr),
                content: Text('my_products_delete_body'.tr),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(result: false),
                    child: Text('cancel'.tr),
                  ),
                  TextButton(
                    onPressed: () => Get.back(result: true),
                    child: Text(
                      'my_products_delete'.tr,
                      style: TextStyle(color: context.appColors.danger),
                    ),
                  ),
                ],
              ),
            ) ??
            false;
        if (!ok) return;
        final result =
            await Get.find<ProductsRepository>().archive(product.id);
        if (result.errorOrNull != null) {
          showAppError(result.errorOrNull);
          return;
        }
        showAppMessage('my_products_deleted'.tr);
        await _loadListings();
    }
  }

  Future<void> _openPeopleProfile(ProfilePeopleItem item) async {
    if (item.userId <= 0) return;
    await navigate(
      UserProfileScreen(),
      payload: UserProfilePayload.preview(
        id: item.userId,
        name: item.name,
        initial: item.initial,
        avatarGradient: item.avatarGradient,
        avatarUrl: item.avatarUrl,
        isBusiness: item.isBusiness,
        country: item.country,
        role: item.businessRole,
      ),
    );
  }

  Future<void> _openProfileViewersSheet() async {
    if (!context.mounted) return;
    await showProfilePeopleBottomSheet(
      context,
      title: 'profile_viewers_title'.tr,
      emptyTitle: 'profile_stat_viewers_empty'.tr,
      emptySubtitle: 'profile_stat_viewers_empty_hint'.tr,
      onUnlockPremium: () async {
        await navigate(SubscriptionScreen());
      },
      onOpenUser: _openPeopleProfile,
      loader: () async {
        final result =
            await Get.find<ProfileRepository>().listProfileViewers(limit: 50);
        return result.when(
          success: (data) {
            final map = asMap(data);
            final locked = map?['locked'] == true;
            final total = (map?['total_count'] as num?)?.toInt() ?? 0;
            final items = asList(data)
                .whereType<Map>()
                .map(
                  (e) => ProfilePeopleItem.fromViewer(
                    ProfileViewer.fromApi(Map<String, dynamic>.from(e)),
                  ),
                )
                .where((e) => e.userId > 0)
                .toList();
            return ProfilePeopleLoadResult(
              locked: locked,
              totalCount: total,
              items: items,
            );
          },
          failure: (_) => ProfilePeopleLoadResult.failedResult,
        );
      },
    );
  }

  Future<void> _openProfileFollowersSheet() async {
    if (!context.mounted) return;
    await showProfilePeopleBottomSheet(
      context,
      title: 'profile_followers'.tr,
      emptyTitle: 'friends_empty'.tr,
      emptySubtitle: 'friends_empty_hint'.tr,
      onOpenUser: _openPeopleProfile,
      loader: () async {
        final result =
            await Get.find<FriendsRepository>().listFriends(limit: 100);
        return result.when(
          success: (data) {
            final items = asList(data)
                .whereType<Map>()
                .map(
                  (e) => ProfilePeopleItem.fromFriend(
                    Friend.fromApi(Map<String, dynamic>.from(e)),
                  ),
                )
                .where((e) => e.userId > 0)
                .toList();
            return ProfilePeopleLoadResult(
              totalCount: items.length,
              items: items,
            );
          },
          failure: (_) => ProfilePeopleLoadResult.failedResult,
        );
      },
    );
  }

  Future<void> _openProfileLikersSheet() async {
    if (!context.mounted) return;
    await showProfilePeopleBottomSheet(
      context,
      title: 'profile_likes'.tr,
      emptyTitle: 'profile_stat_likers_empty'.tr,
      emptySubtitle: 'profile_stat_likers_empty_hint'.tr,
      onOpenUser: _openPeopleProfile,
      loader: () async {
        final result =
            await Get.find<ProfileRepository>().listProductLikers(limit: 100);
        return result.when(
          success: (data) {
            final map = asMap(data);
            final total = (map?['total_count'] as num?)?.toInt() ?? 0;
            final items = asList(data)
                .whereType<Map>()
                .map(
                  (e) => ProfilePeopleItem.fromLiker(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .where((e) => e.userId > 0)
                .toList();
            return ProfilePeopleLoadResult(
              totalCount: total > 0 ? total : items.length,
              items: items,
            );
          },
          failure: (_) => ProfilePeopleLoadResult.failedResult,
        );
      },
    );
  }
}
