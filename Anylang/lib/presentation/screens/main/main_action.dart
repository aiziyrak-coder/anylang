import '../../utils/screen_options/my_action.dart';

/// Faqat Asosiy ekranga xos action'lar.
class MainAction extends MyAction {}

/// Pastki navigatsiyada tab tanlanganda.
class TabSelected extends MainAction {
  final int index;
  TabSelected(this.index);
}

/// Android/iOS tizim orqaga tugmasi (asosiy shell).
class HandleSystemBack extends MainAction {}
