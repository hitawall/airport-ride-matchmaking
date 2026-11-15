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
          final allMatches = ((snapshot.data as Map<String, dynamic>)["matches"] as List)
              .map((m) => MatchSummary.fromJson(m as Map<String, dynamic>))
              .toList();
          final active = allMatches.where((m) => m.status == "mutual").toList();
          final past = allMatches
              .where((m) => m.status == "unmatched" || m.status == "expired")
              .toList();

          if (active.isEmpty && past.isEmpty) {
            return Center(
              child: TextButton(
                onPressed: () => context.go("/create-ride"),
                child: const Text("No matches yet -- create a new ride request"),
              ),
            );
          }

          return ListView(
            children: [
              if (active.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text("Active", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ...active.map((m) => _MatchTile(match: m, active: true)),
              ],
              if (past.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text("Past matches", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ...past.map((m) => _MatchTile(match: m, active: false)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match, required this.active});

  final MatchSummary match;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            match.counterpartPhotoUrl != null ? NetworkImage(match.counterpartPhotoUrl!) : null,
        child: match.counterpartPhotoUrl == null ? const Icon(Icons.person) : null,
      ),
      title: Text(match.counterpartDisplayName),
      subtitle: active
          ? null
          : Text(match.status == "unmatched" ? "Unmatched" : "Expired"),
      trailing: active ? null : const Icon(Icons.chat_bubble_outline, size: 18),
      onTap: () => context.go("/chat/${match.id}"),
    );
  }
}
