import 'package:get/get.dart';

import '../data/audio/voice_player_service.dart';
import '../data/audio/voice_recorder_service.dart';
import '../data/core/buildNetwork/api_service.dart';
import '../data/core/buildNetwork/network_client.dart';
import '../data/core/buildNetwork/token_refresher.dart';
import '../data/local/countries_service.dart';
import '../data/network/auth_repository.dart';
import '../data/network/chat_repository.dart';
import '../data/network/countries_repository.dart';
import '../data/network/friends_repository.dart';
import '../data/network/google_auth_service.dart';
import '../data/network/live_repository.dart';
import '../data/network/payment_repository.dart';
import '../data/network/products_repository.dart';
import '../data/network/profile_repository.dart';
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
    Get.put<ProfileRepository>(
      ProfileRepository(client: Get.find()),
      permanent: true,
    );
    Get.put<ChatRepository>(
      ChatRepository(client: Get.find()),
      permanent: true,
    );
    Get.put<FriendsRepository>(
      FriendsRepository(client: Get.find()),
      permanent: true,
    );
    Get.put<ProductsRepository>(
      ProductsRepository(client: Get.find()),
      permanent: true,
    );
    Get.put<LiveRepository>(
      LiveRepository(client: Get.find()),
      permanent: true,
    );
    Get.put<CountriesRepository>(
      CountriesRepository(client: Get.find()),
      permanent: true,
    );
    Get.put<CountriesService>(
      await CountriesService(repo: Get.find()).init(),
      permanent: true,
    );
    Get.put<GoogleAuthService>(GoogleAuthService(), permanent: true);
    Get.put<SocketService>(SocketService(), permanent: true);
    Get.put<VoiceRecorderService>(VoiceRecorderService(), permanent: true);
    Get.put<VoicePlayerService>(VoicePlayerService(), permanent: true);
  }
}
