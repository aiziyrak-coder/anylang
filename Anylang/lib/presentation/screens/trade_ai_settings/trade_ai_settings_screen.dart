import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/profile_repository.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/auth_validators.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import 'trade_ai_settings_action.dart';
import 'trade_ai_settings_content.dart';
import 'trade_ai_settings_state.dart';

class TradeAiSettingsScreen extends Screen<TradeAiSettingsState, void> {
  TradeAiSettingsScreen() : super(mobileContent: TradeAiSettingsContent());

  @override
  void initState(void payload) {
    state.loading.value = true;
    state.loadError.value = null;
    state.knowledge.value = '';
    state.companyName.value = '';
    _load();
  }

  Future<void> _load() async {
    state.loading.value = true;
    state.loadError.value = null;
    final result = await Get.find<ProfileRepository>().getBusiness();
    if (result.errorOrNull != null) {
      state.loadError.value = AuthValidators.safeError(
        result.errorOrNull,
        fallbackKey: 'trade_ai_settings_load_failed',
      );
      state.loading.value = false;
      return;
    }
    final map = asMap(result.dataOrNull);
    if (map == null) {
      state.loadError.value = 'trade_ai_settings_load_failed'.tr;
      state.loading.value = false;
      return;
    }
    state.companyName.value = (map['company_name'] as String?) ?? '';
    state.knowledge.value = (map['ai_knowledge'] as String?) ?? '';
    state.loading.value = false;
  }

  Future<void> _save(String knowledge) async {
    if (state.saving.value) return;
    state.saving.value = true;
    try {
      final result = await Get.find<ProfileRepository>().updateBusiness({
        'ai_knowledge': knowledge.trim(),
      });
      if (result.errorOrNull != null) {
        showAppError(result.errorOrNull);
        return;
      }
      final map = asMap(result.dataOrNull);
      state.knowledge.value =
          (map?['ai_knowledge'] as String?) ?? knowledge.trim();
      showAppMessage('trade_ai_settings_saved'.tr);
    } finally {
      state.saving.value = false;
    }
  }

  @override
  Future<void> actionHandler(TradeAiSettingsState state, MyAction action) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case RetryLoadTradeAiSettings _:
        await _load();
      case SaveTradeAiKnowledge a:
        await _save(a.knowledge);
    }
  }
}
