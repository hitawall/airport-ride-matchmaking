import "dart:async";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/api_client.dart";
import "../../core/app_theme.dart";
import "../../core/auth_controller.dart";
import "../../core/home_leading_button.dart";
import "../../core/ui/app_page.dart";
import "../../core/ui/dialogs.dart";
import "../../core/ui/formatters.dart";
import "../../core/ui/state_views.dart";
import "../../core/ui/tokens.dart";
import "../../core/ui/trolley_bags.dart";
import "../../data/airports.dart";
import "../../data/models.dart";

const _swipeThreshold = 120.0;
const _flyDistance = 700.0;
const _animDuration = Duration(milliseconds: 220);

// Keeps snackbars above the Pass / Like buttons so they never cover them.
const _snackInset = 132.0;

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
    final indexBefore = _index;
    await _act(action);
    if (!mounted) return;
    if (_index == indexBefore) {
      // The action failed and this is still the same card: slide it back.
      setState(() => _dragOffset = Offset.zero);
      await Future.delayed(_animDuration);
    }
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
    var advance = true;
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
      // perspective, just advance. Anything else, keep the card so the user
      // can try again instead of silently losing this person.
      if (e.statusCode != 409) {
        errorMessage = e.message;
        advance = false;
      }
    }
    if (!mounted) return;

    if (result?["status"] == "mutual") {
      context.go("/mutual-match/${result!["id"]}");
      return;
    }

    setState(() {
      _loading = false;
      if (advance) _index++;
    });

    if (errorMessage != null) {
      showAppSnack(context, errorMessage, error: true, bottomInset: _snackInset);
      return;
    }
    showAppSnack(
      context,
      action == "like" ? "Liked. We'll let you know if it's mutual." : "Passed.",
      bottomInset: _snackInset,
    );

    if (_index >= widget.candidates.length) {
      context.go("/awaiting-match/${widget.rideRequestId}");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.candidates.length) {
      return AppPage(
        leading: homeLeadingButton(context),
        title: "Possible matches",
        body: const SizedBox(height: 360, child: LoadingView()),
      );
    }
    final candidate = widget.candidates[_index];
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final busy = _loading || _animating;

    return Scaffold(
      appBar: AppBar(leading: homeLeadingButton(context), title: const Text("Possible matches")),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.lg),
              child: Column(
                children: [
                  Text("${_index + 1} of ${widget.candidates.length}", style: textTheme.labelLarge),
                  if (_index == 0)
                    Text(
                      "Swipe right to like, left to pass",
                      style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  const SizedBox(height: AppSpacing.md),
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
                          fit: StackFit.expand,
                          children: [
                            _CandidateCard(candidate: candidate),
                            _SwipeStamp(
                              label: "LIKE",
                              color: scheme.primary,
                              opacity: _likeProgress,
                              alignment: Alignment.topRight,
                              angle: -0.3,
                            ),
                            _SwipeStamp(
                              label: "PASS",
                              color: scheme.secondary,
                              opacity: _passProgress,
                              alignment: Alignment.topLeft,
                              angle: 0.3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _RoundAction(
                        label: "Pass",
                        icon: Icons.close_rounded,
                        background: AppTheme.surfaceWhite,
                        foreground: AppTheme.plum,
                        outlined: true,
                        scale: 1 + 0.2 * _passProgress,
                        onPressed: busy ? null : () => _trigger("pass"),
                      ),
                      _RoundAction(
                        label: "Like",
                        icon: Icons.favorite_rounded,
                        background: AppTheme.coral,
                        foreground: Colors.white,
                        scale: 1 + 0.2 * _likeProgress,
                        onPressed: busy ? null : () => _trigger("like"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate});

  final Candidate candidate;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final hasRating = candidate.ratingCount > 0 && candidate.avgRating != null;
    final bio = candidate.bio?.trim() ?? "";

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _Photo(url: candidate.profilePhotoUrl, name: candidate.displayName),
                // On the photo so it is never clipped and is seen before like or pass.
                Positioned(
                  top: AppSpacing.md,
                  right: AppSpacing.md,
                  child: TrolleyBagsBadge(count: candidate.trolleyBags, large: true),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.md),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          candidate.displayName,
                          style: textTheme.headlineSmall?.copyWith(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Icon(
                              hasRating ? Icons.star_rounded : Icons.auto_awesome,
                              size: 16,
                              color: context.appColors.amber,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              hasRating
                                  ? "${candidate.avgRating!.toStringAsFixed(1)} (${candidate.ratingCount})"
                                  : "New traveler",
                              style: textTheme.bodyMedium?.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Sized to its content so the photo gets whatever room is left; the
          // cap and clip keep very short screens from overflowing.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 210),
            child: ClipRect(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _Fact(label: "HEADING TO", value: candidate.destinationLocalityLabel)),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _Fact(
                            label: "LEAVES THE AIRPORT",
                            value: formatFriendlyDateTime(candidate.flightArrivalAt),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _Fact(
                            label: "MEET AT",
                            value: airportTerminalLabel(candidate.airportCode, candidate.terminal),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: candidate.flightNumber != null && candidate.flightNumber!.isNotEmpty
                              ? _Fact(label: "FLIGHT", value: candidate.flightNumber!)
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelSmall?.copyWith(color: AppTheme.mutedInk)),
        Text(value, style: textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.url, required this.name});

  final String? url;
  final String name;

  Widget _fallback(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trimmed = name.trim();
    return Container(
      color: scheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        trimmed.isEmpty ? "?" : trimmed.characters.first.toUpperCase(),
        style: Theme.of(context).textTheme.displayLarge?.copyWith(
          fontSize: 96,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = url;
    if (photoUrl == null || photoUrl.isEmpty) return _fallback(context);
    return Image.network(
      photoUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => _fallback(context),
      loadingBuilder: (context, child, progress) => progress == null ? child : _fallback(context),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.scale,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final double scale;
  final bool outlined;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.scale(
            scale: scale,
            child: Material(
              color: background,
              elevation: 2,
              shape: CircleBorder(
                side: outlined ? const BorderSide(color: AppTheme.line) : BorderSide.none,
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: SizedBox(width: 64, height: 64, child: Icon(icon, size: 30, color: foreground)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
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
      child: IgnorePointer(
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Opacity(
              opacity: opacity,
              child: Transform.rotate(
                angle: angle,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    border: Border.all(color: color, width: 3),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
