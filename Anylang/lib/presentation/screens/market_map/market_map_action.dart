import '../../utils/screen_options/my_action.dart';
import 'market_map_country.dart';

class MarketMapAction extends MyAction {}

class MarketMapRefresh extends MarketMapAction {}

class MarketMapSelectCountry extends MarketMapAction {
  final MarketMapCountry country;
  MarketMapSelectCountry(this.country);
}

class MarketMapViewProducts extends MarketMapAction {
  final String countryCode;
  MarketMapViewProducts(this.countryCode);
}

class MarketMapOpenCompany extends MarketMapAction {
  final int userId;
  MarketMapOpenCompany(this.userId);
}
