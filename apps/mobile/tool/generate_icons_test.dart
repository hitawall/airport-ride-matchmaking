// Draws the launcher icon artwork from the same palette as the in-app
// HorizonScene and writes PNGs to assets/icon/. Run when the artwork changes:
//
//   flutter test tool/generate_icons_test.dart
//   dart run flutter_launcher_icons
//
// To use designer artwork instead, drop files with the same names into
// assets/icon/ and skip this script (see docs/APP_IDENTITY.md).
import "dart:io";
import "dart:math" as math;
import "dart:ui" as ui;

import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mobile/core/app_theme.dart";

const double _s = 1024;

AppColors get _c => AppTheme.light().extension<AppColors>()!;

Path _hills(double baseY, double amp, double phase) {
  final path = Path()
    ..moveTo(0, _s)
    ..lineTo(0, baseY);
  const steps = 24;
  for (var i = 0; i <= steps; i++) {
    final x = _s * i / steps;
    final y = baseY - amp * (0.5 + 0.5 * math.sin(i / steps * math.pi * 2.2 + phase));
    path.lineTo(x, y);
  }
  path
    ..lineTo(_s, _s)
    ..close();
  return path;
}

const _horizon = Offset(_s * 0.5, _s * 0.6);

/// Full-bleed scenery: sky, sun, hills and the road.
void _paintBackground(Canvas canvas) {
  final c = _c;
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, _s, _s),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        const Offset(0, _s * 0.65),
        [c.skyContainer, c.amberContainer],
      ),
  );
  const sun = Offset(_s * 0.74, _s * 0.3);
  canvas.drawCircle(
    sun,
    _s * 0.17,
    Paint()
      ..color = c.amber.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
  );
  canvas.drawCircle(sun, _s * 0.1, Paint()..color = c.amber);

  canvas.drawPath(_hills(_s * 0.58, _s * 0.14, 0.6), Paint()..color = c.moss.withValues(alpha: 0.4));
  canvas.drawPath(_hills(_s * 0.66, _s * 0.1, 2.4), Paint()..color = c.moss.withValues(alpha: 0.75));

  final road = Path()
    ..moveTo(_horizon.dx - 10, _horizon.dy)
    ..lineTo(_horizon.dx + 10, _horizon.dy)
    ..lineTo(_s * 0.92, _s)
    ..lineTo(_s * 0.08, _s)
    ..close();
  canvas.drawPath(road, Paint()..color = c.asphalt);

  final dash = Paint()
    ..color = Colors.white.withValues(alpha: 0.9)
    ..strokeCap = StrokeCap.round;
  const bottom = Offset(_s * 0.5, _s);
  const dashes = 5;
  for (var i = 0; i < dashes; i++) {
    final a = (i + 0.1) / dashes;
    final b = (i + 0.5) / dashes;
    final pa = Offset.lerp(_horizon, bottom, a * a)!;
    final pb = Offset.lerp(_horizon, bottom, b * b)!;
    dash.strokeWidth = 4 + 26 * a;
    canvas.drawLine(pa, pb, dash);
  }
}

/// The subjects, kept inside the central 66% Android guarantees is never cropped.
void _paintForeground(Canvas canvas) {
  // Contrail dots and plane.
  final arc = Path()
    ..moveTo(_s * 0.2, _s * 0.5)
    ..cubicTo(_s * 0.24, _s * 0.3, _s * 0.34, _s * 0.2, _s * 0.5, _s * 0.22);
  final metric = arc.computeMetrics().first;
  final dots = Paint()..color = Colors.white;
  for (var d = 0.0; d < metric.length - 40; d += 48) {
    canvas.drawCircle(metric.getTangentForOffset(d)!.position, 9, dots);
  }
  final tip = metric.getTangentForOffset(metric.length)!;
  canvas.save();
  canvas.translate(tip.position.dx + 30, tip.position.dy);
  canvas.rotate(-tip.angle);
  const k = 74.0;
  final plane = Path()
    ..moveTo(k, 0)
    ..lineTo(-k * 0.8, -k * 0.55)
    ..lineTo(-k * 0.4, 0)
    ..lineTo(-k * 0.8, k * 0.55)
    ..close();
  canvas.drawPath(plane, Paint()..color = Colors.white);
  canvas.drawPath(
    plane,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeJoin = StrokeJoin.round
      ..color = AppTheme.plum,
  );
  canvas.restore();

  // Car on the road.
  const carPos = Offset(_s * 0.5, _s * 0.8);
  const w = 0.17 * _s;
  const h = 0.075 * _s;
  final body = RRect.fromRectAndRadius(
    Rect.fromCenter(center: carPos.translate(0, -h * 0.5), width: w, height: h),
    const Radius.circular(24),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: carPos.translate(0, -h * 1.25), width: w * 0.6, height: h * 0.8),
      const Radius.circular(20),
    ),
    Paint()..color = AppTheme.coral.withValues(alpha: 0.88),
  );
  canvas.drawRRect(body, Paint()..color = AppTheme.coral);
  final wheel = Paint()..color = _c.asphalt;
  canvas.drawCircle(carPos.translate(-w * 0.3, 0), 20, wheel);
  canvas.drawCircle(carPos.translate(w * 0.3, 0), 20, wheel);
  canvas.drawCircle(carPos.translate(0, -h * 0.5), 12, Paint()..color = _c.amber);
}

Future<void> _write(String path, void Function(Canvas) draw, {int size = 1024}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(size / _s);
  draw(canvas);
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(bytes.buffer.asUint8List());
}

void main() {
  testWidgets("generate launcher icon artwork", (tester) async {
    await tester.runAsync(() async {
      await _write("assets/icon/icon_background.png", _paintBackground);
      // flutter_launcher_icons insets the adaptive foreground by 16%, so draw it
      // larger here; after the inset it lands in Android's safe zone.
      await _write("assets/icon/icon_foreground.png", (canvas) {
        canvas
          ..translate(_s / 2, _s / 2)
          ..scale(1.35)
          ..translate(-_s / 2, -_s / 2);
        _paintForeground(canvas);
      });
      await _write("assets/icon/icon.png", (canvas) {
        _paintBackground(canvas);
        _paintForeground(canvas);
      });
      // Square 512 version for the Play Store listing.
      await _write("assets/icon/store_icon_512.png", (canvas) {
        _paintBackground(canvas);
        _paintForeground(canvas);
      }, size: 512);
    });
  });
}
