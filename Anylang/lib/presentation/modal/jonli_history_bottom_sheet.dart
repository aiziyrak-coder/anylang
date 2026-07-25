import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/core/mappers.dart';
import '../../data/network/live_repository.dart';
import '../screens/jonli/jonli_history_session.dart';
import '../ui/buttons/primary_button.dart';
import '../ui/buttons/rich_button.dart';
import '../ui/search_field.dart';
import '../ui/theme/colors.dart';
import '../utils/app_snackbar.dart';
import '../utils/formatters/time_formatter.dart';
import '../utils/size_controller.dart';

Future<void> showJonliHistoryBottomSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _JonliHistorySheet(),
  );
}

class _JonliHistorySheet extends StatefulWidget {
  const _JonliHistorySheet();

  @override
  State<_JonliHistorySheet> createState() => _JonliHistorySheetState();
}

class _JonliHistorySheetState extends State<_JonliHistorySheet> {
  final List<JonliHistorySession> _items = [];
  bool _loading = true;
  bool _exporting = false;
  String _query = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await Get.find<LiveRepository>().sessions(
      today: true,
      q: _query,
      limit: 50,
    );
    final map = asMap(result.dataOrNull);
    final list = map?['items'];
    final parsed = <JonliHistorySession>[];
    if (list is List) {
      for (final raw in list) {
        final m = asMap(raw);
        if (m == null) continue;
        final s = JonliHistorySession.fromJson(m);
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

  void _onSearch(String v) {
    _query = v;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _export(String format, {int? sessionId}) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await Get.find<LiveRepository>().exportBytes(
        format: format,
        today: true,
        sessionId: sessionId,
      );
      if (bytes == null || bytes.isEmpty) {
        showAppError('jonli_export_failed'.tr);
        return;
      }
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final name = sessionId == null
          ? 'anylang_jonli_today_$stamp.$format'
          : 'anylang_jonli_${sessionId}_$stamp.$format';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'jonli_history_title'.tr,
      );
    } catch (e) {
      showAppError(e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final h = MediaQuery.sizeOf(context).height * 0.88;

    return Container(
      height: h,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.dp)),
      ),
      padding: EdgeInsets.fromLTRB(16.dp, 10.dp, 16.dp, 12.dp + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40.dp,
              height: 4.dp,
              decoration: BoxDecoration(
                color: c.outline,
                borderRadius: BorderRadius.circular(99.dp),
              ),
            ),
          ),
          SizedBox(height: 12.dp),
          Text(
            'jonli_history_title'.tr,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.dp),
          Text(
            'jonli_history_today'.tr,
            style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
          ),
          SizedBox(height: 12.dp),
          SearchField(
            hint: 'jonli_history_search'.tr,
            onChanged: _onSearch,
          ),
          SizedBox(height: 12.dp),
          Row(
            children: [
              Expanded(
                child: RichButton(
                  text: 'jonli_export_txt'.tr,
                  onTap: () => _export('txt'),
                  enabled: !_exporting,
                  isLoading: _exporting,
                  loadingCircleColor: c.textPrimary,
                  textColor: c.textPrimary,
                  borderRadius: BorderRadius.circular(14.dp),
                  decoration: BoxDecoration(
                    color: c.background,
                    borderRadius: BorderRadius.circular(14.dp),
                    border: Border.all(color: c.outline),
                  ),
                ),
              ),
              SizedBox(width: 10.dp),
              Expanded(
                child: PrimaryButton(
                  text: 'jonli_export_pdf'.tr,
                  onTap: () => _export('pdf'),
                  enabled: !_exporting,
                  isLoading: _exporting,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.dp),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Text(
                          'jonli_history_empty'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 14.sp,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => SizedBox(height: 8.dp),
                        itemBuilder: (_, i) => _sessionTile(c, _items[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _sessionTile(AppColors c, JonliHistorySession s) {
    final time = formatIsoDateToHHmm(s.startedAt.toUtc().toIso8601String());
    final langs =
        '${s.myLanguage.toUpperCase()} ↔ ${s.otherLanguage.toUpperCase()}';
    return Material(
      color: c.background,
      borderRadius: BorderRadius.circular(14.dp),
      child: InkWell(
        borderRadius: BorderRadius.circular(14.dp),
        onTap: () => _export('txt', sessionId: s.id),
        onLongPress: () => _export('pdf', sessionId: s.id),
        child: Container(
          padding: EdgeInsets.all(12.dp),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.dp),
            border: Border.all(color: c.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    time.isEmpty ? '—' : time,
                    style: TextStyle(
                      color: c.accent,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 8.dp),
                  Text(
                    langs,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'jonli_history_turns'.trParams({'n': '${s.turnCount}'}),
                    style: TextStyle(color: c.textFaint, fontSize: 11.sp),
                  ),
                ],
              ),
              if ((s.preview ?? '').isNotEmpty) ...[
                SizedBox(height: 6.dp),
                Text(
                  s.preview!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13.sp,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
