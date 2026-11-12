import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/auth_controller.dart";

class MutualMatchScreen extends ConsumerWidget {
  const MutualMatchScreen({required this.matchId, super.key});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);

    return Scaffold(
      body: FutureBuilder(
        future: api.get("/api/matches/mine"),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final matches = (snapshot.data as Map<String, dynamic>)["matches"] as List;
          final match = matches.cast<Map<String, dynamic>>().firstWhere(
            (m) => m["id"] == matchId,
            orElse: () => const {},
          );
          final name = match["counterpart_display_name"] as String? ?? "your match";

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.celebration, size: 72, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text("It's a match!", style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  "You and $name are heading the same way. Chat to coordinate "
                  "meeting at the pickup zone.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => context.go("/chat/$matchId"),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Text("Open chat"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
