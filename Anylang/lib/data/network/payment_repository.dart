import '../core/buildNetwork/base_result.dart';
import '../core/buildNetwork/network_client.dart';

class PaymentRepository {
  final NetworkClient _client;

  PaymentRepository({required this._client});

  Future<BaseResult> checkoutSubscription({
    required String plan,
    required String billingCycle,
    String? promoCode,
    String? provider,
  }) {
    return _client.post(
      api: 'api/v1/subscription/checkout',
      data: {
        'plan': plan,
        'billing_cycle': billingCycle,
        'provider': provider ?? 'multicard',
        if (promoCode != null && promoCode.trim().isNotEmpty)
          'promo_code': promoCode.trim(),
      },
    );
  }

  Future<BaseResult> validatePromo({
    required String code,
    required String plan,
    required String billingCycle,
  }) {
    return _client.post(
      api: 'api/v1/payments/promo/validate',
      data: {
        'code': code.trim(),
        'plan': plan,
        'billing_cycle': billingCycle,
      },
    );
  }

  Future<BaseResult> checkoutNumber({required String number}) {
    return _client.post(
      api: 'api/v1/payments/checkout',
      data: {
        'kind': 'number',
        'number': number,
      },
    );
  }

  Future<BaseResult> checkoutSuperGroup({required int chatId}) {
    return _client.post(
      api: 'api/v1/payments/checkout',
      data: {
        'kind': 'super_group',
        'chat_id': chatId,
      },
    );
  }

  /// Qo‘shimcha hisob sloti — \$10 (faqat biznes, max 10).
  Future<BaseResult> checkoutAccountSlot() {
    return _client.post(
      api: 'api/v1/payments/checkout',
      data: {'kind': 'account_slot'},
    );
  }

  /// Mahsulotni TOP ga chiqarish — $5 / 30 kun.
  Future<BaseResult> checkoutProductTop({required int productId}) {
    return _client.post(
      api: 'api/v1/payments/checkout',
      data: {
        'kind': 'product_top',
        'product_id': productId,
      },
    );
  }

  Future<BaseResult> confirmMock(int paymentId) {
    return _client.post(api: 'api/v1/payments/$paymentId/confirm');
  }

  Future<BaseResult> getPayment(int paymentId) {
    return _client.get(api: 'api/v1/payments/$paymentId');
  }
}
