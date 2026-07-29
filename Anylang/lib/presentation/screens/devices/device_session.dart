class DeviceSession {
  final String id;
  final String deviceName;
  final String deviceType;
  final String? platform;
  final String? appVersion;
  final String? ipAddress;
  final bool isCurrent;
  final bool isOnline;
  final DateTime? lastActiveAt;
  final DateTime? sessionStartedAt;
  final bool canRevoke;

  const DeviceSession({
    required this.id,
    required this.deviceName,
    required this.deviceType,
    this.platform,
    this.appVersion,
    this.ipAddress,
    this.isCurrent = false,
    this.isOnline = false,
    this.lastActiveAt,
    this.sessionStartedAt,
    this.canRevoke = false,
  });

  factory DeviceSession.fromApi(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString())?.toLocal();
    }

    final name = (json['device_name']?.toString() ?? '').trim();
    return DeviceSession(
      id: json['id']?.toString() ?? '',
      deviceName: name.isEmpty ? 'Mobile' : name,
      deviceType: json['device_type']?.toString() ?? 'mobile',
      platform: json['platform']?.toString(),
      appVersion: json['app_version']?.toString(),
      ipAddress: json['ip_address']?.toString(),
      isCurrent: json['is_current'] == true,
      isOnline: json['is_online'] == true,
      lastActiveAt: parseDt(json['last_active_at']),
      sessionStartedAt: parseDt(json['session_started_at']),
      canRevoke: json['can_revoke'] == true,
    );
  }

  bool get isPhone {
    final t = deviceType.toLowerCase();
    return t == 'ios' || t == 'android' || t == 'mobile';
  }
}
