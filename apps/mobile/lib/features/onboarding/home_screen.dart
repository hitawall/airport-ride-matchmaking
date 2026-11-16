import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";
import "../../core/notifications.dart";
import "../../core/ui/action_tile.dart";
import "../../core/ui/app_buttons.dart";
import "../../core/ui/app_card.dart";
import "../../core/ui/app_page.dart";
import "../../core/ui/boarding_pass_card.dart";
import "../../core/ui/formatters.dart";
import "../../core/ui/horizon_scene.dart";
import "../../core/ui/info_banner.dart";
import "../../core/ui/state_views.dart";
import "../../core/ui/status_pill.dart";
import "../../core/ui/tokens.dart";
import "../../core/ui/tone.dart";
import "../../data/airports.dart";
import "../../data/models.dart";
import "../feedback/send_feedback_sheet.dart";

/// The landing screen after login. Shows a greeting and the user's current
/// trip. A missing profile is the one case that still auto-redirects
/// (mandatory onboarding gate); everything else is a user-initiated choice.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _loading = true;
  String? _error;
  String? _displayName;
  RideRequest? _ride;
  String? _activeMatchId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    String? error;
    String? name = _displayName;
    RideRequest? ride;
    String? matchId;

    try {
      final profile = await api.get("/api/profile/me") as Map<String, dynamic>;
      name = profile["displayName"] as String?;
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        if (mounted) context.go("/profile-setup");
        return;
      }
      error = e.message;
    }

    try {
      ride = RideRequest.fromJson(await api.get("/api/ride-requests/mine") as Map<String, dynamic>);
    } on ApiException catch (e) {
      // 404 means no ride request yet.
      if (e.statusCode != 404) error = e.message;
    }

    if (ride?.status == "matched") {
      try {
        final result = await api.get("/api/matches/mine") as Map<String, dynamic>;
        final matches = (result["matches"] as List).cast<Map<String, dynamic>>();
        final mutual = matches.where((m) => m["status"] == "mutual").toList();
        if (mutual.isNotEmpty) matchId = mutual.first["id"] as String;
      } on ApiException catch (e) {
        error = e.message;
      }
    }

    // A "matched" trip with no active match behind it (the match expired or
    // ended) is over: show the plan-a-trip state so the rider is never stuck.
    if (ride?.status == "matched" && matchId == null && error == null) ride = null;

    if (!mounted) return;
    setState(() {
      _displayName = name;
      _ride = ride;
      _activeMatchId = matchId;
      _error = error;
      _loading = false;
    });
  }

  /// Pushed screens (settings, matches) can change the trip, e.g. cancelling
  /// a request, so reload when the user comes back.
  Future<void> _openAndRefresh(String location) async {
    await context.push(location);
    if (mounted) _load();
  }

  bool get _hasActiveTrip => _ride?.status == "open" || _ride?.status == "matched";

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final alerts = ref.watch(notificationsProvider);

    return AppPage(
      onRefresh: _load,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: "Settings",
          onPressed: () => _openAndRefresh("/settings"),
        ),
      ],
      bottomBar: (_loading || _hasActiveTrip)
          ? null
          : PrimaryButton(
              label: "Find a ride partner",
              icon: Icons.flight_land,
              onPressed: () => context.go("/create-ride"),
            ),
      body: _loading
          ? const SizedBox(height: 360, child: LoadingView())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const HorizonScene(height: 150),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  _displayName != null ? "Hi, $_displayName" : "Welcome",
                  style: textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _hasActiveTrip ? "Here's where your ride stands." : "Where to after you land?",
                  style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (_error != null) ...[
                  InfoBanner(
                    tone: AppTone.error,
                    message: _error!,
                    action: TextButton(onPressed: _load, child: const Text("Retry")),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                _buildTripCard(context, alerts),
                const SizedBox(height: AppSpacing.lg),
                ActionTile(
                  icon: Icons.favorite_outline,
                  tone: AppTone.safety,
                  title: "My matches",
                  subtitle: alerts.unreadTotal > 0
                      ? "${alerts.unreadTotal} unread ${alerts.unreadTotal == 1 ? "message" : "messages"}"
                      : "Active chats and past matches",
                  onTap: () => _openAndRefresh("/matches"),
                ),
                const SizedBox(height: AppSpacing.lg),
                _FeedbackCallout(
                  onTap: () => showSendFeedbackSheet(context, ref.read(apiClientProvider)),
                ),
              ],
            ),
    );
  }

  Widget _buildTripCard(BuildContext context, NotificationState alerts) {
    final ride = _ride;
    if (ride == null || !_hasActiveTrip) {
      return const EmptyTripCard();
    }
    final isMatched = ride.status == "matched";
    return BoardingPassCard(
      caption: isMatched ? "YOU HAVE A MATCH" : "LOOKING FOR YOUR MATCH",
      origin: ride.terminal == null ? "Airport" : airportTerminalLabel(ride.airportCode, ride.terminal),
      destination: ride.destinationLocalityLabel,
      timeCaption: "LEAVING THE AIRPORT",
      timeLabel: formatFriendlyDateTime(ride.flightArrivalAt),
      flight: ride.flightNumber,
      footer: Row(
        children: [
          StatusPill(
            isMatched ? "Matched" : "Searching",
            tone: isMatched ? AppTone.success : AppTone.info,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              isMatched
                  ? (alerts.unreadTotal > 0 ? "${alerts.unreadTotal} new — tap to open your chat" : "Tap to open your chat")
                  : (alerts.incomingLikes > 0
                      ? "${alerts.incomingLikes} ${alerts.incomingLikes == 1 ? "person likes" : "people like"} your trip — tap to review"
                      : "Tap to check status"),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () {
        if (isMatched) {
          context.go(_activeMatchId == null ? "/matches" : "/chat/$_activeMatchId");
        } else {
          context.go("/awaiting-match/${ride.id}");
        }
      },
    );
  }
}

/// Shown when there is no open or matched request: a gentle nudge rather
/// than a bare empty area. The pinned button below carries the action.
class EmptyTripCard extends StatelessWidget {
  const EmptyTripCard({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      color: scheme.primaryContainer,
      child: Row(
        children: [
          Icon(Icons.flight_land, size: 32, color: scheme.onPrimaryContainer),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "No ride planned yet",
                  style: textTheme.titleMedium?.copyWith(color: scheme.onPrimaryContainer),
                ),
                Text(
                  "Tell us your flight and where you're headed. We'll find someone going your way.",
                  style: textTheme.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _feedbackQuips = [
  "Found a bug? Got a wild idea? We want to hear it.",
  "Tell us what's awkward. We'll pretend we meant to do that.",
  "Your 30-second rant could become next week's feature.",
  "Loved it, hated it, confused by it. Spill it below.",
];

/// A visually distinct callout (not just another tile) so feedback gets
/// noticed instead of blending into the rest of the home screen.
class _FeedbackCallout extends StatelessWidget {
  const _FeedbackCallout({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final quip = _feedbackQuips[DateTime.now().day % _feedbackQuips.length];
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      color: scheme.secondaryContainer,
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: scheme.secondary,
            child: const Icon(Icons.forum_outlined, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Got thoughts? We're all ears",
                  style: textTheme.titleMedium?.copyWith(color: scheme.onSecondaryContainer),
                ),
                Text(quip, style: textTheme.bodySmall?.copyWith(color: scheme.onSecondaryContainer)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.onSecondaryContainer),
        ],
      ),
    );
  }
}
