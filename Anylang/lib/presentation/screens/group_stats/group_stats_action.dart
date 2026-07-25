import '../../utils/screen_options/my_action.dart';

class GroupStatsAction extends MyAction {}

class GroupStatsRefresh extends GroupStatsAction {}

class GroupStatsOpenUser extends GroupStatsAction {
  final int userId;
  GroupStatsOpenUser(this.userId);
}
