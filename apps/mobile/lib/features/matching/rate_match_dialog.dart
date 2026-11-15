import "package:material_ui/material_ui.dart";
import "../../core/api_client.dart";

/// Shows a 1-5 star picker and submits a rating for [matchId]. Shared by the
/// chat screen and the match list so rating a past match never takes more
/// than this one dialog to reach.
Future<void> showRateMatchDialog(
  BuildContext context,
  ApiClient api,
  String matchId, {
  VoidCallback? onRated,
}) async {
  var selected = 5;
  final score = await showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text("Rate your match"),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final star = i + 1;
            return IconButton(
              icon: Icon(
                star <= selected ? Icons.star : Icons.star_border,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: () => setDialogState(() => selected = star),
            );
          }),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(selected),
            child: const Text("Submit"),
          ),
        ],
      ),
    ),
  );
  if (score == null || !context.mounted) return;

  try {
    await api.post("/api/matches/$matchId/rating", {"score": score});
    onRated?.call();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Thanks for rating your match!")));
    }
  } on ApiException catch (e) {
    onRated?.call();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
