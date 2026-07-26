import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/feed_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../modal/create_feed_bottom_sheet.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../user_profile/user_profile_payload.dart';
import '../user_profile/user_profile_screen.dart';
import 'business_feed_action.dart';
import 'business_feed_content.dart';
import 'business_feed_state.dart';
import 'feed_post.dart';

class BusinessFeedScreen extends Screen<BusinessFeedState, void> {
  BusinessFeedScreen() : super(mobileContent: BusinessFeedContent());

  @override
  void initState(void payload) {
    _detectBusiness();
    _load(reset: true);
  }

  Future<void> _detectBusiness() async {
    final me = await Get.find<ProfileRepository>().getMe();
    final map = asMap(me.dataOrNull);
    if (map != null) {
      state.isBusiness.value = map['is_business'] == true;
    }
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      state.loading.value = true;
      state.page.value = 1;
    } else {
      if (state.loadingMore.value || !state.hasMore.value) return;
      state.loadingMore.value = true;
    }
    final page = reset ? 1 : state.page.value + 1;
    final result = await Get.find<FeedRepository>().list(
      page: page,
      limit: 20,
      postType: state.filterType.value,
    );
    if (reset) state.loading.value = false;
    state.loadingMore.value = false;

    result.when(
      success: (data) {
        final map = asMap(data);
        final raw = map?['items'];
        final items = <FeedPost>[];
        if (raw is List) {
          for (final e in raw) {
            if (e is Map) {
              items.add(FeedPost.fromApi(Map<String, dynamic>.from(e)));
            }
          }
        }
        if (reset) {
          state.posts.assignAll(items);
        } else {
          state.posts.addAll(items);
        }
        state.page.value = page;
        state.hasMore.value = map?['has_more'] == true;
      },
      failure: (err) {
        if (reset) showAppError(err);
      },
    );
  }

  @override
  Future<void> actionHandler(BusinessFeedState state, MyAction action) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case FeedRefreshRequested _:
        await _load(reset: true);
      case FeedLoadMoreRequested _:
        await _load(reset: false);
      case FeedSelectType a:
        state.filterType.value = a.type;
        await _load(reset: true);
      case FeedCreateRequested _:
        if (!state.isBusiness.value) {
          showAppError('feed_business_required'.tr);
          return;
        }
        final created = await showCreateFeedBottomSheet(context);
        if (created == null) return;
        await _submitCreate(
          postType: created.postType,
          title: created.title,
          body: created.body,
        );
      case FeedSubmitCreate a:
        await _submitCreate(
          postType: a.postType,
          title: a.title,
          body: a.body,
        );
      case FeedDeleteRequested a:
        final ok = await Get.dialog<bool>(
          AlertDialog(
            title: Text('confirm'.tr),
            content: Text('feed_delete_confirm'.tr),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: Text('settings_cancel'.tr),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                child: Text(
                  'confirm'.tr,
                  style: const TextStyle(color: Color(0xFFB42318)),
                ),
              ),
            ],
          ),
        );
        if (ok != true) return;
        final result = await Get.find<FeedRepository>().delete(a.postId);
        result.when(
          success: (_) {
            state.posts.removeWhere((p) => p.id == a.postId);
            showAppMessage('action_done'.tr);
          },
          failure: showAppError,
        );
      case FeedOpenAuthor a:
        if (a.authorId <= 0) return;
        final me = SessionStore.userId();
        if (me != null && me == a.authorId) return;
        final profile = await Get.find<ProfileRepository>().getPublicUser(a.authorId);
        final map = asMap(profile.dataOrNull);
        if (map == null) {
          showAppError(profile.errorOrNull ?? 'error'.tr);
          return;
        }
        await navigate(
          UserProfileScreen(),
          payload: UserProfilePayload.fromApi(map),
        );
    }
  }

  Future<void> _submitCreate({
    required String postType,
    required String title,
    required String body,
  }) async {
    state.submitting.value = true;
    try {
      final result = await Get.find<FeedRepository>().create({
        'post_type': postType,
        'title': title.trim(),
        'body': body.trim(),
      });
      result.when(
        success: (data) {
          final map = asMap(data);
          if (map != null) {
            state.posts.insert(0, FeedPost.fromApi(map));
          }
          showAppMessage('feed_published'.tr);
        },
        failure: showAppError,
      );
    } finally {
      state.submitting.value = false;
    }
  }
}
