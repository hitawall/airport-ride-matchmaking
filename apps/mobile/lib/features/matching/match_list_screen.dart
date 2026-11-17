import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/api_client.dart";
import "../../core/app_theme.dart";
import "../../core/auth_controller.dart";
import "../../core/notifications.dart";
import "../../core/ui/app_card.dart";
import "../../core/ui/app_page.dart";
import "../../core/ui/avatar.dart";
import "../../core/ui/formatters.dart";
import "../../core/ui/state_views.dart";
import "../notifications/notifications_screen.dart";
import "../../core/ui/status_pill.dart";
import "../../core/ui/tokens.dart";
import "../../core/ui/tone.dart";
import "../../data/models.dart";
import "rate_match_dialog.dart";
import "unmatch_flow.dart";

class MatchListScreen extends ConsumerStatefulWidget {
  const MatchListScreen({super.key});

  @override
  ConsumerState<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends ConsumerState<MatchListScreen> {
  bool _loading = true;
  String? _error;
  List<MatchSummary> _matches = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await ref.read(apiClientProvider).get("/api/matches/mine") as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _matches = (result["matches"] as List)
            .map((m) => MatchSummary.fromJson(m as Map<String, dynamic>))
            .toList();
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _matches.where((m) => m.status == "mutual").toList();
    final past = _matches.where((m) => m.status == "unmatched" || m.status == "expired").toList();

    final Widget body;
    if (_loading) {
      body = const SizedBox(height: 360, child: LoadingView());
    } else if (_error != null && _matches.isEmpty) {
      body = SizedBox(
        height: 420,
        child: ErrorState(
          message: _error,
          onRetry: () {
            setState(() => _loading = true);
            _load();
          },
        ),
      );
    } else if (active.isEmpty && past.isEmpty) {
      body = SizedBox(
        height: 420,
        child: EmptyState(
          icon: Icons.favorite_outline,
          title: "No matches yet",
          message: "Find a ride partner and your matches will show up here.",
          actionLabel: "Find a ride partner",
          onAction: () => context.go("/create-ride"),
        ),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (active.isNotEmpty) ...[
            const SectionHeader("Active"),
            for (final m in active) _MatchTile(match: m, active: true),
          ],
          if (past.isNotEmpty) ...[
            const SectionHeader("Past matches"),
            for (final m in past) _MatchTile(match: m, active: false),
          ],
        ],
      );
    }

    return AppPage(
      title: "Your matches",
      onRefresh: _load,
      actions: [
        const NotificationBell(),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: "Settings",
          onPressed: () => context.push("/settings"),
        ),
      ],
      body: body,
    );
  }
}

class _MatchTile extends ConsumerWidget {
  const _MatchTile({required this.match, required this.active});

  final MatchSummary match;
  final bool active;

  String get _pastLabel => match.status == "unmatched" ? "Unmatched" : "Expired";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final hasRating = match.counterpartRatingCount > 0 && match.counterpartAvgRating != null;
    final updated = match.updatedAt;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        onTap: () => context.push("/chat/${match.id}"),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            AppAvatar(imageUrl: match.counterpartPhotoUrl, name: match.counterpartDisplayName, radius: 26),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(match.counterpartDisplayName, style: textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (hasRating)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 16, color: context.appColors.amber),
                            const SizedBox(width: 2),
                            Text(
                              "${match.counterpartAvgRating!.toStringAsFixed(1)} (${match.counterpartRatingCount})",
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      if (!active && updated != null)
                        Text(formatFriendlyDateTime(updated), style: textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusPill(
                  active ? "Active" : _pastLabel,
                  tone: active
                      ? AppTone.success
                      : (match.status == "expired" ? AppTone.warning : AppTone.neutral),
                ),
                if (active) ...[
                  if ((ref.watch(notificationsProvider).unreadByMatch[match.id] ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: StatusPill("${ref.watch(notificationsProvider).unreadByMatch[match.id]} new", tone: AppTone.info),
                    ),
                  TextButton(
                    onPressed: () => unmatchAndFindAnother(
                      context,
                      ref,
                      matchId: match.id,
                      name: match.counterpartDisplayName,
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: const Text("Unmatch"),
                  ),
                ],
                if (!active)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.star_outline_rounded, size: 22),
                    tooltip: "Rate this match",
                    onPressed: () => showRateMatchDialog(context, ref.read(apiClientProvider), match.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
