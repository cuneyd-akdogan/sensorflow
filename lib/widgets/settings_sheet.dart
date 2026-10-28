import 'package:flutter/material.dart';

import 'package:sensorflow_accelerometer/models/capture_settings.dart';
import 'package:sensorflow_accelerometer/theme/app_theme.dart';

Future<CaptureSettings?> showCaptureSettingsSheet(
  BuildContext context,
  CaptureSettings current,
) {
  return showModalBottomSheet<CaptureSettings>(
    context: context,
    isScrollControlled: true,
    builder: (context) => CaptureSettingsSheet(initial: current),
  );
}

class CaptureSettingsSheet extends StatefulWidget {
  const CaptureSettingsSheet({super.key, required this.initial});

  final CaptureSettings initial;

  @override
  State<CaptureSettingsSheet> createState() => _CaptureSettingsSheetState();
}

class _CaptureSettingsSheetState extends State<CaptureSettingsSheet> {
  late CaptureSettings _settings = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Capture settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Applied to the next recording.',
              style: AppText.caption,
            ),
            const SizedBox(height: 24),
            const _SectionLabel('VIDEO RESOLUTION'),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<VideoQuality>(
                showSelectedIcon: false,
                segments: [
                  for (final quality in VideoQuality.values)
                    ButtonSegment(value: quality, label: Text(quality.label)),
                ],
                selected: {_settings.videoQuality},
                onSelectionChanged: (selection) => setState(
                  () => _settings = _settings.copyWith(
                    videoQuality: selection.first,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('ACCELEROMETER SAMPLING'),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<SamplingRate>(
                showSelectedIcon: false,
                segments: [
                  for (final rate in SamplingRate.values)
                    ButtonSegment(
                      value: rate,
                      label: Text(rate.label),
                      tooltip: rate.approxRate,
                    ),
                ],
                selected: {_settings.samplingRate},
                onSelectionChanged: (selection) => setState(
                  () => _settings = _settings.copyWith(
                    samplingRate: selection.first,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${_settings.samplingRate.label}: ${_settings.samplingRate.approxRate}. '
              'The actual rate depends on the device and is shown live.',
              style: AppText.caption,
            ),
            const SizedBox(height: 24),
            const _SectionLabel('OUTPUT'),
            const SizedBox(height: 10),
            const _OutputRow(
              icon: Icons.movie_outlined,
              title: 'video_<id>.mp4',
              subtitle: 'Gallery',
            ),
            const SizedBox(height: 8),
            const _OutputRow(
              icon: Icons.table_chart_outlined,
              title: 'sensors_<id>.csv',
              subtitle: 'Download · timestamp_ms, x, y, z',
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_settings),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: AppText.label);
}

class _OutputRow extends StatelessWidget {
  const _OutputRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
