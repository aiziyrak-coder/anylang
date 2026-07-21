import 'states_module.dart';
import 'components_module.dart';
import 'data_module.dart';
import 'domain_module.dart';

class MainModule {

  Future<void> initModule() async {
    await ComponentsModule().initModule();
    await DataModule().initModule();
    await DomainModule().initModule();
    await StatesModule().initModule();
  }
}
