import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/audio/voice_player_service.dart';
import '../../screens/chat/chat_message.dart';
import '../../utils/size_controller.dart';
import '../theme/colors.dart';
import '../theme/gradients.dart';
import '../waveform_bars.dart';

/// Suhbatdagi bitta xabar (ListView elementi). Turiga qarab mos ko'rinishni
/// chizadi: matn, rasm, ovoz, mahsulot, joylashuv, fayl, kontakt. Reply
/// sitatasi va (chiquvchi uchun) o'qildi belgisini ham ko'rsatadi. Uzoq bosish
/// kontekst menyusini ochadi (`onLongPress`).
class ChatMessageItem extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onLongPress;
  final ValueChanged<String>? onReplyTap;

  const ChatMessageItem({
    super.key,
    required this.message,
    required this.onLongPress,
    this.onReplyTap,
  });

  bool get _out => message.isOutgoing;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final maxW = SizeController.screenWidth * 0.76;

    return Align(
      alignment: _out ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.dp),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          // Material ota sifatida — ichkaridagi reply-sitata tap'i ishlayveradi.
          // Pufakcha foni `Ink` — ripple ustida ko'rinadi.
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: _bubbleRadius,
              onLongPress: onLongPress,
              child: _body(c),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(AppColors c) {
    switch (message.type) {
      case ChatMsgType.text:
        return _text(c);
      case ChatMsgType.image:
        return _image(c);
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
    return Ink(
      padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 10.dp),
      decoration: BoxDecoration(
        color: _out ? c.accent : c.surface,
        border: _out ? null : Border.all(color: c.surfaceBorder),
        borderRadius: _bubbleRadius,
      ),
      child: child,
    );
  }

  Color _primaryText(AppColors c) => _out ? c.onAccent : c.textPrimary;

  Color _metaColor(AppColors c) =>
      _out ? c.onAccent.withValues(alpha: 0.55) : c.textFaint;

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
            message.status == ChatStatus.read
                ? Icons.done_all_rounded
                : Icons.done_rounded,
            size: 14.dp,
            color: c.onAccent.withValues(alpha: 0.7),
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
            Flexible(
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

  Widget _text(AppColors c) {
    return _bubble(
      c,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.reply != null) _replyQuote(c, message.reply!),
          Text(
            message.displayText,
            style: TextStyle(
              color: _primaryText(c),
              fontSize: 15.sp,
              fontWeight: _out ? FontWeight.w600 : FontWeight.w400,
              height: 1.3,
            ),
          ),
          SizedBox(height: 4.dp),
          Align(alignment: Alignment.centerRight, child: _meta(c)),
        ],
      ),
    );
  }

  Widget _image(AppColors c) {
    final url = message.imageUrl;
    final isNet = url != null &&
        (url.startsWith('http://') || url.startsWith('https://'));
    final isFile = url != null && url.isNotEmpty && !isNet;

    Widget media;
    if (isNet) {
      media = Image.network(
        url!,
        width: 220.dp,
        height: 150.dp,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: 220.dp,
            height: 150.dp,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: message.imageGradient ?? prodTealGradient,
            ),
            child: SizedBox(
              width: 22.dp,
              height: 22.dp,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.onAccent.withValues(alpha: 0.7),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          width: 220.dp,
          height: 150.dp,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: message.imageGradient ?? prodTealGradient,
          ),
          child: Icon(
            Icons.broken_image_outlined,
            size: 36.dp,
            color: c.onAccent.withValues(alpha: 0.45),
          ),
        ),
      );
    } else if (isFile) {
      media = Image.file(
        File(url!),
        width: 220.dp,
        height: 150.dp,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 220.dp,
          height: 150.dp,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: message.imageGradient ?? prodTealGradient,
          ),
          child: Icon(
            Icons.broken_image_outlined,
            size: 36.dp,
            color: c.onAccent.withValues(alpha: 0.45),
          ),
        ),
      );
    } else {
      media = Container(
        width: 220.dp,
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

    return GestureDetector(
      onTap: (isNet || isFile)
          ? () => _openImageViewer(url!)
          : null,
      child: ClipRRect(
        borderRadius: _bubbleRadius,
        child: Stack(
          children: [
            media,
            Positioned(
              right: 8.dp,
              bottom: 8.dp,
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
          ],
        ),
      ),
    );
  }

  void _openImageViewer(String url) {
    final ctx = Get.context;
    if (ctx == null) return;
    Navigator.of(ctx).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        pageBuilder: (_, __, ___) => _ChatImageViewer(url: url),
      ),
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

    return _bubble(
      c,
      Obx(() {
        final active = player.isActive(message.id);
        final playing = active && player.isPlaying.value;
        // Obx trigger
        player.activeId.value;
        player.isPlaying.value;

        Widget wave(double p) => WaveformBars(
              color: waveColor,
              inactiveColor: inactive,
              maxHeight: 20,
              barCount: 22,
              samples: message.voiceSamples,
              progress: p,
            );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.reply != null) _replyQuote(c, message.reply!),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    if (!canPlay || path == null) return;
                    player.toggle(
                      id: message.id,
                      path: path,
                      duration: duration.inMilliseconds > 0
                          ? duration
                          : const Duration(seconds: 1),
                      samples: message.voiceSamples,
                      barCount: 22,
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
                ),
                SizedBox(width: 10.dp),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 150.dp,
                      height: 20.dp,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
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
                              barCount: 22,
                            );
                          }

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (d) => seek(d.localPosition),
                            onHorizontalDragUpdate: (d) => seek(d.localPosition),
                            child: active
                                ? ValueListenableBuilder<double>(
                                    valueListenable: player.progress,
                                    builder: (_, p, _) => wave(p),
                                  )
                                : wave(player.restingProgress(message.id)),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 6.dp),
                    SizedBox(
                      width: 150.dp,
                      child: Row(
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
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  Widget _product(AppColors c) {
    return Ink(
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
    );
  }

  Widget _location(AppColors c) {
    return _bubble(
      c,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10.dp),
            child: Container(
              width: 200.dp,
              height: 110.dp,
              alignment: Alignment.center,
              decoration: const BoxDecoration(gradient: prodTealGradient),
              child: Icon(Icons.location_on, size: 30.dp, color: c.accent),
            ),
          ),
          SizedBox(height: 8.dp),
          Row(
            children: [
              Icon(Icons.place_outlined, size: 14.dp, color: c.accent),
              SizedBox(width: 4.dp),
              Flexible(
                child: Text(
                  '${message.locationLabel ?? ''} · ${message.locationDistance ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textSecondary, fontSize: 12.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.dp),
          Align(alignment: Alignment.centerRight, child: _meta(c)),
        ],
      ),
    );
  }

  Widget _file(AppColors c) {
    return _bubble(
      c,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
    );
  }

  Widget _contact(AppColors c) {
    return _bubble(
      c,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44.dp,
                height: 44.dp,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  message.contactInitial ?? '',
                  style: TextStyle(
                    color: c.accentText,
                    fontSize: 15.sp,
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
                      message.contactName ?? '',
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
                      message.contactPhone ?? '',
                      style: TextStyle(color: c.textFaint, fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.dp),
          Divider(height: 1.dp, thickness: 1, color: c.outline),
          SizedBox(height: 8.dp),
          Center(
            child: Text(
              'chat_contact_send'.tr,
              style: TextStyle(
                color: c.accentText,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 6.dp),
          Align(alignment: Alignment.centerRight, child: _meta(c)),
        ],
      ),
    );
  }
}

class _ChatImageViewer extends StatelessWidget {
  final String url;

  const _ChatImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    final isNet = url.startsWith('http://') || url.startsWith('https://');
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: isNet
                      ? Image.network(url, fit: BoxFit.contain)
                      : Image.file(File(url), fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
