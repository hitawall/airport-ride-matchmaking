import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Edit profile"),
            onTap: () => context.push("/profile-setup"),
          ),
          ListTile(
            leading: const Icon(Icons.cancel_outlined),
            title: const Text("Cancel active ride request"),
            onTap: () async {
              try {
                final mine = await api.get("/api/ride-requests/mine") as Map<String, dynamic>;
                await api.patch("/api/ride-requests/${mine["id"]}", {"status": "cancelled"});
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text("Ride request cancelled")));
                }
              } on ApiException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text("Blocked users"),
            onTap: () => _showBlockedUsers(context, api),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Log out"),
            onTap: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go("/");
            },
          ),
        ],
      ),
    );
  }

  void _showBlockedUsers(BuildContext context, ApiClient api) {
    showModalBottomSheet(
      context: context,
      builder: (context) => FutureBuilder(
        future: api.get("/api/blocks/mine"),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
          }
          final blocks = (snapshot.data as Map<String, dynamic>)["blocks"] as List;
          if (blocks.isEmpty) {
            return const Padding(padding: EdgeInsets.all(24), child: Text("No blocked users"));
          }
          return ListView.builder(
            shrinkWrap: true,
            itemCount: blocks.length,
            itemBuilder: (context, i) {
              final block = blocks[i] as Map<String, dynamic>;
              return ListTile(
                title: Text(block["blockedId"] as String),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await api.delete("/api/blocks/${block["id"]}");
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
