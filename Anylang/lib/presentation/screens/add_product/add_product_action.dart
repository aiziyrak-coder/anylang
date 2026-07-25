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

class AddShippingCountryRequested extends AddProductAction {}

class RemoveShippingCountry extends AddProductAction {
  final String code;
  RemoveShippingCountry(this.code);
}

class PickProductVideoRequested extends AddProductAction {}

class ClearProductVideoRequested extends AddProductAction {}

class ToggleProductCapability extends AddProductAction {
  final String code;
  ToggleProductCapability(this.code);
}

class SaveDraftRequested extends AddProductAction {
  final String name;
  final String price;
  final String shortDescription;
  final String detailedDescription;
  final String moq;
  final String shippingInfo;
  final String videoUrl;
  final String factoryVideoUrl;
  final String processVideoUrl;

  SaveDraftRequested({
    required this.name,
    required this.price,
    required this.shortDescription,
    required this.detailedDescription,
    required this.moq,
    required this.shippingInfo,
    required this.videoUrl,
    required this.factoryVideoUrl,
    required this.processVideoUrl,
  });
}

class PublishProductRequested extends AddProductAction {
  final String name;
  final String price;
  final String shortDescription;
  final String detailedDescription;
  final String moq;
  final String shippingInfo;
  final String videoUrl;
  final String factoryVideoUrl;
  final String processVideoUrl;

  PublishProductRequested({
    required this.name,
    required this.price,
    required this.shortDescription,
    required this.detailedDescription,
    required this.moq,
    required this.shippingInfo,
    required this.videoUrl,
    required this.factoryVideoUrl,
    required this.processVideoUrl,
  });
}
