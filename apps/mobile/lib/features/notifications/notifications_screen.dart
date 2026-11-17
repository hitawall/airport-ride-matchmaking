import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "../../core/notifications.dart";
import "../../core/ui/app_page.dart";
import "../../core/ui/formatters.dart";
import "../../core/ui/state_views.dart";
import "../../core/ui/tokens.dart";

/// The bell in the top bar: how many notifications are waiting, and a way in.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationsProvider.select((s) => s.unreadItems));
    return IconButton(
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? "99+" : "$unread"),
        child: const Icon(Icons.notifications_outlined),
      ),
      tooltip: unread > 0 ? "Notifications, $unread unread" : "Notifications",
      onPressed: () => context.push("/notifications"),
    );
  }
}

IconData _iconFor(String kind) => switch (kind) {
  "match" => Icons.celebration_outlined,
  "ended" => Icons.link_off,
  "likes" => Icons.thumb_up_alt_outlined,
  "msg" => Icons.chat_bubble_outline,
  _ => Icons.notifications_outlined,
};

/// Everything the rider has been told, newest first. Opening it marks it all read.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  // What was unread when the list was opened, so those stay marked as new while
  // they are on screen even though they now count as read.
  final _fresh = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _absorb());
  }

  void _absorb() {
    if (!mounted) return;
    final controller = ref.read(notificationsProvider.notifier);
    setState(() => _fresh.addAll(ref.read(notificationsProvider).items.where((n) => !n.read).map((n) => n.key)));
    controller.markAllRead();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(notificationsProvider.select((s) => s.unreadItems), (_, unread) {
      if (unread > 0) WidgetsBinding.instance.addPostFrameCallback((_) => _absorb());
    });
    final items = ref.watch(notificationsProvider.select((s) => s.items));
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppPage(
      title: "Notifications",
      body: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xxl),
              child: EmptyState(
                icon: Icons.notifications_none,
                title: "Nothing new",
                message: "Matches, likes and messages will show up here.",
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final n in items)
                  Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      leading: Icon(_iconFor(n.kind), color: scheme.primary),
                      title: Text(n.title, style: textTheme.titleSmall?.copyWith(fontWeight: _fresh.contains(n.key) ? FontWeight.w800 : FontWeight.w600)),
                      subtitle: Text("${n.message}\n${formatFriendlyDateTime(n.createdAt)}"),
                      isThreeLine: true,
                      trailing: _fresh.contains(n.key)
                          ? Semantics(
                              label: "New",
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                              ),
                            )
                          : null,
                      onTap: () => context.go(n.route),
                    ),
                  ),
              ],
            ),
    );
  }
}
