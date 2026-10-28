abstract final class MonotonicClock {
  static final Stopwatch _stopwatch = Stopwatch()..start();

  static double get nowMs => _stopwatch.elapsedMicroseconds / 1000.0;
}
