import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/core/mappers.dart';
import '../../data/local/session_store.dart';
import '../../data/network/profile_repository.dart';
import '../ui/buttons/primary_button.dart';
import '../ui/buttons/secondary_button.dart';
import '../ui/theme/colors.dart';
import '../utils/app_snackbar.dart';
import '../utils/size_controller.dart';

class CompanyReviewItem {
  final int id;
  final String authorName;
  final int rating;
  final String text;
  final String status;
  final String moderationNote;
  final String companyReply;

  const CompanyReviewItem({
    required this.id,
    required this.authorName,
    required this.rating,
    required this.text,
    required this.status,
    this.moderationNote = '',
    this.companyReply = '',
  });

  factory CompanyReviewItem.fromApi(Map<String, dynamic> json) {
    return CompanyReviewItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      authorName: (json['author_name'] as String?)?.trim() ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      text: (json['text'] as String?)?.trim() ?? '',
      status: (json['status'] as String?) ?? 'approved',
      moderationNote: (json['moderation_note'] as String?)?.trim() ?? '',
      companyReply: (json['company_reply'] as String?)?.trim() ?? '',
    );
  }
}

/// Kompaniya otzivlari: ko‘rish + (boshqa biznes uchun) yozish + egasi javobi.
Future<void> showCompanyReviewsBottomSheet(
  BuildContext context, {
  required int businessUserId,
  required String companyName,
  double? rating,
  int reviewsCount = 0,
  bool canWrite = false,
  bool canReply = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return _CompanyReviewsSheet(
        businessUserId: businessUserId,
        companyName: companyName,
        rating: rating,
        reviewsCount: reviewsCount,
        canWrite: canWrite,
        canReply: canReply,
      );
    },
  );
}

class _CompanyReviewsSheet extends StatefulWidget {
  final int businessUserId;
  final String companyName;
  final double? rating;
  final int reviewsCount;
  final bool canWrite;
  final bool canReply;

  const _CompanyReviewsSheet({
    required this.businessUserId,
    required this.companyName,
    required this.rating,
    required this.reviewsCount,
    required this.canWrite,
    required this.canReply,
  });

  @override
  State<_CompanyReviewsSheet> createState() => _CompanyReviewsSheetState();
}

class _CompanyReviewsSheetState extends State<_CompanyReviewsSheet> {
  final _textCtrl = TextEditingController();
  final _replyCtrl = TextEditingController();
  var _loading = true;
  var _submitting = false;
  var _replying = false;
  var _writing = false;
  var _stars = 5;
  int? _replyingToId;
  String? _error;
  double? _avg;
  var _count = 0;
  final _items = <CompanyReviewItem>[];
  CompanyReviewItem? _mine;

  @override
  void initState() {
    super.initState();
    _avg = widget.rating;
    _count = widget.reviewsCount;
    unawaited(_load());
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await Get.find<ProfileRepository>().listCompanyReviews(
      widget.businessUserId,
    );
    final map = asMap(result.dataOrNull);
    if (!mounted) return;
    if (map == null) {
      setState(() {
        _loading = false;
        _error = result.errorOrNull?.toString() ?? 'error'.tr;
      });
      return;
    }
    final items = <CompanyReviewItem>[];
    for (final e in asList(map['items'])) {
      if (e is Map) {
        items.add(CompanyReviewItem.fromApi(Map<String, dynamic>.from(e)));
      }
    }
    CompanyReviewItem? mine;
    final rawMine = map['my_review'];
    if (rawMine is Map) {
      mine = CompanyReviewItem.fromApi(Map<String, dynamic>.from(rawMine));
      _stars = mine.rating.clamp(1, 5);
      _textCtrl.text = mine.text;
    }
    setState(() {
      _loading = false;
      _items
        ..clear()
        ..addAll(items);
      _mine = mine;
      _avg = (map['average_rating'] as num?)?.toDouble() ?? _avg;
      _count = (map['reviews_count'] as num?)?.toInt() ?? _count;
    });
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (text.length < 3) {
      showAppError('company_review_text_required'.tr);
      return;
    }
    setState(() => _submitting = true);
    final result = await Get.find<ProfileRepository>().submitCompanyReview(
      widget.businessUserId,
      rating: _stars,
      text: text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.dataOrNull != null) {
      showAppMessage('company_review_submitted'.tr);
      setState(() => _writing = false);
      await _load();
      return;
    }
    showAppError(result.errorOrNull);
  }

  Future<void> _submitReply(int reviewId) async {
    final text = _replyCtrl.text.trim();
    if (text.length < 2) {
      showAppError('company_review_reply_required'.tr);
      return;
    }
    setState(() => _replying = true);
    final result = await Get.find<ProfileRepository>().replyCompanyReview(
      widget.businessUserId,
      reviewId,
      text: text,
    );
    if (!mounted) return;
    setState(() => _replying = false);
    if (result.dataOrNull != null) {
      showAppMessage('company_review_reply_sent'.tr);
      setState(() {
        _replyingToId = null;
        _replyCtrl.clear();
      });
      await _load();
      return;
    }
    showAppError(result.errorOrNull);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final me = SessionStore.userId();
    final canWrite = widget.canWrite &&
        me != null &&
        me != widget.businessUserId;
    final canReply = widget.canReply &&
        me != null &&
        me == widget.businessUserId;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
        border: Border(top: BorderSide(color: c.surfaceBorder, width: 0.7)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.dp, 10.dp, 20.dp, 16.dp + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.dp,
                height: 4.dp,
                decoration: BoxDecoration(
                  color: c.outline,
                  borderRadius: BorderRadius.circular(99.dp),
                ),
              ),
              SizedBox(height: 14.dp),
              Text(
                'company_reviews_title'.tr,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4.dp),
              Text(
                widget.companyName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12.dp),
              Text(
                (_avg != null && _avg! > 0) ? _avg!.toStringAsFixed(1) : '—',
                style: TextStyle(
                  color: (_avg != null && _avg! > 0) ? c.accentText : c.textFaint,
                  fontSize: 36.sp,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              SizedBox(height: 6.dp),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    Icon(
                      (_avg ?? 0) >= i
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: c.accentText,
                      size: 22.dp,
                    ),
                ],
              ),
              SizedBox(height: 6.dp),
              Text(
                _count > 0
                    ? 'profile_rating_detail_reviews'.trParams({'n': '$_count'})
                    : 'profile_rating_detail_empty'.tr,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_mine != null && _mine!.status != 'approved') ...[
                SizedBox(height: 10.dp),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10.dp),
                  decoration: BoxDecoration(
                    color: _mine!.status == 'rejected'
                        ? kListenRed.withValues(alpha: 0.12)
                        : c.accentSoft,
                    borderRadius: BorderRadius.circular(12.dp),
                  ),
                  child: Text(
                    _mine!.status == 'rejected'
                        ? 'company_review_rejected_reason'.trParams({
                            'reason': _mine!.moderationNote.isEmpty
                                ? '—'
                                : _mine!.moderationNote,
                          })
                        : 'company_review_pending_hint'.tr,
                    style: TextStyle(
                      color: _mine!.status == 'rejected'
                          ? kListenRed
                          : c.accentText,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              SizedBox(height: 12.dp),
              if (_writing && canWrite) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20.dp),
                          onTap: () => setState(() => _stars = i),
                          child: Padding(
                            padding: EdgeInsets.all(4.dp),
                            child: Icon(
                              i <= _stars
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: c.accentText,
                              size: 32.dp,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 8.dp),
                TextField(
                  controller: _textCtrl,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    hintText: 'company_review_hint'.tr,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.dp),
                    ),
                  ),
                ),
                SizedBox(height: 8.dp),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        text: 'cancel'.tr,
                        onTap: () => setState(() => _writing = false),
                      ),
                    ),
                    SizedBox(width: 10.dp),
                    Expanded(
                      child: PrimaryButton(
                        text: 'company_review_submit'.tr,
                        isLoading: _submitting,
                        onTap: _submit,
                      ),
                    ),
                  ],
                ),
              ] else if (canWrite) ...[
                PrimaryButton(
                  text: (_mine != null && _mine!.status == 'rejected')
                      ? 'company_review_resubmit'.tr
                      : (_mine != null && _mine!.status == 'pending')
                          ? 'company_review_edit_pending'.tr
                          : 'company_review_write'.tr,
                  onTap: () => setState(() => _writing = true),
                ),
                SizedBox(height: 10.dp),
              ],
              if (_loading)
                Padding(
                  padding: EdgeInsets.all(24.dp),
                  child: const CircularProgressIndicator(),
                )
              else if (_error != null)
                Padding(
                  padding: EdgeInsets.all(16.dp),
                  child: Text(_error!, style: TextStyle(color: kListenRed)),
                )
              else
                Flexible(
                  child: _items.isEmpty
                      ? Padding(
                          padding: EdgeInsets.symmetric(vertical: 20.dp),
                          child: Text(
                            'company_reviews_empty'.tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: c.textFaint,
                              fontSize: 13.sp,
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 20.dp,
                            color: c.surfaceBorder,
                          ),
                          itemBuilder: (_, i) {
                            final r = _items[i];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        r.authorName.isEmpty
                                            ? '—'
                                            : r.authorName,
                                        style: TextStyle(
                                          color: c.textPrimary,
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        for (var s = 1; s <= 5; s++)
                                          Icon(
                                            s <= r.rating
                                                ? Icons.star_rounded
                                                : Icons.star_outline_rounded,
                                            size: 14.dp,
                                            color: c.accentText,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(height: 6.dp),
                                Text(
                                  r.text,
                                  style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 13.sp,
                                    height: 1.35,
                                  ),
                                ),
                                if (r.companyReply.isNotEmpty) ...[
                                  SizedBox(height: 8.dp),
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(10.dp),
                                    decoration: BoxDecoration(
                                      color: c.accentSoft,
                                      borderRadius: BorderRadius.circular(10.dp),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'company_review_reply_label'.tr,
                                          style: TextStyle(
                                            color: c.accentText,
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        SizedBox(height: 4.dp),
                                        Text(
                                          r.companyReply,
                                          style: TextStyle(
                                            color: c.textPrimary,
                                            fontSize: 13.sp,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (canReply) ...[
                                  SizedBox(height: 6.dp),
                                  if (_replyingToId == r.id) ...[
                                    TextField(
                                      controller: _replyCtrl,
                                      maxLines: 3,
                                      maxLength: 1000,
                                      decoration: InputDecoration(
                                        hintText:
                                            'company_review_reply_hint'.tr,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12.dp),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 6.dp),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SecondaryButton(
                                            text: 'cancel'.tr,
                                            onTap: () => setState(() {
                                              _replyingToId = null;
                                              _replyCtrl.clear();
                                            }),
                                          ),
                                        ),
                                        SizedBox(width: 10.dp),
                                        Expanded(
                                          child: PrimaryButton(
                                            text:
                                                'company_review_reply_submit'.tr,
                                            isLoading: _replying,
                                            onTap: () => _submitReply(r.id),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(8.dp),
                                          onTap: () => setState(() {
                                            _replyingToId = r.id;
                                            _replyCtrl.text = r.companyReply;
                                          }),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 4.dp,
                                              vertical: 4.dp,
                                            ),
                                            child: Text(
                                              r.companyReply.isEmpty
                                                  ? 'company_review_reply'
                                                      .tr
                                                  : 'company_review_reply_edit'
                                                      .tr,
                                              style: TextStyle(
                                                color: c.accentText,
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            );
                          },
                        ),
                        ),
            ],
          ),
        ),
      ),
    );
  }
}
