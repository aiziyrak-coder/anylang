import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:anylang/presentation/utils/screen_options/my_action.dart';
import 'package:anylang/presentation/utils/screen_options/screen_content.dart';

class ScreenWidget extends StatefulWidget {

  final ScreenContent mobileContent;
  final ScreenContent? tabletContent;
  final GetxController state;
  final void Function() initState;
  final void Function() dispose;
  final void Function() uiBuildFinished;
  final void Function(BuildContext) setContextCallback;
  final void Function(MyAction) sendActionCallback;

  const ScreenWidget({
    super.key,
    required this.mobileContent,
    this.tabletContent,
    required this.state,
    required this.initState,
    required this.dispose,
    required this.uiBuildFinished,
    required this.setContextCallback,
    required this.sendActionCallback,
  });

  @override
  State<ScreenWidget> createState() => _ScreenWidgetState();
}

class _ScreenWidgetState extends State<ScreenWidget> {

  static const double _tabletBreakpoint = 600;

  bool _screenBuildFinished = false;
  ScreenContent? _content;

  @override
  void initState() {
    super.initState();
    widget.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Joriy mavjud kenglikka qarab tanlaymiz — split-screen'da tablet
    // mobile hajmiga qisqarsa, mobile content ishlatiladi.
    final width = MediaQuery.of(context).size.width;
    final useTablet = width >= _tabletBreakpoint && widget.tabletContent != null;
    final desired = useTablet ? widget.tabletContent! : widget.mobileContent;

    if (!identical(desired, _content)) {
      _activate(desired);
    }
  }

  void _activate(ScreenContent content) {
    _content?.onClose();      // eski content (agar bor bo'lsa) yopiladi
    _content = content;
    content.initContent();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_content, content)) return;

      // Screen darajasi: faqat bir marta — network shu yerda bo'lsa
      // content almashganda qayta yuborilmaydi.
      if (!_screenBuildFinished) {
        _screenBuildFinished = true;
        widget.uiBuildFinished();
      }

      // Content darajasi: har almashganda yangi content uchun (faqat UI).
      content.uiBuildFinished(widget.state);
    });
  }

  @override
  void dispose() {
    _content?.onClose();
    widget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    widget.setContextCallback(context);

    final content = _content!;
    content.isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: content.color,
      body: content.build(context, widget.state, widget.sendActionCallback),
    );
  }
}
