import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:sensorflow_accelerometer/models/accelerometer_sample.dart';
import 'package:sensorflow_accelerometer/models/capture_settings.dart';
import 'package:sensorflow_accelerometer/models/sensor_axis.dart';
import 'package:sensorflow_accelerometer/services/dataset_storage.dart';
import 'package:sensorflow_accelerometer/services/monotonic_clock.dart';
import 'package:sensorflow_accelerometer/services/permission_service.dart';
import 'package:sensorflow_accelerometer/services/sample_ring_buffer.dart';
import 'package:sensorflow_accelerometer/theme/app_theme.dart';
import 'package:sensorflow_accelerometer/widgets/axis_value_tile.dart';
import 'package:sensorflow_accelerometer/widgets/live_axis_chart.dart';
import 'package:sensorflow_accelerometer/widgets/record_button.dart';
import 'package:sensorflow_accelerometer/widgets/recording_badge.dart';
import 'package:sensorflow_accelerometer/widgets/settings_sheet.dart';
import 'package:sensorflow_accelerometer/widgets/status_views.dart';

enum _CameraPhase { initializing, permissionRequired, noCamera, error, ready }

enum _RecorderStatus { idle, starting, recording, stopping, saving }

class LiveSnapshot {
  const LiveSnapshot({
    this.x,
    this.y,
    this.z,
    this.rateHz = 0,
    this.sampleCount = 0,
    this.elapsed = Duration.zero,
  });

  final double? x;
  final double? y;
  final double? z;
  final double rateHz;
  final int sampleCount;
  final Duration elapsed;

  double? valueOf(SensorAxis axis) => switch (axis) {
    SensorAxis.x => x,
    SensorAxis.y => y,
    SensorAxis.z => z,
  };
}

class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen>
    with WidgetsBindingObserver {
  static const _chartWindow = Duration(seconds: 6);
  static const _uiRefreshInterval = Duration(milliseconds: 100);

  final _permissions = PermissionService();
  final _storage = DatasetStorage();
  final _liveBuffer = SampleRingBuffer(4096);
  final _snapshot = ValueNotifier<LiveSnapshot>(const LiveSnapshot());
  final _recordedSamples = <AccelerometerSample>[];
  final _recordingClock = Stopwatch();

  Set<SensorAxis> _visibleAxes = SensorAxis.values.toSet();
  CaptureSettings _settings = CaptureSettings.defaults;
  List<CameraDescription> _cameras = const [];
  CameraController? _camera;
  _CameraPhase _phase = _CameraPhase.initializing;
  _RecorderStatus _status = _RecorderStatus.idle;
  PermissionReport? _permissionReport;
  String? _errorMessage;
  bool _sensorAvailable = true;
  bool _isCollecting = false;
  bool _isBootstrapping = false;
  bool _inBackground = false;
  Future<void>? _pendingStop;
  StreamSubscription<AccelerometerEvent>? _sensorSubscription;
  AccelerometerEvent? _latestEvent;
  Timer? _uiTimer;

  bool get _isRecordingActive =>
      _status == _RecorderStatus.recording ||
      _status == _RecorderStatus.stopping;

  bool get _isBusy =>
      _status == _RecorderStatus.starting ||
      _status == _RecorderStatus.stopping ||
      _status == _RecorderStatus.saving;

  bool get _canRecord =>
      _phase == _CameraPhase.ready && (_camera?.value.isInitialized ?? false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSensor();
    _uiTimer = Timer.periodic(_uiRefreshInterval, (_) => _publishSnapshot());
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiTimer?.cancel();
    _sensorSubscription?.cancel();
    _camera?.dispose();
    _snapshot.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _enterBackground();
      case AppLifecycleState.resumed:
        _exitBackground();
      default:
        break;
    }
  }

  Future<void> _enterBackground() async {
    if (_inBackground) return;
    _inBackground = true;
    _sensorSubscription?.pause();

    if (_status == _RecorderStatus.recording) {
      await _stopRecording();
    } else if (_pendingStop != null) {
      await _pendingStop;
    }

    if (!_inBackground) return;
    final camera = _camera;
    if (camera != null) {
      if (mounted) setState(() => _camera = null);
      await camera.dispose();
    }
  }

  Future<void> _exitBackground() async {
    if (!_inBackground) return;
    _inBackground = false;
    _liveBuffer.clear();
    if (_sensorSubscription?.isPaused ?? false) _sensorSubscription!.resume();

    if (_isBootstrapping || !mounted) return;
    if (_phase == _CameraPhase.permissionRequired) {
      final report = await _permissions.check();
      if (!mounted) return;
      if (report.allGranted) {
        await _bootstrap();
      } else {
        setState(() => _permissionReport = report);
      }
    } else if (_phase == _CameraPhase.error) {
      await _bootstrap();
    } else if (_camera == null && _cameras.isNotEmpty) {
      await _initializeCamera();
    }
  }

  Future<void> _bootstrap() async {
    if (_isBootstrapping || !mounted) return;
    _isBootstrapping = true;
    try {
      if (_phase != _CameraPhase.initializing) {
        setState(() {
          _phase = _CameraPhase.initializing;
          _errorMessage = null;
        });
      }

      final report = await _permissions.request();
      if (!mounted) return;
      _permissionReport = report;
      if (!report.allGranted) {
        setState(() => _phase = _CameraPhase.permissionRequired);
        return;
      }

      if (_cameras.isEmpty) {
        try {
          _cameras = await availableCameras();
        } on CameraException catch (error) {
          _setError(error.description ?? error.code);
          return;
        }
      }
      if (!mounted) return;
      if (_cameras.isEmpty) {
        setState(() => _phase = _CameraPhase.noCamera);
        return;
      }

      await _initializeCamera();
    } finally {
      _isBootstrapping = false;
    }
  }

  Future<void> _initializeCamera() async {
    final previous = _camera;
    if (previous != null) {
      setState(() => _camera = null);
      await previous.dispose();
    }

    final description = _cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );
    final controller = CameraController(
      description,
      _settings.videoQuality.preset,
      enableAudio: true,
    );

    try {
      await controller.initialize();
    } on CameraException catch (error) {
      await controller.dispose();
      _setError(error.description ?? error.code);
      return;
    }

    if (!mounted || _inBackground) {
      await controller.dispose();
      return;
    }

    setState(() {
      _camera = controller;
      _phase = _CameraPhase.ready;
    });
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _CameraPhase.error;
      _errorMessage = message;
    });
  }

  void _startSensor() {
    _sensorSubscription?.cancel();
    _liveBuffer.clear();
    _latestEvent = null;
    _sensorSubscription =
        accelerometerEventStream(
          samplingPeriod: _settings.samplingRate.interval,
        ).listen(
          _onSensorEvent,
          onError: (Object error) {
            if (mounted) setState(() => _sensorAvailable = false);
          },
          cancelOnError: true,
        );
  }

  void _onSensorEvent(AccelerometerEvent event) {
    _latestEvent = event;
    _liveBuffer.add(MonotonicClock.nowMs, event.x, event.y, event.z);
    if (_isCollecting) {
      _recordedSamples.add(
        AccelerometerSample(
          timestampMs: DateTime.now().millisecondsSinceEpoch,
          x: event.x,
          y: event.y,
          z: event.z,
        ),
      );
    }
    if (!_sensorAvailable && mounted) {
      setState(() => _sensorAvailable = true);
    }
  }

  void _publishSnapshot() {
    final event = _latestEvent;
    _snapshot.value = LiveSnapshot(
      x: event?.x,
      y: event?.y,
      z: event?.z,
      rateHz: _liveBuffer.rateHz(nowMs: MonotonicClock.nowMs),
      sampleCount: _recordedSamples.length,
      elapsed: _recordingClock.elapsed,
    );
  }

  Future<void> _onRecordPressed() async {
    switch (_status) {
      case _RecorderStatus.idle:
        await _startRecording();
      case _RecorderStatus.recording:
        await _stopRecording();
      default:
        return;
    }
  }

  Future<void> _startRecording() async {
    final camera = _camera;
    if (camera == null ||
        !camera.value.isInitialized ||
        camera.value.isRecordingVideo) {
      return;
    }

    setState(() => _status = _RecorderStatus.starting);

    final report = await _permissions.check();
    if (!mounted) return;
    if (!report.allGranted) {
      setState(() {
        _status = _RecorderStatus.idle;
        _permissionReport = report;
        _phase = _CameraPhase.permissionRequired;
      });
      return;
    }

    try {
      await camera.startVideoRecording();
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() => _status = _RecorderStatus.idle);
      _showMessage(
        'Could not start recording',
        error.description ?? error.code,
        isError: true,
      );
      return;
    }

    _recordedSamples.clear();
    _recordingClock
      ..reset()
      ..start();
    _isCollecting = true;
    HapticFeedback.mediumImpact();
    if (mounted) setState(() => _status = _RecorderStatus.recording);
  }

  Future<void> _stopRecording() {
    if (_status != _RecorderStatus.recording) {
      return _pendingStop ?? Future.value();
    }
    final future = _performStop().whenComplete(() => _pendingStop = null);
    _pendingStop = future;
    return future;
  }

  Future<void> _performStop() async {
    final camera = _camera;
    if (camera == null) return;
    if (mounted) setState(() => _status = _RecorderStatus.stopping);

    XFile? video;
    String? failure;
    try {
      video = await camera.stopVideoRecording();
    } on CameraException catch (error) {
      failure = error.description ?? error.code;
    }

    _isCollecting = false;
    _recordingClock.stop();
    HapticFeedback.lightImpact();

    if (video == null) {
      if (!mounted) return;
      setState(() => _status = _RecorderStatus.idle);
      _showMessage('Recording failed', failure ?? 'Unknown error', isError: true);
      return;
    }

    if (mounted) setState(() => _status = _RecorderStatus.saving);
    final result = await _storage.save(
      videoPath: video.path,
      samples: List.of(_recordedSamples),
      duration: _recordingClock.elapsed,
    );

    if (!mounted) return;
    setState(() => _status = _RecorderStatus.idle);
    _showSaveResult(result);
  }

  Future<void> _openSettings() async {
    if (_status != _RecorderStatus.idle) return;
    final updated = await showCaptureSettingsSheet(context, _settings);
    if (!mounted || updated == null || updated == _settings) return;

    final qualityChanged = updated.videoQuality != _settings.videoQuality;
    final rateChanged = updated.samplingRate != _settings.samplingRate;

    setState(() {
      _settings = updated;
      if (qualityChanged) _phase = _CameraPhase.initializing;
    });
    if (rateChanged) _startSensor();
    if (qualityChanged) await _initializeCamera();
  }

  void _toggleAxis(SensorAxis axis) {
    final next = {..._visibleAxes};
    if (!next.remove(axis)) next.add(axis);
    if (next.isEmpty) return;
    setState(() => _visibleAxes = next);
  }

  void _showSaveResult(SavedRecording result) {
    final details =
        '${formatElapsed(result.duration)} · ${result.sampleCount} samples · '
        '${result.sampleRateHz.toStringAsFixed(1)} Hz';
    if (result.isComplete) {
      _showMessage('Saved · sensors_${result.id}.csv', details);
    } else {
      _showMessage(
        'Saved with issues',
        '$details\n${result.issues.join('\n')}',
        isError: true,
      );
    }
  }

  void _showMessage(String title, String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: Duration(seconds: isError ? 6 : 4),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: isError ? AppColors.record : AppColors.success,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(message, style: AppText.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.background,
      ),
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final landscape = constraints.maxWidth > constraints.maxHeight;
              if (landscape) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                        child: _buildCameraArea(),
                      ),
                    ),
                    SizedBox(
                      width: math.min(400.0, constraints.maxWidth * 0.45),
                      child: _buildControlPanel(compact: true),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: _buildCameraArea(),
                    ),
                  ),
                  _buildControlPanel(compact: false),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCameraArea() {
    final recording = _isRecordingActive;
    final radius = BorderRadius.circular(24);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.black, borderRadius: radius),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: recording
              ? AppColors.record.withValues(alpha: 0.75)
              : AppColors.outline,
          width: recording ? 2 : 1,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraContent(),
          if (_phase == _CameraPhase.ready) ...[
            Positioned(
              top: 12,
              left: 12,
              child: ValueListenableBuilder<LiveSnapshot>(
                valueListenable: _snapshot,
                builder: (context, snapshot, child) => RecordingBadge(
                  isRecording: recording,
                  elapsed: snapshot.elapsed,
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: _GlassIconButton(
                icon: Icons.tune_rounded,
                tooltip: 'Capture settings',
                onPressed: _status == _RecorderStatus.idle
                    ? _openSettings
                    : null,
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: _GlassChip(text: _settings.summary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCameraContent() {
    const loader = Center(
      child: SizedBox.square(
        dimension: 28,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );

    switch (_phase) {
      case _CameraPhase.initializing:
        return loader;
      case _CameraPhase.permissionRequired:
        return PermissionPanel(
          report: _permissionReport,
          onRequest: _bootstrap,
          onOpenSettings: _permissions.openSettings,
        );
      case _CameraPhase.noCamera:
        return const MessageView(
          icon: Icons.videocam_off_outlined,
          title: 'No camera found',
          message: 'This device does not expose a camera.',
        );
      case _CameraPhase.error:
        return MessageView(
          icon: Icons.error_outline_rounded,
          title: 'Camera unavailable',
          message: _errorMessage,
          actionLabel: 'Retry',
          onAction: _bootstrap,
        );
      case _CameraPhase.ready:
        final camera = _camera;
        if (camera == null || !camera.value.isInitialized) return loader;
        return Center(child: CameraPreview(camera));
    }
  }

  Widget _buildControlPanel({required bool compact}) {
    final chart = Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: LiveAxisChart(
        buffer: _liveBuffer,
        visibleAxes: _visibleAxes,
        window: _chartWindow,
        placeholder: _sensorAvailable
            ? 'Waiting for accelerometer…'
            : 'Accelerometer unavailable',
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 12 : 14, 16, 12),
      child: Column(
        mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPanelHeader(),
          const SizedBox(height: 12),
          _buildAxisTiles(),
          const SizedBox(height: 10),
          if (compact)
            Expanded(child: chart)
          else
            SizedBox(height: 172, child: chart),
          SizedBox(height: compact ? 10 : 14),
          _buildRecordBar(compact: compact),
        ],
      ),
    );
  }

  Widget _buildPanelHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Accelerometer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                'm/s² · last ${_chartWindow.inSeconds} s',
                style: AppText.caption,
              ),
            ],
          ),
        ),
        ValueListenableBuilder<LiveSnapshot>(
          valueListenable: _snapshot,
          builder: (context, snapshot, child) => _RateChip(
            rateHz: snapshot.rateHz,
            available: _sensorAvailable,
          ),
        ),
      ],
    );
  }

  Widget _buildAxisTiles() {
    return ValueListenableBuilder<LiveSnapshot>(
      valueListenable: _snapshot,
      builder: (context, snapshot, child) => Row(
        children: [
          for (final axis in SensorAxis.values) ...[
            if (axis != SensorAxis.values.first) const SizedBox(width: 8),
            Expanded(
              child: AxisValueTile(
                axis: axis,
                value: snapshot.valueOf(axis),
                enabled: _visibleAxes.contains(axis),
                onTap: () => _toggleAxis(axis),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordBar({required bool compact}) {
    final caption = switch (_status) {
      _RecorderStatus.idle => _canRecord ? 'Tap to record' : 'Camera not ready',
      _RecorderStatus.starting => 'Starting…',
      _RecorderStatus.recording => 'Recording',
      _RecorderStatus.stopping => 'Finishing…',
      _RecorderStatus.saving => 'Saving…',
    };

    return ValueListenableBuilder<LiveSnapshot>(
      valueListenable: _snapshot,
      builder: (context, snapshot, child) => Row(
        children: [
          Expanded(
            child: _StatBlock(
              label: 'SAMPLES',
              value: '${snapshot.sampleCount}',
              alignment: CrossAxisAlignment.start,
            ),
          ),
          child!,
          Expanded(
            child: _StatBlock(
              label: 'DURATION',
              value: formatElapsed(snapshot.elapsed),
              alignment: CrossAxisAlignment.end,
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RecordButton(
            size: compact ? 60 : 76,
            isRecording: _isRecordingActive,
            isBusy: _isBusy,
            onPressed: _canRecord ? _onRecordPressed : null,
          ),
          if (!compact) ...[
            const SizedBox(height: 6),
            Text(
              caption,
              style: TextStyle(
                fontSize: 12,
                color: _isRecordingActive
                    ? AppColors.record
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.label,
    required this.value,
    required this.alignment,
  });

  final String label;
  final String value;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppText.label),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFeatures: AppText.tabular,
          ),
        ),
      ],
    );
  }
}

class _RateChip extends StatelessWidget {
  const _RateChip({required this.rateHz, required this.available});

  final double rateHz;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final active = available && rateHz > 0;
    final color = !available
        ? AppColors.record
        : active
        ? AppColors.success
        : AppColors.textMuted;
    final text = !available
        ? 'No sensor'
        : active
        ? '${rateHz.toStringAsFixed(1)} Hz'
        : '— Hz';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sensors_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
              fontFeatures: AppText.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        color: AppColors.textPrimary,
        disabledColor: AppColors.textMuted,
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
