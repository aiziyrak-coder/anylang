import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/buttons/my_icon_button.dart';
import '../../ui/frosted_bar.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme/gradients.dart';
import '../../ui/waveform_bars.dart';
import '../../utils/size_controller.dart';
import 'chat_message.dart';
import 'chat_state.dart';

/// Suhbat pastki paneli: reply / forward ko'rinishi + input/record.
/// Mikrofon tugmasi Telegram uslubida: tap = mic↔camera, hold = yozish,
/// release = yuborish, swipe up = lock.
class ChatComposer extends StatefulWidget {
  final TextEditingController controller;
  final bool recording;
  final bool recordingLocked;
  final ChatComposerMediaMode mediaMode;
  final bool showSend;
  final ChatMessage? reply;
  final String peerName;
  final String recordElapsed;
  final List<double> recordSamples;

  /// Uzatish drafti (Telegram uslubi).
  final int forwardCount;
  final String? forwardPreview;
  final String? forwardSenderLabel;
  final bool forwardShowSender;
  final VoidCallback? onToggleForwardSender;
  final VoidCallback? onCancelForward;

  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onToggleMediaMode;
  final VoidCallback onStartRecording;
  final VoidCallback onLockRecording;
  final VoidCallback onFinishRecording;
  final VoidCallback onAttach;
  final VoidCallback? onAiSuggest;
  final bool aiLoading;
  final VoidCallback onCancelReply;
  final VoidCallback onCancelRecording;
  final VoidCallback? onReplyTap;
  final bool busy;

  const ChatComposer({
    super.key,
    required this.controller,
    required this.recording,
    required this.showSend,
    required this.reply,
    required this.onChanged,
    required this.onSend,
    required this.onToggleMediaMode,
    required this.onStartRecording,
    required this.onLockRecording,
    required this.onFinishRecording,
    required this.onAttach,
    required this.onCancelReply,
    required this.onCancelRecording,
    this.recordingLocked = false,
    this.mediaMode = ChatComposerMediaMode.voice,
    this.onAiSuggest,
    this.aiLoading = false,
    this.peerName = '',
    this.recordElapsed = '0:00',
    this.recordSamples = const [],
    this.forwardCount = 0,
    this.forwardPreview,
    this.forwardSenderLabel,
    this.forwardShowSender = true,
    this.onToggleForwardSender,
    this.onCancelForward,
    this.onReplyTap,
    this.busy = false,
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  /// Hold tugmasi input↔record almashganda ham bir xil State saqlansin.
  final GlobalKey _holdKey = GlobalKey();

  bool get _hasForward => widget.forwardCount > 0;
  bool get _isVideoMode =>
      widget.mediaMode == ChatComposerMediaMode.video;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final recording = widget.recording;

    return FrostedBar(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12.dp, 8.dp, 12.dp, 12.dp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hasForward && !recording) _forwardPreview(c),
              if (!_hasForward && widget.reply != null && !recording)
                _replyPreview(c),
              _mainRow(c),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trailing(AppColors c) {
    if (widget.busy && !widget.recording) {
      return SizedBox(
        width: 44.dp,
        height: 44.dp,
        child: Center(
          child: SizedBox(
            width: 22.dp,
            height: 22.dp,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: c.accent,
            ),
          ),
        ),
      );
    }
    if (!widget.recording && widget.showSend) {
      return _sendButton(c);
    }
    if (widget.recording && widget.recordingLocked) {
      return MyIconButton(
        onClick: widget.onFinishRecording,
        icon: Icons.send_rounded,
        iconColor: c.onAccent,
        iconSize: 22.dp,
        backgroundGradient: limeButtonGradient,
        borderRadius: 22.dp,
        padding: EdgeInsets.all(11.dp),
      );
    }
    return _HoldMediaButton(
      key: _holdKey,
      mediaMode: widget.mediaMode,
      recording: widget.recording,
      locked: widget.recordingLocked,
      onToggle: widget.busy ? () {} : widget.onToggleMediaMode,
      onStart: widget.busy ? () {} : widget.onStartRecording,
      onLock: widget.onLockRecording,
      onReleaseSend: widget.onFinishRecording,
      onCancel: widget.onCancelRecording,
    );
  }

  Widget _mainRow(AppColors c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (widget.recording)
          ..._recordLeading(c)
        else
          Expanded(child: _glassInputCapsule(c)),
        if (widget.recording) ...[
          SizedBox(width: 8.dp),
        ] else
          SizedBox(width: 10.dp),
        _trailing(c),
      ],
    );
  }

  /// Birlashtirilgan liquid-glass input: + · AI · matn maydoni.
  Widget _glassInputCapsule(AppColors c) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26.dp),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          constraints: BoxConstraints(minHeight: 48.dp),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26.dp),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: c.isDark
                  ? const [
                      Color(0x77182A40),
                      Color(0x66121E2E),
                    ]
                  : const [
                      Color(0xAAFFFFFF),
                      Color(0x88F4F7FB),
                    ],
            ),
            border: Border.all(
              color: c.isDark
                  ? const Color(0x55FFFFFF)
                  : const Color(0x99FFFFFF),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: c.isDark
                    ? const Color(0x44000000)
                    : const Color(0x12071526),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: EdgeInsets.only(left: 4.dp, bottom: 4.dp, top: 4.dp),
                child: Opacity(
                  opacity: widget.busy ? 0.45 : 1,
                  child: MyIconButton(
                    onClick: widget.busy ? () {} : widget.onAttach,
                    icon: Icons.add_rounded,
                    iconColor: c.isDark
                        ? const Color(0xFFF4F7FB)
                        : c.accentText,
                    iconSize: 22.dp,
                    backgroundColor: Colors.transparent,
                    borderRadius: 20.dp,
                    padding: EdgeInsets.all(8.dp),
                  ),
                ),
              ),
              if (widget.onAiSuggest != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 4.dp, top: 4.dp),
                  child: Opacity(
                    opacity: widget.aiLoading || widget.busy ? 0.5 : 1,
                    child: MyIconButton(
                      onClick: (widget.aiLoading || widget.busy)
                          ? () {}
                          : widget.onAiSuggest!,
                      icon: widget.aiLoading
                          ? Icons.hourglass_top_rounded
                          : Icons.auto_awesome_rounded,
                      iconColor: c.accent,
                      iconSize: 20.dp,
                      backgroundColor: c.accent.withValues(alpha: 0.14),
                      border: Border.all(
                        color: c.accent.withValues(alpha: 0.35),
                        width: 0.7,
                      ),
                      borderRadius: 18.dp,
                      padding: EdgeInsets.all(8.dp),
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 4.dp,
                    right: 14.dp,
                    top: 2.dp,
                    bottom: 2.dp,
                  ),
                  child: TextField(
                    controller: widget.controller,
                    onChanged: widget.onChanged,
                    enabled: !widget.busy,
                    minLines: 1,
                    maxLines: 4,
                    cursorColor: c.accent,
                    style: TextStyle(
                      color: c.isDark
                          ? const Color(0xFFF4F7FB)
                          : c.textPrimary,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      letterSpacing: 0.15,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 12.dp),
                      hintText: 'chat_input_hint'.tr,
                      hintStyle: TextStyle(
                        color: c.isDark
                            ? const Color(0x99B8C5D6)
                            : c.textFaint,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _recordLeading(AppColors c) {
    return [
      if (widget.recordingLocked)
        MyIconButton(
          onClick: widget.onCancelRecording,
          icon: Icons.delete_outline_rounded,
          iconColor: kListenRed,
          iconSize: 22.dp,
          backgroundColor: c.surface,
          border: Border.all(color: c.surfaceBorder, width: 0.7),
          borderRadius: 22.dp,
          padding: EdgeInsets.all(10.dp),
        )
      else
        SizedBox(
          width: 44.dp,
          child: Center(
            child: Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 22.dp,
              color: c.textFaint,
            ),
          ),
        ),
      SizedBox(width: 8.dp),
      Expanded(
        child: Container(
          height: 44.dp,
          padding: EdgeInsets.symmetric(horizontal: 14.dp),
          decoration: BoxDecoration(
            color: c.isDark ? const Color(0x99152A42) : const Color(0xCCFFFFFF),
            border: Border.all(color: c.surfaceBorder, width: 0.7),
            borderRadius: BorderRadius.circular(22.dp),
          ),
          child: Row(
            children: [
              Container(
                width: 8.dp,
                height: 8.dp,
                decoration: const BoxDecoration(
                  color: kListenRed,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8.dp),
              Text(
                widget.recordElapsed,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 14.sp,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              SizedBox(width: 10.dp),
              Expanded(
                child: widget.recordingLocked
                    ? (_isVideoMode
                        ? Text(
                            'chat_media_locked_hint'.tr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textFaint,
                              fontSize: 13.sp,
                            ),
                          )
                        : ClipRect(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: WaveformBars(
                                color: c.accent,
                                maxHeight: 22,
                                barCount: 30,
                                samples: widget.recordSamples,
                              ),
                            ),
                          ))
                    : Text(
                        'chat_media_slide_to_lock'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.textFaint,
                          fontSize: 13.sp,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _forwardPreview(AppColors c) {
    final title = widget.forwardShowSender
        ? (widget.forwardCount > 1
            ? 'chat_forward_n'.trParams({'n': '${widget.forwardCount}'})
            : 'chat_forward_from'.trParams({
                'name': widget.forwardSenderLabel ?? '',
              }))
        : (widget.forwardCount > 1
            ? 'chat_forward_n_hidden'
                .trParams({'n': '${widget.forwardCount}'})
            : 'chat_forward_hidden'.tr);
    final subtitle = widget.forwardShowSender
        ? () {
            final base = widget.forwardPreview ?? '';
            if (widget.forwardCount <= 1) return base;
            final more = 'chat_forward_more'
                .trParams({'n': '${widget.forwardCount - 1}'});
            return base.isEmpty ? more : '$base · $more';
          }()
        : 'chat_forward_hide_hint'.tr;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onToggleForwardSender,
        borderRadius: BorderRadius.circular(12.dp),
        child: Container(
          margin: EdgeInsets.only(bottom: 8.dp),
          padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 8.dp),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12.dp),
          ),
          child: Row(
            children: [
              Container(
                width: 3.dp,
                height: 40.dp,
                decoration: BoxDecoration(
                  color: c.accentText,
                  borderRadius: BorderRadius.circular(2.dp),
                ),
              ),
              SizedBox(width: 10.dp),
              Icon(
                Icons.shortcut_rounded,
                size: 18.dp,
                color: c.accentText,
              ),
              SizedBox(width: 8.dp),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.accentText,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.dp),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textFaint, fontSize: 13.sp),
                    ),
                  ],
                ),
              ),
              MyIconButton(
                onClick: widget.onCancelForward ?? () {},
                icon: Icons.close_rounded,
                iconColor: c.textSecondary,
                iconSize: 18.dp,
                backgroundColor: Colors.transparent,
                borderRadius: 12.dp,
                padding: EdgeInsets.all(4.dp),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _replyPreview(AppColors c) {
    final target = widget.reply!;
    final author = target.isOutgoing ? 'chat_you'.tr : widget.peerName;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onReplyTap,
        borderRadius: BorderRadius.circular(12.dp),
        child: Container(
          margin: EdgeInsets.only(bottom: 8.dp),
          padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 8.dp),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12.dp),
          ),
          child: Row(
            children: [
              Container(
                width: 3.dp,
                height: 36.dp,
                decoration: BoxDecoration(
                  color: c.accentText,
                  borderRadius: BorderRadius.circular(2.dp),
                ),
              ),
              SizedBox(width: 10.dp),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author.isEmpty ? 'chat_reply_to'.tr : author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.accentText,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.dp),
                    Text(
                      target.previewText(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textFaint, fontSize: 13.sp),
                    ),
                  ],
                ),
              ),
              MyIconButton(
                onClick: widget.onCancelReply,
                icon: Icons.close_rounded,
                iconColor: c.textSecondary,
                iconSize: 18.dp,
                backgroundColor: Colors.transparent,
                borderRadius: 12.dp,
                padding: EdgeInsets.all(4.dp),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sendButton(AppColors c) {
    return MyIconButton(
      onClick: widget.busy ? () {} : widget.onSend,
      icon: Icons.send_rounded,
      iconColor: c.onAccent,
      iconSize: 22.dp,
      backgroundGradient: limeButtonGradient,
      borderRadius: 22.dp,
      padding: EdgeInsets.all(11.dp),
    );
  }
}

/// Telegram uslubidagi hold/tap/swipe-up media tugmasi.
class _HoldMediaButton extends StatefulWidget {
  final ChatComposerMediaMode mediaMode;
  final bool recording;
  final bool locked;
  final VoidCallback onToggle;
  final VoidCallback onStart;
  final VoidCallback onLock;
  final VoidCallback onReleaseSend;
  final VoidCallback onCancel;

  const _HoldMediaButton({
    super.key,
    required this.mediaMode,
    required this.recording,
    required this.locked,
    required this.onToggle,
    required this.onStart,
    required this.onLock,
    required this.onReleaseSend,
    required this.onCancel,
  });

  @override
  State<_HoldMediaButton> createState() => _HoldMediaButtonState();
}

class _HoldMediaButtonState extends State<_HoldMediaButton> {
  bool _holding = false;
  bool _lockedLocal = false;
  bool _cancelledLocal = false;
  static const double _lockThreshold = -48;
  static const double _cancelThreshold = -56;

  bool get _isVideo => widget.mediaMode == ChatComposerMediaMode.video;

  @override
  void didUpdateWidget(covariant _HoldMediaButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.recording) {
      _holding = false;
      _lockedLocal = false;
      _cancelledLocal = false;
    }
    if (widget.locked) {
      _lockedLocal = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final enlarged = _holding && !widget.locked && !_cancelledLocal;
    final pad = enlarged ? 16.dp : 11.dp;
    final iconSize = enlarged ? 26.dp : 22.dp;

    return Semantics(
      label: _isVideo ? 'chat_cam_hold'.tr : 'chat_mic_hold'.tr,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (widget.recording || _holding) return;
          widget.onToggle();
        },
        onLongPressStart: (_) {
          if (widget.locked) return;
          setState(() {
            _holding = true;
            _lockedLocal = false;
            _cancelledLocal = false;
          });
          if (!widget.recording) {
            widget.onStart();
          }
        },
        onLongPressMoveUpdate: (details) {
          if (!_holding || widget.locked) return;
          if (!_cancelledLocal &&
              details.offsetFromOrigin.dx <= _cancelThreshold) {
            _cancelledLocal = true;
            _lockedLocal = false;
            widget.onCancel();
            setState(() {});
            return;
          }
          if (_cancelledLocal) return;
          if (!_lockedLocal &&
              details.offsetFromOrigin.dy <= _lockThreshold) {
            _lockedLocal = true;
            widget.onLock();
            setState(() {});
          }
        },
        onLongPressEnd: (_) {
          final wasHolding = _holding;
          final wasLocked = _lockedLocal || widget.locked;
          final wasCancelled = _cancelledLocal;
          setState(() => _holding = false);
          if (!wasHolding || wasCancelled) return;
          if (wasLocked) return;
          widget.onReleaseSend();
        },
        onLongPressCancel: () {
          final shouldCancel = _holding && !_lockedLocal && !_cancelledLocal;
          setState(() {
            _holding = false;
            _cancelledLocal = true;
          });
          if (shouldCancel) widget.onCancel();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: limeButtonGradient,
            borderRadius: BorderRadius.circular(enlarged ? 28.dp : 22.dp),
            boxShadow: enlarged
                ? [
                    BoxShadow(
                      color: c.accent.withValues(alpha: 0.45),
                      blurRadius: 16.dp,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          padding: EdgeInsets.all(pad),
          child: Icon(
            _isVideo ? Icons.videocam_rounded : Icons.mic_rounded,
            color: c.onAccent,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}
