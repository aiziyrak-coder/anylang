import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../ui/app_loading.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/buttons/primary_button.dart';
import '../../ui/gradient_background.dart';
import '../../ui/keyboard_aware_scroll.dart';
import '../../ui/textfields/app_text_field.dart';
import '../../ui/theme/colors.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'trade_ai_settings_action.dart';
import 'trade_ai_settings_state.dart';

class TradeAiSettingsContent extends ScreenContent<TradeAiSettingsState> {
  late final TextEditingController _knowledgeCtrl;

  Worker? _knowledgeWorker;

  @override
  void initContent() {
    _knowledgeCtrl = TextEditingController();
  }

  @override
  void onClose() {
    _knowledgeWorker?.dispose();
    _knowledgeCtrl.dispose();
  }

  @override
  void uiBuildFinished(TradeAiSettingsState state) {
    _knowledgeWorker?.dispose();
    _knowledgeWorker = ever(state.knowledge, (String value) {
      if (_knowledgeCtrl.text != value) {
        _knowledgeCtrl.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      }
    });
    if (_knowledgeCtrl.text != state.knowledge.value) {
      _knowledgeCtrl.text = state.knowledge.value;
    }
  }

  @override
  Widget build(
    BuildContext context,
    TradeAiSettingsState state,
    FutureOr<void> Function(MyAction action) sendAction,
  ) {
    final c = context.appColors;
    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.dp, 4.dp, 16.dp, 0),
              child: AppTopBar(
                title: 'trade_ai_settings_title'.tr,
                onBack: () => sendAction(Back()),
              ),
            ),
            Expanded(
              child: Obx(() {
                if (state.loading.value) {
                  return const AppLoading();
                }
                final err = state.loadError.value;
                if (err != null) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.dp),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            err,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 14.sp,
                            ),
                          ),
                          SizedBox(height: 16.dp),
                          PrimaryButton(
                            text: 'common_retry'.tr,
                            onTap: () =>
                                sendAction(RetryLoadTradeAiSettings()),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return KeyboardAwareScrollView(
                  padding: EdgeInsets.fromLTRB(16.dp, 12.dp, 16.dp, 28.dp),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _infoCard(c, state),
                      SizedBox(height: 16.dp),
                      AppTextField(
                        label: 'trade_ai_settings_field'.tr,
                        hint: 'trade_ai_settings_hint'.tr,
                        controller: _knowledgeCtrl,
                        maxLines: 14,
                        minLines: 8,
                        textInputAction: TextInputAction.newline,
                      ),
                      SizedBox(height: 8.dp),
                      Text(
                        'trade_ai_settings_limit'.tr,
                        style: TextStyle(
                          color: c.textFaint,
                          fontSize: 11.sp,
                        ),
                      ),
                      SizedBox(height: 20.dp),
                      Obx(
                        () => PrimaryButton(
                          text: 'business_save'.tr,
                          isLoading: state.saving.value,
                          onTap: () => sendAction(
                            SaveTradeAiKnowledge(_knowledgeCtrl.text),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(AppColors c, TradeAiSettingsState state) {
    final name = state.companyName.value.trim();
    return Container(
      padding: EdgeInsets.all(14.dp),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16.dp),
        border: Border.all(color: c.accent.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy_outlined, color: c.accentText, size: 18.dp),
              SizedBox(width: 8.dp),
              Expanded(
                child: Text(
                  name.isEmpty
                      ? 'trade_ai_settings_title'.tr
                      : 'trade_ai_settings_for'.trParams({'name': name}),
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.dp),
          Text(
            'trade_ai_settings_desc'.tr,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.sp,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
