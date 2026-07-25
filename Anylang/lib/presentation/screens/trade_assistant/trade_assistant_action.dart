import '../../utils/screen_options/my_action.dart';
import 'trade_assistant_message.dart';

class TradeAssistantAction extends MyAction {}

class TradeComposerChanged extends TradeAssistantAction {
  final String text;
  TradeComposerChanged(this.text);
}

class TradeSend extends TradeAssistantAction {
  final String text;
  TradeSend(this.text);
}

class TradeTapProduct extends TradeAssistantAction {
  final TradeAssistantMatchProduct product;
  TradeTapProduct(this.product);
}

class TradeTapSeller extends TradeAssistantAction {
  final TradeAssistantMatchSeller seller;
  TradeTapSeller(this.seller);
}

class TradeUseSuggestion extends TradeAssistantAction {
  final String text;
  TradeUseSuggestion(this.text);
}
