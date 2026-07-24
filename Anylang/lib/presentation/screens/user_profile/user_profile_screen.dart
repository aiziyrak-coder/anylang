import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/chat_repository.dart';
import '../../../data/network/friends_repository.dart';
import '../../../data/network/products_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../chat/chat_payload.dart';
import '../chat/chat_screen.dart';
import '../products/product.dart';
import '../products/product_info_bottom_sheet.dart';
import 'user_profile_action.dart';
import 'user_profile_content.dart';
import 'user_profile_payload.dart';
import 'user_profile_state.dart';

class UserProfileScreen extends Screen<UserProfileState, UserProfilePayload> {
  UserProfileScreen() : super(mobileContent: UserProfileContent());

  @override
  void initState(UserProfilePayload? payload) {
    state.data = payload;
    state.syncFriendshipFromPayload(payload);
    _loadListings();
    _refreshFriendship();
  }

  Future<void> _loadListings() async {
    final data = state.data;
    if (data == null || data.id <= 0 || !data.business) return;
    state.listings.clear();
    state.listingsLoading.value = true;
    final result =
        await Get.find<ProductsRepository>().listByUser(data.id, limit: 20);
    if (result.errorOrNull != null) {
      state.listingsLoading.value = false;
      showAppError(result.errorOrNull);
      return;
    }
    final items = asList(result.dataOrNull)
        .whereType<Map>()
        .map((e) => Product.fromApi(Map<String, dynamic>.from(e)))
        .toList();
    state.listings.assignAll(items);
    state.listingsLoading.value = false;
  }

  Future<void> _refreshFriendship() async {
    final id = state.data?.id ?? 0;
    if (id <= 0) return;
    if (id == SessionStore.userId()) return;
    final result = await Get.find<ProfileRepository>().getPublicUser(id);
    result.when(
      success: (raw) {
        final map = asMap(raw);
        if (map == null) return;
        final existing = state.data?.existingChatId;
        final updated = UserProfilePayload.fromApi(
          map,
          existingChatId: existing,
        );
        state.data = updated;
        state.syncFriendshipFromPayload(updated);
      },
      failure: (_) {},
    );
  }

  @override
  Future<void> actionHandler(UserProfileState state, MyAction action) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case WriteMessage _:
        final data = state.data;
        if (data == null || data.id <= 0) return;
        // Chat ichidan profil ochilgan — mavjud chatga orqaga (yangi screen yo'q).
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
        showProductInfoBottomSheet(
          context,
          a.product,
          onOpenBusiness: () {},
        );
    }
  }

  Future<void> _sendFriendRequest(UserProfileState state) async {
    final data = state.data;
    if (data == null || data.id <= 0) return;
    if (state.friendBusy.value) return;
    if (state.friendshipStatus.value == 'pending' ||
        state.friendshipStatus.value == 'accepted') {
      return;
    }
    state.friendBusy.value = true;
    // Optimistic — add_friend ekrani bilan bir xil.
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
      await _refreshFriendship();
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
      await _refreshFriendship();
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
}
