import 'package:camera/camera.dart';
import 'package:sensors_plus/sensors_plus.dart';

enum VideoQuality {
  p480('480p', ResolutionPreset.medium),
  p720('720p', ResolutionPreset.high),
  p1080('1080p', ResolutionPreset.veryHigh),
  p2160('4K', ResolutionPreset.ultraHigh);

  const VideoQuality(this.label, this.preset);

  final String label;
  final ResolutionPreset preset;
}

enum SamplingRate {
  ui('UI', '~15 Hz', SensorInterval.uiInterval),
  game('Game', '~50 Hz', SensorInterval.gameInterval),
  fastest('Fastest', 'max Hz', SensorInterval.fastestInterval);

  const SamplingRate(this.label, this.approxRate, this.interval);

  final String label;
  final String approxRate;
  final Duration interval;
}

class CaptureSettings {
  const CaptureSettings({
    required this.videoQuality,
    required this.samplingRate,
  });

  static const defaults = CaptureSettings(
    videoQuality: VideoQuality.p480,
    samplingRate: SamplingRate.ui,
  );

  final VideoQuality videoQuality;
  final SamplingRate samplingRate;

  String get summary =>
      '${videoQuality.label} · ${samplingRate.label} ${samplingRate.approxRate}';

  CaptureSettings copyWith({
    VideoQuality? videoQuality,
    SamplingRate? samplingRate,
  }) {
    return CaptureSettings(
      videoQuality: videoQuality ?? this.videoQuality,
      samplingRate: samplingRate ?? this.samplingRate,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CaptureSettings &&
      other.videoQuality == videoQuality &&
      other.samplingRate == samplingRate;

  @override
  int get hashCode => Object.hash(videoQuality, samplingRate);
}
