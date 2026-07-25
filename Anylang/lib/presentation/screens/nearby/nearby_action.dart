import '../../utils/screen_options/my_action.dart';
import 'nearby_person.dart';

class NearbyAction extends MyAction {}

class RefreshNearby extends NearbyAction {}

class RetryNearby extends NearbyAction {}

class SelectNearbyLanguage extends NearbyAction {
  final String? languageCode;
  SelectNearbyLanguage(this.languageCode);
}

class OpenNearbyPerson extends NearbyAction {
  final NearbyPerson person;
  OpenNearbyPerson(this.person);
}

class MessageNearbyPerson extends NearbyAction {
  final NearbyPerson person;
  MessageNearbyPerson(this.person);
}

class OpenNearbyPremium extends NearbyAction {}

class ToggleNearbySharing extends NearbyAction {
  final bool enabled;
  ToggleNearbySharing(this.enabled);
}

class BackFromNearby extends NearbyAction {}
