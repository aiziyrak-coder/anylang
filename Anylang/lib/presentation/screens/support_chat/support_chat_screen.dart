import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/support_repository.dart';
import '../../modal/support_history_bottom_sheet.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/auth_validators.dart';
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
    state.composerClearToken.value = 0;
    state.sessionId.value = 0;
    state.sessionStatus.value = '';
    state.showRatingPrompt.value = false;
    state.selectedRating.value = 0;
    state.ratingSubmitting.value = false;
    state.messages.clear();
    Future.microtask(() => _loadActiveSession());
  }

  void _applyWelcome() {
    state.messages
      ..clear()
      ..add(
        SupportMessage(
          id: 'welcome',
          text: 'support_welcome'.tr,
          isOutgoing: false,
          at: DateTime.now(),
        ),
      );
  }

  void _updateRatingPrompt() {
    if (state.sessionStatus.value != 'active' || state.sessionId.value <= 0) {
      state.showRatingPrompt.value = false;
      return;
    }
    final msgs = state.messages
        .where((m) => m.id != 'welcome' && !m.pending && !m.failed)
        .toList();
    if (msgs.isEmpty) {
      state.showRatingPrompt.value = false;
      return;
    }
    final last = msgs.last;
    final hasUser = msgs.any((m) => m.isOutgoing);
    state.showRatingPrompt.value = hasUser && !last.isOutgoing;
  }

  Future<void> _loadActiveSession() async {
    state.loadingSession.value = true;
    state.error.value = '';
    final result = await Get.find<SupportRepository>().fetchActiveSession();
    result.when(
      success: (data) {
        final map = asMap(data);
        if (map == null || map['id'] == null) {
          _applyWelcome();
          state.sessionId.value = 0;
          state.sessionStatus.value = '';
          state.showRatingPrompt.value = false;
          return;
        }
        _applySessionMap(map);
      },
      failure: (err) {
        _applyWelcome();
        state.error.value = AuthValidators.safeError(
          err,
          fallbackKey: 'support_session_load_failed',
        );
      },
    );
    state.loadingSession.value = false;
    _updateRatingPrompt();
  }

  void _applySessionMap(Map<String, dynamic> map) {
    final id = (map['id'] as num?)?.toInt() ?? 0;
    state.sessionId.value = id;
    state.sessionStatus.value = map['status']?.toString() ?? '';
    state.messages.clear();
    final rawMsgs = map['messages'];
    if (rawMsgs is List) {
      for (final raw in rawMsgs) {
        final m = asMap(raw);
        if (m == null) continue;
        final role = m['role']?.toString() ?? 'user';
        final content = (m['content']?.toString() ?? '').trim();
        if (content.isEmpty) continue;
        final mid = (m['id'] as num?)?.toInt() ?? 0;
        final at = m['created_at'] != null
            ? DateTime.tryParse(m['created_at'].toString()) ?? DateTime.now()
            : DateTime.now();
        state.messages.add(
          SupportMessage(
            id: mid > 0 ? 'm_$mid' : 'm_${at.microsecondsSinceEpoch}',
            text: content,
            isOutgoing: role == 'user',
            at: at,
          ),
        );
      }
    }
    if (state.messages.isEmpty) {
      _applyWelcome();
    }
    if (state.sessionStatus.value == 'completed') {
      state.showRatingPrompt.value = false;
    } else {
      _updateRatingPrompt();
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
      case SupportOpenHistory _:
        await showSupportHistoryBottomSheet(
          context,
          onOpenSession: (id) => sendAction(SupportLoadSession(id)),
        );
      case SupportLoadSession a:
        await _loadSessionById(a.sessionId);
      case SupportSubmitRating a:
        await _submitRating(state, a.stars);
      case SupportDismissRating _:
        state.showRatingPrompt.value = false;
        state.selectedRating.value = 0;
    }
  }

  Future<void> _loadSessionById(int sessionId) async {
    state.loadingSession.value = true;
    final result =
        await Get.find<SupportRepository>().getSession(sessionId);
    result.when(
      success: (data) {
        final map = asMap(data);
        if (map != null) _applySessionMap(map);
      },
      failure: showAppError,
    );
    state.loadingSession.value = false;
  }

  Future<void> _submitRating(SupportChatState state, int stars) async {
    final sid = state.sessionId.value;
    if (sid <= 0 || stars < 1 || stars > 5 || state.ratingSubmitting.value) {
      return;
    }
    state.ratingSubmitting.value = true;
    final result = await Get.find<SupportRepository>().rateSession(
      sessionId: sid,
      rating: stars,
    );
    result.when(
      success: (data) {
        final map = asMap(data);
        if (map != null) {
          state.sessionStatus.value = map['status']?.toString() ?? 'completed';
        }
        state.showRatingPrompt.value = false;
        state.selectedRating.value = 0;
        state.sessionId.value = 0;
      },
      failure: showAppError,
    );
    state.ratingSubmitting.value = false;
  }

  String _locale() {
    try {
      final app = SessionStore.appLanguage().toLowerCase();
      if (app.startsWith('ru')) return 'ru';
      if (app.startsWith('en') || app.startsWith('us')) return 'en';
      return 'uz';
    } catch (_) {
      return Get.locale?.languageCode ?? 'uz';
    }
  }

  Future<void> _send(SupportChatState state, String raw) async {
    final text = raw.trim();
    if (text.isEmpty || state.sending.value) return;

    if (state.sessionStatus.value == 'completed' || state.sessionId.value <= 0) {
      if (state.sessionStatus.value == 'completed') {
        state.sessionId.value = 0;
        state.sessionStatus.value = '';
        state.messages.clear();
        _applyWelcome();
      }
    }

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
    if (state.messages.length == 1 && state.messages.first.id == 'welcome') {
      state.messages.removeAt(0);
    }
    state.messages.add(userMsg);
    state.sending.value = true;
    state.error.value = '';
    state.showRatingPrompt.value = false;

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

    final sid = state.sessionId.value > 0 ? state.sessionId.value : null;
    final result = await Get.find<SupportRepository>().send(
      message: text,
      history: history,
      locale: _locale(),
      sessionId: sid,
    );

    final idx = state.messages.indexWhere((m) => m.id == pendingId);
    result.when(
      success: (data) {
        final map = asMap(data) ?? {};
        final reply = (map['reply']?.toString() ?? '').trim();
        final newSid = (map['session_id'] as num?)?.toInt() ?? 0;
        if (newSid > 0) {
          state.sessionId.value = newSid;
          state.sessionStatus.value = 'active';
        }
        if (idx >= 0) {
          state.messages[idx] = SupportMessage(
            id: pendingId,
            text: reply.isEmpty ? 'support_empty_reply'.tr : reply,
            isOutgoing: false,
            at: DateTime.now(),
          );
        }
        state.composerClearToken.value++;
        state.showSend.value = false;
        state.error.value = '';
        _updateRatingPrompt();
      },
      failure: (err) {
        final msg =
            AuthValidators.safeError(err, fallbackKey: 'support_send_failed');
        state.error.value = msg;
        if (idx >= 0) {
          state.messages[idx] = SupportMessage(
            id: pendingId,
            text: msg,
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
