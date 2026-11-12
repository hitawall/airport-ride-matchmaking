import "package:material_ui/material_ui.dart";
import "package:go_router/go_router.dart";

/// A consistent, always-present way back to Home -- used on funnel screens
/// (create-ride, awaiting-match, match-review, mutual-match, chat) that
/// navigate forward via `go` (no back-stack), so no screen is a dead end
/// regardless of how the user arrived at it.
IconButton homeLeadingButton(BuildContext context) {
  return IconButton(
    icon: const Icon(Icons.home_outlined),
    tooltip: "Home",
    onPressed: () => context.go("/home"),
  );
}
