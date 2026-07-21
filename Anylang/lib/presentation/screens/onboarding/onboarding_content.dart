import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/buttons/primary_button.dart';
import '../../ui/gradient_background.dart';
import '../../ui/theme/colors.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'onboarding_action.dart';
import 'onboarding_illustration.dart';
import 'onboarding_state.dart';
import 'page_indicator.dart';

class _Slide {
  final String titleKey;
  final String descKey;
  final Widget illustration;
  const _Slide(this.titleKey, this.descKey, this.illustration);
}

class OnboardingContent extends ScreenContent<OnboardingState> {

  late final PageController _pageController;

  static const List<_Slide> _slides = [
    _Slide('onb1_title', 'onb1_desc', OnbChatIllustration()),
    _Slide('onb2_title', 'onb2_desc', OnbLiveIllustration()),
    _Slide('onb3_title', 'onb3_desc', OnbBusinessIllustration()),
  ];

  // UI controller — content darajasida (initContent/onClose).
  @override
  void initContent() {
    _pageController = PageController();
  }

  @override
  void onClose() {
    _pageController.dispose();
  }

  @override
  Widget build(BuildContext context, OnboardingState state, void Function(MyAction action) sendAction) {
    final c = context.appColors;

    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            // Skip
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 4.dp),
                child: InkWell(
                  onTap: () => sendAction(SkipOnboarding()),
                  borderRadius: BorderRadius.circular(10.dp),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 8.dp),
                    child: Text(
                      'skip'.tr,
                      style: TextStyle(color: c.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => sendAction(PageChanged(i)),
                itemBuilder: (_, i) => _slideView(context, _slides[i]),
              ),
            ),
            SizedBox(height: 8.dp),
            Obx(() => PageIndicator(count: _slides.length, current: state.currentPage.value)),
            SizedBox(height: 20.dp),
            Padding(
              padding: EdgeInsets.fromLTRB(24.dp, 0, 24.dp, 16.dp),
              child: Obx(() {
                final last = state.currentPage.value == _slides.length - 1;
                return PrimaryButton(
                  text: last ? 'start'.tr : 'next'.tr,
                  onTap: () {
                    if (last) {
                      sendAction(Continue());
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slideView(BuildContext context, _Slide slide) {
    final c = context.appColors;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.dp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 12.dp),
          slide.illustration,
          SizedBox(height: 32.dp),
          Text(
            slide.titleKey.tr,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 26.sp,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          SizedBox(height: 12.dp),
          Text(
            slide.descKey.tr,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 15.sp,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
