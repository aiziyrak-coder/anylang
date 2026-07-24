import 'package:get/get.dart';

import '../../presentation/screens/chat/chat_message.dart';

/// Telegram uslubidagi uzatish: manba chatdan chiqib, boshqa suhbatga
/// yopishtiriladigan vaqtinchalik draft (diskda saqlanmaydi).
class ForwardPendingItem {
  final int messageId;
  final String preview;
  final String senderLabel;

  const ForwardPendingItem({
    required this.messageId,
    required this.preview,
    required this.senderLabel,
  });
}

class ForwardPendingStore extends GetxService {
  final RxList<ForwardPendingItem> items = <ForwardPendingItem>[].obs;
  final RxBool showSender = true.obs;
  final RxnInt sourceChatId = RxnInt();

  bool get hasPending => items.isNotEmpty;

  void begin({
    required int sourceChatId,
    required List<ForwardPendingItem> items,
  }) {
    if (items.isEmpty) return;
    this.sourceChatId.value = sourceChatId;
    showSender.value = true;
    this.items.assignAll(items);
  }

  void beginFromMessages({
    required int sourceChatId,
    required List<ChatMessage> messages,
    required String peerName,
    required String youLabel,
  }) {
    final mapped = <ForwardPendingItem>[];
    for (final m in messages) {
      final id = int.tryParse(m.id);
      if (id == null) continue;
      final label = m.isOutgoing
          ? youLabel
          : (m.senderName?.trim().isNotEmpty == true
              ? m.senderName!.trim()
              : peerName);
      mapped.add(
        ForwardPendingItem(
          messageId: id,
          preview: m.previewText(),
          senderLabel: label.isEmpty ? '…' : label,
        ),
      );
    }
    begin(sourceChatId: sourceChatId, items: mapped);
  }

  void toggleShowSender() => showSender.value = !showSender.value;

  void clear() {
    items.clear();
    sourceChatId.value = null;
    showSender.value = true;
  }
}
