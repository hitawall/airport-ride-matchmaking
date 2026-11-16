import "package:material_ui/material_ui.dart";
import "tokens.dart";
import "tone.dart";

/// An inline notice (safety tip, email-only OTP note, trial mode, errors).
/// One component for every callout so they all look related.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    required this.message,
    this.title,
    this.tone = AppTone.info,
    this.icon,
    this.action,
    super.key,
  });

  final String message;
  final String? title;
  final AppTone tone;
  final IconData? icon;

  /// Optional trailing action, usually a small [TextButton].
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = tone.resolve(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? colors.icon, size: 22, color: colors.foreground),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(title!, style: textTheme.titleSmall?.copyWith(color: colors.foreground)),
                Text(message, style: textTheme.bodyMedium?.copyWith(color: colors.foreground)),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: AppSpacing.sm), action!],
        ],
      ),
    );
  }
}
