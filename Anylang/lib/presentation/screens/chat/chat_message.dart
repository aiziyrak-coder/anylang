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

  const ChatMessage({
    required this.id,
    required this.type,
    required this.dir,
    required this.time,
    this.createdAt,
    this.status = ChatStatus.read,
    this.reply,
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

  ChatMessage withToggleOriginal() => ChatMessage(
        id: id,
        type: type,
        dir: dir,
        time: time,
        createdAt: createdAt,
        status: status,
        reply: reply,
        text: text,
        textOriginal: textOriginal,
        showingOriginal: !showingOriginal,
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
      );

  ChatMessage withStatus(ChatStatus status) => ChatMessage(
        id: id,
        type: type,
        dir: dir,
        time: time,
        createdAt: createdAt,
        status: status,
        reply: reply,
        text: text,
        textOriginal: textOriginal,
        showingOriginal: showingOriginal,
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
  }) =>
      ChatMessage(
        id: id,
        type: ChatMsgType.text,
        dir: dir,
        time: time,
        createdAt: createdAt,
        status: status,
        reply: reply,
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
  }) =>
      ChatMessage(
        id: id,
        type: ChatMsgType.image,
        dir: dir,
        time: time,
        createdAt: createdAt,
        status: status,
        reply: reply,
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
  }) =>
      ChatMessage(
        id: id,
        type: ChatMsgType.voice,
        dir: dir,
        time: time,
        createdAt: createdAt,
        status: status,
        reply: reply,
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
  }) =>
      ChatMessage(
        id: id,
        type: ChatMsgType.product,
        dir: dir,
        time: time,
        createdAt: createdAt,
        status: status,
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
  }) =>
      ChatMessage(
        id: id,
        type: ChatMsgType.location,
        dir: dir,
        time: time,
        createdAt: createdAt,
        status: status,
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
  }) =>
      ChatMessage(
        id: id,
        type: ChatMsgType.file,
        dir: dir,
        time: time,
        createdAt: createdAt,
        status: status,
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
  }) =>
      ChatMessage(
        id: id,
        type: ChatMsgType.contact,
        dir: dir,
        time: time,
        createdAt: createdAt,
        status: status,
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
