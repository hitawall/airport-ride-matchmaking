import "dart:async";
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";
import "../app_router.dart";
import "api_client.dart";
import "app_config.dart";
import "app_theme.dart";
import "auth_controller.dart";

/// How often the app asks the server what happened while the rider was elsewhere.
const _pollEvery = Duration(seconds: 10);

/// One banner shown over whatever screen the rider is on.
class InAppAlert {
  const InAppAlert({required this.id, required this.title, required this.message, required this.actionLabel, required this.route});

  final int id;
  final String title;
  final String message;
  final String actionLabel;
  final String route;
}

class NotificationState {
  const NotificationState({
    this.unreadByMatch = const {},
    this.incomingLikes = 0,
    this.likesRideRequestId,
    this.alert,
  });

  final Map<String, int> unreadByMatch;
  final int incomingLikes;
  final String? likesRideRequestId;
  final InAppAlert? alert;

  int get unreadTotal => unreadByMatch.values.fold(0, (a, b) => a + b);

  /// Number shown in the browser tab title and on badges.
  int get badgeCount => unreadTotal + incomingLikes;

  NotificationState copyWith({
    Map<String, int>? unreadByMatch,
    int? incomingLikes,
    String? likesRideRequestId,
    InAppAlert? alert,
    bool clearAlert = false,
  }) {
    return NotificationState(
      unreadByMatch: unreadByMatch ?? this.unreadByMatch,
      incomingLikes: incomingLikes ?? this.incomingLikes,
      likesRideRequestId: likesRideRequestId ?? this.likesRideRequestId,
      alert: clearAlert ? null : (alert ?? this.alert),
    );
  }
}

/// Polls the server while signed in and turns changes into in-app alerts:
/// new messages, people who like the rider's trip, and new mutual matches.
/// Nothing is emailed; this is the only place riders hear about these.
class NotificationController extends StateNotifier<NotificationState> {
  NotificationController(this._ref, {required bool enabled}) : super(const NotificationState()) {
    if (enabled) {
      _loadSeen().then((_) {
        if (!mounted) return;
        poll();
        _timer = Timer.periodic(_pollEvery, (_) => poll());
      });
    }
  }

  final Ref _ref;
  Timer? _timer;
  int _alertCounter = 0;
  int _previousLikes = 0;
  final _alertedMatchIds = <String>{};
  Set<String> _seenMatchIds = {};
  bool _polling = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadSeen() async {
    final raw = await _ref.read(secureStorageProvider).readString("seen_matches");
    _seenMatchIds = raw == null || raw.isEmpty ? {} : raw.split(",").toSet();
  }

  void _remember(String key) {
    if (_seenMatchIds.add(key)) {
      final recent = _seenMatchIds.toList();
      if (recent.length > 100) recent.removeRange(0, recent.length - 100);
      _seenMatchIds = recent.toSet();
      _ref.read(secureStorageProvider).writeString("seen_matches", recent.join(","));
    }
  }

  /// The rider has seen that this match ended (they ended it, or the chat
  /// showed them it ended), so no "match ended" alert is raised for it.
  void markEndedSeen(String matchId) {
    _remember("ended:$matchId");
    _alertedMatchIds.add("ended:$matchId");
    if (state.alert?.route == "/resume-trip") dismissAlert();
  }

  /// The rider has opened this match (chat or "it's a match" screen), so it
  /// should never raise a "new match" alert again, and its unread count clears.
  void markMatchSeen(String matchId) {
    _remember(matchId);
    if (state.unreadByMatch.containsKey(matchId)) {
      final next = Map<String, int>.from(state.unreadByMatch)..remove(matchId);
      state = state.copyWith(unreadByMatch: next);
      _updateTabTitle();
    }
    if (state.alert?.route.endsWith(matchId) ?? false) dismissAlert();
  }

  void dismissAlert() {
    if (state.alert != null) state = state.copyWith(clearAlert: true);
  }

  @visibleForOverriding
  String get currentPath {
    try {
      return _ref.read(appRouterProvider).routerDelegate.currentConfiguration.uri.path;
    } catch (_) {
      return "";
    }
  }

  InAppAlert _alert(String title, String message, String actionLabel, String route) =>
      InAppAlert(id: ++_alertCounter, title: title, message: message, actionLabel: actionLabel, route: route);

  Future<void> poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final data = await _ref.read(apiClientProvider).get("/api/notifications/summary") as Map<String, dynamic>;
      if (!mounted) return;
      final location = currentPath;

      // Unread messages. A chat that is open right now counts as read.
      final unread = <String, int>{};
      InAppAlert? messageAlert;
      for (final item in (data["unreadMessages"] as List).cast<Map<String, dynamic>>()) {
        final matchId = item["matchId"] as String;
        if (location == "/chat/$matchId") continue;
        final count = (item["count"] as num).toInt();
        unread[matchId] = count;
        if (count > (state.unreadByMatch[matchId] ?? 0)) {
          final name = item["senderName"] as String? ?? "Your match";
          messageAlert = _alert(
            "New message",
            count == 1 ? "$name sent you a message." : "$name sent you $count messages.",
            "Open chat",
            "/chat/$matchId",
          );
        }
      }

      // People who liked my open trip and wait for my answer.
      final likes = data["incomingLikes"] as Map<String, dynamic>?;
      final likeCount = (likes?["count"] as num?)?.toInt() ?? 0;
      final likesRideId = likes?["rideRequestId"] as String?;
      InAppAlert? likeAlert;
      final reviewing = location.startsWith("/match-review") || location.startsWith("/awaiting-match");
      if (likeCount > _previousLikes && likesRideId != null && !reviewing) {
        likeAlert = _alert(
          "Someone wants to share a ride",
          likeCount == 1 ? "1 person liked your trip. Take a look." : "$likeCount people liked your trip. Take a look.",
          "Review",
          "/awaiting-match/$likesRideId",
        );
      }
      _previousLikes = likeCount;

      // Mutual matches the rider has not opened yet.
      InAppAlert? matchAlert;
      for (final item in (data["mutualMatches"] as List).cast<Map<String, dynamic>>()) {
        final id = item["id"] as String;
        if (_seenMatchIds.contains(id) || _alertedMatchIds.contains(id)) continue;
        if (location.endsWith(id)) {
          markMatchSeen(id);
          continue;
        }
        _alertedMatchIds.add(id);
        matchAlert = _alert(
          "It's a match!",
          "You and ${item["counterpartName"]} want to share a ride. Say hello.",
          "Open chat",
          "/chat/$id",
        );
      }

      // Matches that ended. The rider is asked whether to search again; they are
      // never put back in the queue automatically, since we cannot know they are
      // still around. An open chat shows its own prompt instead.
      InAppAlert? endedAlert;
      for (final item in (data["endedMatches"] as List? ?? const []).cast<Map<String, dynamic>>()) {
        final id = item["id"] as String;
        final key = "ended:$id";
        if (_seenMatchIds.contains(key) || _alertedMatchIds.contains(key)) continue;
        if (location == "/chat/$id") continue;
        _alertedMatchIds.add(key);
        endedAlert = _alert(
          "Match ended",
          "${item["counterpartName"]} ended the chat. Want to look for someone else?",
          "Find someone else",
          "/resume-trip",
        );
      }

      // One banner at a time; a match matters most, then a match ending, then
      // likes, then messages.
      final next = matchAlert ?? endedAlert ?? likeAlert ?? messageAlert;
      state = NotificationState(
        unreadByMatch: unread,
        incomingLikes: likeCount,
        likesRideRequestId: likesRideId,
        alert: next ?? state.alert,
      );
      _updateTabTitle();
    } on ApiException {
      // transient; the next tick tries again
    } catch (_) {
      // never let alerts break the app
    } finally {
      _polling = false;
    }
  }

  void _updateTabTitle() {
    final count = state.badgeCount;
    SystemChrome.setApplicationSwitcherDescription(
      ApplicationSwitcherDescription(label: count > 0 ? "($count) ${AppConfig.appName}" : AppConfig.appName),
    );
  }
}

final notificationsProvider = StateNotifierProvider<NotificationController, NotificationState>((ref) {
  final signedIn = ref.watch(authControllerProvider.select((a) => a.isAuthenticated));
  return NotificationController(ref, enabled: signedIn);
});

/// Wraps the whole app and floats the current alert at the top of any screen.
class NotificationHost extends ConsumerWidget {
  const NotificationHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alert = ref.watch(notificationsProvider.select((s) => s.alert));
    return Stack(
      children: [
        child,
        if (alert != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _AlertBanner(
                    key: ValueKey(alert.id),
                    alert: alert,
                    onDismiss: () => ref.read(notificationsProvider.notifier).dismissAlert(),
                    onOpen: () {
                      ref.read(notificationsProvider.notifier).dismissAlert();
                      ref.read(appRouterProvider).go(alert.route);
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AlertBanner extends StatefulWidget {
  const _AlertBanner({required this.alert, required this.onDismiss, required this.onOpen, super.key});

  final InAppAlert alert;
  final VoidCallback onDismiss;
  final VoidCallback onOpen;

  @override
  State<_AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<_AlertBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 12), widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Material(
        color: AppTheme.plum,
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_outlined, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.alert.title,
                      style: textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(widget.alert.message, style: textTheme.bodySmall?.copyWith(color: Colors.white)),
                  ],
                ),
              ),
              TextButton(
                onPressed: widget.onOpen,
                style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: AppTheme.coral),
                child: Text(widget.alert.actionLabel),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                tooltip: "Dismiss",
                onPressed: widget.onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
