import 'package:get/get.dart';

class ScamRiskReason {
  final String key;
  final String label;

  const ScamRiskReason({
    required this.key,
    required this.label,
  });

  /// Joriy tilga mos yorliq (`scam_reason_<key>`).
  String get localizedLabel {
    final k = 'scam_reason_$key';
    final tr = k.tr;
    if (tr != k && tr.isNotEmpty) return tr;
    return label;
  }

  factory ScamRiskReason.fromApi(Map<String, dynamic> json) {
    return ScamRiskReason(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }
}

class ScamRisk {
  final String riskLevel;
  final int riskScore;
  final String message;
  final List<ScamRiskReason> reasons;
  final bool showWarning;
  final String generatedBy;

  const ScamRisk({
    this.riskLevel = 'none',
    this.riskScore = 0,
    this.message = '',
    this.reasons = const [],
    this.showWarning = false,
    this.generatedBy = 'rules',
  });

  bool get isHigh => riskLevel == 'high';
  bool get isMedium => riskLevel == 'medium';
  bool get hasWarning =>
      showWarning &&
      (isHigh ||
          isMedium ||
          message.trim().isNotEmpty ||
          reasons.isNotEmpty);

  String get localizedMessage {
    if (isHigh) return 'scam_detection_high'.tr;
    if (isMedium) return 'scam_detection_medium'.tr;
    if (message.trim().isNotEmpty) return message;
    return 'scam_detection_low'.tr;
  }

  factory ScamRisk.fromApi(dynamic raw) {
    if (raw is! Map) return const ScamRisk();
    final map = Map<String, dynamic>.from(raw);
    final reasons = <ScamRiskReason>[];
    final list = map['reasons'];
    if (list is List) {
      for (final e in list) {
        if (e is Map) {
          reasons.add(ScamRiskReason.fromApi(Map<String, dynamic>.from(e)));
        }
      }
    }
    final level = map['risk_level']?.toString() ?? 'none';
    final show = map['show_warning'] == true ||
        level == 'high' ||
        level == 'medium';
    return ScamRisk(
      riskLevel: level,
      riskScore: ((map['risk_score'] as num?)?.toInt() ?? 0).clamp(0, 100),
      message: (map['message'] as String?)?.trim() ?? '',
      reasons: reasons,
      showWarning: show,
      generatedBy: map['generated_by']?.toString() ?? 'rules',
    );
  }
}
