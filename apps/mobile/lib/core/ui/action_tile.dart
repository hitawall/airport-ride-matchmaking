import "package:material_ui/material_ui.dart";
import "app_card.dart";
import "tokens.dart";
import "tone.dart";

/// An icon-led, fully tappable row card used for navigation and status
/// entries. One tap target: the whole card (no nested buttons).
class ActionTile extends StatelessWidget {
  const ActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.tone = AppTone.neutral,
    this.trailing,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final AppTone tone;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = tone.resolve(context);
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: colors.background,
            child: Icon(icon, color: colors.foreground),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          trailing ?? (onTap == null ? const SizedBox.shrink() : const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}
