import "dart:async";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";
import "../../core/home_leading_button.dart";
import "../../data/models.dart";

const _pollInterval = Duration(seconds: 12);

class AwaitingMatchScreen extends ConsumerStatefulWidget {
  const AwaitingMatchScreen({required this.rideRequestId, super.key});

  final String rideRequestId;

  @override
  ConsumerState<AwaitingMatchScreen> createState() => _AwaitingMatchScreenState();
}

class _AwaitingMatchScreenState extends ConsumerState<AwaitingMatchScreen> {
  Timer? _pollTimer;
  final _startedAt = DateTime.now();
  Duration _elapsed = Duration.zero;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _poll();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    final api = ref.read(apiClientProvider);
    if (mounted) setState(() => _elapsed = DateTime.now().difference(_startedAt));
    try {
      final result =
          await api.get("/api/ride-requests/${widget.rideRequestId}/candidates") as Map<String, dynamic>;
      final candidates = (result["candidates"] as List)
          .map((c) => Candidate.fromJson(c as Map<String, dynamic>))
          .toList();
      if (candidates.isNotEmpty && mounted) {
        _pollTimer?.cancel();
        context.go("/match-review/${widget.rideRequestId}", extra: candidates);
      }
    } on ApiException {
      // transient failure -- just try again on the next tick
    }
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.patch("/api/ride-requests/${widget.rideRequestId}", {"status": "cancelled"});
      if (mounted) context.go("/home");
    } on ApiException {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  String get _elapsedLabel {
    final minutes = _elapsed.inMinutes;
    if (minutes < 1) return "just started";
    return "$minutes min";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: homeLeadingButton(context), title: const Text("Finding you a match")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text(
              "No match yet -- we check every 12 seconds or so.",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Searching for $_elapsedLabel. If you're one of the first people trying "
              "this out, there may not be anyone to match with yet -- that's expected, "
              "not a bug. Feel free to head back to Home and check again later.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "Safety tip: always meet your match at the official airport "
                  "pickup zone, and verify their profile photo before you share a cab.",
                ),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _cancelling ? null : _cancel,
              child: _cancelling
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Cancel this request"),
            ),
          ],
        ),
      ),
    );
  }
}
