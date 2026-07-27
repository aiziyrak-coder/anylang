import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/core/mappers.dart';
import '../../data/network/support_repository.dart';
import '../screens/support_chat/support_history_session.dart';
import '../ui/theme/colors.dart';
import '../utils/app_snackbar.dart';
import '../utils/size_controller.dart';

Future<void> showSupportHistoryBottomSheet(
  BuildContext context, {
  required void Function(int sessionId) onOpenSession,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _SupportHistorySheet(onOpenSession: onOpenSession),
  );
}

class _SupportHistorySheet extends StatefulWidget {
  final void Function(int sessionId) onOpenSession;

  const _SupportHistorySheet({required this.onOpenSession});

  @override
  State<_SupportHistorySheet> createState() => _SupportHistorySheetState();
}

class _SupportHistorySheetState extends State<_SupportHistorySheet> {
  final List<SupportHistorySession> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await Get.find<SupportRepository>().listSessions(limit: 50);
    final map = asMap(result.dataOrNull);
    final list = map?['items'];
    final parsed = <SupportHistorySession>[];
    if (list is List) {
      for (final raw in list) {
        final m = asMap(raw);
        if (m == null) continue;
        final s = SupportHistorySession.fromJson(m);
        if (s.id > 0) parsed.add(s);
      }
    }
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(parsed);
      _loading = false;
    });
    if (result.errorOrNull != null && parsed.isEmpty) {
      showAppError(result.errorOrNull);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.dp)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.dp, 16.dp, 20.dp, 8.dp),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'support_history_title'.tr,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: c.textSecondary),
                ),
              ],
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else if (_items.isEmpty)
            Padding(
              padding: EdgeInsets.all(32.dp),
              child: Text(
                'support_history_empty'.tr,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(12.dp, 0, 12.dp, 24.dp),
                itemCount: _items.length,
                separatorBuilder: (_, __) => SizedBox(height: 6.dp),
                itemBuilder: (_, i) {
                  final s = _items[i];
                  final badge = s.isActive
                      ? 'support_history_active'.tr
                      : 'support_history_completed'.tr;
                  final preview = (s.preview ?? '').trim();
                  final subtitle = preview.isNotEmpty
                      ? preview
                      : (s.rating != null ? '★' * s.rating! : badge);
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        widget.onOpenSession(s.id);
                      },
                      borderRadius: BorderRadius.circular(14.dp),
                      child: Container(
                        padding: EdgeInsets.all(14.dp),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14.dp),
                          border: Border.all(color: c.surfaceBorder, width: 0.7),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    badge,
                                    style: TextStyle(
                                      color: s.isActive ? c.accent : c.textFaint,
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 4.dp),
                                  Text(
                                    subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: c.textPrimary,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (s.updatedAt != null)
                              Text(
                                formatChatTime(s.updatedAt),
                                style: TextStyle(
                                  color: c.textFaint,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
