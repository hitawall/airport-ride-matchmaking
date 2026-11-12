import "dart:async";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";
import "../../core/home_leading_button.dart";
import "../../data/models.dart";

const _swipeThreshold = 120.0;
const _flyDistance = 700.0;
const _animDuration = Duration(milliseconds: 220);

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
  bool _animating = false;
  Offset _dragOffset = Offset.zero;

  double get _likeProgress => (_dragOffset.dx / _swipeThreshold).clamp(0, 1);
  double get _passProgress => (-_dragOffset.dx / _swipeThreshold).clamp(0, 1);

  void _onPanUpdate(DragUpdateDetails details) {
    if (_animating) return;
    setState(() => _dragOffset += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    if (_animating) return;
    final dx = _dragOffset.dx;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final triggered = dx.abs() > _swipeThreshold || velocity.abs() > 700;
    if (triggered) {
      unawaited(_trigger(dx >= 0 ? "like" : "pass"));
    } else {
      setState(() {
        _animating = true;
        _dragOffset = Offset.zero;
      });
      Future.delayed(_animDuration, () {
        if (mounted) setState(() => _animating = false);
      });
    }
  }

  /// Shared by both the swipe gesture and the Like/Pass buttons: animates the
  /// card off-screen, then performs the actual match action, then resets for
  /// whatever the next card is.
  Future<void> _trigger(String action) async {
    if (_loading || _animating) return;
    final flyDx = action == "like" ? _flyDistance : -_flyDistance;
    setState(() {
      _animating = true;
      _dragOffset = Offset(flyDx, _dragOffset.dy);
    });
    await Future.delayed(_animDuration);
    await _act(action);
    if (mounted) {
      setState(() {
        _dragOffset = Offset.zero;
        _animating = false;
      });
    }
  }

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
              child: AnimatedContainer(
                duration: _animating ? _animDuration : Duration.zero,
                curve: Curves.easeOut,
                transform: Matrix4.rotationZ(_dragOffset.dx / 900)
                  ..setTranslationRaw(_dragOffset.dx, _dragOffset.dy, 0),
                transformAlignment: Alignment.center,
                child: GestureDetector(
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Stack(
                    children: [
                      Card(
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
                              Text(
                                candidate.displayName,
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
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
                      _SwipeStamp(
                        label: "LIKE",
                        color: Theme.of(context).colorScheme.primary,
                        opacity: _likeProgress,
                        alignment: Alignment.topRight,
                        angle: -0.3,
                      ),
                      _SwipeStamp(
                        label: "PASS",
                        color: Theme.of(context).colorScheme.secondary,
                        opacity: _passProgress,
                        alignment: Alignment.topLeft,
                        angle: 0.3,
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
                Transform.scale(
                  scale: 1 + 0.25 * _passProgress,
                  child: FloatingActionButton(
                    heroTag: "pass",
                    onPressed: _loading || _animating ? null : () => _trigger("pass"),
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.close),
                  ),
                ),
                Transform.scale(
                  scale: 1 + 0.25 * _likeProgress,
                  child: FloatingActionButton(
                    heroTag: "like",
                    onPressed: _loading || _animating ? null : () => _trigger("like"),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.favorite),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeStamp extends StatelessWidget {
  const _SwipeStamp({
    required this.label,
    required this.color,
    required this.opacity,
    required this.alignment,
    required this.angle,
  });

  final String label;
  final Color color;
  final double opacity;
  final Alignment alignment;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: angle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: color, width: 3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: 1.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
