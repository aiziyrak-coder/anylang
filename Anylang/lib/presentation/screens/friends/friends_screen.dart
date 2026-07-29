import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/ai_matching_repository.dart';
import '../../../data/network/chat_repository.dart';
import '../../../data/network/friends_repository.dart';
import '../../../data/network/products_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../modal/country_picker_bottom_sheet.dart';
import '../../ui/theme/colors.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/auth_validators.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../../utils/size_controller.dart';
import '../add_friend/add_friend_payload.dart';
import '../add_friend/add_friend_screen.dart';
import '../chat/chat_payload.dart';
import '../chat/chat_screen.dart';
import '../main/main_state.dart';
import '../products/product.dart';
import '../products/product_info_bottom_sheet.dart';
import '../products/products_state.dart';
import '../subscription/subscription_screen.dart';
import '../user_profile/user_profile_payload.dart';
import '../user_profile/user_profile_screen.dart';
import 'friend.dart';
import 'friend_recommendation.dart';
import 'friend_request.dart';
import 'friends_action.dart';
import 'friends_content.dart';
import 'friends_requests_bottom_sheet.dart';
import 'friends_state.dart';
import 'profile_viewer.dart';

class FriendsScreen extends Screen<FriendsState, void> {
  FriendsScreen() : super(mobileContent: FriendsContent());

  static const _roleCodes = ['manufacturer', 'distributor', 'retail', 'service'];
  final Set<int> _openingChatUserIds = <int>{};
  final Set<int> _openingProfileUserIds = <int>{};

  @override
  void initState(void payload) {
    _load();
    _loadCategories();
  }

  String _uiLanguage() {
    try {
      return SessionStore.appLanguage();
    } catch (_) {
      final code = Get.locale?.toString() ?? 'uz_UZ';
      if (code.startsWith('ru')) return 'ru_RU';
      if (code.startsWith('en') || code.startsWith('us')) return 'us_US';
      return 'uz_UZ';
    }
  }

  String _matchingLocale() {
    final code = _uiLanguage().toLowerCase();
    if (code.startsWith('ru')) return 'ru';
    if (code.startsWith('en') || code.startsWith('us')) return 'en';
    return 'uz';
  }

  Future<void> _loadCategories() async {
    final result = await Get.find<ProductsRepository>().categories(
      language: _uiLanguage(),
    );
    result.when(
      success: (data) {
        state.categoriesLoadFailed.value = false;
        final items = <ProductCategoryOption>[];
        for (final e in asList(data)) {
          if (e is! Map) continue;
          final code = e['code']?.toString();
          final title = e['title']?.toString();
          if (code == null || code.isEmpty || title == null) continue;
          items.add(ProductCategoryOption(code: code, title: title));
        }
        state.productCategories.assignAll(items);
      },
      failure: (err) {
        state.categoriesLoadFailed.value = true;
        showAppWarning('friends_categories_failed'.tr);
      },
    );
  }

  Future<void> _loadPendingCount() async {
    final result = await Get.find<FriendsRepository>().listRequests(type: 'incoming');
    result.when(
      success: (data) {
        final count = asList(data)
            .whereType<Map>()
            .where((e) => (e['status'] as String?) == 'pending')
            .length;
        state.pendingCount.value = count;
      },
      failure: showAppError,
    );
  }

  Future<void> _loadRecommendations() async {
    final result = await Get.find<AiMatchingRepository>().recommendations(
      locale: _matchingLocale(),
      limit: 18,
    );
    result.when(
      success: (data) {
        state.recommendationsLoadFailed.value = false;
        final map = asMap(data);
        final items = asList(data)
            .whereType<Map>()
            .map((e) => FriendRecommendation.fromApi(Map<String, dynamic>.from(e)))
            .where((e) => e.userId > 0)
            .toList();
        state.recommendations.assignAll(items);
        final friendIds = state.friends.map((f) => f.id).toSet();
        state.recommendations.removeWhere((r) => friendIds.contains(r.userId));
        final total = (map?['total_count'] as num?)?.toInt();
        state.recommendationTotalCount.value =
            (total != null && total > 0) ? total : state.recommendations.length;
      },
      failure: (_) {
        state.recommendationsLoadFailed.value = true;
        state.recommendations.clear();
        state.recommendationTotalCount.value = 0;
      },
    );
  }

  Future<void> _loadProfileViewers() async {
    final result =
        await Get.find<ProfileRepository>().listProfileViewers(limit: 20);
    result.when(
      success: (data) {
        final map = asMap(data);
        final locked = map?['locked'] == true;
        final total = (map?['total_count'] as num?)?.toInt() ?? 0;
        final items = asList(data)
            .whereType<Map>()
            .map((e) => ProfileViewer.fromApi(Map<String, dynamic>.from(e)))
            .where((e) => e.userId > 0)
            .toList();
        state.profileViewersLocked.value = locked;
        state.profileViewersTotal.value = total;
        state.profileViewers.assignAll(items);
      },
      failure: (_) {
        state.profileViewers.clear();
        state.profileViewersTotal.value = 0;
        state.profileViewersLocked.value = false;
      },
    );
  }

  Future<void> _load() async {
    state.loading.value = true;
    final repo = Get.find<FriendsRepository>();
    final result = await repo.listFriends();
    result.when(
      success: (data) {
        final map = asMap(data);
        final items = asList(data)
            .whereType<Map>()
            .map((e) => Friend.fromApi(Map<String, dynamic>.from(e)))
            .where((f) => !SessionStore.isUserBlocked(f.id))
            .toList();
        state.friends.assignAll(items);
        final net = map?['networking'];
        if (net is Map) {
          state.networkingConnections.value =
              (net['connections'] as num?)?.toInt() ?? items.length;
          state.networkingCountries.value =
              (net['countries'] as num?)?.toInt() ?? 0;
          state.networkingTrust.value = (net['trust'] as num?)?.toInt();
        } else {
          state.networkingConnections.value = items.length;
          final countries = items
              .map((f) => (f.country ?? '').trim().toUpperCase())
              .where((c) => c.length == 2)
              .toSet();
          state.networkingCountries.value = countries.length;
          state.networkingTrust.value = null;
        }
      },
      failure: showAppError,
    );
    await Future.wait([
      _loadPendingCount(),
      _loadRecommendations(),
      _loadProfileViewers(),
    ]);
    state.loading.value = false;
  }

  Future<void> _openRequestsSheet() async {
    final result = await Get.find<FriendsRepository>().listRequests(type: 'incoming');
    var requests = <FriendRequest>[];
    result.when(
      success: (data) {
        requests = asList(data)
            .whereType<Map>()
            .where((e) => (e['status'] as String?) == 'pending')
            .map((e) => FriendRequest.fromApi(Map<String, dynamic>.from(e)))
            .where((r) => r.requestId > 0)
            .toList();
      },
      failure: (err) {
        showAppError(err);
        return;
      },
    );
    if (!context.mounted) return;
    await showFriendsRequestsBottomSheet(
      context,
      requests: requests,
      onAccept: (requestId) async {
        final r = await Get.find<FriendsRepository>().acceptRequest(requestId);
        r.when(
          success: (_) async {
            await _load();
          },
          failure: showAppError,
        );
      },
      onDecline: (requestId) async {
        final r = await Get.find<FriendsRepository>().declineRequest(requestId);
        r.when(
          success: (_) async {
            state.pendingCount.value =
                (state.pendingCount.value - 1).clamp(0, 999);
          },
          failure: showAppError,
        );
      },
    );
    await _loadPendingCount();
  }

  Future<void> _addRecommended(FriendRecommendation item) async {
    if (item.userId <= 0) return;
    if (state.recommendationRequestedIds.contains(item.userId)) return;
    state.recommendationRequestedIds.add(item.userId);
    state.recommendationRequestedIds.refresh();
    final result = await Get.find<FriendsRepository>().sendRequest(item.userId);
    result.when(
      success: (data) {
        final map = asMap(data);
        final status = map?['status']?.toString();
        if (status == 'accepted' || map?['auto_accepted'] == true) {
          state.recommendations.removeWhere((r) => r.userId == item.userId);
          showAppMessage('add_friend_is_friend'.tr);
          _load();
          return;
        }
        showAppMessage('add_friend_requested'.tr);
      },
      failure: (err) {
        if (AuthValidators.hasErrorCode(err, 'REQUEST_ALREADY_SENT')) {
          showAppMessage('add_friend_requested'.tr);
          return;
        }
        state.recommendationRequestedIds.remove(item.userId);
        state.recommendationRequestedIds.refresh();
        showAppError(err);
      },
    );
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryPickerBottomSheet(
      context,
      title: 'friends_filter_country'.tr,
      desc: 'friends_filter_country_desc'.tr,
      selectedCode: state.filterCountry.value,
    );
    if (picked == null) return;
    state.filterCountry.value = picked.code.toUpperCase();
  }

  Future<void> _pickRole() async {
    final c = context.appColors;
    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
          ),
          padding: EdgeInsets.fromLTRB(20.dp, 16.dp, 20.dp, 28.dp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'friends_filter_industry_title'.tr,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 12.dp),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(ctx, ''),
                  borderRadius: BorderRadius.circular(12.dp),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 14.dp),
                    child: Text(
                      'friends_filter_any'.tr,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              ..._roleCodes.map((code) {
                final selected = state.filterRole.value == code;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(ctx, code),
                    borderRadius: BorderRadius.circular(12.dp),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 14.dp),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'business_role_$code'.tr,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (selected)
                            Icon(Icons.check_rounded, color: c.accent, size: 20.dp),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    state.filterRole.value = selected.isEmpty ? null : selected;
  }

  Future<void> _pickProduct() async {
    final c = context.appColors;
    final cats = state.productCategories.toList();
    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.65),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
          ),
          padding: EdgeInsets.fromLTRB(20.dp, 16.dp, 20.dp, 28.dp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'friends_filter_product_title'.tr,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 12.dp),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(ctx, ''),
                        borderRadius: BorderRadius.circular(12.dp),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 14.dp),
                          child: Text(
                            'friends_filter_any'.tr,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    ...cats.map((cat) {
                      final isSelected =
                          state.filterProduct.value?.toLowerCase() ==
                          cat.code.toLowerCase();
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(ctx, cat.code),
                          borderRadius: BorderRadius.circular(12.dp),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 14.dp),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    cat.title,
                                    style: TextStyle(
                                      color: c.textPrimary,
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_rounded,
                                    color: c.accent,
                                    size: 20.dp,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    state.filterProduct.value = selected.isEmpty ? null : selected.toLowerCase();
  }

  @override
  Future<void> actionHandler(FriendsState state, MyAction action) async {
    switch (action) {
      case FriendsSearchChanged a:
        state.query.value = a.text;
      case RefreshFriends _:
        await _load();
      case OpenFriendRequests _:
        await _openRequestsSheet();
      case AddRecommendedFriend a:
        await _addRecommended(a.item);
      case OpenRecommendedChat a:
        await _openRecommendedChat(a.item);
      case OpenProfileViewer a:
        await _openViewerProfile(a.item);
      case OpenProfileViewersPremium _:
        await navigate(SubscriptionScreen());
      case FriendsPickCountry _:
        await _pickCountry();
      case FriendsSelectCountry a:
        state.filterCountry.value = a.code;
      case FriendsPickRole _:
        await _pickRole();
      case FriendsSelectRole a:
        state.filterRole.value = a.code;
      case FriendsPickProduct _:
        await _pickProduct();
      case FriendsSelectProduct a:
        state.filterProduct.value = a.code;
      case FriendsToggleVerified _:
        state.filterVerified.value = !state.filterVerified.value;
      case FriendsToggleOnline _:
        state.filterOnline.value = !state.filterOnline.value;
      case FriendsClearFilters _:
        state.filterCountry.value = null;
        state.filterRole.value = null;
        state.filterProduct.value = null;
        state.filterVerified.value = false;
        state.filterOnline.value = false;
      case OpenChat a:
        await _openChat(a.friend);
      case OpenFriendCall _:
        showAppWarning('call_unavailable'.tr);
      case OpenFriendLive _:
        if (Get.isRegistered<MainState>()) {
          Get.find<MainState>().currentTab.value = 3;
        }
      case OpenFriendProducts a:
        await _openProducts(a.friend);
      case OpenFriendProfile a:
        await _openProfile(a.friend);
      case AddFriend _:
        await navigate(
          AddFriendScreen(),
          payload: const AddFriendPayload(mode: AddFriendMode.friends),
        );
        await _load();
      case RemoveFriend a:
        final ok = await Get.dialog<bool>(
          AlertDialog(
            title: Text('friends_remove_title'.tr),
            content: Text(a.friend.name),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: Text('settings_cancel'.tr),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                child: Text(
                  'friends_remove'.tr,
                  style: const TextStyle(color: Color(0xFFB42318)),
                ),
              ),
            ],
          ),
        );
        if (ok != true) return;
        final r = await Get.find<FriendsRepository>().removeFriend(a.friend.id);
        r.when(
          success: (_) {
            state.friends.removeWhere((f) => f.id == a.friend.id);
            showAppMessage('friends_removed'.tr);
          },
          failure: showAppError,
        );
    }
  }

  Future<void> _openChat(Friend friend) async {
    if (_openingChatUserIds.contains(friend.id)) return;
    if (SessionStore.isUserBlocked(friend.id)) {
      showAppWarning('chat_blocked'.tr);
      return;
    }
    _openingChatUserIds.add(friend.id);
    try {
      final result = await Get.find<ChatRepository>().createChat(friend.id);
      result.when(
        success: (data) {
          final map = asMap(data);
          final chatId = (map?['id'] as num?)?.toInt() ?? 0;
          if (chatId <= 0) {
            showAppError('chat_open_failed'.tr);
            return;
          }
          navigate(
            ChatScreen(),
            payload: ChatPayload(
              chatId: chatId,
              peerId: friend.id,
              name: friend.name,
              initial: friend.initial,
              avatarGradient: friend.avatarGradient,
              online: friend.online,
              avatarUrl: friend.avatarUrl,
            ),
          );
        },
        failure: showAppError,
      );
    } finally {
      _openingChatUserIds.remove(friend.id);
    }
  }

  Future<void> _openRecommendedChat(FriendRecommendation item) async {
    if (item.userId <= 0) return;
    if (_openingChatUserIds.contains(item.userId)) return;
    if (SessionStore.isUserBlocked(item.userId)) {
      showAppWarning('chat_blocked'.tr);
      return;
    }
    _openingChatUserIds.add(item.userId);
    try {
      final result = await Get.find<ChatRepository>().createChat(item.userId);
      result.when(
        success: (data) {
          final map = asMap(data);
          final chatId = (map?['id'] as num?)?.toInt() ?? 0;
          if (chatId <= 0) {
            showAppError('chat_open_failed'.tr);
            return;
          }
          navigate(
            ChatScreen(),
            payload: ChatPayload(
              chatId: chatId,
              peerId: item.userId,
              name: item.name,
              initial: item.initial,
              avatarGradient: item.avatarGradient,
              online: false,
              avatarUrl: item.logoUrl,
            ),
          );
        },
        failure: showAppError,
      );
    } finally {
      _openingChatUserIds.remove(item.userId);
    }
  }

  Future<void> _openViewerProfile(ProfileViewer item) async {
    if (item.userId <= 0) return;
    if (_openingProfileUserIds.contains(item.userId)) return;
    _openingProfileUserIds.add(item.userId);
    try {
      // Darhol ochish — local preview / cache; to‘liq ma’lumot UserProfileScreen
      // ichida soft refresh bilan yangilanadi.
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
    } finally {
      _openingProfileUserIds.remove(item.userId);
    }
  }

  Future<void> _openProfile(Friend friend) async {
    if (_openingProfileUserIds.contains(friend.id)) return;
    _openingProfileUserIds.add(friend.id);
    try {
      // Tarmoq kartasidagi local ma’lumot bilan darhol ochish;
      // to‘liq profil UserProfileScreen soft refresh’ida yangilanadi.
      await navigate(
        UserProfileScreen(),
        payload: UserProfilePayload.preview(
          id: friend.id,
          name: friend.name,
          initial: friend.initial,
          avatarGradient: friend.avatarGradient,
          avatarUrl: friend.avatarUrl,
          isBusiness: friend.isBusiness,
          country: friend.country,
          role: friend.businessRole,
          verified: friend.verified,
          keywords: friend.keywords,
          listings: friend.productsCount,
          networkingCountries: friend.countriesCount,
          networkingTrust: friend.trust,
          friendshipStatus: 'accepted',
          riskLevel: friend.riskLevel,
          isScammer: friend.isScammer,
        ),
      );
    } finally {
      _openingProfileUserIds.remove(friend.id);
    }
  }

  Future<void> _openProducts(Friend friend) async {
    if (!friend.isBusiness && friend.productsCount <= 0) {
      showAppMessage('user_card_no_products'.tr);
      return;
    }
    final ctx = context;
    final result = await Get.find<ProductsRepository>().listByUser(
      friend.id,
      limit: 40,
    );
    if (result.errorOrNull != null) {
      showAppError(result.errorOrNull);
      return;
    }
    final items = asList(result.dataOrNull)
        .whereType<Map>()
        .map((e) => Product.fromApi(Map<String, dynamic>.from(e)))
        .toList();
    if (items.isEmpty) {
      showAppMessage('user_card_no_products'.tr);
      return;
    }
    if (items.length == 1) {
      await showProductInfoBottomSheet(
        ctx,
        items.first,
        onOpenBusiness: () => _openProfile(friend),
      );
      return;
    }
    await _openProfile(friend);
  }
}
