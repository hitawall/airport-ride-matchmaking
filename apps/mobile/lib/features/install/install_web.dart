import "dart:js_interop";
import "install_stub.dart" show InstallKind;

export "install_stub.dart" show InstallKind;

// `airpoolInstall` is defined in web/index.html. It has to run before Flutter
// starts because the browser fires its install event only once, early on.
@JS("airpoolInstall.kind")
external String _kind();

@JS("airpoolInstall.prompt")
external JSPromise<JSString> _prompt();

InstallKind currentInstallKind() {
  try {
    return switch (_kind()) {
      "prompt" => InstallKind.prompt,
      "ios" => InstallKind.ios,
      "firefox" => InstallKind.firefox,
      _ => InstallKind.none,
    };
  } catch (_) {
    return InstallKind.none;
  }
}

Future<bool> promptInstall() async {
  try {
    final outcome = await _prompt().toDart;
    return outcome.toDart == "accepted";
  } catch (_) {
    return false;
  }
}
