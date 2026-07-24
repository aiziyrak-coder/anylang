import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/chat_repository.dart';
import '../../../data/network/friends_repository.dart';
import '../../ui/app_loading.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/buttons/rich_button.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme/gradients.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import '../chat/chat_payload.dart';
import '../chat/chat_screen.dart';
import '../friends/friend.dart';

class CreateGroupState extends GetxController {
  final title = ''.obs;
  final friends = <Friend>[].obs;
  final selectedIds = <int>{}.obs;
  final loading = true.obs;
  final submitting = false.obs;
}

class CreateGroupScreen extends Screen<CreateGroupState, void> {
  CreateGroupScreen() : super(mobileContent: _CreateGroupContent());

  @override
  void initState(void payload) {
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    state.loading.value = true;
    final result = await Get.find<FriendsRepository>().listFriends(limit: 100);
    result.when(
      success: (data) {
        final items = asList(data)
            .whereType<Map>()
            .map((e) => Friend.fromApi(Map<String, dynamic>.from(e)))
            .toList();
        state.friends.assignAll(items);
      },
      failure: showAppError,
    );
    state.loading.value = false;
  }

  @override
  Future<void> actionHandler(CreateGroupState state, MyAction action) async {
    if (action is _ToggleMember) {
      final next = {...state.selectedIds};
      if (next.contains(action.id)) {
        next.remove(action.id);
      } else {
        next.add(action.id);
      }
      state.selectedIds
        ..clear()
        ..addAll(next);
      state.selectedIds.refresh();
      return;
    }
    if (action is _SubmitGroup) {
      final title = state.title.value.trim();
      if (title.length < 2) {
        showAppError('group_title_required'.tr);
        return;
      }
      if (state.selectedIds.isEmpty) {
        showAppError('group_members_required'.tr);
        return;
      }
      state.submitting.value = true;
      try {
        final result = await Get.find<ChatRepository>().createGroup(
          title: title,
          userIds: state.selectedIds.toList(),
        );
        if (result.errorOrNull != null) {
          showAppError(result.errorOrNull);
          return;
        }
        final map = asMap(result.dataOrNull);
        final chatId = (map?['id'] as num?)?.toInt() ?? 0;
        if (chatId <= 0) {
          showAppError('error'.tr);
          return;
        }
        if (!context.mounted) return;
        final chat = ChatScreen()
          ..payload = ChatPayload(
            chatId: chatId,
            peerId: 0,
            name: title,
            initial: initialsOf(title),
            avatarGradient: avatarGradientFor(chatId),
            online: false,
            isGroup: true,
          );
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => chat.build()),
        );
      } finally {
        state.submitting.value = false;
      }
    }
  }
}

class _ToggleMember extends MyAction {
  final int id;
  _ToggleMember(this.id);
}

class _SubmitGroup extends MyAction {}

class _CreateGroupContent extends ScreenContent<CreateGroupState> {
  _CreateGroupContent() : super();

  @override
  Widget build(
    BuildContext context,
    CreateGroupState state,
    void Function(MyAction action) sendAction,
  ) {
    final c = context.appColors;
    return Column(
      children: [
        AppTopBar(
          title: 'group_create_title'.tr,
          onBack: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Obx(() {
            if (state.loading.value) return const AppLoading();
            return ListView(
              padding: EdgeInsets.fromLTRB(20.dp, 8.dp, 20.dp, 24.dp),
              children: [
                TextField(
                  onChanged: (v) => state.title.value = v,
                  decoration: InputDecoration(
                    labelText: 'group_title'.tr,
                    hintText: 'group_title_hint'.tr,
                  ),
                ),
                SizedBox(height: 16.dp),
                Text(
                  'group_pick_members'.tr,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15.sp,
                  ),
                ),
                SizedBox(height: 8.dp),
                if (state.friends.isEmpty)
                  Text(
                    'group_no_friends'.tr,
                    style: TextStyle(color: c.textSecondary, fontSize: 14.sp),
                  )
                else
                  ...state.friends.map((f) {
                    final selected = state.selectedIds.contains(f.id);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (_) => sendAction(_ToggleMember(f.id)),
                      title: Text(f.name),
                      subtitle: Text(f.number ?? f.status),
                      controlAffinity: ListTileControlAffinity.trailing,
                    );
                  }),
                SizedBox(height: 20.dp),
                Obx(
                  () => RichButton(
                    text: state.submitting.value
                        ? '…'
                        : 'group_create_action'.tr,
                    onTap: state.submitting.value
                        ? () {}
                        : () => sendAction(_SubmitGroup()),
                    textColor: c.onAccent,
                    textStyle: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14.dp),
                    borderRadius: BorderRadius.circular(14.dp),
                    decoration: BoxDecoration(
                      gradient: limeButtonGradient,
                      borderRadius: BorderRadius.circular(14.dp),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }
}
