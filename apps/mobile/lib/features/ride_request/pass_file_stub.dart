import "package:image_picker/image_picker.dart";
import "package:mobile_scanner/mobile_scanner.dart";

/// What came back from letting the rider pick a boarding pass file.
class PassPick {
  const PassPick({this.texts = const [], this.cancelled = false, this.error});

  /// The raw text of every barcode found in the file.
  final List<String> texts;
  final bool cancelled;
  final String? error;
}

/// Whether PDFs can be read here. Only the web build can (see web/boarding_pass.js);
/// the phone apps read photos and screenshots through the scanner library.
const canReadPassPdf = false;

/// Lets the rider choose a photo or screenshot of their boarding pass from the
/// gallery and reads its barcode. The image never leaves the device.
Future<PassPick> pickPassBarcodes() async {
  try {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return const PassPick(cancelled: true);
    final controller = MobileScannerController(
      formats: [BarcodeFormat.pdf417, BarcodeFormat.qrCode, BarcodeFormat.aztec],
    );
    try {
      final capture = await controller.analyzeImage(file.path);
      return PassPick(
        texts: [for (final b in capture?.barcodes ?? const <Barcode>[]) if (b.rawValue != null) b.rawValue!],
      );
    } finally {
      await controller.dispose();
    }
  } catch (e) {
    return PassPick(error: "$e");
  }
}
