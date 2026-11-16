import "package:material_ui/material_ui.dart";
import "tokens.dart";
import "tone.dart";

/// A compact status label such as "Active", "Unmatched" or "Expired".
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {this.tone = AppTone.neutral, super.key});

  final String label;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = tone.resolve(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colors.foreground),
      ),
    );
  }
}
