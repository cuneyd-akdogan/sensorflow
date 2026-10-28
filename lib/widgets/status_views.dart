import 'package:flutter/material.dart';

import 'package:sensorflow_accelerometer/services/permission_service.dart';
import 'package:sensorflow_accelerometer/theme/app_theme.dart';

class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.outline),
              ),
              child: Icon(icon, color: AppColors.textSecondary, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppText.caption,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class PermissionPanel extends StatelessWidget {
  const PermissionPanel({
    super.key,
    required this.report,
    required this.onRequest,
    required this.onOpenSettings,
  });

  final PermissionReport? report;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final report = this.report;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                color: AppColors.textSecondary,
                size: 30,
              ),
              const SizedBox(height: 14),
              const Text(
                'Permissions required',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              const Text(
                'Camera, microphone and storage access are needed to record video and save sensor data.',
                textAlign: TextAlign.center,
                style: AppText.caption,
              ),
              const SizedBox(height: 18),
              _PermissionRow(label: 'Camera', granted: report?.camera ?? false),
              _PermissionRow(
                label: 'Microphone',
                granted: report?.microphone ?? false,
              ),
              _PermissionRow(
                label: 'Storage',
                granted: report?.storage ?? false,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onRequest,
                child: const Text('Grant access'),
              ),
              if (report?.permanentlyDenied ?? false) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onOpenSettings,
                  child: const Text('Open app settings'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.label, required this.granted});

  final String label;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 18,
            color: granted ? AppColors.success : AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
