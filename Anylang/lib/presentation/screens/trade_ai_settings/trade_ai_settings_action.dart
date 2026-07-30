import '../../utils/screen_options/my_action.dart';

class TradeAiSettingsAction extends MyAction {}

class SaveTradeAiKnowledge extends TradeAiSettingsAction {
  final String knowledge;

  SaveTradeAiKnowledge(this.knowledge);
}

class RetryLoadTradeAiSettings extends TradeAiSettingsAction {}
