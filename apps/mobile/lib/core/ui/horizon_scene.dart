import "dart:math" as math;
import "package:material_ui/material_ui.dart";
import "../app_theme.dart";
import "tokens.dart";

/// The brand illustration: sun, hills, a road with a dashed centre line, a
/// car, and a plane drawing a dotted contrail. Drawn in code. When [animated]
/// the car drives toward the horizon while the plane crosses the sky (skipped
/// when the platform asks for reduced motion).
class HorizonScene extends StatefulWidget {
  const HorizonScene({
    this.height = 180,
    this.animated = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadii.lg)),
    super.key,
  });

  final double height;
  final bool animated;
  final BorderRadius borderRadius;

  @override
  State<HorizonScene> createState() => _HorizonSceneState();
}

class _HorizonSceneState extends State<HorizonScene> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
    value: 0.55,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shouldAnimate = widget.animated && !MediaQuery.disableAnimationsOf(context);
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0.55;
    }
  }

  @override
  void didUpdateWidget(HorizonScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animated != widget.animated) didChangeDependencies();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      label: "Illustration of a plane in the sky above a road through green hills",
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _HorizonPainter(colors: colors, controller: _controller),
            ),
          ),
        ),
      ),
    );
  }
}

class _HorizonPainter extends CustomPainter {
  _HorizonPainter({required this.colors, required this.controller}) : super(repaint: controller);

  final AppColors colors;
  final AnimationController controller;

  Path _hills(Size s, double baseY, double amp, double phase) {
    final path = Path()..moveTo(0, s.height);
    path.lineTo(0, baseY);
    const steps = 24;
    for (var i = 0; i <= steps; i++) {
      final x = s.width * i / steps;
      final y = baseY - amp * (0.5 + 0.5 * math.sin(i / steps * math.pi * 2.2 + phase));
      path.lineTo(x, y);
    }
    path.lineTo(s.width, s.height);
    path.close();
    return path;
  }

  void _plane(Canvas canvas, Offset at, double angle, double size) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    final body = Path()
      ..moveTo(size, 0)
      ..lineTo(-size * 0.8, -size * 0.55)
      ..lineTo(-size * 0.4, 0)
      ..lineTo(-size * 0.8, size * 0.55)
      ..close();
    canvas.drawPath(body, Paint()..color = Colors.white);
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppTheme.plum.withValues(alpha: 0.5),
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = controller.value;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.skyContainer, colors.amberContainer],
        ).createShader(Offset.zero & size),
    );

    final sunCenter = Offset(w * 0.8, h * 0.42);
    canvas.drawCircle(
      sunCenter,
      h * 0.2,
      Paint()
        ..color = colors.amber.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawCircle(sunCenter, h * 0.13, Paint()..color = colors.amber);

    // Contrail arc, dotted behind the plane.
    final arc = Path()
      ..moveTo(w * 0.03, h * 0.5)
      ..cubicTo(w * 0.22, h * 0.02, w * 0.5, -h * 0.02, w * 0.9, h * 0.3);
    final metric = arc.computeMetrics().first;
    final planeAt = metric.length * (0.12 + 0.76 * t);
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    for (var d = 0.0; d < planeAt - 14; d += 14) {
      final p = metric.getTangentForOffset(d)!.position;
      canvas.drawCircle(p, 2, dotPaint);
    }
    final tangent = metric.getTangentForOffset(planeAt)!;
    _plane(canvas, tangent.position, -tangent.angle, 11);

    canvas.drawPath(_hills(size, h * 0.66, h * 0.16, 0.6), Paint()..color = colors.moss.withValues(alpha: 0.35));
    canvas.drawPath(_hills(size, h * 0.74, h * 0.12, 2.4), Paint()..color = colors.moss.withValues(alpha: 0.7));

    // Road in perspective from the horizon to the bottom edge.
    final horizon = Offset(w * 0.46, h * 0.7);
    final road = Path()
      ..moveTo(horizon.dx - 4, horizon.dy)
      ..lineTo(horizon.dx + 4, horizon.dy)
      ..lineTo(w * 0.78, h)
      ..lineTo(w * 0.22, h)
      ..close();
    canvas.drawPath(road, Paint()..color = colors.asphalt);

    final bottomCenter = Offset(w * 0.5, h);
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeCap = StrokeCap.round;
    const dashes = 6;
    final phase = (t * dashes * 3) % 1;
    for (var i = 0; i < dashes; i++) {
      final a = ((i + phase) / dashes).clamp(0.0, 1.0);
      final b = ((i + phase + 0.45) / dashes).clamp(0.0, 1.0);
      final pa = Offset.lerp(horizon, bottomCenter, a * a)!;
      final pb = Offset.lerp(horizon, bottomCenter, b * b)!;
      dashPaint.strokeWidth = 1 + 3.5 * a;
      canvas.drawLine(pa, pb, dashPaint);
    }

    // Car driving up the road.
    final carProgress = controller.isAnimating ? ((t * 3) % 1) : 0.45;
    final carT = 1 - carProgress * 0.85;
    final carPos = Offset.lerp(horizon, bottomCenter, carT * carT)!;
    final scale = 0.35 + 0.9 * carT * carT;
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: carPos.translate(0, -5 * scale), width: 30 * scale, height: 11 * scale),
      Radius.circular(4 * scale),
    );
    canvas.drawRRect(body, Paint()..color = AppTheme.coral);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: carPos.translate(0, -12 * scale), width: 18 * scale, height: 8 * scale),
        Radius.circular(3 * scale),
      ),
      Paint()..color = AppTheme.coral.withValues(alpha: 0.85),
    );
    final wheel = Paint()..color = colors.asphalt;
    canvas.drawCircle(carPos.translate(-9 * scale, -1 * scale), 3.2 * scale, wheel);
    canvas.drawCircle(carPos.translate(9 * scale, -1 * scale), 3.2 * scale, wheel);
    canvas.drawCircle(carPos.translate(0, -5 * scale), 2 * scale, Paint()..color = colors.amber);
  }

  @override
  bool shouldRepaint(_HorizonPainter old) => old.colors != colors;
}
