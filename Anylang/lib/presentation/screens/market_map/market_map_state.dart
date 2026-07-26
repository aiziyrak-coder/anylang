import 'package:get/get.dart';

import 'market_map_country.dart';

class MarketMapState extends GetxController {
  final RxBool loading = true.obs;
  final RxList<MarketMapCountry> countries = <MarketMapCountry>[].obs;
  final RxInt totalManufacturers = 0.obs;
  final Rxn<MarketMapCountry> selected = Rxn<MarketMapCountry>();
  final RxnString loadError = RxnString();
}
