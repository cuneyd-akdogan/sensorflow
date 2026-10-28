import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sensorflow_accelerometer/models/accelerometer_sample.dart';
import 'package:sensorflow_accelerometer/models/sensor_axis.dart';
import 'package:sensorflow_accelerometer/services/csv_encoder.dart';
import 'package:sensorflow_accelerometer/services/monotonic_clock.dart';
import 'package:sensorflow_accelerometer/services/sample_ring_buffer.dart';
import 'package:sensorflow_accelerometer/widgets/axis_value_tile.dart';
import 'package:sensorflow_accelerometer/widgets/live_axis_chart.dart';
import 'package:sensorflow_accelerometer/widgets/recording_badge.dart';

void main() {
  group('SampleRingBuffer', () {
    test('keeps samples in order and overwrites the oldest', () {
      final buffer = SampleRingBuffer(3);
      for (var i = 0; i < 5; i++) {
        buffer.add(i * 10.0, i.toDouble(), -i.toDouble(), i * 2.0);
      }
      expect(buffer.length, 3);
      expect([for (var i = 0; i < 3; i++) buffer.timeAt(i)], [20, 30, 40]);
      expect(buffer.valueAt(SensorAxis.x, 0), 2);
      expect(buffer.valueAt(SensorAxis.y, 2), -4);
      expect(buffer.valueAt(SensorAxis.z, 1), 6);
    });

    test('estimates sampling rate', () {
      final buffer = SampleRingBuffer(256);
      for (var i = 0; i <= 100; i++) {
        buffer.add(i * 20.0, 0, 0, 0);
      }
      expect(buffer.rateHz(nowMs: 2000), closeTo(50, 0.01));
      expect(buffer.rateHz(nowMs: 10000), 0);
    });
  });

  test('CSV output keeps the dataset format', () {
    final csv = encodeSamplesCsv(const [
      AccelerometerSample(timestampMs: 1700000000000, x: 0.1, y: -9.81, z: 1.0),
      AccelerometerSample(timestampMs: 1700000000066, x: 0.25, y: -9.8, z: 0.5),
    ]);
    expect(
      csv,
      'timestamp_ms,x,y,z\n'
      '1700000000000,0.1,-9.81,1.0\n'
      '1700000000066,0.25,-9.8,0.5\n',
    );
  });

  test('formats values and durations', () {
    expect(AxisValueTile.format(9.806), '+9.81');
    expect(AxisValueTile.format(-0.5), '−0.50');
    expect(AxisValueTile.format(null), '—');
    expect(formatElapsed(const Duration(minutes: 1, seconds: 5, milliseconds: 430)), '01:05.4');
  });

  testWidgets('live chart renders streaming data', (tester) async {
    final buffer = SampleRingBuffer(512);
    final start = MonotonicClock.nowMs;
    for (var i = 0; i < 120; i++) {
      buffer.add(start - 6000 + i * 50, i % 7 - 3.0, -9.8 + i % 3, i % 5 * 0.4);
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 180,
            child: LiveAxisChart(
              buffer: buffer,
              visibleAxes: SensorAxis.values.toSet(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byType(LiveAxisChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
