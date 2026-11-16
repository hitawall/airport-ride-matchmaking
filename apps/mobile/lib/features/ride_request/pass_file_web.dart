import "dart:convert";
import "dart:js_interop";

/// What came back from letting the rider pick a boarding pass file.
class PassPick {
  const PassPick({this.texts = const [], this.cancelled = false, this.error});

  /// The raw text of every barcode found in the file.
  final List<String> texts;
  final bool cancelled;
  final String? error;
}

/// PDFs (the airline's email attachment) and images can both be read in the browser.
const canReadPassPdf = true;

// Defined in web/boarding_pass.js. It opens the file chooser and reads the
// barcode in the browser; the file is never uploaded.
@JS("airpoolPass.pickAndRead")
external JSPromise<JSString> _pickAndRead();

Future<PassPick> pickPassBarcodes() async {
  try {
    final json = jsonDecode((await _pickAndRead().toDart).toDart) as Map<String, dynamic>;
    if (json["cancelled"] == true) return const PassPick(cancelled: true);
    final error = json["error"] as String?;
    if (error != null) return PassPick(error: error);
    return PassPick(texts: [for (final t in (json["texts"] as List? ?? const [])) t as String]);
  } catch (e) {
    return PassPick(error: "$e");
  }
}
