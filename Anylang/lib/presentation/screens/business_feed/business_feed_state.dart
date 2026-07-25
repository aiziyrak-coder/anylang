import 'package:get/get.dart';
import 'feed_post.dart';

class BusinessFeedState extends GetxController {
  RxList<FeedPost> posts = <FeedPost>[].obs;
  RxBool loading = true.obs;
  RxBool loadingMore = false.obs;
  RxBool submitting = false.obs;
  RxBool hasMore = false.obs;
  RxInt page = 1.obs;
  /// null = barcha turlar
  final RxnString filterType = RxnString();
  RxBool isBusiness = false.obs;
}
