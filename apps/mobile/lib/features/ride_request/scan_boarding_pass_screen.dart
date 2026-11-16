import "dart:async";

import "package:material_ui/material_ui.dart";
import "package:mobile_scanner/mobile_scanner.dart";

import "../../core/app_theme.dart";
import "../../core/bcbp_decoder.dart";
import "../../core/ui/tokens.dart";

/// Scans a boarding pass's PDF417, QR or Aztec barcode (the IATA Bar Coded Boarding
/// Pass format) and pops with the decoded flight number + date for the
/// caller to pre-fill -- never submits anything on its own, since a scan can
/// always be misread.
class ScanBoardingPassScreen extends StatefulWidget {
  const ScanBoardingPassScreen({super.key});

  @override
  State<ScanBoardingPassScreen> createState() => _ScanBoardingPassScreenState();
}

class _ScanBoardingPassScreenState extends State<ScanBoardingPassScreen> {
  final _controller = MobileScannerController(
    // Paper passes use PDF417; phone, wallet and PDF passes use QR or Aztec
    // (IndiGo, for one, prints Aztec).
    formats: [BarcodeFormat.pdf417, BarcodeFormat.qrCode, BarcodeFormat.aztec],
  );
  Timer? _errorTimer;
  bool _handled = false;
  String? _error;

  @override
  void dispose() {
    _errorTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final decoded = decodeBoardingPass(raw);
      if (decoded != null) {
        _handled = true;
        Navigator.of(context).pop(decoded);
        return;
      }
    }
    // The scanner fires on every frame, so show the message once and let it
    // clear itself instead of rebuilding the screen constantly.
    if (_error == null && mounted) {
      setState(
        () => _error =
            "That doesn't look like a boarding pass barcode. Try again.",
      );
      _errorTimer?.cancel();
      _errorTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _error = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: context.appColors.asphalt,
      appBar: AppBar(
        backgroundColor: context.appColors.asphalt,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Scan boarding pass",
          style: textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              if (state.torchState == TorchState.unavailable) {
                return const SizedBox.shrink();
              }
              final on = state.torchState == TorchState.on;
              return IconButton(
                icon: Icon(on ? Icons.flash_on : Icons.flash_off),
                tooltip: on ? "Turn flashlight off" : "Turn flashlight on",
                onPressed: _controller.toggleTorch,
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<MobileScannerState>(
        valueListenable: _controller,
        builder: (context, state, _) => Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => const SizedBox.shrink(),
            ),
            // The scanner lays its own error widget out inside the video box,
            // which misplaces it, so the unavailable state is drawn here. With
            // no camera there is also nothing to frame, and the scrim would
            // dim the explanation.
            if (state.error != null) const Positioned.fill(child: _CameraUnavailable()),
            if (state.error == null) ...[
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _ViewfinderPainter()),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(
                        maxWidth: AppSpacing.maxContentWidth,
                      ),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceWhite,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Line up the barcode",
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            "Hold your boarding pass inside the frame. It works with the wide striped "
                            "barcode or the square QR code.",
                            style: textTheme.bodyMedium,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _error!,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppTheme.danger,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              size: 48,
              color: Colors.white,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              "Camera unavailable",
              style: textTheme.headlineSmall?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "Allow camera access in your browser or device settings, or go back and type "
              "your flight number instead.",
              style: textTheme.bodyMedium?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A dimmed scrim with a rounded window and corner brackets marking where to
/// hold the barcode.
class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final width = (size.width * 0.86).clamp(0.0, 360.0);
    final height = width * 0.6;
    final window = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.38),
        width: width,
        height: height,
      ),
      const Radius.circular(AppRadii.md),
    );

    final scrim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(window),
    );
    canvas.drawPath(
      scrim,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final bracket = Paint()
      ..color = AppTheme.coral
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const arm = 28.0;
    final r = window.outerRect;
    for (final corner in [
      [r.topLeft, const Offset(1, 0), const Offset(0, 1)],
      [r.topRight, const Offset(-1, 0), const Offset(0, 1)],
      [r.bottomLeft, const Offset(1, 0), const Offset(0, -1)],
      [r.bottomRight, const Offset(-1, 0), const Offset(0, -1)],
    ]) {
      final origin = corner[0];
      canvas.drawLine(origin, origin + corner[1] * arm, bracket);
      canvas.drawLine(origin, origin + corner[2] * arm, bracket);
    }
  }

  @override
  bool shouldRepaint(_ViewfinderPainter old) => false;
}
