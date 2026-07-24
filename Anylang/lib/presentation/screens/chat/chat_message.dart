import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Xabar yo'nalishi: kiruvchi (suhbatdosh) yoki chiquvchi (men).
enum ChatDir { incoming, outgoing }

/// Chiquvchi xabar yetkazilish holati (kiruvchida ishlatilmaydi).
enum ChatStatus { sent, delivered, read }

/// Xabar turi.
enum ChatMsgType { text, image, voice, product, location, file, contact }

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

  // image
  final LinearGradient? imageGradient;
  final String? imageUrl;

  // voice
  final String? voiceDuration; // "0:21"
  final bool voiceDownloaded; // play (true) yoki download (false) holati
  final String? voicePath; // lokal fayl yoki remote URL
  final List<double> voiceSamples; // waveform amplitude 0..1
  final int? voiceDurationMs;

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

  /// Tahrirlangan vaqt (API edited_at).
  final DateTime? editedAt;
  /// [{emoji, count, mine}]
  final List<Map<String, dynamic>> reactions;
  final bool pinned;

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
    this.imageGradient,
    this.imageUrl,
    this.voiceDuration,
    this.voiceDownloaded = true,
    this.voicePath,
    this.voiceSamples = const [],
    this.voiceDurationMs,
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
    this.editedAt,
    this.reactions = const [],
    this.pinned = false,
  });

  bool get isOutgoing => dir == ChatDir.outgoing;

  /// Bubble'da ko'rsatiladigan matn (tarjima / asl toggle).
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

  ChatMessage _copy({
    ChatStatus? status,
    bool? showingOriginal,
    int? senderId,
    String? senderName,
    String? senderAvatarUrl,
    String? text,
    String? textOriginal,
    DateTime? editedAt,
    List<Map<String, dynamic>>? reactions,
    bool? pinned,
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
        imageGradient: imageGradient,
        imageUrl: imageUrl,
        voiceDuration: voiceDuration,
        voiceDownloaded: voiceDownloaded,
        voicePath: voicePath,
        voiceSamples: voiceSamples,
        voiceDurationMs: voiceDurationMs,
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
        editedAt: editedAt ?? this.editedAt,
        reactions: reactions ?? this.reactions,
        pinned: pinned ?? this.pinned,
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
  }) =>
      _copy(
        editedAt: editedAt,
        reactions: reactions,
        pinned: pinned,
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
    }
  }
}
