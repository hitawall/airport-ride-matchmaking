import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/api_client.dart";
import "../../core/app_theme.dart";
import "../../core/auth_controller.dart";
import "../../core/home_leading_button.dart";
import "../../core/ui/app_page.dart";
import "../../core/ui/avatar.dart";
import "../../core/ui/dialogs.dart";
import "../../core/ui/formatters.dart";
import "../../core/ui/state_views.dart";
import "../../core/ui/tokens.dart";
import "../../core/ui/trolley_bags.dart";
import "../../data/airports.dart";
import "../../data/models.dart";

const _pageDuration = Duration(milliseconds: 220);

// Keeps snackbars above the Pass / Like buttons so they never cover them.
const _snackInset = 132.0;

/// Shows everyone who could share the ride. The rider browses all of them
/// (swipe, the arrows, or the strip of faces) and only then likes the ones they
/// would be happy to travel with; deciding on one never forces the next.
class MatchReviewScreen extends ConsumerStatefulWidget {
  const MatchReviewScreen({required this.rideRequestId, required this.candidates, super.key});

  final String rideRequestId;
  final List<Candidate> candidates;

  @override
  ConsumerState<MatchReviewScreen> createState() => _MatchReviewScreenState();
}

class _MatchReviewScreenState extends ConsumerState<MatchReviewScreen> {
  final _pages = PageController();
  int _index = 0;
  bool _loading = false;

  /// What the rider did with each person, by ride request id: "like" or "pass".
  final _decisions = <String, String>{};

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool get _allDecided => widget.candidates.every((c) => _decisions.containsKey(c.rideRequestId));

  void _goTo(int index) {
    if (index < 0 || index >= widget.candidates.length) return;
    _pages.animateToPage(index, duration: _pageDuration, curve: Curves.easeOut);
  }

  /// The next person after the current one who has no decision yet (wrapping
  /// round), or null when everyone has one.
  int? _nextUndecided() {
    final count = widget.candidates.length;
    for (var step = 1; step < count; step++) {
      final i = (_index + step) % count;
      if (!_decisions.containsKey(widget.candidates[i].rideRequestId)) return i;
    }
    return null;
  }

  Future<void> _act(String action) async {
    if (_loading || _index >= widget.candidates.length) return;
    final candidate = widget.candidates[_index];
    if (_decisions.containsKey(candidate.rideRequestId)) return;
    setState(() => _loading = true);

    Map<String, dynamic>? result;
    String? errorMessage;
    var recorded = true;
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
      // perspective. Anything else, leave the card undecided so the user can
      // try again instead of silently losing this person.
      if (e.statusCode != 409) {
        errorMessage = e.message;
        recorded = false;
      }
    }
    if (!mounted) return;

    if (result?["status"] == "mutual") {
      context.go("/mutual-match/${result!["id"]}");
      return;
    }

    setState(() {
      _loading = false;
      if (recorded) _decisions[candidate.rideRequestId] = action;
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

    if (_allDecided) {
      context.go("/awaiting-match/${widget.rideRequestId}");
      return;
    }
    final next = _nextUndecided();
    if (next != null) _goTo(next);
  }

  @override
  Widget build(BuildContext context) {
    final candidates = widget.candidates;
    if (candidates.isEmpty) {
      return AppPage(
        leading: homeLeadingButton(context),
        title: "Possible matches",
        body: const SizedBox(height: 360, child: LoadingView()),
      );
    }
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final current = candidates[_index];
    final decided = _decisions[current.rideRequestId];
    final busy = _loading || decided != null;

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        tooltip: "Previous person",
                        onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
                      ),
                      Text("${_index + 1} of ${candidates.length}", style: textTheme.labelLarge),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        tooltip: "Next person",
                        onPressed: _index < candidates.length - 1 ? () => _goTo(_index + 1) : null,
                      ),
                    ],
                  ),
                  // Said until the rider has made a first choice, then out of the way.
                  if (_decisions.isEmpty)
                    Text(
                      candidates.length > 1
                          ? "Look at everyone first, then like the people you'd be happy to share with. "
                              "Whoever likes you back first becomes your match."
                          : "Like them if you'd be happy to share the ride.",
                      style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  // The strip needs room; on very short screens the arrows and swipe do the job.
                  if (candidates.length > 1 && MediaQuery.sizeOf(context).height >= 640) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 70,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: candidates.length,
                        separatorBuilder: (context, i) => const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (context, i) => _OverviewChip(
                          candidate: candidates[i],
                          decision: _decisions[candidates[i].rideRequestId],
                          selected: i == _index,
                          onTap: () => _goTo(i),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: candidates.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _CandidateCard(candidate: candidates[i]),
                            if (_decisions[candidates[i].rideRequestId] != null)
                              Positioned(
                                top: AppSpacing.md,
                                left: AppSpacing.md,
                                child: _DecisionTag(
                                  liked: _decisions[candidates[i].rideRequestId] == "like",
                                  name: candidates[i].displayName,
                                ),
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
                        scale: 1,
                        onPressed: busy ? null : () => _act("pass"),
                      ),
                      _RoundAction(
                        label: "Like",
                        icon: Icons.favorite_rounded,
                        background: AppTheme.coral,
                        foreground: Colors.white,
                        scale: 1,
                        onPressed: busy ? null : () => _act("like"),
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

/// One person in the strip above the card: face, first name, and what the
/// rider has done with them, so everyone can be compared at a glance.
class _OverviewChip extends StatelessWidget {
  const _OverviewChip({required this.candidate, required this.decision, required this.selected, required this.onTap});

  final Candidate candidate;
  final String? decision;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final firstName = candidate.displayName.trim().split(" ").first;
    final status = switch (decision) {
      "like" => ", liked",
      "pass" => ", passed",
      _ => "",
    };
    final bags = candidate.trolleyBags;
    return Semantics(
      button: true,
      selected: selected,
      label: "${candidate.displayName}, ${trolleyBagsLabel(bags)}$status",
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Container(
          width: 80,
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: selected ? scheme.primary : AppTheme.line, width: selected ? 2 : 1),
          ),
          child: Opacity(
            opacity: decision == "pass" ? 0.5 : 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AppAvatar(imageUrl: candidate.profilePhotoUrl, name: candidate.displayName, radius: 16),
                    if (decision != null)
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Icon(
                          decision == "like" ? Icons.favorite : Icons.close_rounded,
                          size: 16,
                          color: decision == "like" ? scheme.primary : scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                Text(firstName, style: textTheme.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  bags == null ? "" : "$bags bag${bags == 1 ? "" : "s"}",
                  style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DecisionTag extends StatelessWidget {
  const _DecisionTag({required this.liked, required this.name});

  final bool liked;
  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: liked ? scheme.primary : AppTheme.line, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(liked ? Icons.favorite : Icons.close_rounded, size: 16, color: liked ? scheme.primary : scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            liked ? "You liked $name" : "You passed",
            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
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

  Widget _fallback(BuildContext context, {bool noPhoto = false}) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final trimmed = name.trim();
    return Container(
      color: scheme.primaryContainer,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            trimmed.isEmpty ? "?" : trimmed.characters.first.toUpperCase(),
            style: textTheme.displayLarge?.copyWith(fontSize: 96, color: scheme.onPrimaryContainer),
          ),
          if (noPhoto)
            Text("No photo added", style: textTheme.bodyMedium?.copyWith(color: scheme.onPrimaryContainer)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = url;
    if (photoUrl == null || photoUrl.isEmpty) return _fallback(context, noPhoto: true);
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
