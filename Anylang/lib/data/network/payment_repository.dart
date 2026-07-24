import '../core/buildNetwork/base_result.dart';
import '../core/buildNetwork/network_client.dart';

class PaymentRepository {
  final NetworkClient _client;

  PaymentRepository({required this._client});

  Future<BaseResult> checkoutSubscription({
    required String plan,
    required String billingCycle,
  }) {
    return _client.post(
      api: 'api/v1/payments/checkout',
      data: {
        'kind': 'subscription',
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

  Future<BaseResult> confirmMock(int paymentId) {
    return _client.post(api: 'api/v1/payments/$paymentId/confirm');
  }

  Future<BaseResult> getPayment(int paymentId) {
    return _client.get(api: 'api/v1/payments/$paymentId');
  }
}
