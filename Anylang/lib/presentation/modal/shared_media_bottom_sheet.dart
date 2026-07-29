import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/core/mappers.dart';
import '../../data/network/chat_repository.dart';
import 'full_screen_image_dialog.dart';
import 'product_video_dialog.dart';
import '../ui/theme/colors.dart';
import '../utils/app_snackbar.dart';
import '../utils/size_controller.dart';

/// Telegram uslubidagi Shared Media: rasmlar, video, fayl, audio, link, ovoz.
Future<void> showSharedMediaBottomSheet(
  BuildContext context, {
  required int chatId,
  required String title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (ctx) => _SharedMediaSheet(chatId: chatId, title: title),
  );
}

class _SharedMediaSheet extends StatefulWidget {
  final int chatId;
  final String title;

  const _SharedMediaSheet({required this.chatId, required this.title});

  @override
  State<_SharedMediaSheet> createState() => _SharedMediaSheetState();
}

class _SharedMediaSheetState extends State<_SharedMediaSheet> {
  bool _loading = true;
  String _section = 'summary';
  Map<String, int> _counts = const {};
  List<Map<String, dynamic>> _items = const [];
  bool _hasMore = false;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load(section: 'summary');
  }

  Future<void> _load({required String section, int? beforeId}) async {
    if (beforeId == null) {
      setState(() {
        _loading = true;
        _section = section;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    final result = await Get.find<ChatRepository>().sharedMedia(
      widget.chatId,
      section: section,
      beforeId: beforeId,
    );
    if (!mounted) return;
    result.when(
      success: (data) {
        final map = asMap(data) ?? {};
        final countsRaw = asMap(map['counts']) ?? {};
        final counts = <String, int>{
          for (final e in countsRaw.entries)
            e.key: (e.value as num?)?.toInt() ?? 0,
        };
        final rawItems = asList(map['items'])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        setState(() {
          _counts = counts;
          if (beforeId == null) {
            _items = rawItems;
          } else {
            _items = [..._items, ...rawItems];
          }
          _hasMore = map['has_more'] == true;
          _loading = false;
          _loadingMore = false;
          _section = section;
        });
      },
      failure: (err) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
        showAppError(err);
      },
    );
  }

  int _c(String key) => _counts[key] ?? 0;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final h = MediaQuery.sizeOf(context).height * 0.88;
    return Container(
      height: h,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.dp)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(8.dp, 10.dp, 8.dp, 4.dp),
            child: Row(
              children: [
                if (_section != 'summary')
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: c.textPrimary),
                    onPressed: () => _load(section: 'summary'),
                  )
                else
                  SizedBox(width: 48.dp),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _section == 'summary'
                            ? widget.title
                            : _sectionTitle(_section),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_section == 'summary')
                        Text(
                          'shared_media_chats_count'.trParams({
                            'n': '${_c('total_messages')}',
                          }),
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12.sp,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: c.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.surfaceBorder),
          Expanded(
            child: _loading
                ? Center(
                    child: SizedBox(
                      width: 28.dp,
                      height: 28.dp,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: c.accent,
                      ),
                    ),
                  )
                : (_section == 'summary'
                    ? _summaryList(c)
                    : _sectionList(c)),
          ),
        ],
      ),
    );
  }

  Widget _summaryList(AppColors c) {
    final rows = <(String, IconData, String, int)>[
      ('photos', Icons.image_outlined, 'shared_media_photos'.tr, _c('photos')),
      ('videos', Icons.videocam_outlined, 'shared_media_videos'.tr, _c('videos')),
      ('files', Icons.insert_drive_file_outlined, 'shared_media_files'.tr, _c('files')),
      ('audio', Icons.headphones_outlined, 'shared_media_audio'.tr, _c('audio')),
      ('links', Icons.link_rounded, 'shared_media_links'.tr, _c('links')),
      ('voice', Icons.mic_none_rounded, 'shared_media_voice'.tr, _c('voice')),
    ];
    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 8.dp),
      itemCount: rows.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: c.surfaceBorder),
      itemBuilder: (ctx, i) {
        final (sec, icon, label, count) = rows[i];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: count <= 0 ? null : () => _load(section: sec),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 18.dp, vertical: 14.dp),
              child: Row(
                children: [
                  Icon(icon, color: c.textPrimary, size: 24.dp),
                  SizedBox(width: 14.dp),
                  Expanded(
                    child: Text(
                      '$count $label',
                      style: TextStyle(
                        color: count > 0 ? c.textPrimary : c.textFaint,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (count > 0)
                    Icon(Icons.chevron_right_rounded, color: c.textFaint),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionList(AppColors c) {
    if (_items.isEmpty) {
      return Center(
        child: Text(
          'shared_media_empty'.tr,
          style: TextStyle(color: c.textSecondary, fontSize: 14.sp),
        ),
      );
    }
    if (_section == 'photos' || _section == 'videos') {
      return GridView.builder(
        padding: EdgeInsets.all(10.dp),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4.dp,
          crossAxisSpacing: 4.dp,
        ),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i >= _items.length) {
            if (!_loadingMore) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final lastId = (_items.last['id'] as num?)?.toInt();
                if (lastId != null) {
                  _load(section: _section, beforeId: lastId);
                }
              });
            }
            return Center(
              child: SizedBox(
                width: 22.dp,
                height: 22.dp,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
              ),
            );
          }
          final item = _items[i];
          final url = item['url']?.toString() ?? '';
          final isVideo = _section == 'videos';
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                if (url.isEmpty) return;
                if (isVideo) {
                  await showProductVideoDialog(
                    context,
                    url: url,
                    maxPlay: null,
                  );
                } else {
                  await showFullScreenImage(context, url: url);
                }
              },
              child: Ink(
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(8.dp),
                  image: (!isVideo && url.isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(url),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: isVideo
                    ? Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: c.accent,
                          size: 36.dp,
                        ),
                      )
                    : null,
              ),
            ),
          );
        },
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 6.dp),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, _) => Divider(height: 1, color: c.surfaceBorder),
      itemBuilder: (ctx, i) {
        if (i >= _items.length) {
          if (!_loadingMore) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final lastId = (_items.last['id'] as num?)?.toInt();
              if (lastId != null) _load(section: _section, beforeId: lastId);
            });
          }
          return Padding(
            padding: EdgeInsets.all(16.dp),
            child: Center(
              child: SizedBox(
                width: 22.dp,
                height: 22.dp,
                child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
              ),
            ),
          );
        }
        final item = _items[i];
        final title = item['title']?.toString() ??
            item['url']?.toString() ??
            item['text']?.toString() ??
            '—';
        final subtitle = item['subtitle']?.toString();
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              final url = item['url']?.toString() ?? '';
              if (url.isEmpty) return;
              if (_section == 'links' || url.startsWith('http')) {
                final uri = Uri.tryParse(url);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.dp, vertical: 12.dp),
              child: Row(
                children: [
                  Icon(
                    _sectionIcon(_section),
                    color: c.accentText,
                    size: 22.dp,
                  ),
                  SizedBox(width: 12.dp),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 12.sp,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _sectionTitle(String section) => switch (section) {
        'photos' => 'shared_media_photos_title'.tr,
        'videos' => 'shared_media_videos_title'.tr,
        'files' => 'shared_media_files_title'.tr,
        'audio' => 'shared_media_audio_title'.tr,
        'links' => 'shared_media_links_title'.tr,
        'voice' => 'shared_media_voice_title'.tr,
        _ => 'shared_media_title'.tr,
      };

  IconData _sectionIcon(String section) => switch (section) {
        'files' => Icons.insert_drive_file_outlined,
        'audio' => Icons.headphones_outlined,
        'links' => Icons.link_rounded,
        'voice' => Icons.mic_none_rounded,
        _ => Icons.folder_outlined,
      };
}
