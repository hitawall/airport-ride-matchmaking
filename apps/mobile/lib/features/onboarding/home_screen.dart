import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";

/// The landing screen after login. Shows a welcome summary and the status of
/// the user's most recent ride request, with an action to match. A missing
/// profile is the one case that still auto-redirects (mandatory onboarding
/// gate); everything else is a user-initiated choice, not a forced redirect.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _loading = true;
  String? _error;
  String? _displayName;
  String? _rideRequestStatus;
  String? _rideRequestId;
  String? _activeMatchId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);

    try {
      final profile = await api.get("/api/profile/me") as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _displayName = profile["displayName"] as String?);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        if (mounted) context.go("/profile-setup");
        return;
      }
      if (mounted) setState(() => _error = e.message);
    }

    try {
      final rideRequest = await api.get("/api/ride-requests/mine") as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _rideRequestStatus = rideRequest["status"] as String;
        _rideRequestId = rideRequest["id"] as String;
      });
    } on ApiException catch (e) {
      if (e.statusCode != 404) {
        if (mounted) setState(() => _error = e.message);
      }
      // 404 -- no ride request yet, leave status null.
    }

    if (_rideRequestStatus == "matched") {
      try {
        final result = await api.get("/api/matches/mine") as Map<String, dynamic>;
        final matches = (result["matches"] as List).cast<Map<String, dynamic>>();
        final mutual = matches.where((m) => m["status"] == "mutual").toList();
        if (mounted && mutual.isNotEmpty) {
          setState(() => _activeMatchId = mutual.first["id"] as String);
        }
      } on ApiException catch (e) {
        if (mounted) setState(() => _error = e.message);
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Airport Ride Matchmaking"),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () => context.push("/settings")),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () {
                setState(() => _loading = true);
                return _load();
              },
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.flight_takeoff,
                            size: 36,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _displayName != null ? "Hi, $_displayName" : "Welcome",
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Let's get you a ride buddy for the trip out of the airport.",
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        if (_error != null) ...[
                          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          const SizedBox(height: 16),
                        ],
                        _buildStatusCard(context),
                        const SizedBox(height: 16),
                        _HomeTile(
                          icon: Icons.favorite_outline,
                          iconBackground: Theme.of(context).colorScheme.tertiaryContainer,
                          iconColor: Theme.of(context).colorScheme.onTertiaryContainer,
                          title: "My matches",
                          subtitle: "Active chats and past matches",
                          onTap: () => context.push("/matches"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    switch (_rideRequestStatus) {
      case "open":
        return _HomeTile(
          icon: Icons.hourglass_top,
          iconBackground: Theme.of(context).colorScheme.secondaryContainer,
          iconColor: Theme.of(context).colorScheme.onSecondaryContainer,
          title: "Looking for your match",
          subtitle: "We're checking for travelers heading your way",
          trailingLabel: "Check status",
          onTap: () => context.go("/awaiting-match/$_rideRequestId"),
        );
      case "matched":
        return _HomeTile(
          icon: Icons.celebration_outlined,
          iconBackground: Theme.of(context).colorScheme.primaryContainer,
          iconColor: Theme.of(context).colorScheme.onPrimaryContainer,
          title: "You have a match!",
          subtitle: "Coordinate meeting at the pickup zone",
          trailingLabel: "Open chat",
          onTap: _activeMatchId == null ? null : () => context.go("/chat/$_activeMatchId"),
        );
      default:
        return _HomeTile(
          icon: Icons.flight_land,
          iconBackground: Theme.of(context).colorScheme.secondaryContainer,
          iconColor: Theme.of(context).colorScheme.onSecondaryContainer,
          title: "Ready to find a ride partner?",
          subtitle: "Tell us your flight and destination",
          trailingLabel: "Start",
          onTap: () => context.go("/create-ride"),
        );
    }
  }
}

/// A rounded, icon-led card used throughout the home screen for status and
/// quick-action entries -- gives the screen a consistent "modern tile" feel
/// instead of plain ListTiles.
class _HomeTile extends StatelessWidget {
  const _HomeTile({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailingLabel,
    this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? trailingLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: iconBackground,
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingLabel != null)
                FilledButton(
                  onPressed: onTap,
                  child: Text(trailingLabel!),
                )
              else
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
