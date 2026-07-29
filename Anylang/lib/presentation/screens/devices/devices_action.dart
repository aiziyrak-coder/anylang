import '../../utils/screen_options/my_action.dart';
import 'device_session.dart';

class DevicesAction extends MyAction {}

class RefreshDevices extends DevicesAction {}

class RevokeDeviceSession extends DevicesAction {
  final DeviceSession session;
  RevokeDeviceSession(this.session);
}

class RevokeOtherDeviceSessions extends DevicesAction {}
