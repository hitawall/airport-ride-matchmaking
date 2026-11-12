import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";
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
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.post("/api/matches", {
        "rideRequestId": widget.rideRequestId,
        "candidateRideRequestId": candidate.rideRequestId,
        "action": action,
      }) as Map<String, dynamic>;

      if (result["status"] == "mutual") {
        if (mounted) context.go("/mutual-match/${result["id"]}");
        return;
      }
    } on ApiException {
      // Fall through to advancing the deck either way -- the candidate either
      // got excluded server-side (rejected/matched elsewhere) or will show up
      // again on the next poll if this was transient.
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _index++;
        });
      }
      if (_index >= widget.candidates.length && mounted) {
        context.go("/awaiting-match/${widget.rideRequestId}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.candidates.length) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final candidate = widget.candidates[_index];

    return Scaffold(
      appBar: AppBar(title: const Text("Possible matches")),
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
