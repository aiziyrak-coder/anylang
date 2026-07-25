import '../../utils/screen_options/my_action.dart';

import 'deal_mode_models.dart';

class DealModeAction extends MyAction {}

class DealModeRefresh extends DealModeAction {}

class DealModeSave extends DealModeAction {}

class DealModeAccept extends DealModeAction {}

class DealModeClose extends DealModeAction {}

class DealModeAttachDoc extends DealModeAction {
  final DealDocumentCandidate candidate;
  DealModeAttachDoc(this.candidate);
}

class DealModeDetachDoc extends DealModeAction {
  final int messageId;
  DealModeDetachDoc(this.messageId);
}

class DealModePickCurrency extends DealModeAction {
  final String currency;
  DealModePickCurrency(this.currency);
}
