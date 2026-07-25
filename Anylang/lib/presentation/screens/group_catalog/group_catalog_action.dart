import '../../utils/screen_options/my_action.dart';
import 'group_catalog_models.dart';

class GroupCatalogAction extends MyAction {}

class GroupCatalogRefresh extends GroupCatalogAction {}

class GroupCatalogSelectSection extends GroupCatalogAction {
  final String section;
  GroupCatalogSelectSection(this.section);
}

class GroupCatalogOpenProduct extends GroupCatalogAction {
  final GroupCatalogProduct item;
  GroupCatalogOpenProduct(this.item);
}

class GroupCatalogOpenDocument extends GroupCatalogAction {
  final GroupCatalogDocument item;
  GroupCatalogOpenDocument(this.item);
}

class GroupCatalogOpenCompany extends GroupCatalogAction {
  final GroupCatalogCompany item;
  GroupCatalogOpenCompany(this.item);
}
