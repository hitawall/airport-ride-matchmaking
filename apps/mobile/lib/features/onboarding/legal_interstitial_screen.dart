import "package:material_ui/material_ui.dart";
import "package:go_router/go_router.dart";
import "../../core/ui/app_buttons.dart";
import "../../core/ui/app_page.dart";
import "../../core/ui/horizon_scene.dart";
import "../../core/ui/tokens.dart";

class LegalInterstitialScreen extends StatelessWidget {
  const LegalInterstitialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AppPage(
      showAppBar: false,
      centered: true,
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: "I understand, continue",
            onPressed: () => context.go("/email"),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                "By continuing you accept our",
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              TextButton(
                onPressed: () => context.push("/terms"),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: const Text("Terms"),
              ),
              Text("and", style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              TextButton(
                onPressed: () => context.push("/privacy"),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: const Text("Privacy policy"),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),
          const HorizonScene(height: 190),
          const SizedBox(height: AppSpacing.xl),
          Text("Before you start", style: textTheme.labelLarge?.copyWith(color: scheme.primary)),
          const SizedBox(height: AppSpacing.xs),
          Text("Landing soon? Share the ride home.", style: textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xl),
          const _Promise(
            icon: Icons.groups_outlined,
            title: "Meet travelers heading your way",
            text: "We match you by airport, arrival time and destination.",
          ),
          const _Promise(
            icon: Icons.local_taxi_outlined,
            title: "You book and pay your own cab",
            text: "Uber, Ola or Rapido. We never handle payment or the booking.",
          ),
          const _Promise(
            icon: Icons.shield_outlined,
            title: "Meet at the official pickup zone",
            text: "Always in a well-lit, public area.",
          ),
        ],
      ),
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: scheme.secondaryContainer,
            child: Icon(icon, color: scheme.onSecondaryContainer),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                Text(text, style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
