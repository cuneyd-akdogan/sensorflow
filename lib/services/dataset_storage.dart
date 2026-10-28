import 'dart:io';

import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:sensorflow_accelerometer/models/accelerometer_sample.dart';
import 'package:sensorflow_accelerometer/services/csv_encoder.dart';

class SavedRecording {
  const SavedRecording({
    required this.id,
    required this.sampleCount,
    required this.duration,
    required this.videoLocation,
    required this.csvPath,
    required this.issues,
  });

  final String id;
  final int sampleCount;
  final Duration duration;
  final String? videoLocation;
  final String? csvPath;
  final List<String> issues;

  bool get isComplete => issues.isEmpty;

  double get sampleRateHz {
    final seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;
    return seconds <= 0 ? 0 : sampleCount / seconds;
  }
}

class DatasetStorage {
  static const _androidDownloads = '/storage/emulated/0/Download';

  Future<Directory> _outputDirectory() async {
    final directory = Platform.isAndroid
        ? Directory(_androidDownloads)
        : await getApplicationDocumentsDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<SavedRecording> save({
    required String videoPath,
    required List<AccelerometerSample> samples,
    required Duration duration,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final issues = <String>[];

    Directory? outputDirectory;
    try {
      outputDirectory = await _outputDirectory();
    } catch (error) {
      issues.add('Output folder unavailable: $error');
    }

    String? csvPath;
    if (outputDirectory != null) {
      try {
        final file = File('${outputDirectory.path}/sensors_$id.csv');
        await file.writeAsString(encodeSamplesCsv(samples), flush: true);
        csvPath = file.path;
      } catch (error) {
        issues.add('CSV not saved: $error');
      }
    }

    String? videoLocation;
    try {
      final result = await ImageGallerySaverPlus.saveFile(
        videoPath,
        name: 'video_$id.mp4',
      );
      if (result is Map && result['isSuccess'] == true) {
        videoLocation = 'Gallery';
      }
    } catch (_) {
      videoLocation = null;
    }

    if (videoLocation == null && outputDirectory != null) {
      try {
        final copy = await File(
          videoPath,
        ).copy('${outputDirectory.path}/video_$id.mp4');
        videoLocation = copy.path;
      } catch (error) {
        issues.add('Video not saved: $error');
      }
    } else if (videoLocation == null) {
      issues.add('Video not saved');
    }

    if (videoLocation != null) {
      try {
        await File(videoPath).delete();
      } catch (_) {}
    }

    return SavedRecording(
      id: id,
      sampleCount: samples.length,
      duration: duration,
      videoLocation: videoLocation,
      csvPath: csvPath,
      issues: issues,
    );
  }
}
