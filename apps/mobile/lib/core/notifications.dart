import "dart:async";
import "dart:convert";
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

/// Most notifications kept on the device per person.
const _maxKept = 50;

/// One banner shown over whatever screen the rider is on.
class InAppAlert {
  const InAppAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.route,
    this.key = "",
  });

  final int id;
  final String title;
  final String message;
  final String actionLabel;
  final String route;

  /// The notification this banner belongs to, so opening it marks it read.
  final String key;
}

/// One entry in the notifications list (the bell). Kept on the device so a
/// banner that was shown once never comes back at the next sign-in.
class AppNotification {
  const AppNotification({
    required this.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.route,
    required this.createdAt,
    this.read = false,
    this.count = 0,
  });

  /// Stable id such as `match:<id>`, `ended:<id>`, `likes:<ride id>`, `msg:<id>`.
  final String key;
  final String title;
  final String message;
  final String actionLabel;
  final String route;
  final DateTime createdAt;
  final bool read;

  /// For likes and messages: how many were already announced.
  final int count;

  String get kind => key.split(":").first;

  AppNotification copyWith({bool? read, int? count}) => AppNotification(
    key: key,
    title: title,
    message: message,
    actionLabel: actionLabel,
    route: route,
    createdAt: createdAt,
    read: read ?? this.read,
    count: count ?? this.count,
  );

  Map<String, dynamic> toJson() => {
    "key": key,
    "title": title,
    "message": message,
    "actionLabel": actionLabel,
    "route": route,
    "createdAt": createdAt.toUtc().toIso8601String(),
    "read": read,
    "count": count,
  };

  static AppNotification? tryParse(Object? raw) {
    try {
      final json = raw as Map<String, dynamic>;
      return AppNotification(
        key: json["key"] as String,
        title: json["title"] as String,
        message: json["message"] as String,
        actionLabel: json["actionLabel"] as String,
        route: json["route"] as String,
        createdAt: DateTime.parse(json["createdAt"] as String),
        read: json["read"] as bool? ?? false,
        count: (json["count"] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

class NotificationState {
  const NotificationState({
    this.unreadByMatch = const {},
    this.incomingLikes = 0,
    this.likesRideRequestId,
    this.alert,
    this.items = const [],
  });

  final Map<String, int> unreadByMatch;
  final int incomingLikes;
  final String? likesRideRequestId;
  final InAppAlert? alert;

  /// Everything the rider has been told, newest first.
  final List<AppNotification> items;

  int get unreadTotal => unreadByMatch.values.fold(0, (a, b) => a + b);

  /// Notifications in the list the rider has not opened yet (the bell's number).
  int get unreadItems => items.where((n) => !n.read).length;

  /// Number shown in the browser tab title and on badges.
  int get badgeCount => unreadTotal + incomingLikes;

  NotificationState copyWith({
    Map<String, int>? unreadByMatch,
    int? incomingLikes,
    String? likesRideRequestId,
    InAppAlert? alert,
    List<AppNotification>? items,
    bool clearAlert = false,
  }) {
    return NotificationState(
      unreadByMatch: unreadByMatch ?? this.unreadByMatch,
      incomingLikes: incomingLikes ?? this.incomingLikes,
      likesRideRequestId: likesRideRequestId ?? this.likesRideRequestId,
      alert: clearAlert ? null : (alert ?? this.alert),
      items: items ?? this.items,
    );
  }
}

/// Polls the server while signed in and turns changes into in-app alerts:
/// new messages, people who like the rider's trip, and new mutual matches.
/// Nothing is emailed; this is the only place riders hear about these.
///
/// Each alert is also kept in a list on the device, so a banner is shown once
/// and never again, and the rider can read everything under the bell.
class NotificationController extends StateNotifier<NotificationState> {
  NotificationController(this._ref, {required bool enabled, String? userId})
    : _storageKey = "notifications_${userId ?? "anon"}",
      super(const NotificationState()) {
    if (enabled) {
      _loadStored().then((_) {
        if (!mounted) return;
        poll();
        _timer = Timer.periodic(_pollEvery, (_) => poll());
      });
    }
  }

  final Ref _ref;
  final String _storageKey;
  Timer? _timer;
  int _alertCounter = 0;
  final _alertedMatchIds = <String>{};
  Set<String> _seenMatchIds = {};
  bool _polling = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadStored() async {
    final storage = _ref.read(secureStorageProvider);
    final raw = await storage.readString("seen_matches");
    _seenMatchIds = raw == null || raw.isEmpty ? {} : raw.split(",").toSet();
    try {
      final stored = await storage.readString(_storageKey);
      if (stored != null && stored.isNotEmpty && mounted) {
        final items = (jsonDecode(stored) as List).map(AppNotification.tryParse).whereType<AppNotification>().toList();
        state = state.copyWith(items: items);
      }
    } catch (_) {
      // a damaged list is just treated as empty
    }
  }

  /// Loads what was kept on the device (tests call this; the app does it itself).
  @visibleForTesting
  Future<void> restore() => _loadStored();

  void _save() {
    final items = state.items.length > _maxKept ? state.items.sublist(0, _maxKept) : state.items;
    try {
      _ref
          .read(secureStorageProvider)
          .writeString(_storageKey, jsonEncode([for (final n in items) n.toJson()]))
          .catchError((Object _) {});
    } catch (_) {
      // never let saving break the app
    }
  }

  void _setItems(List<AppNotification> items) {
    state = state.copyWith(items: items);
    _save();
  }

  AppNotification? _find(String key) {
    for (final n in state.items) {
      if (n.key == key) return n;
    }
    return null;
  }

  /// Adds or refreshes a notification as unread (newest first) and returns the
  /// banner to show for it.
  InAppAlert _raise(String key, String title, String message, String actionLabel, String route, {int count = 0}) {
    final fresh = AppNotification(
      key: key,
      title: title,
      message: message,
      actionLabel: actionLabel,
      route: route,
      createdAt: DateTime.now(),
      count: count,
    );
    _setItems([fresh, ...state.items.where((n) => n.key != key)]);
    return InAppAlert(
      id: ++_alertCounter,
      title: title,
      message: message,
      actionLabel: actionLabel,
      route: route,
      key: key,
    );
  }

  /// Changes a stored notification without announcing it again.
  void _update(String key, {bool? read, int? count}) {
    final current = _find(key);
    if (current == null) return;
    if ((read == null || read == current.read) && (count == null || count == current.count)) return;
    _setItems([for (final n in state.items) n.key == key ? n.copyWith(read: read, count: count) : n]);
  }

  /// The rider opened the notifications list: everything counts as read.
  void markAllRead() {
    if (state.unreadItems == 0) return;
    _setItems([for (final n in state.items) n.read ? n : n.copyWith(read: true)]);
  }

  void markRead(String key) => _update(key, read: true);

  /// The rider has seen that this match ended (they ended it, or the chat
  /// showed them it ended), so no "match ended" alert is raised for it.
  void markEndedSeen(String matchId) {
    _remember("ended:$matchId");
    _alertedMatchIds.add("ended:$matchId");
    _update("ended:$matchId", read: true);
    if (state.alert?.route == "/resume-trip") dismissAlert();
  }

  void _remember(String key) {
    if (_seenMatchIds.add(key)) {
      final recent = _seenMatchIds.toList();
      if (recent.length > 100) recent.removeRange(0, recent.length - 100);
      _seenMatchIds = recent.toSet();
      _ref.read(secureStorageProvider).writeString("seen_matches", recent.join(","));
    }
  }

  /// The rider has opened this match (chat or "it's a match" screen), so it
  /// should never raise a "new match" alert again, and its unread count clears.
  void markMatchSeen(String matchId) {
    _remember(matchId);
    _update("match:$matchId", read: true);
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

  /// The rider tapped the banner's action.
  void openAlert(InAppAlert alert) {
    if (alert.key.isNotEmpty) markRead(alert.key);
    dismissAlert();
  }

  @visibleForOverriding
  String get currentPath {
    try {
      return _ref.read(appRouterProvider).routerDelegate.currentConfiguration.uri.path;
    } catch (_) {
      return "";
    }
  }

  Future<void> poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final data = await _ref.read(apiClientProvider).get("/api/notifications/summary") as Map<String, dynamic>;
      if (!mounted) return;
      final location = currentPath;

      // Unread messages. A chat that is open right now counts as read. A
      // message item announces only when the unread number grows.
      final unread = <String, int>{};
      InAppAlert? messageAlert;
      for (final item in (data["unreadMessages"] as List).cast<Map<String, dynamic>>()) {
        final matchId = item["matchId"] as String;
        if (location == "/chat/$matchId") continue;
        final count = (item["count"] as num).toInt();
        unread[matchId] = count;
        if (count > (_find("msg:$matchId")?.count ?? 0)) {
          final name = item["senderName"] as String? ?? "Your match";
          messageAlert = _raise(
            "msg:$matchId",
            "New message",
            count == 1 ? "$name sent you a message." : "$name sent you $count messages.",
            "Open chat",
            "/chat/$matchId",
            count: count,
          );
        }
      }
      // Chats with nothing unread any more are read; the next message counts anew.
      for (final n in state.items.where((n) => n.kind == "msg").toList()) {
        if (!unread.containsKey(n.key.substring(4))) _update(n.key, read: true, count: 0);
      }

      // People who liked my open trip and wait for my answer.
      final likes = data["incomingLikes"] as Map<String, dynamic>?;
      final likeCount = (likes?["count"] as num?)?.toInt() ?? 0;
      final likesRideId = likes?["rideRequestId"] as String?;
      InAppAlert? likeAlert;
      final reviewing = location.startsWith("/match-review") || location.startsWith("/awaiting-match");
      if (likesRideId != null) {
        final key = "likes:$likesRideId";
        final announced = _find(key)?.count ?? 0;
        if (likeCount > announced && !reviewing) {
          likeAlert = _raise(
            key,
            "Someone wants to share a ride",
            likeCount == 1 ? "1 person liked your trip. Take a look." : "$likeCount people liked your trip. Take a look.",
            "Review",
            "/awaiting-match/$likesRideId",
            count: likeCount,
          );
        } else if (likeCount != announced) {
          // Fewer likes than before, or the rider is looking at them right now.
          _update(key, read: likeCount == 0 || reviewing ? true : null, count: likeCount);
        }
      } else {
        for (final n in state.items.where((n) => n.kind == "likes" && n.count > 0).toList()) {
          _update(n.key, read: true, count: 0);
        }
      }

      // Mutual matches the rider has not opened yet.
      InAppAlert? matchAlert;
      for (final item in (data["mutualMatches"] as List).cast<Map<String, dynamic>>()) {
        final id = item["id"] as String;
        if (_seenMatchIds.contains(id) || _alertedMatchIds.contains(id) || _find("match:$id") != null) continue;
        if (location.endsWith(id)) {
          markMatchSeen(id);
          continue;
        }
        _alertedMatchIds.add(id);
        matchAlert = _raise(
          "match:$id",
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
        if (_seenMatchIds.contains(key) || _alertedMatchIds.contains(key) || _find(key) != null) continue;
        if (location == "/chat/$id") continue;
        _alertedMatchIds.add(key);
        endedAlert = _raise(
          key,
          "Match ended",
          "${item["counterpartName"]} ended the chat. Want to look for someone else?",
          "Find someone else",
          "/resume-trip",
        );
      }

      // One banner at a time; a match matters most, then a match ending, then
      // likes, then messages. The rest wait under the bell.
      final next = matchAlert ?? endedAlert ?? likeAlert ?? messageAlert;
      state = NotificationState(
        unreadByMatch: unread,
        incomingLikes: likeCount,
        likesRideRequestId: likesRideId,
        alert: next ?? state.alert,
        items: state.items,
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
  final auth = ref.watch(authControllerProvider.select((a) => (a.isAuthenticated, a.userId)));
  return NotificationController(ref, enabled: auth.$1, userId: auth.$2);
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
                      ref.read(notificationsProvider.notifier).openAlert(alert);
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
