import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";
import "../../core/notifications.dart";
import "../../core/ui/dialogs.dart";

/// Asks for confirmation, unmatches, and then puts the rider straight back into
/// the search so they are never left at a dead end. Returns true if it unmatched.
Future<bool> unmatchAndFindAnother(
  BuildContext context,
  WidgetRef ref, {
  required String matchId,
  required String name,
}) async {
  final confirmed = await confirmAction(
    context,
    title: "Unmatch $name?",
    message: "This ends the chat for both of you. We'll put you straight back into the search so you can find someone else.",
    confirmLabel: "Unmatch",
    destructive: true,
  );
  if (!confirmed || !context.mounted) return false;

  try {
    final result = await ref.read(apiClientProvider).post("/api/matches/$matchId/unmatch") as Map<String, dynamic>;
    // I ended it myself, so I should not also be told that it ended.
    ref.read(notificationsProvider.notifier).markEndedSeen(matchId);
    if (!context.mounted) return true;
    final reopenedId = result["reopenedRideRequestId"] as String?;
    if (reopenedId != null) {
      showAppSnack(context, "Unmatched. You're back in the search.");
      context.go("/awaiting-match/$reopenedId");
    } else {
      showAppSnack(context, "Unmatched. Start a new search to find someone else.");
      context.go("/home");
    }
    return true;
  } on ApiException catch (e) {
    if (context.mounted) showAppSnack(context, e.message, error: true);
    return false;
  }
}
