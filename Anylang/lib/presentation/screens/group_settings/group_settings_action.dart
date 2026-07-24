import '../../utils/screen_options/my_action.dart';

class GroupSettingsAction extends MyAction {}

class SaveGroupTitle extends GroupSettingsAction {
  final String title;
  SaveGroupTitle(this.title);
}

class PickGroupAvatar extends GroupSettingsAction {}

class ReloadMembers extends GroupSettingsAction {}

class RemoveGroupMember extends GroupSettingsAction {
  final int userId;
  RemoveGroupMember(this.userId);
}

class PromoteGroupAdmin extends GroupSettingsAction {
  final int userId;
  PromoteGroupAdmin(this.userId);
}

class DemoteGroupAdmin extends GroupSettingsAction {
  final int userId;
  DemoteGroupAdmin(this.userId);
}

class LeaveGroupAction extends GroupSettingsAction {}

class TransferOwnershipAction extends GroupSettingsAction {
  final int userId;
  TransferOwnershipAction(this.userId);
}

class DeleteGroupAction extends GroupSettingsAction {}

class CopyInviteLink extends GroupSettingsAction {}

class RegenerateInviteLink extends GroupSettingsAction {}

class DisableInviteLink extends GroupSettingsAction {}

class UpgradeSuperGroup extends GroupSettingsAction {}
