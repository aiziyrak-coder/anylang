import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/core/mappers.dart';
import '../../data/network/profile_repository.dart';
import '../modal/image_picker.dart';
import '../ui/buttons/rich_button.dart';
import '../ui/theme/colors.dart';
import '../ui/theme/gradients.dart';
import '../utils/app_snackbar.dart';
import '../utils/size_controller.dart';

class BusinessVerificationSnapshot {
  final String status;
  final bool documentsVerified;
  final bool canUpload;
  final bool canSubmit;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> missingRequired;
  final List<Map<String, dynamic>> missingRecommended;
  final String? adminNote;

  const BusinessVerificationSnapshot({
    required this.status,
    required this.documentsVerified,
    required this.canUpload,
    required this.canSubmit,
    required this.items,
    required this.missingRequired,
    required this.missingRecommended,
    this.adminNote,
  });

  factory BusinessVerificationSnapshot.fromApi(Map<String, dynamic> json) {
    final req = json['request'];
    return BusinessVerificationSnapshot(
      status: (json['status'] as String?) ?? 'none',
      documentsVerified: json['documents_verified'] == true,
      canUpload: json['can_upload'] == true,
      canSubmit: json['can_submit'] == true,
      items: (json['items'] is List)
          ? (json['items'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const [],
      missingRequired: (json['missing_required'] is List)
          ? (json['missing_required'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const [],
      missingRecommended: (json['missing_recommended'] is List)
          ? (json['missing_recommended'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const [],
      adminNote: req is Map ? (req['admin_note'] as String?) : null,
    );
  }

  bool get isApproved => documentsVerified || status == 'approved';
  bool get isPending => status == 'pending';
}

Future<BusinessVerificationSnapshot?> showBusinessVerificationBottomSheet(
  BuildContext context,
) {
  return showModalBottomSheet<BusinessVerificationSnapshot>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _BusinessVerificationSheet(),
  );
}

class _BusinessVerificationSheet extends StatefulWidget {
  const _BusinessVerificationSheet();

  @override
  State<_BusinessVerificationSheet> createState() =>
      _BusinessVerificationSheetState();
}

class _BusinessVerificationSheetState extends State<_BusinessVerificationSheet> {
  BusinessVerificationSnapshot? _data;
  bool _loading = true;
  bool _busy = false;
  String? _uploadingType;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await Get.find<ProfileRepository>().getBusinessVerification();
    if (!mounted) return;
    result.when(
      success: (raw) {
        final map = asMap(raw);
        if (map == null) {
          setState(() {
            _loading = false;
            _error = 'verification_load_failed'.tr;
          });
          return;
        }
        setState(() {
          _data = BusinessVerificationSnapshot.fromApi(map);
          _loading = false;
        });
      },
      failure: (err) {
        setState(() {
          _loading = false;
          _error = err.toString();
        });
      },
    );
  }

  Future<void> _upload(String docType) async {
    if (_busy || _data?.canUpload != true) return;
    final file = await pickImage(context);
    if (file == null || !mounted) return;
    setState(() {
      _busy = true;
      _uploadingType = docType;
    });
    final result = await Get.find<ProfileRepository>().uploadVerificationDocument(
      filePath: file.path,
      docType: docType,
    );
    if (!mounted) return;
    result.when(
      success: (raw) {
        final map = asMap(raw);
        if (map != null) {
          setState(() {
            _data = BusinessVerificationSnapshot.fromApi(map);
            _busy = false;
            _uploadingType = null;
          });
          showAppMessage('verification_doc_uploaded'.tr);
        } else {
          setState(() {
            _busy = false;
            _uploadingType = null;
          });
        }
      },
      failure: (err) {
        setState(() {
          _busy = false;
          _uploadingType = null;
        });
        showAppError(err);
      },
    );
  }

  Future<void> _submit() async {
    if (_busy || _data?.canSubmit != true) return;
    setState(() => _busy = true);
    final result = await Get.find<ProfileRepository>().submitBusinessVerification();
    if (!mounted) return;
    result.when(
      success: (raw) {
        final map = asMap(raw);
        if (map != null) {
          final snap = BusinessVerificationSnapshot.fromApi(map);
          setState(() {
            _data = snap;
            _busy = false;
          });
          showAppMessage('verification_submitted'.tr);
          Navigator.pop(context, snap);
        } else {
          setState(() => _busy = false);
        }
      },
      failure: (err) {
        setState(() => _busy = false);
        showAppError(err);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      margin: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10.dp),
            Container(
              width: 40.dp,
              height: 4.dp,
              decoration: BoxDecoration(
                color: c.surfaceBorder,
                borderRadius: BorderRadius.circular(99.dp),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.dp, 16.dp, 20.dp, 8.dp),
              child: Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: c.accent, size: 22.dp),
                  SizedBox(width: 10.dp),
                  Expanded(
                    child: Text(
                      'verification_sheet_title'.tr,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, _data),
                    icon: Icon(Icons.close_rounded, color: c.textSecondary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.dp),
              child: Text(
                'verification_sheet_desc'.tr,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13.sp,
                  height: 1.35,
                ),
              ),
            ),
            if (_loading)
              Padding(
                padding: EdgeInsets.all(40.dp),
                child: CircularProgressIndicator(color: c.accent),
              )
            else if (_error != null)
              Padding(
                padding: EdgeInsets.all(24.dp),
                child: Column(
                  children: [
                    Text(_error!, style: TextStyle(color: c.textSecondary)),
                    SizedBox(height: 12.dp),
                    TextButton(
                      onPressed: _load,
                      child: Text('common_retry'.tr),
                    ),
                  ],
                ),
              )
            else if (_data != null) ...[
              if (_data!.isApproved)
                _statusBanner(
                  c,
                  icon: Icons.verified_rounded,
                  title: 'verification_status_approved'.tr,
                  subtitle: 'verification_approved_desc'.tr,
                  color: c.accent,
                )
              else if (_data!.isPending)
                _statusBanner(
                  c,
                  icon: Icons.hourglass_top_rounded,
                  title: 'verification_status_pending'.tr,
                  subtitle: 'verification_pending_desc'.tr,
                  color: c.textSecondary,
                )
              else if (_data!.status == 'rejected')
                _statusBanner(
                  c,
                  icon: Icons.error_outline_rounded,
                  title: 'verification_status_rejected'.tr,
                  subtitle: (_data!.adminNote?.trim().isNotEmpty == true)
                      ? _data!.adminNote!
                      : 'verification_rejected_desc'.tr,
                  color: c.danger,
                ),
              if (_data!.missingRequired.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.fromLTRB(20.dp, 12.dp, 20.dp, 4.dp),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'verification_missing_required'.tr,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.42,
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(16.dp, 8.dp, 16.dp, 16.dp),
                  itemCount: _data!.items.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8.dp),
                  itemBuilder: (context, i) {
                    final item = _data!.items[i];
                    return _DocTile(
                      item: item,
                      busy: _uploadingType == item['type'],
                      canUpload: _data!.canUpload && !_busy,
                      onUpload: () => _upload(item['type']?.toString() ?? ''),
                    );
                  },
                ),
              ),
              if (!_data!.isApproved && !_data!.isPending)
                Padding(
                  padding: EdgeInsets.fromLTRB(16.dp, 0, 16.dp, 16.dp),
                  child: RichButton(
                    text: _busy
                        ? 'verification_submitting'.tr
                        : 'verification_submit'.tr,
                    onTap: _submit,
                    enabled: _data!.canSubmit && !_busy,
                    isLoading: _busy,
                    textColor: c.onAccent,
                    textStyle: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: c.onAccent,
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14.dp),
                    borderRadius: BorderRadius.circular(14.dp),
                    decoration: BoxDecoration(
                      gradient: _data!.canSubmit
                          ? limeButtonGradient
                          : null,
                      color: _data!.canSubmit ? null : c.surfaceBorder,
                      borderRadius: BorderRadius.circular(14.dp),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBanner(
    AppColors c, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(16.dp, 12.dp, 16.dp, 4.dp),
      padding: EdgeInsets.all(14.dp),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14.dp),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22.dp),
          SizedBox(width: 10.dp),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4.dp),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12.sp,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool busy;
  final bool canUpload;
  final VoidCallback onUpload;

  const _DocTile({
    required this.item,
    required this.busy,
    required this.canUpload,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final required = item['required'] == true;
    final uploaded = item['uploaded'] == true;
    final label = item['label']?.toString() ?? item['type']?.toString() ?? '';
    final badge = required
        ? 'verification_required'.tr
        : 'verification_recommended'.tr;

    return Material(
      color: c.background,
      borderRadius: BorderRadius.circular(14.dp),
      child: InkWell(
        onTap: canUpload && !uploaded ? onUpload : null,
        borderRadius: BorderRadius.circular(14.dp),
        child: Container(
          padding: EdgeInsets.all(14.dp),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.dp),
            border: Border.all(
              color: uploaded
                  ? c.accent.withValues(alpha: 0.45)
                  : required
                      ? c.danger.withValues(alpha: 0.35)
                      : c.surfaceBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40.dp,
                height: 40.dp,
                decoration: BoxDecoration(
                  color: uploaded
                      ? c.accent.withValues(alpha: 0.15)
                      : c.surface,
                  borderRadius: BorderRadius.circular(12.dp),
                ),
                child: busy
                    ? Padding(
                        padding: EdgeInsets.all(10.dp),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.accent,
                        ),
                      )
                    : Icon(
                        uploaded
                            ? Icons.check_circle_rounded
                            : Icons.upload_file_rounded,
                        color: uploaded ? c.accent : c.textSecondary,
                        size: 22.dp,
                      ),
              ),
              SizedBox(width: 12.dp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.dp),
                    Text(
                      uploaded
                          ? 'verification_doc_ok'.tr
                          : badge,
                      style: TextStyle(
                        color: uploaded
                            ? c.accentText
                            : required
                                ? c.danger
                                : c.textFaint,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (canUpload && !uploaded)
                Icon(Icons.add_a_photo_outlined, color: c.accent, size: 20.dp),
            ],
          ),
        ),
      ),
    );
  }
}
