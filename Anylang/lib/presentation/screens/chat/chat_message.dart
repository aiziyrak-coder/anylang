import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Xabar yo'nalishi: kiruvchi (suhbatdosh) yoki chiquvchi (men).
enum ChatDir { incoming, outgoing }

/// Chiquvchi xabar yetkazilish holati (kiruvchida ishlatilmaydi).
/// `pending` — offline / yuborilmagan (Telegram soat ikonkasi).
enum ChatStatus { pending, sent, delivered, read }

/// Xabar turi.
enum ChatMsgType {
  text,
  image,
  voice,
  product,
  location,
  file,
  contact,
  invoice,
  catalog,
  businessCard,
  offer,
  rfq,
}

/// Javob (reply) uchun sitata bloki — qaysi xabarga javob berilayotgani.
class ChatReply {
  final String author;
  final String preview;
  /// Asosiy xabar id (bosganda shu xabarga scroll).
  final String? messageId;

  const ChatReply({
    required this.author,
    required this.preview,
    this.messageId,
  });
}

/// Bitta chat xabari. Barcha turlar bitta modelda — turi `type` bilan
/// belgilanadi, tegishli maydonlar to'ldiriladi.
class ChatMessage {
  final String id;
  final ChatMsgType type;
  final ChatDir dir;
  final String time; // "14:32"
  final DateTime? createdAt;
  final ChatStatus status; // faqat chiquvchi uchun
  final ChatReply? reply;

  /// Guruh chatlari uchun jo'natuvchi (DM da ko'pincha null).
  final int? senderId;
  final String? senderName;
  final String? senderAvatarUrl;

  // text
  final String? text;
  /// Jo'natuvchi asl matni (tarjima qilingan xabarlarda).
  final String? textOriginal;
  /// `true` bo'lsa bubble'da `textOriginal` ko'rsatiladi.
  final bool showingOriginal;
  /// AI FAQ avto-javob.
  final bool isAiFaq;

  // image
  final LinearGradient? imageGradient;
  final String? imageUrl;

  // voice
  final String? voiceDuration; // "0:21"
  final bool voiceDownloaded; // play (true) yoki download (false) holati
  final String? voicePath; // lokal fayl yoki remote URL
  final List<double> voiceSamples; // waveform amplitude 0..1
  final int? voiceDurationMs;

  /// Voice STT: matn hali tayyor emas.
  final bool transcriptPending;
  /// Voice STT: aniqlanmadi / xato.
  final bool transcriptFailed;

  // product
  final String? productTitle;
  final String? productPrice;
  final int? productId;

  // location
  final String? locationLabel; // "Do'kon manzili"
  final String? locationDistance; // "1.2 km"
  final double? latitude;
  final double? longitude;

  // file
  final String? fileName; // "Shartnoma.pdf"
  final String? fileSize; // "248 KB"
  final String? fileExt; // "PDF"
  final String? fileUrl;

  // contact
  final String? contactName;
  final String? contactPhone;
  final String? contactInitial;
  final int? contactUserId;
  final String? contactAvatarUrl;
  final String? contactNumber;

  // invoice / catalog / business_card
  final String? cardTitle;
  final String? cardSubtitle;
  final String? cardDetail;
  final String? cardImageUrl;
  final int? cardUserId;

  // offer (narx muzokarasi)
  final String? offerProduct;
  final String? offerPrice;
  final String? offerCurrency;
  final String? offerDelivery;
  final String? offerMoq;
  final String? offerPayment;
  /// offered | accepted | countered
  final String? offerStatus;

  // rfq (marketplace ehtiyoj so'rovi)
  final String? rfqProduct;
  final String? rfqQuantity;
  final String? rfqUnit;
  final String? rfqSpecs;
  final String? rfqDeadline;

  /// Tahrirlangan vaqt (API edited_at).
  final DateTime? editedAt;
  /// [{emoji, count, mine}]
  final List<Map<String, dynamic>> reactions;
  final bool pinned;
  /// Noma'lum yuboruvchi uchun avto biznes kartochka (xabar tepasida).
  final AutoBusinessCard? autoBusinessCard;

  const ChatMessage({
    required this.id,
    required this.type,
    required this.dir,
    required this.time,
    this.createdAt,
    this.status = ChatStatus.read,
    this.reply,
    this.senderId,
    this.senderName,
    this.senderAvatarUrl,
    this.text,
    this.textOriginal,
    this.showingOriginal = false,
    this.isAiFaq = false,
    this.imageGradient,
    this.imageUrl,
    this.voiceDuration,
    this.voiceDownloaded = true,
    this.voicePath,
    this.voiceSamples = const [],
    this.voiceDurationMs,
    this.transcriptPending = false,
    this.transcriptFailed = false,
    this.productTitle,
    this.productPrice,
    this.productId,
    this.locationLabel,
    this.locationDistance,
    this.latitude,
    this.longitude,
    this.fileName,
    this.fileSize,
    this.fileExt,
    this.fileUrl,
    this.contactName,
    this.contactPhone,
    this.contactInitial,
    this.contactUserId,
    this.contactAvatarUrl,
    this.contactNumber,
    this.cardTitle,
    this.cardSubtitle,
    this.cardDetail,
    this.cardImageUrl,
    this.cardUserId,
    this.offerProduct,
    this.offerPrice,
    this.offerCurrency,
    this.offerDelivery,
    this.offerMoq,
    this.offerPayment,
    this.offerStatus,
    this.rfqProduct,
    this.rfqQuantity,
    this.rfqUnit,
    this.rfqSpecs,
    this.rfqDeadline,
    this.editedAt,
    this.reactions = const [],
    this.pinned = false,
    this.autoBusinessCard,
  });

  bool get isOutgoing => dir == ChatDir.outgoing;

  /// Tarjima + asl farq qilsa — ikkalasini ko‘rsatish uchun.
  bool get hasDualLanguage {
    final t = text?.trim() ?? '';
    final o = textOriginal?.trim() ?? '';
    return t.isNotEmpty && o.isNotEmpty && t != o;
  }

  /// Bubble'da asosiy matn (tarjima ustun).
  String get displayText {
    if (showingOriginal &&
        textOriginal != null &&
        textOriginal!.trim().isNotEmpty) {
      return textOriginal!;
    }
    final translated = text?.trim();
    if (translated != null && translated.isNotEmpty) return text!;
    final original = textOriginal?.trim();
    if (original != null && original.isNotEmpty) return textOriginal!;
    return '';
  }

  /// Asl matn (ixtiyoriy yon ko‘rinish). Bubble default faqat [displayText];
  /// asl — menyu orqali [showingOriginal].
  String? get originalAside {
    if (showingOriginal) return null;
    if (!hasDualLanguage) return null;
    return textOriginal!.trim();
  }

  ChatMessage _copy({
    ChatStatus? status,
    bool? showingOriginal,
    bool? isAiFaq,
    int? senderId,
    String? senderName,
    String? senderAvatarUrl,
    String? text,
    String? textOriginal,
    DateTime? editedAt,
    List<Map<String, dynamic>>? reactions,
    bool? pinned,
    AutoBusinessCard? autoBusinessCard,
    bool clearAutoBusinessCard = false,
    bool? transcriptPending,
    bool? transcriptFailed,
  }) =>
      ChatMessage(
        id: id,
        type: type,
        dir: dir,
        time: time,
        createdAt: createdAt,
        status: status ?? this.status,
        reply: reply,
        senderId: senderId ?? this.senderId,
        senderName: senderName ?? this.senderName,
        senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
        text: text ?? this.text,
        textOriginal: textOriginal ?? this.textOriginal,
        showingOriginal: showingOriginal ?? this.showingOriginal,
        isAiFaq: isAiFaq ?? this.isAiFaq,
        imageGradient: imageGradient,
        imageUrl: imageUrl,
        voiceDuration: voiceDuration,
        voiceDownloaded: voiceDownloaded,
        voicePath: voicePath,
        voiceSamples: voiceSamples,
        voiceDurationMs: voiceDurationMs,
        transcriptPending: transcriptPending ?? this.transcriptPending,
        transcriptFailed: transcriptFailed ?? this.transcriptFailed,
        productTitle: productTitle,
        productPrice: productPrice,
        productId: productId,
        locationLabel: locationLabel,
        locationDistance: locationDistance,
        latitude: latitude,
        longitude: longitude,
        fileName: fileName,
        fileSize: fileSize,
        fileExt: fileExt,
        fileUrl: fileUrl,
        contactName: contactName,
        contactPhone: contactPhone,
        contactInitial: contactInitial,
        contactUserId: contactUserId,
        contactAvatarUrl: contactAvatarUrl,
        contactNumber: contactNumber,
        cardTitle: cardTitle,
        cardSubtitle: cardSubtitle,
        cardDetail: cardDetail,
        cardImageUrl: cardImageUrl,
        cardUserId: cardUserId,
        offerProduct: offerProduct,
        offerPrice: offerPrice,
        offerCurrency: offerCurrency,
        offerDelivery: offerDelivery,
        offerMoq: offerMoq,
        offerPayment: offerPayment,
        offerStatus: offerStatus,
        rfqProduct: rfqProduct,
        rfqQuantity: rfqQuantity,
        rfqUnit: rfqUnit,
        rfqSpecs: rfqSpecs,
        rfqDeadline: rfqDeadline,
        editedAt: editedAt ?? this.editedAt,
        reactions: reactions ?? this.reactions,
        pinned: pinned ?? this.pinned,
        autoBusinessCard: clearAutoBusinessCard
            ? null
            : (autoBusinessCard ?? this.autoBusinessCard),
      );

  ChatMessage withToggleOriginal() =>
      _copy(showingOriginal: !showingOriginal);

  ChatMessage withShowingOriginal(bool value) =>
      _copy(showingOriginal: value);

  ChatMessage withStatus(ChatStatus status) => _copy(status: status);

  ChatMessage withSenderMeta({
    int? senderId,
    String? senderName,
    String? senderAvatarUrl,
  }) =>
      _copy(
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
      );

  ChatMessage withReactions(List<Map<String, dynamic>> reactions) =>
      _copy(reactions: reactions);

  ChatMessage withPinned(bool pinned) => _copy(pinned: pinned);

  ChatMessage withEditedText(String text, {DateTime? editedAt}) => _copy(
        text: text,
        textOriginal: text,
        editedAt: editedAt ?? DateTime.now().toUtc(),
      );

  ChatMessage withExtras({
    DateTime? editedAt,
    List<Map<String, dynamic>>? reactions,
    bool? pinned,
    AutoBusinessCard? autoBusinessCard,
  }) =>
      _copy(
        editedAt: editedAt,
        reactions: reactions,
        pinned: pinned,
        autoBusinessCard: autoBusinessCard,
      );

  factory ChatMessage.text({
    required String id,
    required ChatDir dir,
    required String time,
    required String text,
    DateTime? createdAt,
    String? textOriginal,
    ChatStatus status = ChatStatus.read,
    ChatReply? reply,
    bool showingOriginal = false,
    bool isAiFaq = false,
    int? senderId,
    String? senderName,
    String? senderAvatarUrl,
  }) =>
      ChatMessage(
        id: id,
        type: ChatMsgType.text,
        dir: dir,
        time: time,
        createdAt: createdAt,
        status: status,
        reply: reply,
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
        text: text,
        textOriginal: textOriginal,
        showingOriginal: showingOriginal,
        isAiFaq: isAiFaq,
      );

  factory ChatMessage.image({
    required String id,
    required ChatDir dir,
    required String time,
    DateTime? createdAt,
    LinearGradient? gradient,
    String? url,
    ChatStatus status = ChatStatus.read,
    ChatReply? reply,
    int? senderId,
    String? senderName,
    String? senderAvatarUrl,
  }) =>
      ChatMessage(
        id: id,
        type: ChatMsgType.image,
        dir: dir,
        time: time,
        createdAt: createdAt,
        status: status,
        reply: reply,
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
        imageGradient: gradient,
        imageUrl: url,
      );

  factory ChatMessage.voice({
    required String id,
    required ChatDir dir,
    required String time,
    required String duration,
    DateTime? createdAt,
    bool downloaded = true,
    ChatStatus status = ChatStatus.read,
    String? path,
    List<double> samples = const [],
    int? durationMs,
    ChatReply? reply,
    int? senderId,
    String? senderName,
    String? senderAvatarUrl,
    String? text,
    String? textOriginal,
    bool showingOriginal = false,
    bool transcriptPending = false,
    bool transcriptFailed = false,
  }) =>
      ChatMessage(
        id: id,
        type: ChatMsgType.voice,
        dir: dir,
        time: time,
        createdAt: createdAt,
        status: status,
        reply: reply,
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
        text: text,
        textOriginal: textOriginal,
        showingOriginal: showingOriginal,
        voiceDuration: duration,
        voiceDownloaded: downloaded,
        voicePath: path,
        voiceSamples: samples,
        voiceDurationMs: durationMs,
        transcriptPending: transcriptPending,
        transcriptFailed: transcriptFailed,
      );

  factory ChatMessage.product({
    required String id,
    required ChatDir dir,
    required String time,
    required String title,
    required String price,
    DateTime? createdAt,
    int? productId,
    ChatStatus status = ChatStatus.read,
    int? senderId,
    String? senderName,
    String? senderAvatarUrl,
  }) =>
      ChatMessage(
        id: id,
        type: ChatMsgType.product,
        dir: dir,
        time: time,
        createdAt: createdAt,
        status: status,
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
        productTitle: title,
        productPrice: price,
        productId: productId,
      );

  factory ChatMessage.location({
    required String id,
    required ChatDir dir,
    required String time,
    required String label,
    required String distance,
    DateTime? createdAt,
    double? latitude,
    double? longitude,
    ChatStatus status = ChatStatus.read,
    int? senderId,
    String? senderName,
    String? senderAvatarUrl,
  }) =>
      ChatMessage(
        id: id,
        type: ChatMsgType.location,
        dir: dir,
        time: time,
        createdAt: createdAt,
        status: status,
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
        locationLabel: label,
        locationDistance: distance,
        latitude: latitude,
        longitude: longitude,
      );

  factory ChatMessage.file({
    required String id,
    required ChatDir dir,
    required String time,
    required String name,
    required String size,
    required String ext,
    DateTime? createdAt,
    String? url,
    ChatStatus status = ChatStatus.read,
    int? senderId,
    String? senderName,
    String? senderAvatarUrl,
  }) =>
      ChatMessage(
        id: id,
        type: ChatMsgType.file,
        dir: dir,
        time: time,
        createdAt: createdAt,
        status: status,
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
        fileName: name,
        fileSize: size,
        fileExt: ext,
        fileUrl: url,
      );

  factory ChatMessage.contact({
    required String id,
    required ChatDir dir,
    required String time,
    required String name,
    required String phone,
    required String initial,
    DateTime? createdAt,
    ChatStatus status = ChatStatus.read,
    int? senderId,
    String? senderName,
    String? senderAvatarUrl,
    int? userId,
    String? avatarUrl,
    String? number,
  }) =>
      ChatMessage(
        id: id,
        type: ChatMsgType.contact,
        dir: dir,
        time: time,
        createdAt: createdAt,
        status: status,
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
        contactName: name,
        contactPhone: phone,
        contactInitial: initial,
        contactUserId: userId,
        contactAvatarUrl: avatarUrl,
        contactNumber: number,
      );

  /// Javob (reply) sitatasi va "Nusxa olish" uchun qisqa matn ko'rinishi.
  String previewText() {
    switch (type) {
      case ChatMsgType.text:
        return displayText;
      case ChatMsgType.image:
        return 'chat_preview_photo'.tr;
      case ChatMsgType.voice:
        final caption = displayText.trim();
        if (caption.isNotEmpty) return caption;
        return 'chat_preview_voice'.tr;
      case ChatMsgType.product:
        return productTitle ?? 'chat_preview_product'.tr;
      case ChatMsgType.location:
        return locationLabel ?? 'chat_preview_location'.tr;
      case ChatMsgType.file:
        return fileName ?? 'chat_preview_file'.tr;
      case ChatMsgType.contact:
        return contactName ?? 'chat_preview_contact'.tr;
      case ChatMsgType.invoice:
        return cardTitle ?? 'chat_preview_invoice'.tr;
      case ChatMsgType.catalog:
        return cardTitle ?? 'chat_preview_catalog'.tr;
      case ChatMsgType.businessCard:
        return cardTitle ?? 'chat_preview_business_card'.tr;
      case ChatMsgType.offer:
        final p = offerProduct ?? '';
        final price = [
          offerPrice ?? '',
          offerCurrency ?? '',
        ].where((e) => e.isNotEmpty).join(' ');
        if (p.isNotEmpty && price.isNotEmpty) return '$p · $price';
        if (p.isNotEmpty) return p;
        return 'chat_preview_offer'.tr;
      case ChatMsgType.rfq:
        final p = rfqProduct ?? '';
        final qty = [
          rfqQuantity ?? '',
          rfqUnit ?? '',
        ].where((e) => e.isNotEmpty).join(' ');
        if (p.isNotEmpty && qty.isNotEmpty) return '$p · $qty';
        if (p.isNotEmpty) return p;
        return 'chat_preview_rfq'.tr;
    }
  }

  factory ChatMessage.invoice({
    required String id,
    required ChatDir dir,
    required String time,
    required String title,
    required String amount,
    DateTime? createdAt,
    String? note,
    ChatStatus status = ChatStatus.read,
    int? senderId,
    String? senderName,
    String? senderAvatarUrl,
  }) =>
      ChatMessage(
        id: id,
        type: ChatMsgType.invoice,
        dir: dir,
        time: time,
        createdAt: createdAt,
        status: status,
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
        cardTitle: title,
        cardSubtitle: amount,
        cardDetail: note,
      );

  factory ChatMessage.catalog({
    required String id,
    required ChatDir dir,
    required String time,
    required String title,
    required String subtitle,
    DateTime? createdAt,
    String? detail,
    String? imageUrl,
    ChatStatus status = ChatStatus.read,
    int? senderId,
    String? senderName,
    String? senderAvatarUrl,
  }) =>
      ChatMessage(
        id: id,
        type: ChatMsgType.catalog,
        dir: dir,
        time: time,
        createdAt: createdAt,
        status: status,
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
        cardTitle: title,
        cardSubtitle: subtitle,
        cardDetail: detail,
        cardImageUrl: imageUrl,
      );

  factory ChatMessage.businessCard({
    required String id,
    required ChatDir dir,
    required String time,
    required String name,
    DateTime? createdAt,
    String? company,
    String? role,
    String? phone,
    String? imageUrl,
    int? userId,
    ChatStatus status = ChatStatus.read,
    int? senderId,
    String? senderName,
    String? senderAvatarUrl,
  }) =>
      ChatMessage(
        id: id,
        type: ChatMsgType.businessCard,
        dir: dir,
        time: time,
        createdAt: createdAt,
        status: status,
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
        cardTitle: name,
        cardSubtitle: company,
        cardDetail: [
          if (role != null && role.isNotEmpty) role,
          if (phone != null && phone.isNotEmpty) phone,
        ].join(' · '),
        cardImageUrl: imageUrl,
        cardUserId: userId,
      );

  factory ChatMessage.offer({
    required String id,
    required ChatDir dir,
    required String time,
    required String product,
    required String price,
    DateTime? createdAt,
    String? currency,
    String? delivery,
    String? moq,
    String? payment,
    String status = 'offered',
    int? productId,
    ChatStatus chatStatus = ChatStatus.read,
    int? senderId,
    String? senderName,
    String? senderAvatarUrl,
  }) =>
      ChatMessage(
        id: id,
        type: ChatMsgType.offer,
        dir: dir,
        time: time,
        createdAt: createdAt,
        status: chatStatus,
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
        productId: productId,
        offerProduct: product,
        offerPrice: price,
        offerCurrency: currency,
        offerDelivery: delivery,
        offerMoq: moq,
        offerPayment: payment,
        offerStatus: status,
      );

  factory ChatMessage.rfq({
    required String id,
    required ChatDir dir,
    required String time,
    required String product,
    required String quantity,
    DateTime? createdAt,
    String? unit,
    String? specs,
    String? deadline,
    ChatStatus chatStatus = ChatStatus.read,
    int? senderId,
    String? senderName,
    String? senderAvatarUrl,
    ChatReply? reply,
  }) =>
      ChatMessage(
        id: id,
        type: ChatMsgType.rfq,
        dir: dir,
        time: time,
        createdAt: createdAt,
        status: chatStatus,
        reply: reply,
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
        rfqProduct: product,
        rfqQuantity: quantity,
        rfqUnit: unit,
        rfqSpecs: specs,
        rfqDeadline: deadline,
      );
}

/// Noma'lum yuboruvchi haqidagi qisqa biznes kartochka.
class AutoBusinessCard {
  final int userId;
  final String companyName;
  final String? country;
  final bool verified;
  final double? rating;
  final int productsCount;
  final bool isBusiness;
  final String? avatarUrl;

  const AutoBusinessCard({
    required this.userId,
    required this.companyName,
    this.country,
    this.verified = false,
    this.rating,
    this.productsCount = 0,
    this.isBusiness = false,
    this.avatarUrl,
  });

  factory AutoBusinessCard.fromApi(Map<String, dynamic> json) {
    return AutoBusinessCard(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      companyName: json['company_name']?.toString() ?? '',
      country: json['country']?.toString(),
      verified: json['verified'] == true,
      rating: (json['rating'] as num?)?.toDouble(),
      productsCount: (json['products_count'] as num?)?.toInt() ?? 0,
      isBusiness: json['is_business'] == true,
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}
