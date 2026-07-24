import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/support_repository.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import 'support_chat_action.dart';
import 'support_chat_content.dart';
import 'support_chat_state.dart';
import 'support_message.dart';

class SupportChatScreen extends Screen<SupportChatState, void> {
  SupportChatScreen() : super(mobileContent: SupportChatContent());

  @override
  void initState(void payload) {
    state.error.value = '';
    state.sending.value = false;
    state.showSend.value = false;
    if (state.messages.isEmpty) {
      state.messages.add(
        SupportMessage(
          id: 'welcome',
          text: 'support_welcome'.tr,
          isOutgoing: false,
          at: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<void> actionHandler(SupportChatState state, MyAction action) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case SupportComposerChanged a:
        state.showSend.value = a.text.trim().isNotEmpty;
      case SupportSend a:
        await _send(state, a.text);
    }
  }

  Future<void> _send(SupportChatState state, String raw) async {
    final text = raw.trim();
    if (text.isEmpty || state.sending.value) return;

    final history = state.messages
        .where((m) => m.id != 'welcome' && !m.failed && m.text.trim().isNotEmpty)
        .map(
          (m) => <String, String>{
            'role': m.isOutgoing ? 'user' : 'assistant',
            'content': m.text,
          },
        )
        .toList();

    final userMsg = SupportMessage(
      id: 'u_${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      isOutgoing: true,
      at: DateTime.now(),
    );
    state.messages.add(userMsg);
    state.sending.value = true;
    state.error.value = '';

    final pendingId = 'a_${DateTime.now().microsecondsSinceEpoch}';
    state.messages.add(
      SupportMessage(
        id: pendingId,
        text: 'support_typing'.tr,
        isOutgoing: false,
        at: DateTime.now(),
        pending: true,
      ),
    );

    final locale = SessionStore.preferredLanguage().isNotEmpty
        ? SessionStore.preferredLanguage()
        : (Get.locale?.languageCode ?? 'uz');

    final result = await Get.find<SupportRepository>().send(
      message: text,
      history: history,
      locale: locale,
    );

    final idx = state.messages.indexWhere((m) => m.id == pendingId);
    result.when(
      success: (data) {
        final map = asMap(data) ?? {};
        final reply = (map['reply']?.toString() ?? '').trim();
        if (idx >= 0) {
          state.messages[idx] = SupportMessage(
            id: pendingId,
            text: reply.isEmpty ? 'support_empty_reply'.tr : reply,
            isOutgoing: false,
            at: DateTime.now(),
          );
        }
      },
      failure: (err) {
        final msg = '$err'.trim();
        state.error.value = msg;
        if (idx >= 0) {
          state.messages[idx] = SupportMessage(
            id: pendingId,
            text: msg.isNotEmpty ? msg : 'support_send_failed'.tr,
            isOutgoing: false,
            at: DateTime.now(),
            failed: true,
          );
        }
      },
    );
    state.sending.value = false;
  }
}
