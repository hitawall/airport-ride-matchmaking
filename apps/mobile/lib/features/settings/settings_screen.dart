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
            onTap: () => _cancelActiveRideRequest(context, api),
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text("Blocked users"),
            onTap: () => _showBlockedUsers(context, api),
          ),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text("Send feedback"),
            onTap: () => _showSendFeedback(context, api),
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

  Future<void> _cancelActiveRideRequest(BuildContext context, ApiClient api) async {
    Map<String, dynamic>? mine;
    try {
      mine = await api.get("/api/ride-requests/mine") as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.statusCode == 404 ? "You don't have a ride request" : e.message)),
        );
      }
      return;
    }

    if (mine["status"] != "open") {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("You don't have an active ride request to cancel")));
      }
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel this request?"),
        content: const Text(
          "You'll stop showing up in other travelers' candidate lists and will need to "
          "create a new request to search again.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Keep searching")),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Cancel request"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
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
  }

  void _showSendFeedback(BuildContext context, ApiClient api) {
    final messageController = TextEditingController();
    var type = "general";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Send feedback", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: "Type", border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: "feature_request", child: Text("Suggest a feature")),
                  DropdownMenuItem(value: "bug_report", child: Text("Report a bug")),
                  DropdownMenuItem(value: "general", child: Text("General feedback")),
                ],
                onChanged: (v) => setSheetState(() => type = v!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: "Message",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final message = messageController.text.trim();
                    if (message.isEmpty) return;
                    try {
                      await api.post("/api/feedback", {"type": type, "message": message});
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Thanks for the feedback!")),
                        );
                      }
                    } on ApiException catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    }
                  },
                  child: const Text("Submit"),
                ),
              ),
            ],
          ),
        ),
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
