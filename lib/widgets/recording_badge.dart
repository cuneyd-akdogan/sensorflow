import 'package:flutter/material.dart';

import 'package:sensorflow_accelerometer/theme/app_theme.dart';

String formatElapsed(Duration duration) {
  final minutes = duration.inMinutes.toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  final tenths = (duration.inMilliseconds % 1000) ~/ 100;
  return '$minutes:$seconds.$tenths';
}

class RecordingBadge extends StatefulWidget {
  const RecordingBadge({
    super.key,
    required this.isRecording,
    required this.elapsed,
  });

  final bool isRecording;
  final Duration elapsed;

  @override
  State<RecordingBadge> createState() => _RecordingBadgeState();
}

class _RecordingBadgeState extends State<RecordingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double> _dotOpacity = Tween<double>(
    begin: 0.25,
    end: 1,
  ).animate(_pulse);

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(RecordingBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRecording != widget.isRecording) _syncPulse();
  }

  void _syncPulse() {
    if (widget.isRecording) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recording = widget.isRecording;
    final dotColor = recording ? AppColors.record : AppColors.success;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: recording
            ? AppColors.record.withValues(alpha: 0.18)
            : Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: recording
              ? AppColors.record.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _dotOpacity,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            recording ? 'REC  ${formatElapsed(widget.elapsed)}' : 'LIVE',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.textPrimary,
              fontFeatures: AppText.tabular,
            ),
          ),
        ],
      ),
    );
  }
}
