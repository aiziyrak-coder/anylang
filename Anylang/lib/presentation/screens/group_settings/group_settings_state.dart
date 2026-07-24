import 'package:get/get.dart';

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
}
