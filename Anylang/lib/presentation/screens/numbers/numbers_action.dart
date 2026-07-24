import '../../utils/screen_options/my_action.dart';
import 'number_models.dart';

class NumbersAction extends MyAction {}

class NumbersBack extends NumbersAction {}

class NumbersRetry extends NumbersAction {}

class NumbersSearch extends NumbersAction {
  final String query;
  NumbersSearch(this.query);
}

class NumbersSelectGroup extends NumbersAction {
  final int? groupId;
  NumbersSelectGroup(this.groupId);
}

class NumbersToggleBonus extends NumbersAction {}

class NumbersChangeSort extends NumbersAction {
  final String sort;
  NumbersChangeSort(this.sort);
}

class NumbersLoadMore extends NumbersAction {}

class NumbersRandomSwap extends NumbersAction {}

class NumbersBuy extends NumbersAction {
  final CatalogNumber item;
  NumbersBuy(this.item);
}

class NumbersOpenItem extends NumbersAction {
  final CatalogNumber item;
  NumbersOpenItem(this.item);
}

class NumbersCheckPayment extends NumbersAction {}
