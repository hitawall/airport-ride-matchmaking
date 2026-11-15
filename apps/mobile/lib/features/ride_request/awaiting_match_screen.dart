import "dart:async";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";
import "../../core/home_leading_button.dart";
import "../../data/models.dart";

const _pollInterval = Duration(seconds: 12);
const _quipInterval = Duration(seconds: 6);

const _waitingQuips = [
  "Scanning the terminal for your ride buddy...",
  "Checking who else just touched down nearby...",
  "Good carpools are worth the wait.",
  "Somewhere out there, someone's luggage just hit the belt.",
  "Still looking -- the airport is bigger than it feels right now.",
];

class AwaitingMatchScreen extends ConsumerStatefulWidget {
  const AwaitingMatchScreen({required this.rideRequestId, super.key});

  final String rideRequestId;

  @override
  ConsumerState<AwaitingMatchScreen> createState() => _AwaitingMatchScreenState();
}

class _AwaitingMatchScreenState extends ConsumerState<AwaitingMatchScreen> {
  Timer? _pollTimer;
  Timer? _quipTimer;
  Timer? _tickTimer;
  final _startedAt = DateTime.now();
  Duration _elapsed = Duration.zero;
  int _quipIndex = 0;
  bool _cancelling = false;
  String? _endedStatus;

  @override
  void initState() {
    super.initState();
    _poll();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
    _quipTimer = Timer.periodic(
      _quipInterval,
      (_) => setState(() => _quipIndex = (_quipIndex + 1) % _waitingQuips.length),
    );
    _tickTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _elapsed = DateTime.now().difference(_startedAt)),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _quipTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    final api = ref.read(apiClientProvider);
    try {
      final result =
          await api.get("/api/ride-requests/${widget.rideRequestId}/candidates") as Map<String, dynamic>;

      final status = result["rideRequestStatus"] as String?;
      if (status != null && status != "open") {
        _pollTimer?.cancel();
        if (!mounted) return;
        if (status == "matched") {
          // Matched via another path (e.g. another device/tab) -- send them
          // to Home, which already knows how to route into the active chat.
          context.go("/home");
        } else {
          setState(() => _endedStatus = status);
        }
        return;
      }

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel this request?"),
        content: const Text(
          "You'll stop showing up in other travelers' candidate lists and will need to "
          "create a new request to search again.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Keep searching")),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Cancel request"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

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
    final minutes = _elapsed.inMinutes.remainder(60).toString().padLeft(2, "0");
    final seconds = _elapsed.inSeconds.remainder(60).toString().padLeft(2, "0");
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    if (_endedStatus != null) {
      return Scaffold(
        appBar: AppBar(leading: homeLeadingButton(context), title: const Text("Finding you a match")),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _endedStatus == "cancelled" ? Icons.cancel_outlined : Icons.timer_off_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                _endedStatus == "cancelled"
                    ? "This request was cancelled"
                    : "This request has expired",
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _endedStatus == "cancelled"
                    ? "You (or another session) cancelled this ride request. Start a new one "
                          "whenever you're ready to look for a match again."
                    : "Nobody matched within the arrival window, so this request stopped "
                          "searching. Create a new one with an updated arrival time.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go("/create-ride"),
                child: const Text("Create a new request"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(leading: homeLeadingButton(context), title: const Text("Finding you a match")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 96,
              width: 96,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const SizedBox(height: 96, width: 96, child: CircularProgressIndicator(strokeWidth: 3)),
                  Text(
                    _elapsedLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Finding your ride buddy",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _waitingQuips[_quipIndex],
                key: ValueKey(_quipIndex),
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Early days -- if you're one of the first people trying this out, there may "
              "not be anyone to match with yet. That's expected, not a bug.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
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
