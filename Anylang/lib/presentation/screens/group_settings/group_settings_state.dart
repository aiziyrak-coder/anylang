import 'package:get/get.dart';

import '../group_catalog/group_catalog_models.dart';

class GroupMemberVm {
  final int userId;
  final String fullName;
  final String role;
  final String? avatarUrl;
  final bool isOnline;
  final String? number;

  const GroupMemberVm({
    required this.userId,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.isOnline = false,
    this.number,
  });

  factory GroupMemberVm.fromApi(Map<String, dynamic> json) {
    return GroupMemberVm(
      userId: (json['user_id'] as num).toInt(),
      fullName: json['full_name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'member',
      avatarUrl: json['avatar_url']?.toString(),
      isOnline: json['is_online'] == true,
      number: json['number']?.toString(),
    );
  }
}

/// 0 Azolar · 1 Media · 2 Products · 3 Documents · 4 Companies
class GroupSettingsState extends GetxController {
  int chatId = 0;
  final RxString title = ''.obs;
  final RxnString avatarUrl = RxnString();
  final RxnString myRole = RxnString();
  final RxBool isSuper = false.obs;
  final RxnString inviteLink = RxnString();
  final RxnInt memberLimit = RxnInt();
  final RxList<GroupMemberVm> members = <GroupMemberVm>[].obs;
  final RxBool loading = true.obs;
  final RxBool saving = false.obs;

  final RxInt tabIndex = 0.obs;

  final RxList<GroupCatalogProduct> products = <GroupCatalogProduct>[].obs;
  final RxList<GroupCatalogDocument> documents = <GroupCatalogDocument>[].obs;
  final RxList<GroupCatalogCompany> companies = <GroupCatalogCompany>[].obs;
  final RxBool catalogLoading = false.obs;
  final RxBool catalogLoaded = false.obs;

  final RxList<Map<String, dynamic>> mediaItems = <Map<String, dynamic>>[].obs;
  final RxMap<String, int> mediaCounts = <String, int>{}.obs;
  final RxBool mediaLoading = false.obs;
  final RxBool mediaLoaded = false.obs;
}
