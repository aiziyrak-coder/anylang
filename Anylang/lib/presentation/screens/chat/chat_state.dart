import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/theme/gradients.dart';
import 'chat_message.dart';

class ChatState extends GetxController {
  // Suhbatdosh ma'lumoti — Screen.initState'da payload'dan beriladi
  String peerName = '';
  String peerInitial = '';
  LinearGradient peerAvatar = avatarTealGradient;
  final RxBool peerOnline = false.obs;
  final RxBool peerTyping = false.obs;
  int chatId = 0;
  int peerId = 0;

  /// Suhbat xabarlari (eng eskisi tepada, eng yangisi pastda).
  final RxList<ChatMessage> messages = <ChatMessage>[].obs;

  /// Input maydonidagi joriy matn (bo'sh bo'lsa mic, aks holda yuborish).
  final RxString input = ''.obs;

  /// Javob berilayotgan xabar (reply rejimi). null bo'lsa — oddiy rejim.
  final Rx<ChatMessage?> replyTo = Rx<ChatMessage?>(null);

  /// Ovoz yozish holati (composer record ko'rinishiga o'tadi).
  final RxBool recording = false.obs;
  final RxBool loading = true.obs;

  /// Matn yuborilmoqda — dubl yuborishni oldini oladi.
  final RxBool sending = false.obs;

  /// Chat ichida qidiruv (Telegram uslubi).
  final RxBool searching = false.obs;
  final RxString searchQuery = ''.obs;

  /// Shu suhbat uchun bildirishnoma o‘chirilganmi.
  final RxBool muted = false.obs;
}
