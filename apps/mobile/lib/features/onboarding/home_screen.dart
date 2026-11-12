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
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    _displayName != null ? "Hi, $_displayName" : "Welcome",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  _buildStatusCard(context),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.favorite_outline),
                    title: const Text("My matches"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push("/matches"),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    switch (_rideRequestStatus) {
      case "open":
        return Card(
          child: ListTile(
            leading: const Icon(Icons.hourglass_top),
            title: const Text("Looking for your match"),
            subtitle: const Text("We're checking for travelers heading your way."),
            trailing: FilledButton(
              onPressed: () => context.go("/awaiting-match/$_rideRequestId"),
              child: const Text("Check status"),
            ),
          ),
        );
      case "matched":
        return Card(
          child: ListTile(
            leading: const Icon(Icons.celebration_outlined),
            title: const Text("You have a match!"),
            subtitle: const Text("Coordinate meeting at the pickup zone."),
            trailing: FilledButton(
              onPressed: _activeMatchId == null ? null : () => context.go("/chat/$_activeMatchId"),
              child: const Text("Open chat"),
            ),
          ),
        );
      default:
        return Card(
          child: ListTile(
            leading: const Icon(Icons.flight_land),
            title: const Text("Ready to find a ride partner?"),
            subtitle: const Text("Tell us your flight and destination."),
            trailing: FilledButton(
              onPressed: () => context.go("/create-ride"),
              child: const Text("Start"),
            ),
          ),
        );
    }
  }
}
