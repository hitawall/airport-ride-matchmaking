import "package:flutter/foundation.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "app_router.dart";
import "core/app_config.dart";
import "core/app_theme.dart";
import "core/auth_controller.dart";
import "core/telemetry.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Telemetry.init();

  // Unhandled errors still print as before; we also send a scrubbed copy.
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (previousOnError != null) {
      previousOnError(details);
    } else {
      FlutterError.presentError(details);
    }
    Telemetry.reportError(details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint("Unhandled error: $error\n$stack");
    Telemetry.reportError(error, stack);
    return true;
  };

  runApp(const ProviderScope(child: AirportRideMatchmakingApp()));
}

class AirportRideMatchmakingApp extends ConsumerWidget {
  const AirportRideMatchmakingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // Count one "app opened" per run, once the user is signed in.
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.isAuthenticated && !(previous?.isAuthenticated ?? false)) {
        Telemetry.reportAppOpened(ref.read(apiClientProvider));
      }
    });
    return MaterialApp.router(
      title: AppConfig.appName,
      theme: AppTheme.light(),
      routerConfig: router,
      // The default debug banner sits on top of the Settings icon in several
      // AppBars and absorbs its taps -- see issue #37.
      debugShowCheckedModeBanner: false,
    );
  }
}
