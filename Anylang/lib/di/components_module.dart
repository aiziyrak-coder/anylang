import 'package:get/get.dart';
import '../presentation/ui/theme/theme_controller.dart';

class ComponentsModule {

  Future<void> initModule() async {
    Get.put<ThemeController>(ThemeController(), permanent: true);
  }
}
