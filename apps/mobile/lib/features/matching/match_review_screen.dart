import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";
import "../../core/home_leading_button.dart";
import "../../data/models.dart";

class MatchReviewScreen extends ConsumerStatefulWidget {
  const MatchReviewScreen({required this.rideRequestId, required this.candidates, super.key});

  final String rideRequestId;
  final List<Candidate> candidates;

  @override
  ConsumerState<MatchReviewScreen> createState() => _MatchReviewScreenState();
}

class _MatchReviewScreenState extends ConsumerState<MatchReviewScreen> {
  int _index = 0;
  bool _loading = false;

  Future<void> _act(String action) async {
    if (_index >= widget.candidates.length) return;
    final candidate = widget.candidates[_index];
    setState(() => _loading = true);

    Map<String, dynamic>? result;
    String? errorMessage;
    try {
      final api = ref.read(apiClientProvider);
      result = await api.post("/api/matches", {
        "rideRequestId": widget.rideRequestId,
        "candidateRideRequestId": candidate.rideRequestId,
        "action": action,
      }) as Map<String, dynamic>;
    } on ApiException catch (e) {
      // The candidate may have already been excluded server-side (matched
      // elsewhere, already rejected) -- that's not a failure from the user's
      // perspective, just advance. Anything else, surface it.
      errorMessage = e.statusCode == 409 ? null : e.message;
    }
    if (!mounted) return;

    if (result?["status"] == "mutual") {
      context.go("/mutual-match/${result!["id"]}");
      return;
    }

    setState(() {
      _loading = false;
      _index++;
    });

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(
          errorMessage ?? (action == "like" ? "Liked -- we'll let you know if it's mutual" : "Passed"),
        ),
      ),
    );

    if (_index >= widget.candidates.length) {
      context.go("/awaiting-match/${widget.rideRequestId}");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.candidates.length) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final candidate = widget.candidates[_index];

    return Scaffold(
      appBar: AppBar(leading: homeLeadingButton(context), title: const Text("Possible matches")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundImage: candidate.profilePhotoUrl != null
                            ? NetworkImage(candidate.profilePhotoUrl!)
                            : null,
                        child: candidate.profilePhotoUrl == null
                            ? const Icon(Icons.person, size: 56)
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(candidate.displayName, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text("Heading to ${candidate.destinationLocalityLabel}"),
                      const SizedBox(height: 4),
                      Text(
                        "Landing around ${candidate.flightArrivalAt.toLocal()}".split(".").first,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: "pass",
                  onPressed: _loading ? null : () => _act("pass"),
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.close),
                ),
                FloatingActionButton(
                  heroTag: "like",
                  onPressed: _loading ? null : () => _act("like"),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.favorite),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
