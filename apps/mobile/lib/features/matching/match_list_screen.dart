import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/auth_controller.dart";
import "../../data/models.dart";

class MatchListScreen extends ConsumerWidget {
  const MatchListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your matches"),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () => context.push("/settings")),
        ],
      ),
      body: FutureBuilder(
        future: api.get("/api/matches/mine"),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final matches = ((snapshot.data as Map<String, dynamic>)["matches"] as List)
              .map((m) => MatchSummary.fromJson(m as Map<String, dynamic>))
              .where((m) => m.status == "mutual")
              .toList();

          if (matches.isEmpty) {
            return Center(
              child: TextButton(
                onPressed: () => context.go("/create-ride"),
                child: const Text("No matches yet -- create a new ride request"),
              ),
            );
          }

          return ListView.builder(
            itemCount: matches.length,
            itemBuilder: (context, i) {
              final m = matches[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                      m.counterpartPhotoUrl != null ? NetworkImage(m.counterpartPhotoUrl!) : null,
                  child: m.counterpartPhotoUrl == null ? const Icon(Icons.person) : null,
                ),
                title: Text(m.counterpartDisplayName),
                onTap: () => context.go("/chat/${m.id}"),
              );
            },
          );
        },
      ),
    );
  }
}
