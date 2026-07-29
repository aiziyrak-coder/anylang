import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../ui/app_loading.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

class ChatSummaryData {
  final String title;
  final List<String> bullets;
  final int messageCount;
  final int coveredCount;
  final String? latestTopic;
  final bool latestTopicIsGreetingOnly;
  final String? previousTopic;

  const ChatSummaryData({
    required this.title,
    required this.bullets,
    this.messageCount = 0,
    this.coveredCount = 0,
    this.latestTopic,
    this.latestTopicIsGreetingOnly = false,
    this.previousTopic,
  });

  factory ChatSummaryData.fromApi(Map<String, dynamic> map) {
    final raw = map['bullets'];
    final bullets = raw is List
        ? raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    final latest = map['latest_topic']?.toString().trim();
    final previous = map['previous_topic']?.toString().trim();
    return ChatSummaryData(
      title: (map['title']?.toString().trim().isNotEmpty == true)
          ? map['title'].toString().trim()
          : 'chat_summary_title'.tr,
      bullets: bullets,
      messageCount: (map['message_count'] as num?)?.toInt() ?? 0,
      coveredCount: (map['covered_count'] as num?)?.toInt() ?? 0,
      latestTopic: (latest != null && latest.isNotEmpty) ? latest : null,
      latestTopicIsGreetingOnly:
          map['latest_topic_is_greeting_only'] == true,
      previousTopic:
          (previous != null && previous.isNotEmpty) ? previous : null,
    );
  }

  String get latestTopicDisplay {
    if (latestTopicIsGreetingOnly) {
      return 'chat_summary_no_important_topic'.tr;
    }
    return latestTopic ?? '';
  }

  bool get hasLatestTopic =>
      latestTopicIsGreetingOnly ||
      (latestTopic != null && latestTopic!.trim().isNotEmpty);

  bool get hasPreviousTopic =>
      previousTopic != null && previousTopic!.trim().isNotEmpty;

  String get copyText {
    final buf = StringBuffer(title);
    for (final b in bullets) {
      buf.writeln();
      buf.write('• $b');
    }
    if (hasLatestTopic) {
      buf.writeln();
      buf.writeln();
      buf.writeln('chat_summary_latest_topic'.tr);
      buf.write(latestTopicDisplay);
    }
    if (hasPreviousTopic) {
      buf.writeln();
      buf.writeln();
      buf.writeln('chat_summary_previous_topic'.tr);
      buf.write(previousTopic);
    }
    return buf.toString();
  }
}

Future<void> showChatSummaryBottomSheet(
  BuildContext context, {
  required Future<ChatSummaryData?> Function() load,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _ChatSummarySheet(load: load),
  );
}

class _ChatSummarySheet extends StatefulWidget {
  final Future<ChatSummaryData?> Function() load;

  const _ChatSummarySheet({required this.load});

  @override
  State<_ChatSummarySheet> createState() => _ChatSummarySheetState();
}

class _ChatSummarySheetState extends State<_ChatSummarySheet> {
  ChatSummaryData? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        if (data == null || data.bullets.isEmpty) {
          _error = 'chat_summary_empty'.tr;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
      ),
      padding: EdgeInsets.fromLTRB(20.dp, 12.dp, 20.dp, 24.dp),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44.dp,
                height: 5.dp,
                decoration: BoxDecoration(
                  color: c.outline,
                  borderRadius: BorderRadius.circular(5.dp),
                ),
              ),
            ),
            SizedBox(height: 14.dp),
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: c.accentText, size: 22.dp),
                SizedBox(width: 8.dp),
                Expanded(
                  child: Text(
                    'chat_summary_sheet_title'.tr,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_data != null && _data!.bullets.isNotEmpty)
                  Material(
                    color: c.accentSoft,
                    borderRadius: BorderRadius.circular(10.dp),
                    child: InkWell(
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(text: _data!.copyText),
                        );
                        Get.snackbar('AnyLang', 'chat_summary_copied'.tr);
                      },
                      borderRadius: BorderRadius.circular(10.dp),
                      child: Padding(
                        padding: EdgeInsets.all(8.dp),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 18.dp,
                          color: c.accentText,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (_data != null && _data!.messageCount > 0) ...[
              SizedBox(height: 6.dp),
              Text(
                'chat_summary_meta'.trParams({
                  'n': '${_data!.messageCount}',
                  'm': '${_data!.coveredCount}',
                }),
                style: TextStyle(color: c.textSecondary, fontSize: 12.sp),
              ),
            ],
            SizedBox(height: 14.dp),
            if (_loading)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 36.dp),
                child: AppLoading(message: 'chat_summary_loading'.tr),
              )
            else if (_error != null)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24.dp),
                child: Column(
                  children: [
                    Text(
                      _error.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textSecondary, fontSize: 14.sp),
                    ),
                    SizedBox(height: 12.dp),
                    TextButton(
                      onPressed: _run,
                      child: Text('chat_summary_retry'.tr),
                    ),
                  ],
                ),
              )
            else ...[
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Text(
                      _data!.title,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 12.dp),
                    for (var i = 0; i < _data!.bullets.length; i++) ...[
                      if (i > 0) SizedBox(height: 10.dp),
                      _bulletRow(c, _data!.bullets[i]),
                    ],
                    if (_data!.hasLatestTopic) ...[
                      SizedBox(height: 20.dp),
                      _topicBlock(
                        c,
                        title: 'chat_summary_latest_topic'.tr,
                        body: _data!.latestTopicDisplay,
                      ),
                    ],
                    if (_data!.hasPreviousTopic) ...[
                      SizedBox(height: 16.dp),
                      _topicBlock(
                        c,
                        title: 'chat_summary_previous_topic'.tr,
                        body: _data!.previousTopic!,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bulletRow(AppColors c, String bullet) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(top: 6.dp),
          width: 7.dp,
          height: 7.dp,
          decoration: BoxDecoration(
            color: c.accent,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 10.dp),
        Expanded(
          child: Text(
            bullet,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 14.sp,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _topicBlock(
    AppColors c, {
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.dp),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(14.dp),
        border: Border.all(color: c.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.dp),
          Text(
            body,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13.sp,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
