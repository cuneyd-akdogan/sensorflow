import 'package:flutter/material.dart';

import 'package:sensorflow_accelerometer/theme/app_theme.dart';

class RecordButton extends StatelessWidget {
  const RecordButton({
    super.key,
    required this.isRecording,
    required this.isBusy,
    required this.onPressed,
    this.size = 76,
  });

  final bool isRecording;
  final bool isBusy;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isBusy;
    final innerSize = isRecording ? size * 0.38 : size * 0.78;

    return Semantics(
      button: true,
      label: isRecording ? 'Stop recording' : 'Start recording',
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: onPressed == null ? 0.4 : 1,
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.textPrimary,
                      width: 3.5,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: innerSize,
                  height: innerSize,
                  decoration: BoxDecoration(
                    color: AppColors.record,
                    borderRadius: BorderRadius.circular(
                      isRecording ? 8 : innerSize / 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.record.withValues(
                          alpha: isRecording ? 0.45 : 0.2,
                        ),
                        blurRadius: isRecording ? 22 : 12,
                      ),
                    ],
                  ),
                ),
                if (isBusy)
                  const SizedBox.square(
                    dimension: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
