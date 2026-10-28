class AccelerometerSample {
  const AccelerometerSample({
    required this.timestampMs,
    required this.x,
    required this.y,
    required this.z,
  });

  final int timestampMs;
  final double x;
  final double y;
  final double z;

  String toCsvRow() => '$timestampMs,$x,$y,$z';
}
