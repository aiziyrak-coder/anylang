import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/chat_repository.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/auth_validators.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import 'deal_mode_action.dart';
import 'deal_mode_content.dart';
import 'deal_mode_models.dart';
import 'deal_mode_payload.dart';
import 'deal_mode_state.dart';

class DealModeScreen extends Screen<DealModeState, DealModePayload> {
  DealModeScreen() : super(mobileContent: DealModeContent());

  @override
  void initState(DealModePayload? payload) {
    if (payload != null) {
      state.chatId.value = payload.chatId;
      state.title.value = payload.title;
    }
    _ensureAndLoad();
  }

  Future<void> _ensureAndLoad() async {
    final chatId = state.chatId.value;
    if (chatId <= 0) {
      showAppError('deal_mode_invalid_chat'.tr);
      popBackNavigate();
      return;
    }
    state.loading.value = true;
    state.loadError.value = null;
    try {
      final repo = Get.find<ChatRepository>();
      var result = await repo.getDeal(chatId);
      var map = asMap(result.dataOrNull);
      final existing = map?['deal'];
      if (existing == null) {
        result = await repo.startDeal(chatId);
        map = asMap(result.dataOrNull);
      }
      if (map == null) {
        final msg = AuthValidators.safeError(
          result.errorOrNull,
          fallbackKey: 'deal_mode_offline',
        );
        state.loadError.value = msg;
        showAppError(msg);
        return;
      }
      _applyResponse(map);
    } finally {
      state.loading.value = false;
    }
  }

  Future<void> _reload() async {
    final chatId = state.chatId.value;
    if (chatId <= 0) return;
    state.loading.value = true;
    state.loadError.value = null;
    try {
      final result = await Get.find<ChatRepository>().getDeal(chatId);
      final map = asMap(result.dataOrNull);
      if (map == null) {
        final msg = AuthValidators.safeError(
          result.errorOrNull,
          fallbackKey: 'deal_mode_offline',
        );
        state.loadError.value = msg;
        showAppError(msg);
        return;
      }
      _applyResponse(map);
    } finally {
      state.loading.value = false;
    }
  }

  void _applyResponse(Map<String, dynamic> map) {
    final dealRaw = map['deal'];
    if (dealRaw is Map) {
      state.applyDeal(DealData.fromApi(Map<String, dynamic>.from(dealRaw)));
    } else {
      state.applyDeal(null);
    }
    final candRaw = map['candidates'];
    final cands = <DealDocumentCandidate>[];
    if (candRaw is List) {
      for (final e in candRaw) {
        if (e is Map) {
          cands.add(
            DealDocumentCandidate.fromApi(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    state.candidates.assignAll(cands);
  }

  Future<void> _save() async {
    final chatId = state.chatId.value;
    if (chatId <= 0 || state.saving.value) return;
    state.saving.value = true;
    final result = await Get.find<ChatRepository>().updateDeal(
      chatId,
      product: state.productCtrl.text.trim(),
      price: state.priceCtrl.text.trim(),
      currency: state.currency.value,
      quantity: state.quantityCtrl.text.trim(),
      unit: state.unitCtrl.text.trim(),
      delivery: state.deliveryCtrl.text.trim(),
      payment: state.paymentCtrl.text.trim(),
    );
    state.saving.value = false;
    final map = asMap(result.dataOrNull);
    if (map == null) {
      showAppError(result.errorOrNull ?? 'error'.tr);
      return;
    }
    _applyResponse(map);
    showAppMessage('deal_mode_saved'.tr);
  }

  Future<void> _accept() async {
    final chatId = state.chatId.value;
    if (chatId <= 0 || state.saving.value) return;
    state.saving.value = true;
    try {
      // Avval saqlash
      await _saveSilent();
      final result = await Get.find<ChatRepository>().acceptDeal(chatId);
      final map = asMap(result.dataOrNull);
      if (map == null) {
        showAppError(result.errorOrNull ?? 'error'.tr);
        return;
      }
      _applyResponse(map);
    } finally {
      state.saving.value = false;
    }
  }

  Future<void> _saveSilent() async {
    final chatId = state.chatId.value;
    if (chatId <= 0) return;
    final result = await Get.find<ChatRepository>().updateDeal(
      chatId,
      product: state.productCtrl.text.trim(),
      price: state.priceCtrl.text.trim(),
      currency: state.currency.value,
      quantity: state.quantityCtrl.text.trim(),
      unit: state.unitCtrl.text.trim(),
      delivery: state.deliveryCtrl.text.trim(),
      payment: state.paymentCtrl.text.trim(),
    );
    final map = asMap(result.dataOrNull);
    if (map != null) _applyResponse(map);
  }

  Future<void> _close() async {
    final chatId = state.chatId.value;
    if (chatId <= 0) return;
    state.saving.value = true;
    final result = await Get.find<ChatRepository>().closeDeal(chatId);
    state.saving.value = false;
    final map = asMap(result.dataOrNull);
    if (map == null) {
      showAppError(result.errorOrNull ?? 'error'.tr);
      return;
    }
    popBackNavigate();
  }

  Future<void> _attach(DealDocumentCandidate c) async {
    final chatId = state.chatId.value;
    if (chatId <= 0) return;
    state.saving.value = true;
    final result =
        await Get.find<ChatRepository>().attachDealDocument(chatId, c.messageId);
    state.saving.value = false;
    final map = asMap(result.dataOrNull);
    if (map == null) {
      showAppError(result.errorOrNull ?? 'error'.tr);
      return;
    }
    _applyResponse(map);
  }

  Future<void> _detach(int messageId) async {
    final chatId = state.chatId.value;
    if (chatId <= 0) return;
    state.saving.value = true;
    final result =
        await Get.find<ChatRepository>().detachDealDocument(chatId, messageId);
    state.saving.value = false;
    final map = asMap(result.dataOrNull);
    if (map == null) {
      showAppError(result.errorOrNull ?? 'error'.tr);
      return;
    }
    _applyResponse(map);
  }

  @override
  Future<void> actionHandler(DealModeState state, MyAction action) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case DealModeRefresh _:
        await _reload();
      case DealModeSave _:
        await _save();
      case DealModeAccept _:
        await _accept();
      case DealModeClose _:
        await _close();
      case DealModeAttachDoc a:
        await _attach(a.candidate);
      case DealModeDetachDoc a:
        await _detach(a.messageId);
      case DealModePickCurrency a:
        state.currency.value = a.currency;
    }
  }
}
