import "../../core/bcbp_decoder.dart";
import "pass_file_stub.dart" if (dart.library.js_interop) "pass_file_web.dart";

export "pass_file_stub.dart" if (dart.library.js_interop) "pass_file_web.dart" show canReadPassPdf;

/// The outcome of choosing a boarding pass file: the flight read from it, or a
/// plain-words reason nothing could be read. [cancelled] means the rider closed
/// the chooser, which needs no message.
class PassFileResult {
  const PassFileResult({this.data, this.message, this.cancelled = false});

  final BoardingPassData? data;
  final String? message;
  final bool cancelled;
}

/// Turns the barcodes found in a file into flight details.
PassFileResult interpretPassBarcodes(List<String> texts) {
  if (texts.isEmpty) {
    return const PassFileResult(
      message: "We couldn't find a barcode in that file. Try the PDF from your airline, or a clear, "
          "straight-on screenshot of the barcode.",
    );
  }
  for (final text in texts) {
    final data = decodeBoardingPass(text);
    if (data != null) return PassFileResult(data: data);
  }
  return const PassFileResult(message: "That barcode isn't from a boarding pass. Try the barcode on your boarding pass.");
}

/// Lets the rider choose a boarding pass file (PDF or image on the web, a photo
/// on phones) and reads the flight from it. Never submits anything.
Future<PassFileResult> pickBoardingPassFile() async {
  final pick = await pickPassBarcodes();
  if (pick.cancelled) return const PassFileResult(cancelled: true);
  if (pick.error != null) {
    return const PassFileResult(
      message: "We couldn't read that file. Check you're online and try again, or type your flight number instead.",
    );
  }
  return interpretPassBarcodes(pick.texts);
}
