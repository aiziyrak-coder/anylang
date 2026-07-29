import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/core/mappers.dart';
import '../../../data/local/public_profile_cache.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/chat_repository.dart';
import '../../../data/network/friends_repository.dart';
import '../../../data/network/products_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../modal/business_verification_bottom_sheet.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../chat/chat_payload.dart';
import '../chat/chat_screen.dart';
import '../products/product.dart';
import '../products/product_info_bottom_sheet.dart';
import '../trade_assistant/trade_assistant_payload.dart';
import '../trade_assistant/trade_assistant_screen.dart';
import 'user_profile_action.dart';
import 'user_profile_content.dart';
import 'user_profile_payload.dart';
import 'user_profile_state.dart';

class UserProfileScreen extends Screen<UserProfileState, UserProfilePayload> {
  UserProfileScreen() : super(mobileContent: UserProfileContent());

  @override
  void initState(UserProfilePayload? payload) {
    if (payload == null) {
      Future.microtask(() {
        showAppError('screen_payload_missing'.tr);
        popBackNavigate();
      });
      return;
    }
    // Birinchi frame’dayoq local preview / Hive cache — network kutmasin.
    var initial = payload;
    final id = payload.id;
    final other = id > 0 &&
        (SessionStore.userId() == null || id != SessionStore.userId());
    if (other) {
      final cached = PublicProfileCache.get(id);
      if (cached != null) {
        initial = UserProfilePayload.fromApi(
          cached,
          existingChatId: payload.existingChatId,
        );
      }
    }
    state.data = initial;
    state.syncFriendshipFromPayload(initial);
    state.profileRefreshing.value = false;
    state.profileLoading.value = false;

    Future.microtask(() => _bootstrap(payload));
  }

  Future<void> _bootstrap(UserProfilePayload payload) async {
    final id = payload.id;
    final existing = payload.existingChatId;
    final other = id > 0 &&
        (SessionStore.userId() == null || id != SessionStore.userId());

    final data = state.data;
    if (data != null && data.business) {
      _loadListings();
    } else if (payload.business) {
      _loadListings();
    }

    if (!other) return;

    // Soft refresh fonida — ochilishni bloklamaydi.
    // ignore: unawaited_futures
    _refreshFromNetwork(
      id: id,
      existingChatId: existing,
      showRefreshingBadge: true,
      silentFailure: true,
    );
  }

  Future<void> _refreshFromNetwork({
    required int id,
    required int? existingChatId,
    required bool showRefreshingBadge,
    required bool silentFailure,
  }) async {
    if (id <= 0) return;
    final me = SessionStore.userId();
    if (me != null && id == me) return;

    if (showRefreshingBadge) {
      state.profileRefreshing.value = true;
    }
    try {
      final result = await Get.find<ProfileRepository>().getPublicUser(id);
      final map = asMap(result.dataOrNull);
      if (map != null) {
        await PublicProfileCache.put(id, map);
        final updated = UserProfilePayload.fromApi(
          map,
          existingChatId: existingChatId,
        );
        state.data = updated;
        state.syncFriendshipFromPayload(updated);
        _loadListings();
      } else if (!silentFailure && result.errorOrNull != null) {
        showAppError(result.errorOrNull);
      }
    } finally {
      state.profileRefreshing.value = false;
    }
  }

  Future<void> _loadListings() async {
    final data = state.data;
    if (data == null || data.id <= 0 || !data.business) return;
    state.listings.clear();
    state.listingsError.value = null;
    state.listingsLoading.value = true;
    try {
      final result =
          await Get.find<ProductsRepository>().listByUser(data.id, limit: 20);
      if (result.errorOrNull != null) {
        state.listingsError.value = result.errorOrNull?.toString() ?? 'error'.tr;
        return;
      }
      final items = asList(result.dataOrNull)
          .whereType<Map>()
          .map((e) => Product.fromApi(Map<String, dynamic>.from(e)))
          .toList();
      state.listings.assignAll(items);
    } finally {
      state.listingsLoading.value = false;
    }
  }

  @override
  Future<void> actionHandler(UserProfileState state, MyAction action) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case WriteMessage _:
        final data = state.data;
        if (data == null || data.id <= 0) return;
        if (SessionStore.isUserBlocked(data.id)) {
          showAppWarning('chat_blocked'.tr);
          return;
        }
        final existingId = data.existingChatId;
        if (existingId != null && existingId > 0) {
          popBackNavigate();
          return;
        }
        final result = await Get.find<ChatRepository>().createChat(data.id);
        result.when(
          success: (raw) {
            final map = asMap(raw);
            final chatId = (map?['id'] as num?)?.toInt() ?? 0;
            if (chatId <= 0) {
              showAppError('chat_open_failed'.tr);
              return;
            }
            navigate(
              ChatScreen(),
              payload: ChatPayload(
                chatId: chatId,
                peerId: data.id,
                name: data.name,
                initial: data.initial,
                avatarGradient: data.avatarGradient,
                avatarUrl: data.avatarUrl,
              ),
            );
          },
          failure: showAppError,
        );
      case OpenCompanyTradeAssistant _:
        final data = state.data;
        if (data == null || !data.business || data.id <= 0) return;
        await navigate(
          TradeAssistantScreen(),
          payload: TradeAssistantPayload(
            sellerId: data.id,
            companyName: data.name,
          ),
        );
      case AddFriendFromProfile _:
        await _sendFriendRequest(state);
      case CancelFriendFromProfile _:
        await _cancelFriendRequest(state);
      case AcceptFriendFromProfile _:
        await _acceptFriendRequest(state);
      case OpenWebsite _:
        final url = state.data?.website;
        if (url == null || url.isEmpty) return;
        final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
        if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
      case OpenListing a:
        final data = state.data;
        showProductInfoBottomSheet(
          context,
          a.product,
          onOpenBusiness: () {},
          existingPeerId: data?.id,
          existingPeerChatId: data?.existingChatId,
          onReturnToExistingChat: () {
            if ((data?.existingChatId ?? 0) > 0) {
              popBackNavigate();
            }
          },
        );
      case OpenOwnBusinessVerification _:
        final data = state.data;
        if (data == null || !data.business) return;
        final me = SessionStore.userId();
        if (me == null || data.id != me) return;
        if (!context.mounted) return;
        final snap = await showBusinessVerificationBottomSheet(context);
        if (snap == null) return;
        final result = await Get.find<ProfileRepository>().getMe();
        final map = asMap(result.dataOrNull);
        if (map != null) {
          final updated = UserProfilePayload.fromApi(
            map,
            existingChatId: data.existingChatId,
          );
          state.data = updated;
          state.syncFriendshipFromPayload(updated);
        }
    }
  }

  Future<void> _sendFriendRequest(UserProfileState state) async {
    final data = state.data;
    if (data == null || data.id <= 0) return;
    if (SessionStore.isUserBlocked(data.id)) {
      showAppWarning('chat_blocked'.tr);
      return;
    }
    if (state.friendBusy.value) return;
    if (state.friendshipStatus.value == 'pending' ||
        state.friendshipStatus.value == 'accepted') {
      return;
    }
    state.friendBusy.value = true;
    state.friendshipStatus.value = 'pending';
    state.isRequestIncoming.value = false;
    final result = await Get.find<FriendsRepository>().sendRequest(data.id);
    result.when(
      success: (raw) {
        final map = asMap(raw);
        final requestId = (map?['id'] as num?)?.toInt();
        final status = map?['status']?.toString();
        if (status == 'accepted' || map?['auto_accepted'] == true) {
          state.friendshipStatus.value = 'accepted';
          state.friendshipRequestId.value = requestId;
          state.isRequestIncoming.value = false;
          showAppMessage('add_friend_is_friend'.tr);
          return;
        }
        state.friendshipStatus.value = 'pending';
        state.friendshipRequestId.value = requestId;
        state.isRequestIncoming.value = false;
        showAppMessage('add_friend_requested'.tr);
      },
      failure: (err) {
        final msg = err?.toString() ?? '';
        if (msg.contains('REQUEST_ALREADY_SENT') ||
            msg.contains('allaqachon')) {
          state.friendshipStatus.value = 'pending';
          state.isRequestIncoming.value = false;
          return;
        }
        state.friendshipStatus.value = 'none';
        state.friendshipRequestId.value = null;
        showAppError(err);
      },
    );
    state.friendBusy.value = false;
  }

  Future<void> _cancelFriendRequest(UserProfileState state) async {
    if (state.friendBusy.value) return;
    final requestId = state.friendshipRequestId.value;
    if (requestId == null) {
      state.friendshipStatus.value = 'none';
      state.isRequestIncoming.value = false;
      await _softRefreshFriendship();
      return;
    }
    state.friendBusy.value = true;
    final result = await Get.find<FriendsRepository>().cancelRequest(requestId);
    result.when(
      success: (_) {
        state.friendshipStatus.value = 'none';
        state.friendshipRequestId.value = null;
        state.isRequestIncoming.value = false;
      },
      failure: showAppError,
    );
    state.friendBusy.value = false;
  }

  Future<void> _acceptFriendRequest(UserProfileState state) async {
    if (state.friendBusy.value) return;
    final requestId = state.friendshipRequestId.value;
    if (requestId == null) {
      await _softRefreshFriendship();
      return;
    }
    state.friendBusy.value = true;
    final result = await Get.find<FriendsRepository>().acceptRequest(requestId);
    result.when(
      success: (_) {
        state.friendshipStatus.value = 'accepted';
        state.isRequestIncoming.value = false;
        showAppMessage('add_friend_is_friend'.tr);
      },
      failure: showAppError,
    );
    state.friendBusy.value = false;
  }

  Future<void> _softRefreshFriendship() async {
    final id = state.data?.id ?? 0;
    if (id <= 0) return;
    await _refreshFromNetwork(
      id: id,
      existingChatId: state.data?.existingChatId,
      showRefreshingBadge: true,
      silentFailure: true,
    );
  }
}
