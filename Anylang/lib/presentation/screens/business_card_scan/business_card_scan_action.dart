import '../../utils/screen_options/my_action.dart';

class BusinessCardScanAction extends MyAction {}

class BusinessCardScanned extends BusinessCardScanAction {
  final String raw;
  BusinessCardScanned(this.raw);
}

class CloseBusinessCardScan extends BusinessCardScanAction {}
