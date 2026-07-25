import '../../utils/screen_options/my_action.dart';

class BusinessFeedAction extends MyAction {}

class FeedRefreshRequested extends BusinessFeedAction {}

class FeedLoadMoreRequested extends BusinessFeedAction {}

class FeedSelectType extends BusinessFeedAction {
  final String? type;
  FeedSelectType(this.type);
}

class FeedCreateRequested extends BusinessFeedAction {}

class FeedDeleteRequested extends BusinessFeedAction {
  final int postId;
  FeedDeleteRequested(this.postId);
}

class FeedOpenAuthor extends BusinessFeedAction {
  final int authorId;
  FeedOpenAuthor(this.authorId);
}

class FeedSubmitCreate extends BusinessFeedAction {
  final String postType;
  final String title;
  final String body;
  FeedSubmitCreate({
    required this.postType,
    required this.title,
    required this.body,
  });
}
