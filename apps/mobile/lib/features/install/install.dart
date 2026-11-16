import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";
import "../../core/auth_controller.dart";
import "../../core/ui/app_buttons.dart";
import "../../core/ui/dialogs.dart";
import "../../core/ui/info_banner.dart";
import "../../core/ui/tokens.dart";
import "../../core/ui/tone.dart";
import "install_stub.dart" if (dart.library.js_interop) "install_web.dart";

export "install_stub.dart" if (dart.library.js_interop) "install_web.dart" show InstallKind;

const _dismissedKey = "install_hint_dismissed";

/// What this device can do to add the app to its home screen. Tests override it.
final installKindProvider = Provider<InstallKind>((ref) => currentInstallKind());

/// The one-line steps for browsers that cannot show an install prompt.
String installSteps(InstallKind kind) => switch (kind) {
  InstallKind.ios => "Tap the Share button, then choose Add to Home Screen.",
  InstallKind.firefox => "Open the browser menu (the three dots), then choose Install or Add to Home screen.",
  _ => "",
};

/// Starts the install: the browser's own dialog where we have it, otherwise the steps.
Future<void> startInstall(BuildContext context, InstallKind kind) async {
  if (kind == InstallKind.prompt) {
    final accepted = await promptInstall();
    if (accepted && context.mounted) showAppSnack(context, "Installing. Look for the app on your home screen.");
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Add to your home screen", style: Theme.of(sheetContext).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(installSteps(kind), style: Theme.of(sheetContext).textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            SecondaryButton(label: "Got it", onPressed: () => Navigator.of(sheetContext).pop()),
          ],
        ),
      ),
    ),
  );
}

/// A dismissible card on the home screen offering to install the app. Shows
/// nothing when the app is already installed, the browser cannot install, or the
/// rider dismissed it before.
class InstallBanner extends ConsumerStatefulWidget {
  const InstallBanner({super.key});

  @override
  ConsumerState<InstallBanner> createState() => _InstallBannerState();
}

class _InstallBannerState extends ConsumerState<InstallBanner> {
  bool _dismissed = true; // hidden until we know it was not dismissed before

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (ref.read(installKindProvider) == InstallKind.none) return;
    String? stored;
    try {
      stored = await ref.read(secureStorageProvider).readString(_dismissedKey);
    } catch (_) {
      // storage unavailable: show the hint rather than hide it forever
    }
    if (mounted) setState(() => _dismissed = stored == "1");
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    try {
      await ref.read(secureStorageProvider).writeString(_dismissedKey, "1");
    } catch (_) {
      // dismissed for this visit at least
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = ref.watch(installKindProvider);
    if (kind == InstallKind.none || _dismissed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: InfoBanner(
        tone: AppTone.info,
        icon: Icons.install_mobile_outlined,
        title: "Get the app on your home screen",
        message: kind == InstallKind.prompt
            ? "Open it in one tap, like any other app."
            : "Open it in one tap. ${installSteps(kind)}",
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kind == InstallKind.prompt)
              TextButton(onPressed: () => startInstall(context, kind), child: const Text("Install")),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: "Dismiss",
              visualDensity: VisualDensity.compact,
              onPressed: _dismiss,
            ),
          ],
        ),
      ),
    );
  }
}
