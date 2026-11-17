import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";
import "../../core/ui/dialogs.dart";

/// Asks for confirmation, then cancels the rider's open search so they stop
/// appearing in other people's lists. Returns true if it was cancelled. Used by
/// the search page and the home screen so both behave the same.
Future<bool> confirmAndCancelSearch(BuildContext context, WidgetRef ref, String rideRequestId) async {
  final confirmed = await confirmAction(
    context,
    title: "Stop searching?",
    message:
        "You'll stop showing up in other travelers' lists. You can start a new search any time.",
    confirmLabel: "Stop searching",
    cancelLabel: "Keep searching",
    destructive: true,
  );
  if (!confirmed || !context.mounted) return false;

  try {
    await ref.read(apiClientProvider).patch("/api/ride-requests/$rideRequestId", {"status": "cancelled"});
    return true;
  } on ApiException catch (e) {
    if (context.mounted) showAppSnack(context, e.message, error: true);
    return false;
  }
}
