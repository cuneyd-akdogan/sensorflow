import 'package:sensorflow_accelerometer/models/accelerometer_sample.dart';

const csvHeader = 'timestamp_ms,x,y,z';

String encodeSamplesCsv(List<AccelerometerSample> samples) {
  final buffer = StringBuffer()..writeln(csvHeader);
  for (final sample in samples) {
    buffer.writeln(sample.toCsvRow());
  }
  return buffer.toString();
}
