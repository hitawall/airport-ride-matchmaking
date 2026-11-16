import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/auth_controller.dart";
import "../../core/ui/app_buttons.dart";
import "../../core/ui/app_card.dart";
import "../../core/ui/app_page.dart";
import "../../core/ui/tokens.dart";

/// Public (no login) page describing how to delete an account and what that
/// removes. App stores require such a page to be reachable from a web link.
class DeleteAccountInfoScreen extends ConsumerWidget {
  const DeleteAccountInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authControllerProvider).isAuthenticated;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AppPage(
      title: "Delete your account",
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: "Back",
        onPressed: () => context.go(signedIn ? "/home" : "/"),
      ),
      bottomBar: PrimaryButton(
        label: signedIn ? "Open settings" : "Sign in to continue",
        onPressed: () => context.go(signedIn ? "/settings" : "/email"),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text("Delete your account and data", style: textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "You can delete your Airport Ride Matchmaking account at any time, from the app or from this website. It takes a few seconds.",
            style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text("How to delete", style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          const _Step(number: 1, text: "Sign in with your email (we send a one-time code)."),
          const _Step(number: 2, text: "Open Settings from the home screen."),
          const _Step(number: 3, text: "Tap Delete account and confirm."),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("What is deleted", style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  "Your profile and profile photo, phone number, ride requests, matches, chat messages, ratings, "
                  "reports and feedback you sent, blocks, and your login codes. It happens immediately and can't be undone.",
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  "People you were matched with lose that match. You can sign up again later with the same email as a new account.",
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              "$number",
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
