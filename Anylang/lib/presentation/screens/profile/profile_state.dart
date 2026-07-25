import 'package:get/get.dart';
import '../../ui/ai_matching.dart';
import '../../ui/market_analytics.dart';
import 'profile_account.dart';

class ProfileState extends GetxController {
  /// Joriy foydalanuvchi profili — Screen.initState'da yuklanadi.
  Rx<ProfileAccount?> account = Rx<ProfileAccount?>(null);
  final RxBool loading = true.obs;
  final RxnString error = RxnString();
  final Rxn<AiMatchingResult> aiMatching = Rxn<AiMatchingResult>();
  final RxBool aiMatchingLoading = false.obs;
  final Rxn<MarketAnalyticsResult> marketAnalytics = Rxn<MarketAnalyticsResult>();
  final RxBool marketAnalyticsLoading = false.obs;
}
