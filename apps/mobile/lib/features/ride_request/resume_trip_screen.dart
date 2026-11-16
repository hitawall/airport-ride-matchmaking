import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";
import "../../core/ui/state_views.dart";

/// Puts the rider back in the search with the trip they already had, after a
/// match ended. It only runs when the rider asks (a button or an alert), never
/// automatically. If the trip is no longer possible they are sent to start a
/// new one.
class ResumeTripScreen extends ConsumerStatefulWidget {
  const ResumeTripScreen({super.key});

  @override
  ConsumerState<ResumeTripScreen> createState() => _ResumeTripScreenState();
}

class _ResumeTripScreenState extends ConsumerState<ResumeTripScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_resume);
  }

  Future<void> _resume() async {
    if (mounted && _error != null) setState(() => _error = null);
    try {
      final trip = await ref.read(apiClientProvider).post("/api/ride-requests/resume") as Map<String, dynamic>;
      if (mounted) context.go("/awaiting-match/${trip["id"]}");
    } on ApiException catch (e) {
      if (!mounted) return;
      // 404: no trip at all; 410: the arrival window has passed.
      if (e.statusCode == 404 || e.statusCode == 410) {
        context.go("/create-ride");
      } else if (e.statusCode == 409) {
        context.go("/matches");
      } else {
        setState(() => _error = e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _error == null
            ? const LoadingView(message: "Putting you back in the search...")
            : ErrorState(message: _error, onRetry: _resume),
      ),
    );
  }
}
