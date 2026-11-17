import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/api_client.dart";
import "../../core/app_theme.dart";
import "../../core/auth_controller.dart";
import "../../core/home_leading_button.dart";
import "../../core/notifications.dart";
import "../../core/ui/app_buttons.dart";
import "../../core/ui/app_page.dart";
import "../../core/ui/avatar.dart";
import "../../core/ui/state_views.dart";
import "../../core/ui/tokens.dart";
import "../../data/models.dart";

class MutualMatchScreen extends ConsumerStatefulWidget {
  const MutualMatchScreen({required this.matchId, super.key});

  final String matchId;

  @override
  ConsumerState<MutualMatchScreen> createState() => _MutualMatchScreenState();
}

class _MutualMatchScreenState extends ConsumerState<MutualMatchScreen> {
  bool _loading = true;
  String? _error;
  MatchSummary? _match;
  String? _myPhotoUrl;
  String? _myName;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(notificationsProvider.notifier).markMatchSeen(widget.matchId));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = ref.read(apiClientProvider);
    try {
      final result = await api.get("/api/matches/mine") as Map<String, dynamic>;
      final matches = (result["matches"] as List)
          .map((m) => MatchSummary.fromJson(m as Map<String, dynamic>))
          .toList();
      _match = matches.where((m) => m.id == widget.matchId).firstOrNull;
      try {
        final profile = await api.get("/api/profile/me") as Map<String, dynamic>;
        _myPhotoUrl = profile["profilePhotoUrl"] as String?;
        _myName = profile["displayName"] as String?;
      } on ApiException {
        // Our own photo is decoration; the match itself is what matters.
      }
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return AppPage(
        leading: homeLeadingButton(context),
        body: const SizedBox(height: 420, child: LoadingView()),
      );
    }
    if (_error != null) {
      return AppPage(
        leading: homeLeadingButton(context),
        body: SizedBox(height: 420, child: ErrorState(message: _error, onRetry: _load)),
      );
    }

    final name = _match?.counterpartDisplayName ?? "your match";
    return AppPage(
      leading: homeLeadingButton(context),
      centered: true,
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: "Open chat",
            icon: Icons.chat_bubble_outline,
            onPressed: () => context.go("/chat/${widget.matchId}"),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(onPressed: () => context.go("/home"), child: const Text("Back to home")),
        ],
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Celebration(
            mine: AppAvatar(imageUrl: _myPhotoUrl, name: _myName, radius: 52),
            theirs: AppAvatar(
              imageUrl: _match?.counterpartPhotoUrl,
              name: _match?.counterpartDisplayName,
              radius: 52,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text("It's a match!", style: textTheme.displaySmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "You and $name are heading the same way. Chat to agree on a landmark to meet at, like a coffee shop or a pillar near the pickup zone.",
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Two overlapping photos that pop in with a heart between them. Skipped
/// (shown instantly) when the platform asks for reduced motion.
class _Celebration extends StatelessWidget {
  const _Celebration({required this.mine, required this.theirs});

  final Widget mine;
  final Widget theirs;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 900),
      curve: Curves.elasticOut,
      builder: (context, t, _) {
        final scale = t.clamp(0.0, 1.4);
        return SizedBox(
          height: 124,
          width: 240,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                child: Transform.scale(scale: scale, child: _Ring(child: mine)),
              ),
              Positioned(
                right: 0,
                child: Transform.scale(scale: scale, child: _Ring(child: theirs)),
              ),
              Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: const BoxDecoration(color: AppTheme.coral, shape: BoxShape.circle),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 26),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(color: AppTheme.cream, shape: BoxShape.circle),
      child: child,
    );
  }
}
