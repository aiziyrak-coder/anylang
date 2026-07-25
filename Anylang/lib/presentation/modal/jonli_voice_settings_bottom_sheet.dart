import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ui/buttons/primary_button.dart';
import '../ui/gender_selector.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

class JonliVoiceSettingsResult {
  final String voice; // female | male
  final double speed; // 0.5–2.0

  const JonliVoiceSettingsResult({required this.voice, required this.speed});
}

Future<JonliVoiceSettingsResult?> showJonliVoiceSettingsBottomSheet(
  BuildContext context, {
  required String voice,
  required double speed,
}) {
  return showModalBottomSheet<JonliVoiceSettingsResult>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _JonliVoiceSettingsSheet(
      initialVoice: voice,
      initialSpeed: speed,
    ),
  );
}

class _JonliVoiceSettingsSheet extends StatefulWidget {
  final String initialVoice;
  final double initialSpeed;

  const _JonliVoiceSettingsSheet({
    required this.initialVoice,
    required this.initialSpeed,
  });

  @override
  State<_JonliVoiceSettingsSheet> createState() =>
      _JonliVoiceSettingsSheetState();
}

class _JonliVoiceSettingsSheetState extends State<_JonliVoiceSettingsSheet> {
  late String _voice;
  late double _speed;

  static const _presets = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _voice = widget.initialVoice == 'male' ? 'male' : 'female';
    _speed = widget.initialSpeed.clamp(0.5, 2.0);
  }

  String _speedLabel(double v) {
    if (v == v.roundToDouble()) return '${v.toStringAsFixed(0)}x';
    return '${v.toStringAsFixed(2)}x';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.dp)),
      ),
      padding: EdgeInsets.fromLTRB(18.dp, 12.dp, 18.dp, 16.dp + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40.dp,
              height: 4.dp,
              decoration: BoxDecoration(
                color: c.outline,
                borderRadius: BorderRadius.circular(99.dp),
              ),
            ),
          ),
          SizedBox(height: 14.dp),
          Text(
            'jonli_voice_settings_title'.tr,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.dp),
          Text(
            'jonli_voice_settings_desc'.tr,
            style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
          ),
          SizedBox(height: 18.dp),
          Text(
            'jonli_voice_gender'.tr,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.dp),
          GenderSelector(
            value: _voice,
            onSelect: (v) => setState(() => _voice = v),
          ),
          SizedBox(height: 20.dp),
          Row(
            children: [
              Text(
                'jonli_voice_speed'.tr,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _speedLabel(_speed),
                style: TextStyle(
                  color: c.accent,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: c.accent,
              inactiveTrackColor: c.outline,
              thumbColor: c.accent,
              overlayColor: c.accent.withValues(alpha: 0.16),
              trackHeight: 3.dp,
            ),
            child: Slider(
              value: _speed,
              min: 0.5,
              max: 2.0,
              divisions: 6,
              onChanged: (v) => setState(() => _speed = v),
            ),
          ),
          Wrap(
            spacing: 8.dp,
            runSpacing: 8.dp,
            children: [
              for (final p in _presets)
                Material(
                  color: (_speed - p).abs() < 0.01
                      ? c.accentSoft
                      : c.background,
                  borderRadius: BorderRadius.circular(99.dp),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(99.dp),
                    onTap: () => setState(() => _speed = p),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.dp,
                        vertical: 7.dp,
                      ),
                      child: Text(
                        _speedLabel(p),
                        style: TextStyle(
                          color: (_speed - p).abs() < 0.01
                              ? c.accent
                              : c.textSecondary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 18.dp),
          PrimaryButton(
            text: 'jonli_voice_apply'.tr,
            onTap: () {
              Navigator.pop(
                context,
                JonliVoiceSettingsResult(voice: _voice, speed: _speed),
              );
            },
          ),
        ],
      ),
    );
  }
}
