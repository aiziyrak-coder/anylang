import 'package:get/get.dart';

import '../screens/chat/chat_message.dart';

/// Smart Pin turlari — pin bannerida emoji + label.
enum SmartPinKind {
  contract,
  product,
  address,
  invoice,
  other,
}

class SmartPinInfo {
  final SmartPinKind kind;
  final String emoji;
  final String labelKey;

  const SmartPinInfo({
    required this.kind,
    required this.emoji,
    required this.labelKey,
  });

  String get label => labelKey.tr;
}

const _kContract = SmartPinInfo(
  kind: SmartPinKind.contract,
  emoji: '📄',
  labelKey: 'smart_pin_contract',
);
const _kProduct = SmartPinInfo(
  kind: SmartPinKind.product,
  emoji: '📦',
  labelKey: 'smart_pin_product',
);
const _kAddress = SmartPinInfo(
  kind: SmartPinKind.address,
  emoji: '📍',
  labelKey: 'smart_pin_address',
);
const _kInvoice = SmartPinInfo(
  kind: SmartPinKind.invoice,
  emoji: '💰',
  labelKey: 'smart_pin_invoice',
);
const _kOther = SmartPinInfo(
  kind: SmartPinKind.other,
  emoji: '📌',
  labelKey: 'smart_pin_other',
);

SmartPinInfo classifySmartPin(ChatMessage msg) {
  switch (msg.type) {
    case ChatMsgType.invoice:
    case ChatMsgType.offer:
      return _kInvoice;
    case ChatMsgType.product:
    case ChatMsgType.catalog:
    case ChatMsgType.rfq:
      return _kProduct;
    case ChatMsgType.location:
      return _kAddress;
    case ChatMsgType.file:
      final name = (msg.fileName ?? '').toLowerCase();
      final ext = (msg.fileExt ?? '').toLowerCase();
      if (ext == 'pdf' ||
          name.contains('contract') ||
          name.contains('shartnoma') ||
          name.contains('dogovor') ||
          name.contains('agreement')) {
        return _kContract;
      }
      break;
    case ChatMsgType.text:
    case ChatMsgType.voice:
    case ChatMsgType.video:
    case ChatMsgType.image:
    case ChatMsgType.contact:
    case ChatMsgType.businessCard:
      break;
  }

  final text = [
    msg.displayText,
    msg.previewText(),
    msg.cardTitle ?? '',
    msg.fileName ?? '',
  ].join(' ').toLowerCase();

  if (_looksLikeInvoice(text)) return _kInvoice;
  if (_looksLikeProduct(text)) return _kProduct;
  if (_looksLikeAddress(text)) return _kAddress;
  if (_looksLikeContract(text)) return _kContract;
  return _kOther;
}

bool _looksLikeInvoice(String t) {
  return t.contains('invoice') ||
      t.contains('инвойс') ||
      t.contains('invoys') ||
      t.contains('payment') ||
      t.contains('to‘lov') ||
      t.contains('tolov') ||
      t.contains('оплат') ||
      t.contains('сумма') ||
      RegExp(r'\b(usd|eur|uzs)\b').hasMatch(t);
}

bool _looksLikeProduct(String t) {
  return t.contains('product') ||
      t.contains('mahsulot') ||
      t.contains('товар') ||
      t.contains('moq') ||
      t.contains('sku') ||
      t.contains('catalog') ||
      t.contains('katalog');
}

bool _looksLikeAddress(String t) {
  return t.contains('address') ||
      t.contains('manzil') ||
      t.contains('адрес') ||
      t.contains('location') ||
      t.contains('warehouse') ||
      t.contains('ombor') ||
      t.contains('shanghai') ||
      t.contains('fob ') ||
      t.contains('cif ');
}

bool _looksLikeContract(String t) {
  return t.contains('contract') ||
      t.contains('shartnoma') ||
      t.contains('договор') ||
      t.contains('agreement') ||
      t.contains('terms') ||
      t.contains('nda');
}

String smartPinPreview(ChatMessage msg) {
  final info = classifySmartPin(msg);
  switch (info.kind) {
    case SmartPinKind.invoice:
      if (msg.type == ChatMsgType.offer) {
        final bits = [
          msg.offerProduct,
          [msg.offerPrice, msg.offerCurrency]
              .where((e) => (e ?? '').isNotEmpty)
              .join(' '),
        ].whereType<String>().where((e) => e.isNotEmpty);
        final s = bits.join(' · ');
        if (s.isNotEmpty) return s;
      }
      if ((msg.cardTitle ?? '').isNotEmpty) {
        final amount = msg.cardSubtitle ?? '';
        return amount.isNotEmpty
            ? '${msg.cardTitle} · $amount'
            : msg.cardTitle!;
      }
      break;
    case SmartPinKind.product:
      if ((msg.productTitle ?? '').isNotEmpty) {
        final price = msg.productPrice ?? '';
        return price.isNotEmpty
            ? '${msg.productTitle} · $price'
            : msg.productTitle!;
      }
      if ((msg.cardTitle ?? '').isNotEmpty) return msg.cardTitle!;
      if ((msg.offerProduct ?? '').isNotEmpty) return msg.offerProduct!;
      break;
    case SmartPinKind.address:
      if ((msg.locationLabel ?? '').isNotEmpty) return msg.locationLabel!;
      break;
    case SmartPinKind.contract:
      if ((msg.fileName ?? '').isNotEmpty) return msg.fileName!;
      break;
    case SmartPinKind.other:
      break;
  }
  final preview = msg.previewText().trim();
  if (preview.isNotEmpty) return preview;
  return info.label;
}
