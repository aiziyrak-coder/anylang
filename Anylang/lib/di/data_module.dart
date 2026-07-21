import 'package:get/get.dart';

import '../data/core/buildNetwork/api_service.dart';
import '../data/core/buildNetwork/network_client.dart';
import '../data/core/buildNetwork/token_refresher.dart';
import '../data/network/auth_repository.dart';
import '../data/network/google_auth_service.dart';
import '../data/network/payment_repository.dart';
import '../data/network/socket_service.dart';

class DataModule {
  Future<void> initModule() async {
    final refresher = TokenRefresher();
    Get.put<TokenRefresher>(refresher, permanent: true);
    Get.put<SessionExpiredBus>(SessionExpiredBus(), permanent: true);

    final api = ApiService(tokenRefresher: refresher);
    Get.put<ApiService>(api, permanent: true);
    Get.put<NetworkClient>(NetworkClient(apiService: api), permanent: true);
    Get.put<AuthRepository>(
      AuthRepository(client: Get.find()),
      permanent: true,
    );
    Get.put<PaymentRepository>(
      PaymentRepository(client: Get.find()),
      permanent: true,
    );
    Get.put<GoogleAuthService>(GoogleAuthService(), permanent: true);
    Get.put<SocketService>(SocketService(), permanent: true);
  }
}
