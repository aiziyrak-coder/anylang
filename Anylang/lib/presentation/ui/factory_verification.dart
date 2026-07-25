/// Factory Verified badge holati (API `factory_verification`).
class FactoryVerification {
  final bool factoryVerified;
  final bool inspectionPassed;
  final bool iso;
  final bool ce;
  final bool fda;
  final String? auditReportUrl;

  const FactoryVerification({
    this.factoryVerified = false,
    this.inspectionPassed = false,
    this.iso = false,
    this.ce = false,
    this.fda = false,
    this.auditReportUrl,
  });

  bool get hasAny =>
      factoryVerified ||
      inspectionPassed ||
      iso ||
      ce ||
      fda ||
      (auditReportUrl != null && auditReportUrl!.isNotEmpty);

  bool get hasAuditReport =>
      auditReportUrl != null && auditReportUrl!.trim().isNotEmpty;

  factory FactoryVerification.fromApi(dynamic raw) {
    if (raw is! Map) return const FactoryVerification();
    return FactoryVerification(
      factoryVerified: raw['factory_verified'] == true,
      inspectionPassed: raw['inspection_passed'] == true,
      iso: raw['iso'] == true,
      ce: raw['ce'] == true,
      fda: raw['fda'] == true,
      auditReportUrl: (raw['audit_report_url'] as String?)?.trim(),
    );
  }

  /// Business map yoki to'g'ridan-to'g'ri factory_verification dan.
  factory FactoryVerification.fromBusiness(Map? biz) {
    if (biz == null) return const FactoryVerification();
    final nested = biz['factory_verification'];
    if (nested is Map) return FactoryVerification.fromApi(nested);
    final certs = <String>[];
    final rawCerts = biz['certificates'];
    if (rawCerts is List) {
      for (final c in rawCerts) {
        final s = c.toString().trim().toLowerCase();
        if (s.isNotEmpty) certs.add(s);
      }
    }
    final iso = certs.any((c) => c.contains('iso'));
    final ce = certs.any(
      (c) => c == 'ce' || c.startsWith('ce ') || c.endsWith(' ce') || c.contains(' ce '),
    );
    final fda = certs.any((c) => c.contains('fda'));
    final inspection = biz['inspection_passed'] == true;
    final factoryVerified = biz['factory_verified'] == true || inspection;
    return FactoryVerification(
      factoryVerified: factoryVerified,
      inspectionPassed: inspection,
      iso: iso,
      ce: ce,
      fda: fda,
      auditReportUrl: (biz['audit_report_url'] as String?)?.trim(),
    );
  }
}
