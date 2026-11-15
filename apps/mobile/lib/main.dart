import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "app_router.dart";
import "core/app_theme.dart";

void main() {
  runApp(const ProviderScope(child: AirportRideMatchmakingApp()));
}

class AirportRideMatchmakingApp extends ConsumerWidget {
  const AirportRideMatchmakingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: "Airport Ride Matchmaking",
      theme: AppTheme.light(),
      routerConfig: router,
      // The default debug banner sits on top of the Settings icon in several
      // AppBars and absorbs its taps -- see issue #37.
      debugShowCheckedModeBanner: false,
    );
  }
}
