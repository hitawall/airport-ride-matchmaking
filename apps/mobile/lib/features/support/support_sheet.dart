import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";
import "../../core/app_config.dart";
import "../../core/ui/app_buttons.dart";
import "../../core/ui/dialogs.dart";
import "../../core/ui/info_banner.dart";
import "../../core/ui/tokens.dart";
import "../../core/ui/tone.dart";

/// Shows how to reach support. The address comes from AppConfig.supportEmail;
/// until the owner sets it the sheet says so instead of showing a made-up one.
void showSupportSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final textTheme = Theme.of(sheetContext).textTheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Contact support", style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "Questions, a problem with a match, or a privacy request? Email us and include what happened.",
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (AppConfig.hasSupportEmail) ...[
              SelectableText(AppConfig.supportEmail, style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.lg),
              SecondaryButton(
                label: "Copy email address",
                icon: Icons.copy,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: AppConfig.supportEmail));
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                    showAppSnack(context, "Email address copied.");
                  }
                },
              ),
            ] else
              const InfoBanner(
                tone: AppTone.info,
                message: "A support address isn't set up yet. For safety concerns, use Report inside the chat.",
              ),
          ],
        ),
      );
    },
  );
}
