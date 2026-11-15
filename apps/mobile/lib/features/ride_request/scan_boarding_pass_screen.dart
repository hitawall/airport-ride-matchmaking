import "package:material_ui/material_ui.dart";
import "package:mobile_scanner/mobile_scanner.dart";
import "../../core/bcbp_decoder.dart";

/// Scans a boarding pass's PDF417/QR barcode (the IATA Bar Coded Boarding
/// Pass format) and pops with the decoded flight number + date for the
/// caller to pre-fill -- never submits anything on its own, since a scan can
/// always be misread.
class ScanBoardingPassScreen extends StatefulWidget {
  const ScanBoardingPassScreen({super.key});

  @override
  State<ScanBoardingPassScreen> createState() => _ScanBoardingPassScreenState();
}

class _ScanBoardingPassScreenState extends State<ScanBoardingPassScreen> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.pdf417, BarcodeFormat.qrCode]);
  bool _handled = false;
  String? _error;

  @override
  void dispose() {
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
    if (mounted) {
      setState(() => _error = "That doesn't look like a boarding pass barcode -- try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan boarding pass")),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Point your camera at the PDF417 barcode on your boarding pass "
                    "(the striped one, not the QR code for your flight app).",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.amber)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
