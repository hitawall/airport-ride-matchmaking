import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "app_router.dart";

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
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      routerConfig: router,
    );
  }
}
