import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";
import "../../core/app_theme.dart";
import "../../core/ui/info_banner.dart";
import "../../core/ui/tokens.dart";
import "../../core/ui/tone.dart";
import "fare_split.dart";

/// Opens the "Split the fare" helper for two matched riders. [riders] must be
/// the two riders with real coordinates; [airportLat]/[airportLng] is the pickup.
Future<void> showFareSplitSheet(
  BuildContext context, {
  required double airportLat,
  required double airportLng,
  required List<SplitRider> riders,
  required Map<String, String> areaByRiderId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FareSplitSheet(
      split: suggestFareSplit(airportLat: airportLat, airportLng: airportLng, riders: riders),
      areaByRiderId: areaByRiderId,
    ),
  );
}

class FareSplitSheet extends StatefulWidget {
  const FareSplitSheet({required this.split, required this.areaByRiderId, super.key});

  final FareSplit split;

  /// Destination area name per rider id, shown next to each person.
  final Map<String, String> areaByRiderId;

  @override
  State<FareSplitSheet> createState() => _FareSplitSheetState();
}

class _FareSplitSheetState extends State<FareSplitSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? get _fare {
    final value = double.tryParse(_controller.text.trim());
    return value == null || value <= 0 ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final fare = _fare;
    final amounts = fare == null ? null : widget.split.amountsFor(fare);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Split the fare", style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text("Enter what the cab costs to see a fair way to share it.", style: textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r"[0-9.]"))],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: "Total fare", prefixText: "₹ "),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (var i = 0; i < widget.split.shares.length; i++) ...[
              _ShareRow(
                name: widget.split.shares[i].name,
                area: widget.areaByRiderId[widget.split.shares[i].riderId],
                percent: widget.split.shares[i].percent,
                fraction: widget.split.shares[i].fraction,
                amount: amounts?[i],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            _Working(split: widget.split),
            const SizedBox(height: AppSpacing.md),
            const InfoBanner(
              tone: AppTone.neutral,
              icon: Icons.info_outline,
              title: "Just a suggestion",
              message:
                  "This is only a guide. The app never collects, holds or asks for money, and nothing here is "
                  "an agreement. You are free to split it any way you both like.",
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.name,
    required this.area,
    required this.percent,
    required this.fraction,
    required this.amount,
  });

  final String name;
  final String? area;
  final int percent;
  final double fraction;
  final int? amount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(area == null ? name : "$name · $area", style: textTheme.titleMedium),
            ),
            Text("$percent%", style: textTheme.titleMedium),
            if (amount != null) ...[
              const SizedBox(width: AppSpacing.md),
              Text("₹$amount", style: textTheme.titleLarge?.copyWith(color: AppTheme.coral)),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: LinearProgressIndicator(
            value: fraction.clamp(0, 1),
            minHeight: 8,
            color: AppTheme.coral,
            backgroundColor: AppTheme.sand,
          ),
        ),
      ],
    );
  }
}

/// The working in plain words, so riders can see why the numbers are what they are.
class _Working extends StatelessWidget {
  const _Working({required this.split});

  final FareSplit split;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lines = <String>[];
    for (final leg in split.legs) {
      final who = leg.riderNames.length == 1 ? leg.riderNames.first : leg.riderNames.join(" and ");
      lines.add(
        leg.riderNames.length == 1
            ? "${leg.km.toStringAsFixed(1)} km: only $who is in the cab, so $who pays for it."
            : "${leg.km.toStringAsFixed(1)} km: $who ride together and share it equally.",
      );
    }
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text("How is this worked out?", style: textTheme.titleSmall),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "The cab drops the nearer person first. Each stretch of the route is split equally between "
                  "whoever is still in the cab, using straight-line distances.",
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final line in lines) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text("• $line", style: textTheme.bodyMedium)),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
