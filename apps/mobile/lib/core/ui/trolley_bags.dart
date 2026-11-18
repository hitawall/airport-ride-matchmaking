import "package:material_ui/material_ui.dart";
import "../app_theme.dart";
import "tokens.dart";

/// The choices are 0, 1, 2, 3 and "3+". "3+" is stored as this value, and any
/// older trip with more bags than that is shown the same way.
const manyTrolleyBags = 4;

/// Plain words for how much luggage someone brings. Null means the trip was
/// created before this was asked.
String trolleyBagsLabel(int? count) => switch (count) {
  null => "Luggage not given",
  0 => "No trolley bags",
  1 => "1 trolley bag",
  >= manyTrolleyBags => "3+ trolley bags",
  _ => "$count trolley bags",
};

/// A highlighted badge so both riders see the luggage before deciding.
class TrolleyBagsBadge extends StatelessWidget {
  const TrolleyBagsBadge({required this.count, this.large = false, super.key});

  final int? count;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? AppSpacing.md : 10, vertical: large ? 8 : 5),
      decoration: BoxDecoration(
        color: colors.amberContainer,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: colors.amber, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.luggage_outlined, size: large ? 22 : 18, color: AppTheme.ink),
          const SizedBox(width: 6),
          Text(
            trolleyBagsLabel(count),
            style: (large ? textTheme.titleSmall : textTheme.labelLarge)?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
