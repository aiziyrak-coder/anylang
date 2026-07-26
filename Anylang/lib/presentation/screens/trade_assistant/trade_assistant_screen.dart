import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/products_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../../data/network/trade_assistant_repository.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/auth_validators.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../products/product.dart';
import '../products/product_info_bottom_sheet.dart';
import '../user_profile/user_profile_payload.dart';
import '../user_profile/user_profile_screen.dart';
import 'trade_assistant_action.dart';
import 'trade_assistant_content.dart';
import 'trade_assistant_message.dart';
import 'trade_assistant_payload.dart';
import 'trade_assistant_state.dart';

class TradeAssistantScreen
    extends Screen<TradeAssistantState, TradeAssistantPayload?> {
  TradeAssistantScreen() : super(mobileContent: TradeAssistantContent());

  @override
  void initState(TradeAssistantPayload? payload) {
    state.sellerId.value = payload?.sellerId;
    state.companyName.value = payload?.companyName;
    state.error.value = '';
    state.sending.value = false;
    state.showSend.value = false;
    state.messages.clear();
    final company = (payload?.companyName ?? '').trim();
    final welcomeName = company.isNotEmpty ? company : 'trade_ai_guest'.tr;
    state.messages.add(
      TradeAssistantMessage(
        id: 'welcome',
        text: payload?.sellerId != null
            ? 'trade_ai_welcome_company'.trParams({
                'name': welcomeName,
              })
            : 'trade_ai_welcome'.tr,
        isOutgoing: false,
        at: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> actionHandler(
    TradeAssistantState state,
    MyAction action,
  ) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case TradeComposerChanged a:
        state.showSend.value = a.text.trim().isNotEmpty;
      case TradeSend a:
        await _send(state, a.text);
      case TradeUseSuggestion a:
        await _send(state, a.text);
      case TradeTapProduct a:
        await _openProduct(a.product);
      case TradeTapSeller a:
        await _openSeller(a.seller);
    }
  }

  Future<void> _send(TradeAssistantState state, String raw) async {
    final text = raw.trim();
    if (text.isEmpty || state.sending.value) return;

    final history = state.messages
        .where((m) => m.id != 'welcome' && !m.failed && m.text.trim().isNotEmpty)
        .map(
          (m) => <String, String>{
            'role': m.isOutgoing ? 'user' : 'assistant',
            'content': m.text,
          },
        )
        .toList();

    state.messages.add(
      TradeAssistantMessage(
        id: 'u_${DateTime.now().microsecondsSinceEpoch}',
        text: text,
        isOutgoing: true,
        at: DateTime.now(),
      ),
    );
    state.sending.value = true;
    state.error.value = '';

    final pendingId = 'a_${DateTime.now().microsecondsSinceEpoch}';
    state.messages.add(
      TradeAssistantMessage(
        id: pendingId,
        text: 'trade_ai_typing'.tr,
        isOutgoing: false,
        at: DateTime.now(),
        pending: true,
      ),
    );

    final locale = SessionStore.preferredLanguage().isNotEmpty
        ? SessionStore.preferredLanguage()
        : (Get.locale?.languageCode ?? 'uz');

    final result = await Get.find<TradeAssistantRepository>().send(
      message: text,
      history: history,
      locale: locale,
      sellerId: state.sellerId.value,
    );

    final idx = state.messages.indexWhere((m) => m.id == pendingId);
    result.when(
      success: (data) {
        final map = asMap(data) ?? {};
        final reply = (map['reply']?.toString() ?? '').trim();
        final products = asList(map, 'products')
            .whereType<Map>()
            .map((e) => TradeAssistantMatchProduct.fromApi(
                  Map<String, dynamic>.from(e),
                ))
            .where((e) => e.id > 0)
            .toList();
        final sellers = asList(map, 'sellers')
            .whereType<Map>()
            .map((e) => TradeAssistantMatchSeller.fromApi(
                  Map<String, dynamic>.from(e),
                ))
            .where((e) => e.id > 0)
            .toList();
        final questions = <String>[];
        final rawQ = map['next_questions'];
        if (rawQ is List) {
          for (final q in rawQ) {
            final s = q?.toString().trim() ?? '';
            if (s.isNotEmpty) questions.add(s);
          }
        }
        if (idx >= 0) {
          state.messages[idx] = TradeAssistantMessage(
            id: pendingId,
            text: reply.isEmpty ? 'trade_ai_empty'.tr : reply,
            isOutgoing: false,
            at: DateTime.now(),
            products: products,
            sellers: sellers,
            nextQuestions: questions,
          );
        }
      },
      failure: (err) {
        final msg = AuthValidators.safeError(err, fallbackKey: 'trade_ai_failed');
        state.error.value = msg;
        if (idx >= 0) {
          state.messages[idx] = TradeAssistantMessage(
            id: pendingId,
            text: msg,
            isOutgoing: false,
            at: DateTime.now(),
            failed: true,
          );
        }
      },
    );
    state.sending.value = false;
  }

  Future<void> _openProduct(TradeAssistantMatchProduct match) async {
    if (match.id <= 0) return;
    final result = await Get.find<ProductsRepository>().detail(match.id);
    result.when(
      success: (data) {
        final map = asMap(data);
        if (map == null) return;
        final product = Product.fromApi(map);
        showProductInfoBottomSheet(
          context,
          product,
          onOpenBusiness: () async {
            if (product.sellerId <= 0) return;
            final profile =
                await Get.find<ProfileRepository>().getPublicUser(product.sellerId);
            profile.when(
              success: (raw) {
                final pmap = asMap(raw);
                if (pmap == null) return;
                navigate(
                  UserProfileScreen(),
                  payload: UserProfilePayload.fromApi(pmap),
                );
              },
              failure: showAppError,
            );
          },
        );
      },
      failure: showAppError,
    );
  }

  Future<void> _openSeller(TradeAssistantMatchSeller seller) async {
    if (seller.id <= 0) return;
    final result = await Get.find<ProfileRepository>().getPublicUser(seller.id);
    result.when(
      success: (data) {
        final map = asMap(data);
        if (map == null) return;
        navigate(
          UserProfileScreen(),
          payload: UserProfilePayload.fromApi(map),
        );
      },
      failure: showAppError,
    );
  }
}
