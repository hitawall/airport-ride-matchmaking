import "dart:async";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";
import "../../core/home_leading_button.dart";
import "../../core/ui/app_buttons.dart";
import "../../core/ui/app_page.dart";
import "../../core/ui/boarding_pass_card.dart";
import "../../core/ui/dialogs.dart";
import "../../core/ui/formatters.dart";
import "../../core/ui/horizon_scene.dart";
import "../../core/ui/info_banner.dart";
import "../../core/ui/state_views.dart";
import "../../core/ui/tokens.dart";
import "../../core/ui/tone.dart";
import "../../data/airports.dart";
import "../../data/models.dart";

const _pollInterval = Duration(seconds: 12);
const _quipInterval = Duration(seconds: 6);

const _waitingQuips = [
  "Scanning the terminal for your ride buddy...",
  "Checking who else just touched down nearby...",
  "Good carpools are worth the wait.",
  "Somewhere out there, someone's luggage just hit the belt.",
  "New here? Matches grow with every traveler who joins.",
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
  DateTime _startedAt = DateTime.now();
  Duration _elapsed = Duration.zero;
  int _quipIndex = 0;
  bool _cancelling = false;
  bool _connectionLost = false;
  String? _endedStatus;
  RideRequest? _ride;

  @override
  void initState() {
    super.initState();
    _loadRequest();
    _poll();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
    _quipTimer = Timer.periodic(_quipInterval, (_) {
      if (mounted) setState(() => _quipIndex = (_quipIndex + 1) % _waitingQuips.length);
    });
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = DateTime.now().difference(_startedAt));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _quipTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  /// Fetches what was requested so the screen can show it, and so the timer
  /// counts from when the request was created rather than from screen entry.
  Future<void> _loadRequest() async {
    try {
      final json = await ref.read(apiClientProvider).get("/api/ride-requests/mine") as Map<String, dynamic>;
      if (json["id"] != widget.rideRequestId || !mounted) return;
      final createdAt = DateTime.tryParse(json["createdAt"] as String? ?? "");
      setState(() {
        _ride = RideRequest.fromJson(json);
        if (createdAt != null) _startedAt = createdAt;
      });
    } on ApiException {
      // The summary is a nicety; the search itself keeps working without it.
    }
  }

  Future<void> _poll() async {
    final api = ref.read(apiClientProvider);
    try {
      final result =
          await api.get("/api/ride-requests/${widget.rideRequestId}/candidates") as Map<String, dynamic>;
      if (mounted && _connectionLost) setState(() => _connectionLost = false);

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
      if (mounted) setState(() => _connectionLost = true);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await confirmAction(
      context,
      title: "Cancel this request?",
      message:
          "You'll stop showing up in other travelers' candidate lists and will need to "
          "create a new request to search again.",
      confirmLabel: "Cancel request",
      cancelLabel: "Keep searching",
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.patch("/api/ride-requests/${widget.rideRequestId}", {"status": "cancelled"});
      if (mounted) context.go("/home");
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _cancelling = false);
        showAppSnack(context, e.message, error: true);
      }
    }
  }

  String get _elapsedLabel {
    final hours = _elapsed.inHours;
    final minutes = _elapsed.inMinutes.remainder(60).toString().padLeft(2, "0");
    final seconds = _elapsed.inSeconds.remainder(60).toString().padLeft(2, "0");
    return hours > 0 ? "$hours:$minutes:$seconds" : "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (_endedStatus != null) {
      final cancelled = _endedStatus == "cancelled";
      return AppPage(
        leading: homeLeadingButton(context),
        title: "Your ride request",
        body: SizedBox(
          height: 420,
          child: EmptyState(
            icon: cancelled ? Icons.cancel_outlined : Icons.timer_off_outlined,
            title: cancelled ? "This request was cancelled" : "This request has expired",
            message: cancelled
                ? "You (or another session) cancelled this ride request. Start a new one "
                      "whenever you're ready to look for a match again."
                : "Nobody matched within the arrival window, so this request stopped "
                      "searching. Create a new one with an updated arrival time.",
            actionLabel: "Create a new request",
            onAction: () => context.go("/create-ride"),
          ),
        ),
      );
    }

    final ride = _ride;
    return AppPage(
      leading: homeLeadingButton(context),
      title: "Finding your ride buddy",
      bottomBar: SecondaryButton(label: "Cancel this request", loading: _cancelling, onPressed: _cancel),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_connectionLost) ...[
            const InfoBanner(
              tone: AppTone.warning,
              icon: Icons.wifi_off_outlined,
              title: "Connection lost",
              message: "We'll keep trying. Your request is still active.",
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          const HorizonScene(height: 170, animated: true),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              _elapsedLabel,
              style: textTheme.displaySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Center(child: Text("searching so far", style: textTheme.bodySmall)),
          const SizedBox(height: AppSpacing.md),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              _waitingQuips[_quipIndex],
              key: ValueKey(_quipIndex),
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (ride != null) ...[
            BoardingPassCard(
              caption: "YOUR REQUEST",
              origin: ride.terminal == null ? "Airport" : airportTerminalLabel(ride.airportCode, ride.terminal),
              destination: ride.destinationLocalityLabel,
              timeCaption: "LEAVING THE AIRPORT",
              timeLabel: formatFriendlyDateTime(ride.flightArrivalAt),
              flight: ride.flightNumber,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          const InfoBanner(
            tone: AppTone.safety,
            title: "Stay safe",
            message:
                "Meet your match at the official airport pickup zone, and check their profile "
                "photo before you share a cab.",
          ),
        ],
      ),
    );
  }
}
