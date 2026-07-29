import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/audio/voice_player_service.dart';
import '../../../data/network/invite_deep_link_service.dart';
import '../../modal/full_screen_image_dialog.dart';
import '../../modal/product_video_dialog.dart';
import '../../screens/chat/chat_message.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/business_reactions.dart';
import '../../utils/size_controller.dart';
import '../chat_auto_business_card.dart';
import '../chat_video_thumbnail.dart';
import '../profile_avatar.dart';
import '../theme/colors.dart';
import '../theme/gradients.dart';
import '../transcript_shimmer.dart';
import '../waveform_bars.dart';
import '../../../data/core/mappers.dart';

/// Chat ichidagi rasm bubble kengligi (balandlik aspect ratio bo'yicha).
const double _kChatImageWidth = 220;

/// Suhbatdagi bitta xabar (ListView elementi). Turiga qarab mos ko'rinishni
/// chizadi: matn, rasm, ovoz, mahsulot, joylashuv, fayl, kontakt. Reply
/// sitatasi va (chiquvchi uchun) o'qildi belgisini ham ko'rsatadi. Uzoq bosish
/// kontekst menyusini ochadi (`onLongPress`).
class ChatMessageItem extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;
  final ValueChanged<String>? onReplyTap;
  final VoidCallback? onProductTap;
  /// Guruh — yuboruvchi avatar/ismiga bosilganda.
  final VoidCallback? onSenderTap;
  /// Guruh chat — Telegram uslubi (avatar + ism).
  final bool isGroup;
  /// Bir xil jo'natuvchi ketma-ketligida faqat birinchida ism.
  final bool showSenderName;
  /// Ketma-ketlikning oxirgi xabarida avatar (past chap).
  final bool showAvatar;
  /// Multi-select rejimi.
  final bool selecting;
  final bool selected;
  /// Chat ichidagi qidiruv — joriy topilma.
  final bool searchHighlight;
  /// Guruh invite linki ostidagi "Qo'shilish" tugmasi.
  final ValueChanged<String>? onJoinGroupInvite;
  /// Kontakt kartasi: Xabar / Qo‘shish.
  final VoidCallback? onContactMessage;
  final VoidCallback? onContactAdd;
  /// Narx taklifi: qabul / qarshi.
  final VoidCallback? onAcceptOffer;
  final VoidCallback? onCounterOffer;
  /// Marketplace RFQ: taklif yuborish.
  final VoidCallback? onReplyToRfq;
  /// Auto Business Card — ketma-ketlikning birinchi xabarida.
  final bool showAutoBusinessCard;

  const ChatMessageItem({
    super.key,
    required this.message,
    required this.onLongPress,
    this.onTap,
    this.onReplyTap,
    this.onProductTap,
    this.onSenderTap,
    this.isGroup = false,
    this.showSenderName = false,
    this.showAvatar = false,
    this.selecting = false,
    this.selected = false,
    this.searchHighlight = false,
    this.onJoinGroupInvite,
    this.onContactMessage,
    this.onContactAdd,
    this.onAcceptOffer,
    this.onCounterOffer,
    this.onReplyToRfq,
    this.showAutoBusinessCard = false,
  });

  bool get _out => message.isOutgoing;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final maxW = SizeController.screenWidth * (isGroup && !_out ? 0.72 : 0.76);

    Widget bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Column(
        crossAxisAlignment:
            _out ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          _body(context, c),
          if (message.reactions.isNotEmpty) ...[
            SizedBox(height: 4.dp),
            Wrap(
              spacing: 4.dp,
              runSpacing: 4.dp,
              children: [
                for (final r in message.reactions)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.dp, vertical: 3.dp),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(12.dp),
                      border: Border.all(
                        color: (r['me'] == true)
                            ? c.accent
                            : c.outline.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      reactionDisplayText(
                        '${r['emoji'] ?? ''}',
                        count: r['count'],
                      ),
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (message.editedAt != null)
            Padding(
              padding: EdgeInsets.only(top: 2.dp),
              child: Text(
                'chat_edited'.tr,
                style: TextStyle(fontSize: 10.sp, color: c.textFaint),
              ),
            ),
        ],
      ),
    );

    if (isGroup && !_out) {
      const avatarSize = 32.0;
      bubble = Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: avatarSize.dp,
            height: avatarSize.dp,
            child: showAvatar
                ? GestureDetector(
                    onTap: onSenderTap,
                    behavior: HitTestBehavior.opaque,
                    child: ProfileAvatar(
                      initial: initialsOf(message.senderName ?? '?'),
                      gradient: avatarGradientFor(message.senderId ?? 0),
                      imageUrl: message.senderAvatarUrl,
                      size: avatarSize,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          SizedBox(width: 6.dp),
          Flexible(child: bubble),
        ],
      );
    }

    final mark = selecting ? _selectMark(c) : null;
    final aligned = selecting
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _out
                ? [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: bubble,
                      ),
                    ),
                    mark!,
                  ]
                : [
                    mark!,
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: bubble,
                      ),
                    ),
                  ],
          )
        : Align(
            alignment: _out ? Alignment.centerRight : Alignment.centerLeft,
            child: bubble,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showAutoBusinessCard &&
            !_out &&
            message.autoBusinessCard != null) ...[
          Padding(
            padding: EdgeInsets.only(
              left: selecting ? 10.dp : 0,
              right: selecting ? 10.dp : 0,
              bottom: 6.dp,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW + (isGroup ? 40.dp : 0)),
                child: ChatAutoBusinessCard(
                  card: message.autoBusinessCard!,
                  onTap: onSenderTap,
                ),
              ),
            ),
          ),
        ],
        Material(
          color: selected
              ? c.accent.withValues(alpha: 0.14)
              : (searchHighlight
                  ? c.accent.withValues(alpha: 0.18)
                  : Colors.transparent),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: selecting ? onTap : null,
            onLongPress: onLongPress,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: selecting ? 10.dp : 0,
                vertical: 4.dp,
              ),
              child: aligned,
            ),
          ),
        ),
      ],
    );
  }

  Widget _selectMark(AppColors c) {
    return Padding(
      padding: EdgeInsets.only(
        left: _out ? 8.dp : 4.dp,
        right: _out ? 4.dp : 8.dp,
        bottom: 6.dp,
      ),
      child: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        size: 22.dp,
        color: selected ? c.accent : c.textFaint.withValues(alpha: 0.9),
      ),
    );
  }

  Widget _body(BuildContext context, AppColors c) {
    switch (message.type) {
      case ChatMsgType.text:
        return _text(context, c);
      case ChatMsgType.image:
        return _image(context, c);
      case ChatMsgType.video:
        return _video(context, c);
      case ChatMsgType.voice:
        return _voice(c);
      case ChatMsgType.product:
        return _product(c);
      case ChatMsgType.location:
        return _location(c);
      case ChatMsgType.file:
        return _file(c);
      case ChatMsgType.contact:
        return _contact(c);
      case ChatMsgType.invoice:
      case ChatMsgType.catalog:
      case ChatMsgType.businessCard:
        return _tradeCard(c);
      case ChatMsgType.offer:
        return _offerCard(c);
      case ChatMsgType.rfq:
        return _rfqCard(c);
    }
  }

  // ---------------------------------------------------------------------------
  // Umumiy qobiq (bubble) + yordamchilar
  // ---------------------------------------------------------------------------

  BorderRadius get _bubbleRadius => BorderRadius.only(
        topLeft: Radius.circular(18.dp),
        topRight: Radius.circular(18.dp),
        bottomLeft: Radius.circular(_out ? 18.dp : 5.dp),
        bottomRight: Radius.circular(_out ? 5.dp : 18.dp),
      );

  Widget _bubble(AppColors c, Widget child) {
    final radius = _bubbleRadius;
    final name = message.senderName?.trim();
    final showName = showSenderName && !_out && name != null && name.isNotEmpty;
    final nameColor = avatarGradientFor(message.senderId ?? 0).colors.first;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: _out
                ? const Color(0x330B1F36)
                : (c.isDark
                    ? const Color(0x66000000)
                    : const Color(0x140B1F36)),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 10.dp),
          decoration: BoxDecoration(
            color: _out
                ? c.accent
                : (c.isDark
                    ? const Color(0xF21A3148)
                    : const Color(0xFFFFFFFF)),
            borderRadius: radius,
            border: _out
                ? null
                : Border.all(
                    color: c.isDark
                        ? const Color(0x33FFFFFF)
                        : const Color(0x22071526),
                    width: 0.7,
                  ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showName) ...[
                GestureDetector(
                  onTap: onSenderTap,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: nameColor,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ),
                SizedBox(height: 4.dp),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }

  Color _primaryText(AppColors c) =>
      _out ? c.onAccent : c.textPrimary;

  Color _metaColor(AppColors c) =>
      _out ? c.onAccent.withValues(alpha: 0.65) : c.textSecondary;

  /// Vaqt + (chiquvchi uchun) o'qildi belgisi.
  Widget _meta(AppColors c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message.time,
          style: TextStyle(color: _metaColor(c), fontSize: 11.sp),
        ),
        if (_out) ...[
          SizedBox(width: 4.dp),
          Icon(
            switch (message.status) {
              ChatStatus.pending => Icons.access_time_rounded,
              ChatStatus.read => Icons.done_all_rounded,
              ChatStatus.delivered || ChatStatus.sent => Icons.done_rounded,
            },
            size: 14.dp,
            color: message.status == ChatStatus.pending
                ? c.onAccent.withValues(alpha: 0.55)
                : c.onAccent.withValues(alpha: 0.7),
          ),
        ],
      ],
    );
  }

  /// Reply (javob) sitatasi — chap akssent chizig'i + jo'natuvchi + snippet.
  /// Chiquvchi bubble'da Telegram uslubi: to'qroq akssent (accentText) lime ustida.
  Widget _replyQuote(AppColors c, ChatReply r) {
    final barColor = _out ? c.accentText : c.accent;
    final nameColor = _out ? c.accentText : c.accentText;
    final prevColor =
        _out ? c.onAccent.withValues(alpha: 0.72) : c.textFaint;
    final bg = _out ? c.onAccent.withValues(alpha: 0.10) : c.accentSoft;

    final quote = Container(
      margin: EdgeInsets.only(bottom: 6.dp),
      padding: EdgeInsets.symmetric(horizontal: 8.dp, vertical: 6.dp),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8.dp),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3.dp,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(2.dp),
              ),
            ),
            SizedBox(width: 8.dp),
            // Flexible emas — aks holda bubble maxWidth gacha cho'ziladi.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: SizeController.screenWidth * 0.55),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: nameColor,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.dp),
                  Text(
                    r.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: prevColor, fontSize: 12.sp),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final targetId = r.messageId;
    if (targetId == null || onReplyTap == null) return quote;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onReplyTap!(targetId),
      child: quote,
    );
  }

  Widget _iconTile(AppColors c, {required Widget child}) {
    return Container(
      width: 44.dp,
      height: 44.dp,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(12.dp),
      ),
      child: child,
    );
  }

  // ---------------------------------------------------------------------------
  // Turlar
  // ---------------------------------------------------------------------------

  Widget _text(BuildContext context, AppColors c) {
    final rawForToken =
        '${message.displayText}\n${message.textOriginal ?? ''}';
    final inviteToken = InviteDeepLinkService.tokenFromText(rawForToken);
    final showJoin = inviteToken != null &&
        inviteToken.isNotEmpty &&
        onJoinGroupInvite != null;
    final bodyText = message.displayText.isEmpty ? '—' : message.displayText;

    // Default: faqat tarjima (displayText). Asl matn — long-press menyu
    // orqali showingOriginal (tegilmaydi). IntrinsicWidth: qisqa matn
    // bubble'ni kontentga qisqartiradi; tashqi maxWidth (~76%) chegara.
    return _bubble(
      c,
      IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (message.reply != null) _replyQuote(c, message.reply!),
            if (message.isAiFaq) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.dp, vertical: 3.dp),
                margin: EdgeInsets.only(bottom: 6.dp),
                decoration: BoxDecoration(
                  color: _out
                      ? c.onAccent.withValues(alpha: 0.14)
                      : c.accentSoft,
                  borderRadius: BorderRadius.circular(8.dp),
                ),
                child: Text(
                  'chat_ai_faq_badge'.tr,
                  style: TextStyle(
                    color: _out ? c.onAccent : c.accent,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
            _InviteAwareText(
              text: bodyText,
              baseStyle: TextStyle(
                color: _primaryText(c),
                fontSize: 15.sp,
                fontWeight: _out ? FontWeight.w600 : FontWeight.w400,
                height: 1.3,
              ),
              linkColor: _out ? c.onAccent : c.accentText,
              onInviteTap: onJoinGroupInvite,
            ),
            if (showJoin) ...[
              SizedBox(height: 10.dp),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onJoinGroupInvite!(inviteToken),
                  borderRadius: BorderRadius.circular(12.dp),
                  child: Ink(
                    padding: EdgeInsets.symmetric(vertical: 10.dp, horizontal: 12.dp),
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12.dp),
                      border: Border.all(color: c.accent.withValues(alpha: 0.55)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_add_rounded, size: 18.dp, color: c.accentText),
                        SizedBox(width: 8.dp),
                        Text(
                          'group_join_button'.tr,
                          style: TextStyle(
                            color: c.accentText,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            SizedBox(height: 4.dp),
            Align(alignment: Alignment.centerRight, child: _meta(c)),
          ],
        ),
      ),
    );
  }

  Widget _image(BuildContext context, AppColors c) {
    final url = message.imageUrl;
    final isNet = url != null &&
        (url.startsWith('http://') || url.startsWith('https://'));
    final isFile = url != null && url.isNotEmpty && !isNet;
    final width = _kChatImageWidth.dp;

    Widget media;
    if (isNet) {
      media = _ChatAdaptiveImage(
        width: width,
        gradient: message.imageGradient ?? prodTealGradient,
        imageProvider: NetworkImage(url),
        builder: (provider, fit) => Image(
          image: provider,
          width: width,
          fit: fit,
          gaplessPlayback: true,
        ),
      );
    } else if (isFile) {
      media = _ChatAdaptiveImage(
        width: width,
        gradient: message.imageGradient ?? prodTealGradient,
        imageProvider: FileImage(File(url)),
        builder: (provider, fit) => Image(
          image: provider,
          width: width,
          fit: fit,
          gaplessPlayback: true,
        ),
      );
    } else {
      media = Container(
        width: width,
        height: 150.dp,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: message.imageGradient ?? prodTealGradient,
        ),
        child: Icon(
          Icons.image_outlined,
          size: 36.dp,
          color: c.onAccent.withValues(alpha: 0.35),
        ),
      );
    }

    final openable = isNet || isFile;
    final name = message.senderName?.trim();
    final showName = showSenderName && !_out && name != null && name.isNotEmpty;
    final nameColor = avatarGradientFor(message.senderId ?? 0).colors.first;

    Widget imageBubble = ClipRRect(
      borderRadius: _bubbleRadius,
      child: Stack(
        children: [
          media,
          if (openable)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => showFullScreenImage(context, url: url),
                ),
              ),
            ),
          Positioned(
            right: 8.dp,
            bottom: 8.dp,
            child: IgnorePointer(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.dp, vertical: 3.dp),
                decoration: BoxDecoration(
                  color: kNavy.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10.dp),
                ),
                child: _meta(
                  c.copyWith(onAccent: kAvatarFg, textFaint: kAvatarFg),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (!showName && message.reply == null) return imageBubble;
    return Column(
      crossAxisAlignment:
          _out ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.reply != null)
          Padding(
            padding: EdgeInsets.only(bottom: 6.dp),
            child: _replyQuote(c, message.reply!),
          ),
        if (showName)
          Padding(
            padding: EdgeInsets.only(left: 4.dp, bottom: 4.dp),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: nameColor,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        imageBubble,
      ],
    );
  }

  Widget _video(BuildContext context, AppColors c) {
    final url = message.videoUrl;
    final isNet = url != null &&
        (url.startsWith('http://') || url.startsWith('https://'));
    final isFile = url != null && url.isNotEmpty && !isNet;
    final openable = isNet || isFile;
    final round = message.isRoundNote;
    final size = round ? 180.dp : _kChatImageWidth.dp;
    final height = round ? size : 160.dp;
    final metaColor = _out
        ? c.onAccent.withValues(alpha: 0.85)
        : c.textFaint;

    Future<void> open() async {
      final path = url;
      if (!openable || path == null || path.isEmpty) return;
      await showProductVideoDialog(context, url: path, maxPlay: null);
    }

    final thumb = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: openable ? open : null,
        customBorder: round ? const CircleBorder() : null,
        borderRadius: round ? null : _bubbleRadius,
        child: Container(
          width: size,
          height: height,
          decoration: BoxDecoration(
            color: c.isDark ? const Color(0xFF12263A) : const Color(0xFFE8EEF5),
            shape: round ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: round ? null : _bubbleRadius,
            border: round
                ? Border.all(color: c.accent.withValues(alpha: 0.55), width: 3)
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url != null && url.isNotEmpty)
                ChatVideoThumbnail(
                  url: url,
                  width: size,
                  height: height,
                  round: round,
                ),
              // O‘qish uchun engil qoraytirish + play.
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.18),
              ),
              Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  size: round ? 56.dp : 48.dp,
                  color: Colors.white.withValues(alpha: 0.95),
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              if ((message.videoDuration ?? '').isNotEmpty)
                Positioned(
                  left: round ? null : 10.dp,
                  bottom: round ? 14.dp : 10.dp,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.dp,
                      vertical: 3.dp,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(10.dp),
                    ),
                    child: Text(
                      message.videoDuration!,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: round ? 14.dp : 8.dp,
                bottom: round ? 14.dp : 8.dp,
                child: _meta(
                  c.copyWith(onAccent: kAvatarFg, textFaint: kAvatarFg),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final caption = message.displayText.trim();
    final showCaption = caption.isNotEmpty ||
        message.transcriptPending ||
        message.transcriptFailed;

    return Column(
      crossAxisAlignment:
          _out ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.reply != null)
          Padding(
            padding: EdgeInsets.only(bottom: 6.dp),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: size),
              child: _replyQuote(c, message.reply!),
            ),
          ),
        thumb,
        if (showCaption)
          Padding(
            padding: EdgeInsets.only(top: 6.dp),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: size),
              child: _bubble(
                c,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (caption.isNotEmpty)
                      Text(
                        caption,
                        style: TextStyle(
                          color: _out ? c.onAccent : c.textPrimary,
                          fontSize: 14.sp,
                          height: 1.35,
                        ),
                      ),
                    _VoiceTranscriptSection(
                      message: message,
                      outgoing: _out,
                      metaColor: metaColor,
                      primaryText: _out ? c.onAccent : c.textPrimary,
                      colors: c,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _voice(AppColors c) {
    final player = Get.find<VoicePlayerService>();
    final waveColor = _out ? c.onAccent.withValues(alpha: 0.55) : c.textFaint;
    final inactive = _out
        ? c.onAccent.withValues(alpha: 0.28)
        : c.textFaint.withValues(alpha: 0.45);
    final path = message.voicePath;
    final canPlay = VoicePlayerService.canPlay(path);
    final duration = Duration(milliseconds: message.voiceDurationMs ?? 0);
    // Shimmer / matn cardni kengaytirsa — waveform + time ham shu kenglikka cho'ziladi.
    final expandToTranscript = message.transcriptFailed ||
        (message.transcriptPending && message.displayText.trim().isEmpty) ||
        message.displayText.trim().isNotEmpty;
    final transcriptMaxW = SizeController.screenWidth * 0.62;

    return _bubble(
      c,
      Obx(() {
        final active = player.activeId.value == message.id;
        final playing = active && player.isPlaying.value;

        Widget wave(double p, int barCount) => WaveformBars(
              color: waveColor,
              inactiveColor: inactive,
              maxHeight: 20,
              barCount: barCount,
              samples: message.voiceSamples,
              progress: p,
            );

        Widget waveMeta({required bool expand}) {
          final waveChild = LayoutBuilder(
            builder: (context, constraints) {
              final avail = constraints.maxWidth;
              final barW = 2.5.dp;
              final gap = 3.dp;
              final barCount = expand
                  ? ((avail + gap) / (barW + gap)).floor().clamp(18, 56)
                  : 22;

              void seek(Offset local) {
                if (!canPlay || path == null) return;
                final frac =
                    (local.dx / constraints.maxWidth).clamp(0.0, 1.0);
                player.seek(
                  id: message.id,
                  path: path,
                  duration: duration.inMilliseconds > 0
                      ? duration
                      : const Duration(seconds: 1),
                  frac: frac,
                  samples: message.voiceSamples,
                  barCount: barCount,
                );
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => seek(d.localPosition),
                onHorizontalDragUpdate: (d) => seek(d.localPosition),
                child: active
                    ? ValueListenableBuilder<double>(
                        valueListenable: player.progress,
                        builder: (_, p, _) => wave(p, barCount),
                      )
                    : wave(player.restingProgress(message.id), barCount),
              );
            },
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: expand ? null : 150.dp,
                height: 20.dp,
                child: waveChild,
              ),
              SizedBox(height: 6.dp),
              Row(
                children: [
                  Text(
                    message.voiceDuration ?? '',
                    style: TextStyle(
                      color: _out ? c.onAccent : c.textSecondary,
                      fontSize: 11.sp,
                    ),
                  ),
                  const Spacer(),
                  _meta(c),
                ],
              ),
            ],
          );
        }

        final playBtn = GestureDetector(
          onTap: () {
            if (!canPlay || path == null) {
              showAppMessage('chat_voice_unavailable'.tr);
              return;
            }
            HapticFeedback.selectionClick();
            player.toggle(
              id: message.id,
              path: path,
              duration: duration.inMilliseconds > 0
                  ? duration
                  : const Duration(seconds: 1),
              samples: message.voiceSamples,
              barCount: expandToTranscript ? 36 : 22,
            );
          },
          child: Container(
            width: 40.dp,
            height: 40.dp,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _out ? c.onAccent.withValues(alpha: 0.18) : c.accent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              !canPlay
                  ? Icons.file_download_outlined
                  : (playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
              size: 20.dp,
              color: c.onAccent,
            ),
          ),
        );

        final voiceRow = Row(
          mainAxisSize: expandToTranscript ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            playBtn,
            SizedBox(width: 10.dp),
            if (expandToTranscript)
              Expanded(child: waveMeta(expand: true))
            else
              SizedBox(width: 150.dp, child: waveMeta(expand: false)),
          ],
        );

        Widget column = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: expandToTranscript
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
          children: [
            if (message.reply != null) _replyQuote(c, message.reply!),
            voiceRow,
            _VoiceTranscriptSection(
              message: message,
              outgoing: _out,
              metaColor: _metaColor(c),
              primaryText: _primaryText(c),
              colors: c,
            ),
          ],
        );

        // Transcript/shimmer kengligiga voice qatorini bog'lash (Expanded ishlashi uchun).
        if (expandToTranscript) {
          column = SizedBox(width: transcriptMaxW, child: column);
        }

        return column;
      }),
    );
  }

  Widget _product(AppColors c) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: _bubbleRadius,
        onTap: onProductTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onProductTap!();
              },
        child: Ink(
          padding: EdgeInsets.all(12.dp),
          decoration: BoxDecoration(
            color: c.accentSoft,
            border: Border.all(color: c.accent.withValues(alpha: 0.3)),
            borderRadius: _bubbleRadius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.reply != null) _replyQuote(c, message.reply!),
              Text(
                'chat_product_label'.tr,
                style: TextStyle(
                  color: c.accentText,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 6.dp),
              Text(
                message.productTitle ?? '',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2.dp),
              Text(
                message.productPrice ?? '',
                style: TextStyle(
                  color: c.accentText,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8.dp),
              Text(
                'chat_product_view'.tr,
                style: TextStyle(
                  color: c.accentText,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 6.dp),
              Align(alignment: Alignment.centerRight, child: _meta(c)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tradeCard(AppColors c) {
    final label = switch (message.type) {
      ChatMsgType.invoice => 'chat_invoice_label'.tr,
      ChatMsgType.catalog => 'chat_catalog_label'.tr,
      _ => 'chat_business_card_label'.tr,
    };
    final icon = switch (message.type) {
      ChatMsgType.invoice => Icons.receipt_long_rounded,
      ChatMsgType.catalog => Icons.menu_book_rounded,
      _ => Icons.badge_outlined,
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: _bubbleRadius,
        onTap: onProductTap,
        child: Ink(
          padding: EdgeInsets.all(12.dp),
          decoration: BoxDecoration(
            color: c.accentSoft,
            border: Border.all(color: c.accent.withValues(alpha: 0.3)),
            borderRadius: _bubbleRadius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16.dp, color: c.accentText),
                  SizedBox(width: 6.dp),
                  Text(
                    label,
                    style: TextStyle(
                      color: c.accentText,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.dp),
              Text(
                message.cardTitle ?? '',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if ((message.cardSubtitle ?? '').isNotEmpty) ...[
                SizedBox(height: 4.dp),
                Text(
                  message.cardSubtitle!,
                  style: TextStyle(
                    color: c.accentText,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if ((message.cardDetail ?? '').isNotEmpty) ...[
                SizedBox(height: 4.dp),
                Text(
                  message.cardDetail!,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12.sp,
                    height: 1.3,
                  ),
                ),
              ],
              SizedBox(height: 6.dp),
              Align(alignment: Alignment.centerRight, child: _meta(c)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _offerCard(AppColors c) {
    final status = (message.offerStatus ?? 'offered').toLowerCase();
    final statusLabel = switch (status) {
      'accepted' => 'chat_offer_status_accepted'.tr,
      'countered' => 'chat_offer_status_countered'.tr,
      _ => 'chat_offer_label'.tr,
    };
    final statusColor = switch (status) {
      'accepted' => c.accent,
      'countered' => c.textSecondary,
      _ => c.accentText,
    };
    final price = [
      message.offerPrice ?? '',
      message.offerCurrency ?? '',
    ].where((e) => e.isNotEmpty).join(' ');
    final showActions = !_out &&
        !selecting &&
        (status == 'offered' || status == 'countered') &&
        (onAcceptOffer != null || onCounterOffer != null);

    Widget row(String emoji, String label, String value) {
      if (value.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(bottom: 6.dp),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22.dp,
              child: Text(emoji, style: TextStyle(fontSize: 13.sp)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: c.textFaint,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Ink(
        padding: EdgeInsets.all(12.dp),
        decoration: BoxDecoration(
          color: c.accentSoft,
          border: Border.all(color: c.accent.withValues(alpha: 0.35)),
          borderRadius: _bubbleRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.handshake_outlined, size: 16.dp, color: statusColor),
                SizedBox(width: 6.dp),
                Expanded(
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.dp),
            row('📦', 'chat_offer_product'.tr, message.offerProduct ?? ''),
            row('💵', 'chat_offer_price'.tr, price),
            row('📅', 'chat_offer_delivery'.tr, message.offerDelivery ?? ''),
            row('🔢', 'chat_offer_moq'.tr, message.offerMoq ?? ''),
            row('💳', 'chat_offer_payment'.tr, message.offerPayment ?? ''),
            if (showActions) ...[
              SizedBox(height: 4.dp),
              Row(
                children: [
                  if (onAcceptOffer != null)
                    Expanded(
                      child: _offerActionBtn(
                        c,
                        label: 'chat_offer_accept'.tr,
                        filled: true,
                        onTap: onAcceptOffer!,
                      ),
                    ),
                  if (onAcceptOffer != null && onCounterOffer != null)
                    SizedBox(width: 8.dp),
                  if (onCounterOffer != null)
                    Expanded(
                      child: _offerActionBtn(
                        c,
                        label: 'chat_offer_counter'.tr,
                        filled: false,
                        onTap: onCounterOffer!,
                      ),
                    ),
                ],
              ),
            ],
            SizedBox(height: 6.dp),
            Align(alignment: Alignment.centerRight, child: _meta(c)),
          ],
        ),
      ),
    );
  }

  Widget _rfqCard(AppColors c) {
    final qty = [
      message.rfqQuantity ?? '',
      message.rfqUnit ?? '',
    ].where((e) => e.isNotEmpty).join(' ');
    final showOffer = !_out && !selecting && onReplyToRfq != null;

    Widget row(String emoji, String label, String value) {
      if (value.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(bottom: 6.dp),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22.dp,
              child: Text(emoji, style: TextStyle(fontSize: 13.sp)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: c.textFaint,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Ink(
        padding: EdgeInsets.all(12.dp),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.outline.withValues(alpha: 0.7)),
          borderRadius: _bubbleRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'chat_rfq_label'.tr,
              style: TextStyle(
                color: c.accent,
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            SizedBox(height: 8.dp),
            row('📦', 'chat_rfq_product'.tr, message.rfqProduct ?? ''),
            row('🔢', 'chat_rfq_quantity'.tr, qty),
            row('📝', 'chat_rfq_specs'.tr, message.rfqSpecs ?? ''),
            row('⏰', 'chat_rfq_deadline'.tr, message.rfqDeadline ?? ''),
            if (showOffer) ...[
              SizedBox(height: 8.dp),
              _offerActionBtn(
                c,
                label: 'chat_rfq_send_offer'.tr,
                filled: true,
                onTap: onReplyToRfq!,
              ),
            ],
            SizedBox(height: 6.dp),
            Align(alignment: Alignment.centerRight, child: _meta(c)),
          ],
        ),
      ),
    );
  }

  Widget _offerActionBtn(
    AppColors c, {
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    final radius = BorderRadius.circular(12.dp);
    return Material(
      color: filled ? c.accent : c.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: 9.dp),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: filled
                ? null
                : Border.all(color: c.outline.withValues(alpha: 0.6)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: filled ? c.onAccent : c.textPrimary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _location(AppColors c) {
    final lat = message.latitude;
    final lng = message.longitude;
    final hasCoords = lat != null && lng != null;
    // Telegram uslubi: katta xarita preview + markazda pin + past o'ngda vaqt.
    final mapUrl = hasCoords
        ? 'https://staticmap.openstreetmap.de/staticmap.php'
            '?center=$lat,$lng&zoom=16&size=640x360&maptype=mapnik'
            '&markers=$lat,$lng,lightblue1'
        : null;
    final title = (message.locationLabel?.trim().isNotEmpty == true)
        ? message.locationLabel!.trim()
        : 'chat_my_location'.tr;
    final showTitle = title != 'chat_my_location'.tr;

    final mapW = 220.dp;
    final mapH = 140.dp;

    return Column(
      crossAxisAlignment:
          _out ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.reply != null)
          Padding(
            padding: EdgeInsets.only(bottom: 6.dp),
            child: _replyQuote(c, message.reply!),
          ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: _bubbleRadius,
            onTap: () async {
              HapticFeedback.selectionClick();
              final uri = hasCoords
                  ? Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                    )
                  : Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(title)}',
                    );
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                showAppMessage('maps_open_failed'.tr);
              }
            },
            child: ClipRRect(
          borderRadius: _bubbleRadius,
          child: SizedBox(
            width: mapW,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: mapW,
                  height: mapH,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: c.isDark
                            ? const Color(0xFF1A3148)
                            : const Color(0xFFE8EEF4),
                      ),
                      if (mapUrl != null)
                        Image.network(
                          mapUrl,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => Center(
                            child: Icon(
                              Icons.map_rounded,
                              size: 36.dp,
                              color: c.textFaint,
                            ),
                          ),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: SizedBox(
                                width: 20.dp,
                                height: 20.dp,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: c.accent,
                                ),
                              ),
                            );
                          },
                        ),
                      // Telegram uslubidagi markaziy pin
                      Align(
                        alignment: const Alignment(0, -0.05),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 28.dp,
                              height: 28.dp,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.circle,
                                size: 12.dp,
                                color: const Color(0xFF3390EC),
                              ),
                            ),
                            CustomPaint(
                              size: Size(3.dp, 14.dp),
                              painter: _PinStemPainter(
                                color: const Color(0xFF3390EC),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 8.dp,
                        bottom: 6.dp,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 7.dp,
                            vertical: 3.dp,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(10.dp),
                          ),
                          child: _meta(
                            c.copyWith(
                              onAccent: Colors.white,
                              textSecondary: Colors.white70,
                              textFaint: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (showTitle)
                  Container(
                    color: _out
                        ? c.accent
                        : (c.isDark
                            ? const Color(0xF21A3148)
                            : const Color(0xFFFFFFFF)),
                    padding: EdgeInsets.fromLTRB(12.dp, 8.dp, 12.dp, 10.dp),
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _primaryText(c),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
        ),
      ],
    );
  }

  Widget _file(AppColors c) {
    return GestureDetector(
      onTap: () async {
        final url = message.fileUrl?.trim();
        if (url == null || url.isEmpty) {
          showAppMessage(
            message.status == ChatStatus.pending
                ? 'chat_file_pending'.tr
                : 'file_open_failed'.tr,
          );
          return;
        }
        HapticFeedback.selectionClick();
        final uri = Uri.tryParse(url);
        if (uri == null ||
            !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          showAppMessage('file_open_failed'.tr);
        }
      },
      child: _bubble(
        c,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.reply != null) _replyQuote(c, message.reply!),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _iconTile(
                  c,
                  child: Text(
                    message.fileExt ?? '',
                    style: TextStyle(
                      color: c.accentText,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: 12.dp),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.fileName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 3.dp),
                      Text(
                        '${message.fileSize ?? ''} · ${message.fileExt ?? ''}',
                        style: TextStyle(color: c.textFaint, fontSize: 12.sp),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.dp),
            Align(alignment: Alignment.centerRight, child: _meta(c)),
          ],
        ),
      ),
    );
  }

  Widget _contact(AppColors c) {
    final name = (message.contactName ?? '').trim().isEmpty
        ? 'chat_contact_fallback'.tr
        : message.contactName!.trim();
    final phone = (message.contactPhone ?? '').trim();
    final number = (message.contactNumber ?? '').trim();
    final subtitle = phone.isNotEmpty
        ? phone
        : (number.isNotEmpty ? '#$number' : 'chat_contact_fallback'.tr);
    final titleColor = _primaryText(c);
    final subColor = _metaColor(c);
    final actionColor = _out ? c.onAccent : c.accentText;
    final lineColor = _out
        ? c.onAccent.withValues(alpha: 0.28)
        : c.outline.withValues(alpha: 0.7);

    return _bubble(
      c,
      ConstrainedBox(
        constraints: BoxConstraints(minWidth: 210.dp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (message.reply != null) _replyQuote(c, message.reply!),
            Row(
              children: [
                ProfileAvatar(
                  initial: (message.contactInitial ?? initialsOf(name)),
                  gradient: avatarGradientFor(message.contactUserId ?? name.hashCode),
                  imageUrl: message.contactAvatarUrl,
                  size: 48,
                  shape: ProfileAvatarShape.circle,
                ),
                SizedBox(width: 12.dp),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3.dp),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subColor,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.dp),
            Divider(height: 1.dp, thickness: 1, color: lineColor),
            SizedBox(height: 2.dp),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onContactMessage,
                      borderRadius: BorderRadius.circular(8.dp),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 10.dp),
                        child: Text(
                          'chat_contact_message'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: actionColor,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(width: 1.dp, height: 28.dp, color: lineColor),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onContactAdd,
                      borderRadius: BorderRadius.circular(8.dp),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 10.dp),
                        child: Text(
                          'chat_contact_add'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: actionColor,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Align(alignment: Alignment.centerRight, child: _meta(c)),
          ],
        ),
      ),
    );
  }
}

class _ChatAdaptiveImage extends StatefulWidget {
  final double width;
  final LinearGradient gradient;
  final ImageProvider imageProvider;
  final Widget Function(ImageProvider provider, BoxFit fit) builder;

  const _ChatAdaptiveImage({
    required this.width,
    required this.gradient,
    required this.imageProvider,
    required this.builder,
  });

  @override
  State<_ChatAdaptiveImage> createState() => _ChatAdaptiveImageState();
}

class _ChatAdaptiveImageState extends State<_ChatAdaptiveImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? _aspect; // width / height
  bool _failed = false;
  int _retryKey = 0;

  static const double _fallbackAspect = 220 / 150;
  static const double _minAspect = 0.55; // juda baland
  static const double _maxAspect = 2.4; // juda keng

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _ChatAdaptiveImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider) {
      _failed = false;
      _aspect = null;
      _resolve();
    }
  }

  void _resolve() {
    _detach();
    final stream = widget.imageProvider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (w <= 0 || h <= 0) return;
        final raw = w / h;
        final clamped = raw.clamp(_minAspect, _maxAspect).toDouble();
        if (!mounted) return;
        setState(() {
          _aspect = clamped;
          _failed = false;
        });
      },
      onError: (_, __) {
        if (!mounted) return;
        setState(() => _failed = true);
      },
    );
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  void _detach() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final aspect = _aspect ?? _fallbackAspect;
    final height = widget.width / aspect;

    if (_failed) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _failed = false;
            _retryKey++;
            _aspect = null;
          });
          _resolve();
        },
        child: Container(
          width: widget.width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(gradient: widget.gradient),
          child: Icon(
            Icons.broken_image_outlined,
            size: 36.dp,
            color: c.onAccent.withValues(alpha: 0.45),
          ),
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(decoration: BoxDecoration(gradient: widget.gradient)),
          if (_aspect == null)
            Center(
              child: SizedBox(
                width: 22.dp,
                height: 22.dp,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.onAccent.withValues(alpha: 0.7),
                ),
              ),
            ),
          KeyedSubtree(
            key: ValueKey(_retryKey),
            child: widget.builder(widget.imageProvider, BoxFit.cover),
          ),
        ],
      ),
    );
  }
}

/// Joylashuv pinining pastki uchi (Telegram uslubi).
class _PinStemPainter extends CustomPainter {
  final Color color;

  _PinStemPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PinStemPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Xabar matnidagi AnyLang guruh linklarini bosiladigan qiladi.
class _InviteAwareText extends StatefulWidget {
  final String text;
  final TextStyle baseStyle;
  final Color linkColor;
  final ValueChanged<String>? onInviteTap;

  const _InviteAwareText({
    required this.text,
    required this.baseStyle,
    required this.linkColor,
    this.onInviteTap,
  });

  @override
  State<_InviteAwareText> createState() => _InviteAwareTextState();
}

class _InviteAwareTextState extends State<_InviteAwareText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final text = widget.text;
    final matches = InviteDeepLinkService.inviteTokenInText.allMatches(text).toList();
    if (matches.isEmpty || widget.onInviteTap == null) {
      return Text(text, style: widget.baseStyle);
    }

    final spans = <InlineSpan>[];
    var start = 0;
    for (final m in matches) {
      if (m.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, m.start),
          style: widget.baseStyle,
        ));
      }
      final url = m.group(0)!;
      final token = m.group(1)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => widget.onInviteTap?.call(token);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: url,
          style: widget.baseStyle.copyWith(
            color: widget.linkColor,
            decoration: TextDecoration.underline,
            decorationColor: widget.linkColor,
            fontWeight: FontWeight.w700,
          ),
          recognizer: recognizer,
        ),
      );
      start = m.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: widget.baseStyle,
      ));
    }

    return Text.rich(TextSpan(children: spans));
  }
}

/// Ovoz → matn: pending shimmer, timeout/failed — lokalizatsiyalangan xato.
class _VoiceTranscriptSection extends StatefulWidget {
  final ChatMessage message;
  final bool outgoing;
  final Color metaColor;
  final Color primaryText;
  final AppColors colors;

  const _VoiceTranscriptSection({
    required this.message,
    required this.outgoing,
    required this.metaColor,
    required this.primaryText,
    required this.colors,
  });

  @override
  State<_VoiceTranscriptSection> createState() =>
      _VoiceTranscriptSectionState();
}

class _VoiceTranscriptSectionState extends State<_VoiceTranscriptSection> {
  static const _sttTimeout = Duration(seconds: 45);
  Timer? _timer;
  bool _timedOut = false;

  ChatMessage get message => widget.message;

  @override
  void initState() {
    super.initState();
    _armTimer();
  }

  @override
  void didUpdateWidget(covariant _VoiceTranscriptSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.id != message.id ||
        oldWidget.message.transcriptPending != message.transcriptPending ||
        oldWidget.message.transcriptFailed != message.transcriptFailed ||
        oldWidget.message.displayText != message.displayText) {
      _armTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _armTimer() {
    _timer?.cancel();
    _timedOut = false;
    final hasText = message.displayText.trim().isNotEmpty;
    if (message.transcriptFailed ||
        hasText ||
        !message.transcriptPending) {
      return;
    }
    final created = message.createdAt ?? DateTime.now();
    final remaining =
        _sttTimeout - DateTime.now().toUtc().difference(created.toUtc());
    if (remaining <= Duration.zero) {
      _timedOut = true;
      return;
    }
    _timer = Timer(remaining, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  bool get _showFailed =>
      message.transcriptFailed ||
      (_timedOut &&
          message.transcriptPending &&
          message.displayText.trim().isEmpty);

  bool get _showPending =>
      !_showFailed &&
      message.transcriptPending &&
      message.displayText.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    if (_showFailed) {
      return Padding(
        padding: EdgeInsets.only(top: 8.dp),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.translate_rounded,
              size: 16.dp,
              color: widget.metaColor,
            ),
            SizedBox(width: 6.dp),
            Expanded(
              child: Text(
                'voice_transcript_failed'.tr,
                style: TextStyle(
                  color: widget.metaColor,
                  fontSize: 12.5.sp,
                  fontStyle: FontStyle.italic,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_showPending) {
      return Padding(
        padding: EdgeInsets.only(top: 8.dp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.translate_rounded,
                  size: 16.dp,
                  color: widget.metaColor,
                ),
                SizedBox(width: 6.dp),
                Expanded(
                  child: Text(
                    'voice_transcribing'.tr,
                    style: TextStyle(
                      color: widget.metaColor,
                      fontSize: 11.5.sp,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.dp),
            TranscriptShimmer(
              color: widget.outgoing
                  ? widget.colors.onAccent.withValues(alpha: 0.35)
                  : widget.colors.textFaint.withValues(alpha: 0.35),
            ),
          ],
        ),
      );
    }
    final text = message.displayText.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: 8.dp),
      child: Text(
        text,
        style: TextStyle(
          color: widget.primaryText,
          fontSize: 14.sp,
          fontWeight: widget.outgoing ? FontWeight.w600 : FontWeight.w400,
          height: 1.3,
        ),
      ),
    );
  }
}
