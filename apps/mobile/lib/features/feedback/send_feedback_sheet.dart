import "package:material_ui/material_ui.dart";
import "../../core/api_client.dart";

/// Shared feedback bottom sheet, reachable from both Settings and the home
/// screen so sending feedback never takes more than one tap to reach.
void showSendFeedbackSheet(BuildContext context, ApiClient api) {
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
            Text("Got thoughts? We're all ears", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              "Bug, brainwave, or just venting -- it all helps.",
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: "Type"),
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
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text("Thanks for the feedback!")));
                    }
                  } on ApiException catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
