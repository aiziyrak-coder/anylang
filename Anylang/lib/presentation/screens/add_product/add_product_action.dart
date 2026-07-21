import '../../utils/screen_options/my_action.dart';

/// Faqat Mahsulot qo'shish ekraniga xos action'lar.
class AddProductAction extends MyAction {}

class AddProductImageRequested extends AddProductAction {}

class RemoveProductImage extends AddProductAction {
  final int index;
  RemoveProductImage(this.index);
}

class SelectCurrency extends AddProductAction {
  final String currency;
  SelectCurrency(this.currency);
}

class SelectCategory extends AddProductAction {
  final String category;
  SelectCategory(this.category);
}

class SaveDraftRequested extends AddProductAction {}

class PublishProductRequested extends AddProductAction {
  final String name;
  final String price;
  final String shortDescription;
  final String detailedDescription;

  PublishProductRequested({
    required this.name,
    required this.price,
    required this.shortDescription,
    required this.detailedDescription,
  });
}
