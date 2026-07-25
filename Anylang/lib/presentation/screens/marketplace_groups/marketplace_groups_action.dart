import '../../utils/screen_options/my_action.dart';
import 'marketplace_group.dart';

class MarketplaceGroupsAction extends MyAction {}

class MarketplaceGroupsRefresh extends MarketplaceGroupsAction {}

class MarketplaceGroupOpen extends MarketplaceGroupsAction {
  final MarketplaceGroup group;
  MarketplaceGroupOpen(this.group);
}
