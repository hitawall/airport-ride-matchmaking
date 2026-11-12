import "package:material_ui/material_ui.dart";
import "package:go_router/go_router.dart";

class LegalInterstitialScreen extends StatelessWidget {
  const LegalInterstitialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flight_land, size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                "Before you start",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              const Text(
                "This app only introduces travelers heading the same way so you "
                "can split a cab. You book and pay for your own ride via Uber, "
                "Ola, or Rapido -- we never handle payment or the booking "
                "itself.\n\nAlways meet your match at the official airport "
                "pickup zone, in a well-lit, public area.",
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go("/phone"),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text("I understand, continue"),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
