import "package:material_ui/material_ui.dart";
import "../app_theme.dart";
import "road_divider.dart";
import "tokens.dart";

/// A ticket-shaped card (notched perforation between two halves) that shows
/// a trip at a glance: airport to destination, when, and which flight.
class BoardingPassCard extends StatelessWidget {
  const BoardingPassCard({
    required this.destination,
    required this.timeLabel,
    this.origin = "Airport",
    this.caption = "YOUR RIDE",
    this.timeCaption = "DEPARTING",
    this.flight,
    this.footer,
    this.onTap,
    super.key,
  });

  final String origin;
  final String destination;
  final String timeLabel;
  final String caption;
  final String timeCaption;
  final String? flight;

  /// Shown under the lower half, e.g. a status pill or a call to action.
  final Widget? footer;
  final VoidCallback? onTap;

  static const double _notchRadius = 11;

  Widget _notch(bool left) {
    return Positioned(
      left: left ? 0 : null,
      right: left ? null : 0,
      top: 0,
      child: ClipRect(
        child: Align(
          alignment: left ? Alignment.centerRight : Alignment.centerLeft,
          widthFactor: 0.5,
          child: Container(
            width: _notchRadius * 2,
            height: _notchRadius * 2,
            decoration: BoxDecoration(
              color: AppTheme.cream,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.line),
            ),
          ),
        ),
      ),
    );
  }

  Widget _info(BuildContext context, String label, String value, {CrossAxisAlignment align = CrossAxisAlignment.start}) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: textTheme.labelSmall?.copyWith(color: AppTheme.mutedInk)),
        const SizedBox(height: 2),
        Text(value, style: textTheme.titleMedium),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppTheme.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: const BorderSide(color: AppTheme.line),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(caption, style: textTheme.labelSmall?.copyWith(color: AppTheme.coral)),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(child: Text(origin, style: textTheme.titleLarge, maxLines: 2)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        child: Icon(Icons.flight, size: 22),
                      ),
                      Expanded(
                        child: Text(
                          destination,
                          style: textTheme.titleLarge,
                          textAlign: TextAlign.end,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              height: _notchRadius * 2,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Positioned.fill(
                    left: _notchRadius + AppSpacing.md,
                    right: _notchRadius + AppSpacing.md,
                    child: Center(child: RoadDivider()),
                  ),
                  _notch(true),
                  _notch(false),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _info(context, timeCaption, timeLabel)),
                      if (flight != null) _info(context, "FLIGHT", flight!, align: CrossAxisAlignment.end),
                    ],
                  ),
                  if (footer != null) ...[const SizedBox(height: AppSpacing.md), footer!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
