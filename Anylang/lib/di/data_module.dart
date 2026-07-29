import 'package:get/get.dart';

import '../data/audio/message_alert_sound_service.dart';
import '../data/audio/voice_player_service.dart';
import '../data/audio/voice_recorder_service.dart';
import '../data/core/buildNetwork/api_service.dart';
import '../data/core/buildNetwork/network_client.dart';
import '../data/core/buildNetwork/token_refresher.dart';
import '../data/local/countries_service.dart';
import '../data/local/flag_cache_service.dart';
import '../data/local/languages_service.dart';
import '../data/network/auth_repository.dart';
import '../data/network/chat_repository.dart';
import '../data/network/countries_repository.dart';
import '../data/network/friends_repository.dart';
import '../data/network/google_auth_service.dart';
import '../data/network/languages_repository.dart';
import '../data/network/live_repository.dart';
import '../data/network/numbers_repository.dart';
import '../data/network/payment_repository.dart';
import '../data/network/products_repository.dart';
import '../data/network/profile_repository.dart';
import '../data/network/realtime_sync_service.dart';
import '../data/network/socket_service.dart';
import '../data/network/invite_deep_link_service.dart';
import '../data/network/forward_pending_store.dart';
import '../data/network/support_repository.dart';
import '../data/network/trade_assistant_repository.dart';
import '../data/network/ai_matching_repository.dart';
import '../data/network/market_analytics_repository.dart';
import '../data/network/marketplace_groups_repository.dart';
import '../data/network/business_card_deep_link_service.dart';
import '../data/network/nearby_repository.dart';
import '../data/network/connectivity_service.dart';
import '../data/network/connection_status_service.dart';
import '../data/network/offline_outbox_service.dart';
import '../data/local/offline_chat_store.dart';

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
    Get.put<NearbyRepository>(
      NearbyRepository(client: Get.find()),
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
    Get.put<NumbersRepository>(
      NumbersRepository(client: Get.find()),
      permanent: true,
    );
    Get.put<CountriesRepository>(
      CountriesRepository(client: Get.find()),
      permanent: true,
    );
    Get.put<LanguagesRepository>(
      LanguagesRepository(client: Get.find()),
      permanent: true,
    );
    Get.put<SupportRepository>(
      SupportRepository(client: Get.find()),
      permanent: true,
    );
    Get.put<TradeAssistantRepository>(
      TradeAssistantRepository(client: Get.find()),
      permanent: true,
    );
    Get.put<AiMatchingRepository>(
      AiMatchingRepository(client: Get.find()),
      permanent: true,
    );
    Get.put<MarketAnalyticsRepository>(
      MarketAnalyticsRepository(client: Get.find()),
      permanent: true,
    );
    Get.put<MarketplaceGroupsRepository>(
      MarketplaceGroupsRepository(client: Get.find()),
      permanent: true,
    );
    Get.put<CountriesService>(
      await CountriesService(repo: Get.find()).init(),
      permanent: true,
    );
    Get.put<LanguagesService>(
      await LanguagesService(repo: Get.find()).init(),
      permanent: true,
    );
    Get.put<FlagCacheService>(
      await FlagCacheService(dio: api.dio).init(),
      permanent: true,
    );
    Get.put<GoogleAuthService>(GoogleAuthService(), permanent: true);
    Get.put<SocketService>(SocketService(), permanent: true);
    Get.put<RealtimeSyncService>(RealtimeSyncService(), permanent: true);
    Get.put<ForwardPendingStore>(ForwardPendingStore(), permanent: true);
    Get.put<VoiceRecorderService>(VoiceRecorderService(), permanent: true);
    Get.put<VoicePlayerService>(VoicePlayerService(), permanent: true);
    Get.put<MessageAlertSoundService>(MessageAlertSoundService(), permanent: true);
    await OfflineChatStore.open();
    await Get.putAsync<ConnectivityService>(
      () => ConnectivityService().init(),
      permanent: true,
    );
    await Get.putAsync<OfflineOutboxService>(
      () => OfflineOutboxService().init(),
      permanent: true,
    );
    await Get.putAsync<ConnectionStatusService>(
      () => ConnectionStatusService().init(),
      permanent: true,
    );
    await Get.putAsync<InviteDeepLinkService>(
      () => InviteDeepLinkService().init(),
      permanent: true,
    );
    await Get.putAsync<BusinessCardDeepLinkService>(
      () => BusinessCardDeepLinkService().init(),
      permanent: true,
    );
  }
}
