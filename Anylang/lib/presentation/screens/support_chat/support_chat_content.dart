import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../ui/chat_wallpaper_background.dart';
import '../../ui/frosted_bar.dart';
import '../../ui/buttons/my_icon_button.dart';
import '../../ui/profile_avatar.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme/gradients.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'support_chat_action.dart';
import 'support_chat_state.dart';
import 'support_message.dart';

class SupportChatContent extends ScreenContent<SupportChatState> {
  late final TextEditingController _composer;
  late final ScrollController _scroll;

  @override
  void initContent() {
    _composer = TextEditingController();
    _scroll = ScrollController();
  }

  @override
  void onClose() {
    _composer.dispose();
    _scroll.dispose();
  }

  @override
  Widget build(
    BuildContext context,
    SupportChatState state,
    void Function(MyAction action) sendAction,
  ) {
    final c = context.appColors;

    return ChatWallpaperBackground(
      child: Column(
        children: [
          _appBar(c, sendAction),
          Expanded(
            child: Obx(() {
              final items = state.messages.toList();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_scroll.hasClients) return;
                _scroll.jumpTo(_scroll.position.maxScrollExtent);
              });
              return ListView.builder(
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(14.dp, 12.dp, 14.dp, 12.dp),
                itemCount: items.length,
                itemBuilder: (_, i) => _bubble(c, items[i]),
              );
            }),
          ),
          Obx(() {
            final err = state.error.value;
            if (err.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: EdgeInsets.fromLTRB(16.dp, 0, 16.dp, 6.dp),
              child: Text(
                err,
                style: TextStyle(
                  color: kListenRed,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }),
          _composerBar(c, state, sendAction),
        ],
      ),
    );
  }

  Widget _appBar(AppColors c, void Function(MyAction) sendAction) {
    return FrostedBar(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(6.dp, 6.dp, 12.dp, 10.dp),
          child: Row(
            children: [
              MyIconButton(
                onClick: () => sendAction(Back()),
                icon: Icons.arrow_back_ios_new_rounded,
                iconColor: c.accentText,
                iconSize: 18.dp,
                backgroundColor: Colors.transparent,
                borderRadius: 12.dp,
                padding: EdgeInsets.all(8.dp),
              ),
              ProfileAvatar(
                initial: 'S',
                gradient: avatarGreenGradient,
                size: 40,
                shape: ProfileAvatarShape.circle,
              ),
              SizedBox(width: 10.dp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'support_agent_name'.tr,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2.dp),
                    Text(
                      'support_agent_status'.tr,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bubble(AppColors c, SupportMessage m) {
    final out = m.isOutgoing;
    final bg = out ? c.accent : c.surface;
    final fg = out ? c.onAccent : c.textPrimary;
    final align = out ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: align,
      child: Container(
        margin: EdgeInsets.only(bottom: 10.dp),
        constraints: BoxConstraints(maxWidth: SizeController.screenWidth * 0.78),
        padding: EdgeInsets.fromLTRB(14.dp, 10.dp, 14.dp, 10.dp),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18.dp),
            topRight: Radius.circular(18.dp),
            bottomLeft: Radius.circular(out ? 18.dp : 6.dp),
            bottomRight: Radius.circular(out ? 6.dp : 18.dp),
          ),
          border: out ? null : Border.all(color: c.surfaceBorder, width: 0.7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: c.isDark ? 0.25 : 0.06),
              blurRadius: 10.dp,
              offset: Offset(0, 3.dp),
            ),
          ],
        ),
        child: Text(
          m.text,
          style: TextStyle(
            color: m.failed
                ? kListenRed
                : (m.pending ? fg.withValues(alpha: 0.65) : fg),
            fontSize: 15.sp,
            fontWeight: m.pending ? FontWeight.w500 : FontWeight.w600,
            height: 1.35,
            fontStyle: m.pending ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }

  Widget _composerBar(
    AppColors c,
    SupportChatState state,
    void Function(MyAction) sendAction,
  ) {
    return FrostedBar(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12.dp, 8.dp, 12.dp, 12.dp),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(22.dp),
                    border: Border.all(color: c.surfaceBorder, width: 1),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16.dp),
                  child: TextField(
                    controller: _composer,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onChanged: (v) => sendAction(SupportComposerChanged(v)),
                    onSubmitted: (_) => _submit(state, sendAction),
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 14.dp),
                      border: InputBorder.none,
                      hintText: 'support_composer_hint'.tr,
                      hintStyle: TextStyle(
                        color: c.textFaint,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.dp),
              Obx(() {
                final canSend = state.showSend.value && !state.sending.value;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: canSend ? () => _submit(state, sendAction) : null,
                    customBorder: const CircleBorder(),
                    child: Ink(
                      width: 48.dp,
                      height: 48.dp,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: canSend ? c.textPrimary : c.surfaceBorder,
                      ),
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: canSend ? c.accent : c.textFaint,
                        size: 24.dp,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _submit(SupportChatState state, void Function(MyAction) sendAction) {
    final text = _composer.text.trim();
    if (text.isEmpty || state.sending.value) return;
    HapticFeedback.lightImpact();
    _composer.clear();
    sendAction(SupportComposerChanged(''));
    sendAction(SupportSend(text));
  }
}
