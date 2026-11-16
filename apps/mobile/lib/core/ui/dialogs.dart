import "package:material_ui/material_ui.dart";
import "../app_theme.dart";
import "app_buttons.dart";
import "tokens.dart";

/// Asks the user to confirm. Returns true only when they confirm. Use
/// [destructive] for irreversible actions so the confirm button is error-toned.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = "Cancel",
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(cancelLabel)),
        destructive
            ? DestructiveButton(
                label: confirmLabel,
                expand: false,
                onPressed: () => Navigator.of(dialogContext).pop(true),
              )
            : PrimaryButton(
                label: confirmLabel,
                expand: false,
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
      ],
    ),
  );
  return result == true;
}

/// A consistent floating snackbar. Errors use the danger colour.
void showAppSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(content: Text(message), backgroundColor: error ? AppTheme.danger : null),
  );
}
