import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";

/// Lands authenticated users in the right place: profile setup if they have
/// none yet, the active ride request's screen if they have one, otherwise
/// the create-ride-request form.
class HomeRedirectScreen extends ConsumerStatefulWidget {
  const HomeRedirectScreen({super.key});

  @override
  ConsumerState<HomeRedirectScreen> createState() => _HomeRedirectScreenState();
}

class _HomeRedirectScreenState extends ConsumerState<HomeRedirectScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    final api = ref.read(apiClientProvider);

    try {
      await api.get("/api/profile/me");
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        if (mounted) context.go("/profile-setup");
        return;
      }
      rethrow;
    }

    try {
      final rideRequest = await api.get("/api/ride-requests/mine") as Map<String, dynamic>;
      final status = rideRequest["status"] as String;
      final id = rideRequest["id"] as String;
      if (!mounted) return;
      switch (status) {
        case "open":
          context.go("/awaiting-match/$id");
        case "matched":
          context.go("/matches");
        default:
          context.go("/create-ride");
      }
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        if (mounted) context.go("/create-ride");
        return;
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
