import "package:material_ui/material_ui.dart";
import "../app_theme.dart";

/// A dashed "road centre line" divider, used instead of a plain rule.
class RoadDivider extends StatelessWidget {
  const RoadDivider({this.color, this.thickness = 2, this.dash = 10, this.gap = 8, super.key});

  final Color? color;
  final double thickness;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: thickness,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashPainter(color: color ?? AppTheme.line, thickness: thickness, dash: dash, gap: gap),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter({required this.color, required this.thickness, required this.dash, required this.gap});

  final Color color;
  final double thickness;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset((x + dash).clamp(0, size.width), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.color != color || old.thickness != thickness || old.dash != dash || old.gap != gap;
}
