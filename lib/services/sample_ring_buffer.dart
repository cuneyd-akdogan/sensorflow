import 'dart:typed_data';

import 'package:sensorflow_accelerometer/models/sensor_axis.dart';

class SampleRingBuffer {
  SampleRingBuffer(this.capacity)
    : assert(capacity > 0),
      _time = Float64List(capacity),
      _x = Float64List(capacity),
      _y = Float64List(capacity),
      _z = Float64List(capacity);

  final int capacity;
  final Float64List _time;
  final Float64List _x;
  final Float64List _y;
  final Float64List _z;

  int _head = 0;
  int _length = 0;

  int get length => _length;
  bool get isEmpty => _length == 0;
  bool get isNotEmpty => _length > 0;

  void add(double timeMs, double x, double y, double z) {
    _time[_head] = timeMs;
    _x[_head] = x;
    _y[_head] = y;
    _z[_head] = z;
    _head = (_head + 1) % capacity;
    if (_length < capacity) _length++;
  }

  void clear() {
    _head = 0;
    _length = 0;
  }

  int _index(int i) {
    assert(i >= 0 && i < _length, 'Index $i out of range 0..${_length - 1}');
    return (_head - _length + i + capacity) % capacity;
  }

  double timeAt(int i) => _time[_index(i)];

  double valueAt(SensorAxis axis, int i) {
    final index = _index(i);
    return switch (axis) {
      SensorAxis.x => _x[index],
      SensorAxis.y => _y[index],
      SensorAxis.z => _z[index],
    };
  }

  double rateHz({required double nowMs, double windowMs = 2000}) {
    if (_length < 2) return 0;
    final newest = timeAt(_length - 1);
    if (nowMs - newest > windowMs) return 0;
    var oldestIndex = _length - 1;
    while (oldestIndex > 0 && timeAt(oldestIndex - 1) >= nowMs - windowMs) {
      oldestIndex--;
    }
    final intervals = _length - 1 - oldestIndex;
    final span = newest - timeAt(oldestIndex);
    if (intervals == 0 || span <= 0) return 0;
    return intervals * 1000 / span;
  }
}
