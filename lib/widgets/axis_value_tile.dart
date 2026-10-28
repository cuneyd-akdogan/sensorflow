import 'package:flutter/material.dart';

import 'package:sensorflow_accelerometer/models/sensor_axis.dart';
import 'package:sensorflow_accelerometer/theme/app_theme.dart';

class AxisValueTile extends StatelessWidget {
  const AxisValueTile({
    super.key,
    required this.axis,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final SensorAxis axis;
  final double? value;
  final bool enabled;
  final VoidCallback onTap;

  static String format(double? value) {
    if (value == null || !value.isFinite) return '—';
    final sign = value < 0 ? '−' : '+';
    return '$sign${value.abs().toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forAxis(axis);
    final borderRadius = BorderRadius.circular(14);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(
            color: enabled ? color.withValues(alpha: 0.35) : AppColors.outline,
          ),
        ),
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(axis.label, style: AppText.label),
                    const Spacer(),
                    Icon(
                      enabled
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(format(value), style: AppText.value),
                ),
                const SizedBox(height: 2),
                const Text(
                  'm/s²',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
