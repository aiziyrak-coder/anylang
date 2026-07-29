import 'chat_state.dart';

/// Nested [ChatScreen] uchun stack — har ochilgan chat o'z [ChatState]iga ega.
///
/// Bitta GetX singleton bo'lsa, guruh ichidan DM ochganda pastdagi guruh
/// state'i ham DM ga aylanadi va back stack buziladi. Shu scope shuni oldini oladi.
class ChatStateScope {
  ChatStateScope._();

  static final List<ChatState> _stack = <ChatState>[];

  static bool get isRegistered => _stack.isNotEmpty;

  static ChatState? get currentOrNull =>
      _stack.isEmpty ? null : _stack.last;

  static List<ChatState> get all => List<ChatState>.unmodifiable(_stack);

  /// Screen init bo'lganda stackga qo'shadi (constructor emas — leak oldini olish).
  static void attach(ChatState s) {
    if (!_stack.contains(s)) {
      _stack.add(s);
    }
  }

  static void pop(ChatState s) {
    final i = _stack.lastIndexOf(s);
    if (i >= 0) {
      _stack.removeAt(i);
    }
  }

  /// Stackdagi berilgan [chatId] ga mos barcha state'larga qo'llaydi.
  static void forChatId(int chatId, void Function(ChatState chat) fn) {
    for (final s in _stack) {
      if (s.chatId.value == chatId) {
        fn(s);
      }
    }
  }
}
