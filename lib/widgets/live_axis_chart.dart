import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:sensorflow_accelerometer/models/sensor_axis.dart';
import 'package:sensorflow_accelerometer/services/monotonic_clock.dart';
import 'package:sensorflow_accelerometer/services/sample_ring_buffer.dart';
import 'package:sensorflow_accelerometer/theme/app_theme.dart';

class LiveAxisChart extends StatefulWidget {
  const LiveAxisChart({
    super.key,
    required this.buffer,
    required this.visibleAxes,
    this.window = const Duration(seconds: 6),
    this.backgroundColor = AppColors.surfaceRaised,
    this.placeholder = 'Waiting for accelerometer…',
  });

  final SampleRingBuffer buffer;
  final Set<SensorAxis> visibleAxes;
  final Duration window;
  final Color backgroundColor;
  final String placeholder;

  @override
  State<LiveAxisChart> createState() => _LiveAxisChartState();
}

class _LiveAxisChartState extends State<LiveAxisChart>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _viewport = _ChartViewport();
  final _frame = ValueNotifier<int>(0);
  Duration _lastTick = Duration.zero;

  double get _windowMs => widget.window.inMicroseconds / 1000.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dtSeconds = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    _viewport.update(
      buffer: widget.buffer,
      visibleAxes: widget.visibleAxes,
      nowMs: MonotonicClock.nowMs,
      windowMs: _windowMs,
      dtSeconds: dtSeconds,
    );
    _frame.value++;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _LiveAxisPainter(
          buffer: widget.buffer,
          viewport: _viewport,
          visibleAxes: widget.visibleAxes,
          windowMs: _windowMs,
          backgroundColor: widget.backgroundColor,
          placeholder: widget.placeholder,
          repaint: _frame,
        ),
      ),
    );
  }
}

class _ChartViewport {
  static const double _minSpan = 4;
  static const double _headroom = 1.35;
  static const double _smoothingSeconds = 0.25;

  double nowMs = 0;
  double minValue = -10;
  double maxValue = 10;
  bool _initialized = false;

  void update({
    required SampleRingBuffer buffer,
    required Set<SensorAxis> visibleAxes,
    required double nowMs,
    required double windowMs,
    required double dtSeconds,
  }) {
    this.nowMs = nowMs;
    if (buffer.isEmpty || visibleAxes.isEmpty) return;

    final startMs = nowMs - windowMs;
    var low = double.infinity;
    var high = double.negativeInfinity;
    for (var i = buffer.length - 1; i >= 0; i--) {
      for (final axis in visibleAxes) {
        final value = buffer.valueAt(axis, i);
        if (value < low) low = value;
        if (value > high) high = value;
      }
      if (buffer.timeAt(i) < startMs) break;
    }
    if (!low.isFinite || !high.isFinite) return;

    final mid = (low + high) / 2;
    final span = math.max((high - low) * _headroom, _minSpan);
    final targetMin = mid - span / 2;
    final targetMax = mid + span / 2;

    if (!_initialized) {
      minValue = targetMin;
      maxValue = targetMax;
      _initialized = true;
      return;
    }

    final blend = 1 - math.exp(-dtSeconds.clamp(0.0, 1.0) / _smoothingSeconds);
    minValue += (targetMin - minValue) * blend;
    maxValue += (targetMax - maxValue) * blend;
  }
}

class _HeadMarker {
  _HeadMarker(this.axis, this.x, this.y, this.value) : tagY = y;

  final SensorAxis axis;
  final double x;
  final double y;
  final double value;
  double tagY;
}

class _LiveAxisPainter extends CustomPainter {
  _LiveAxisPainter({
    required this.buffer,
    required this.viewport,
    required this.visibleAxes,
    required this.windowMs,
    required this.backgroundColor,
    required this.placeholder,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final SampleRingBuffer buffer;
  final _ChartViewport viewport;
  final Set<SensorAxis> visibleAxes;
  final double windowMs;
  final Color backgroundColor;
  final String placeholder;

  static const double _gutter = 50;
  static const double _verticalPadding = 10;
  static const double _tagHeight = 18;
  static const double _fadeWidth = 28;

  static const _gridLabelStyle = TextStyle(
    color: AppColors.textMuted,
    fontSize: 10,
    fontFeatures: AppText.tabular,
  );

  static const _tagStyle = TextStyle(
    color: AppColors.background,
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    fontFeatures: AppText.tabular,
  );

  static final Map<String, TextPainter> _textCache = {};

  static TextPainter _text(String text, TextStyle style, String key) {
    final cacheKey = '$key|$text';
    final cached = _textCache[cacheKey];
    if (cached != null) return cached;
    if (_textCache.length > 160) _textCache.clear();
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return _textCache[cacheKey] = painter;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      0,
      _verticalPadding,
      size.width - _gutter,
      size.height - _verticalPadding,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    final nowMs = viewport.nowMs;
    final startMs = nowMs - windowMs;
    final low = viewport.minValue;
    final high = viewport.maxValue;
    final range = high - low;

    double yOf(double value) => plot.bottom - (value - low) / range * plot.height;
    double xOf(double timeMs) =>
        plot.left + (timeMs - startMs) / windowMs * plot.width;

    _paintGrid(canvas, plot, size, startMs, nowMs, low, high, yOf, xOf);

    if (buffer.isEmpty) {
      final label = _text(placeholder, _gridLabelStyle, 'placeholder');
      label.paint(
        canvas,
        plot.center - Offset(label.width / 2, label.height / 2),
      );
      return;
    }

    var firstIndex = buffer.length - 1;
    while (firstIndex > 0 && buffer.timeAt(firstIndex) > startMs) {
      firstIndex--;
    }

    final heads = <_HeadMarker>[];
    canvas.save();
    canvas.clipRect(plot.inflate(2));
    for (final axis in SensorAxis.values) {
      if (!visibleAxes.contains(axis)) continue;
      final color = AppColors.forAxis(axis);
      final path = Path();
      for (var i = firstIndex; i < buffer.length; i++) {
        final x = xOf(buffer.timeAt(i));
        final y = yOf(buffer.valueAt(axis, i));
        if (i == firstIndex) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color.withValues(alpha: 0.14),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );

      final lastIndex = buffer.length - 1;
      final value = buffer.valueAt(axis, lastIndex);
      heads.add(
        _HeadMarker(
          axis,
          xOf(buffer.timeAt(lastIndex)),
          yOf(value).clamp(plot.top, plot.bottom),
          value,
        ),
      );
    }
    canvas.restore();

    final fadeRect = Rect.fromLTWH(0, 0, _fadeWidth, size.height);
    canvas.drawRect(
      fadeRect,
      Paint()
        ..shader = LinearGradient(
          colors: [backgroundColor, backgroundColor.withValues(alpha: 0)],
        ).createShader(fadeRect),
    );

    for (final head in heads) {
      final color = AppColors.forAxis(head.axis);
      _paintDashedLine(
        canvas,
        Offset(head.x, head.y),
        Offset(plot.right, head.y),
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        Offset(head.x, head.y),
        6,
        Paint()..color = color.withValues(alpha: 0.22),
      );
      canvas.drawCircle(Offset(head.x, head.y), 3, Paint()..color = color);
    }

    _paintTags(canvas, heads, plot, size);
  }

  void _paintGrid(
    Canvas canvas,
    Rect plot,
    Size size,
    double startMs,
    double nowMs,
    double low,
    double high,
    double Function(double) yOf,
    double Function(double) xOf,
  ) {
    final gridPaint = Paint()
      ..color = AppColors.grid
      ..strokeWidth = 1;

    for (var t = (startMs / 1000).ceilToDouble() * 1000; t <= nowMs; t += 1000) {
      final x = xOf(t);
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), gridPaint);
    }

    final step = _niceStep((high - low) / 4);
    final decimals = step >= 1 ? 0 : 1;
    for (var k = (low / step).ceil(); k * step <= high; k++) {
      final value = k * step;
      final y = yOf(value);
      final isZero = k == 0;
      canvas.drawLine(
        Offset(plot.left, y),
        Offset(plot.right, y),
        isZero
            ? (Paint()
                ..color = AppColors.textMuted.withValues(alpha: 0.55)
                ..strokeWidth = 1)
            : gridPaint,
      );
      final label = _text(value.toStringAsFixed(decimals), _gridLabelStyle, 'grid');
      label.paint(canvas, Offset(plot.right + 8, y - label.height / 2));
    }

    canvas.drawLine(
      Offset(plot.right, 0),
      Offset(plot.right, size.height),
      gridPaint,
    );
  }

  void _paintTags(Canvas canvas, List<_HeadMarker> heads, Rect plot, Size size) {
    if (heads.isEmpty) return;
    const gap = 2.0;
    const half = _tagHeight / 2;
    heads.sort((a, b) => a.y.compareTo(b.y));

    for (var i = 0; i < heads.length; i++) {
      heads[i].tagY = heads[i].y.clamp(half, size.height - half);
      if (i > 0) {
        final minY = heads[i - 1].tagY + _tagHeight + gap;
        if (heads[i].tagY < minY) heads[i].tagY = minY;
      }
    }
    var maxY = size.height - half;
    for (var i = heads.length - 1; i >= 0; i--) {
      if (heads[i].tagY > maxY) heads[i].tagY = maxY;
      maxY = heads[i].tagY - _tagHeight - gap;
    }

    for (final head in heads) {
      final rect = Rect.fromLTWH(
        plot.right + 3,
        head.tagY - half,
        _gutter - 4,
        _tagHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        Paint()..color = AppColors.forAxis(head.axis),
      );
      final label = _text(head.value.toStringAsFixed(2), _tagStyle, 'tag');
      label.paint(
        canvas,
        Offset(
          rect.center.dx - label.width / 2,
          rect.center.dy - label.height / 2,
        ),
      );
    }
  }

  void _paintDashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 3.0;
    const space = 3.0;
    final length = (to - from).distance;
    if (length <= 0) return;
    final direction = (to - from) / length;
    for (var d = 0.0; d < length; d += dash + space) {
      final end = math.min(d + dash, length);
      canvas.drawLine(from + direction * d, from + direction * end, paint);
    }
  }

  static double _niceStep(double raw) {
    if (raw <= 0 || !raw.isFinite) return 1;
    final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final fraction = raw / magnitude;
    final nice = fraction < 1.5
        ? 1.0
        : fraction < 3
        ? 2.0
        : fraction < 7
        ? 5.0
        : 10.0;
    return nice * magnitude;
  }

  @override
  bool shouldRepaint(_LiveAxisPainter oldDelegate) =>
      oldDelegate.buffer != buffer ||
      oldDelegate.visibleAxes != visibleAxes ||
      oldDelegate.windowMs != windowMs ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.placeholder != placeholder;
}
