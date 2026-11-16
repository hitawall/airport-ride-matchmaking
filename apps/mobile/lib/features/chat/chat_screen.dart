import "dart:async";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../core/api_client.dart";
import "../../core/app_theme.dart";
import "../../core/auth_controller.dart";
import "../../core/home_leading_button.dart";
import "../../core/notifications.dart";
import "../../core/pusher_client.dart";
import "../../core/ui/app_buttons.dart";
import "../../core/ui/avatar.dart";
import "../../core/ui/dialogs.dart";
import "../../core/ui/formatters.dart";
import "../../core/ui/info_banner.dart";
import "../../core/ui/state_views.dart";
import "../../core/ui/tokens.dart";
import "../../core/ui/tone.dart";
import "../../data/airports.dart";
import "../../data/models.dart";
import "../matching/rate_match_dialog.dart";

const _reportReasons = {
  "harassment": "Harassment",
  "inappropriate_messages": "Inappropriate messages",
  "no_show": "Didn't show up",
  "fake_profile": "Fake profile",
  "safety_concern": "I feel unsafe",
  "other": "Something else",
};

const _quickReplies = ["Hi! I just landed", "Where should we meet?", "Which terminal are you at?"];

/// Messages further apart than this get a timestamp divider between them.
const _groupGap = Duration(minutes: 30);

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.matchId, super.key});

  final String matchId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messages = <ChatMessage>[];
  final _inputController = TextEditingController();
  Timer? _pollTimer;
  String? _counterpartUserId;
  String? _counterpartName;
  String? _meetingPoint;
  String? _counterpartPhotoUrl;
  String? _matchStatus;
  double? _counterpartAvgRating;
  int _counterpartRatingCount = 0;
  bool _hasRated = false;
  bool _loadingMessages = true;
  bool _sending = false;
  bool _safetyDismissed = false;
  late final String _channelName = "match-${widget.matchId}";

  bool get _isActive => _matchStatus == null || _matchStatus == "mutual";
  String get _displayName => _counterpartName ?? "Your match";

  @override
  void initState() {
    super.initState();
    _inputController.addListener(() => setState(() {}));
    // Opening a chat clears its unread count and any "new match" alert.
    Future.microtask(() => ref.read(notificationsProvider.notifier).markMatchSeen(widget.matchId));
    _loadCounterpart();
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _poll());
    PusherClientService.instance.addHandler(_onPusherEvent);
    PusherClientService.instance.subscribe(_channelName);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _inputController.dispose();
    PusherClientService.instance.removeHandler(_onPusherEvent);
    PusherClientService.instance.unsubscribe(_channelName);
    super.dispose();
  }

  void _onPusherEvent(String channelName, String eventName, Map<String, dynamic> data) {
    if (channelName != _channelName || eventName != "new-message" || !mounted) return;
    _addMessages([ChatMessage.fromJson(data)]);
  }

  void _addMessages(List<ChatMessage> incoming) {
    final fresh = incoming.where((m) => !_messages.any((existing) => existing.id == m.id)).toList();
    if (fresh.isEmpty || !mounted) return;
    setState(() => _messages.addAll(fresh));
  }

  Future<void> _loadCounterpart() async {
    final api = ref.read(apiClientProvider);
    final myUserId = ref.read(authControllerProvider).userId;
    try {
      final match = await api.get("/api/matches/${widget.matchId}") as Map<String, dynamic>;
      final other = match["userAId"] == myUserId ? match["userBId"] : match["userAId"];
      if (mounted) {
        setState(() {
          _counterpartUserId = other as String;
          _counterpartName = match["counterpartDisplayName"] as String?;
          _meetingPoint = match["terminal"] == null
              ? null
              : airportTerminalLabel(match["airportCode"] as String?, match["terminal"] as String?);
          _counterpartPhotoUrl = match["counterpartPhotoUrl"] as String?;
          _matchStatus = match["status"] as String?;
          final avgRating = match["counterpartAvgRating"];
          _counterpartAvgRating = avgRating == null ? null : (avgRating as num).toDouble();
          _counterpartRatingCount = (match["counterpartRatingCount"] as num?)?.toInt() ?? 0;
        });
      }
    } on ApiException {
      // non-fatal -- report/block menu just won't work until this resolves
    }
  }

  Future<void> _unmatch() async {
    final confirmed = await confirmAction(
      context,
      title: "Unmatch $_displayName?",
      message: "You'll both lose access to this chat going forward. This can't be undone.",
      confirmLabel: "Unmatch",
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(apiClientProvider).post("/api/matches/${widget.matchId}/unmatch");
      if (mounted) setState(() => _matchStatus = "unmatched");
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    }
  }

  Future<void> _rate() => showRateMatchDialog(
    context,
    ref.read(apiClientProvider),
    widget.matchId,
    onRated: () {
      if (mounted) setState(() => _hasRated = true);
    },
  );

  Future<void> _report() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.xs),
              child: Text("Report $_displayName", style: Theme.of(sheetContext).textTheme.headlineSmall),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.sm),
              child: Text("What went wrong? Our team reviews every report.", style: Theme.of(sheetContext).textTheme.bodyMedium),
            ),
            for (final entry in _reportReasons.entries)
              ListTile(
                title: Text(entry.value),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(sheetContext).pop(entry.key),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (reason == null || _counterpartUserId == null || !mounted) return;

    try {
      await ref.read(apiClientProvider).post("/api/reports", {
        "reportedUserId": _counterpartUserId,
        "matchId": widget.matchId,
        "reason": reason,
      });
      if (mounted) showAppSnack(context, "Report sent. Thank you for helping keep rides safe.");
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    }
  }

  Future<void> _block() async {
    if (_counterpartUserId == null) return;
    final confirmed = await confirmAction(
      context,
      title: "Block $_displayName?",
      message: "You won't be matched with each other again. You can unblock them any time in Settings.",
      confirmLabel: "Block",
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(apiClientProvider).post("/api/blocks", {"blockedUserId": _counterpartUserId});
      if (mounted) showAppSnack(context, "$_displayName is blocked.");
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    }
  }

  Future<void> _onMenuAction(String action) {
    switch (action) {
      case "unmatch":
        return _unmatch();
      case "rate":
        return _rate();
      case "report":
        return _report();
      default:
        return _block();
    }
  }

  Future<void> _poll() async {
    final api = ref.read(apiClientProvider);
    final after = _messages.isEmpty ? null : _messages.last.createdAt.toIso8601String();
    final path = after == null
        ? "/api/matches/${widget.matchId}/messages"
        : "/api/matches/${widget.matchId}/messages?after=$after";
    try {
      final result = await api.get(path) as Map<String, dynamic>;
      final fetched = (result["messages"] as List)
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList();
      _addMessages(fetched);
    } on ApiException {
      // transient -- retried on the next tick
    }
    if (mounted && _loadingMessages) setState(() => _loadingMessages = false);
  }

  Future<void> _send() async {
    final body = _inputController.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final message = await ref.read(apiClientProvider).post("/api/matches/${widget.matchId}/messages", {
        "body": body,
      });
      // Only clear once it is saved, so a failed send never loses the text.
      _inputController.clear();
      _addMessages([ChatMessage.fromJson(message as Map<String, dynamic>)]);
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true, bottomInset: 90);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: homeLeadingButton(context),
        titleSpacing: 0,
        title: Row(
          children: [
            AppAvatar(imageUrl: _counterpartPhotoUrl, name: _counterpartName, radius: 18),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _displayName,
                    style: textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_meetingPoint != null)
                    Text(
                      "Meet at $_meetingPoint",
                      style: textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (_counterpartRatingCount > 0 && _counterpartAvgRating != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 14, color: context.appColors.amber),
                        const SizedBox(width: 2),
                        Text(
                          "${_counterpartAvgRating!.toStringAsFixed(1)} ($_counterpartRatingCount)",
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: _onMenuAction,
            itemBuilder: (context) => [
              if (_isActive) const PopupMenuItem(value: "unmatch", child: Text("Unmatch")),
              if (!_isActive && !_hasRated) const PopupMenuItem(value: "rate", child: Text("Rate your match")),
              const PopupMenuItem(value: "report", child: Text("Report")),
              const PopupMenuItem(value: "block", child: Text("Block")),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
            child: Column(
              children: [
                if (_isActive && !_safetyDismissed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                    child: InfoBanner(
                      tone: AppTone.safety,
                      title: "Stay safe",
                      message: "Meet at the official airport pickup zone, and check their photo before you share a cab.",
                      action: IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: "Dismiss",
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _safetyDismissed = true),
                      ),
                    ),
                  ),
                if (!_isActive)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                    child: InfoBanner(
                      tone: AppTone.neutral,
                      icon: Icons.history,
                      message: "This match has ended. You can still read your messages, but can't send new ones.",
                    ),
                  ),
                Expanded(child: _buildMessages(context)),
                if (_isActive)
                  _Composer(
                    controller: _inputController,
                    sending: _sending,
                    onSend: _send,
                  )
                else if (!_hasRated)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: PrimaryButton(label: "Rate your match", icon: Icons.star_outline_rounded, onPressed: _rate),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessages(BuildContext context) {
    if (_loadingMessages) return const LoadingView();

    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAvatar(imageUrl: _counterpartPhotoUrl, name: _counterpartName, radius: 40),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _isActive ? "Say hi to $_displayName" : "No messages here",
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (_isActive) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  "Agree on where to meet at the pickup zone.",
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final reply in _quickReplies)
                      ActionChip(
                        label: Text(reply),
                        onPressed: () => _inputController.text = reply,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    final myUserId = ref.watch(authControllerProvider).userId;
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final index = _messages.length - 1 - i;
        final message = _messages[index];
        final previous = index > 0 ? _messages[index - 1] : null;
        final showTime = previous == null || message.createdAt.difference(previous.createdAt) > _groupGap;
        return Column(
          children: [
            if (showTime) _TimeDivider(formatFriendlyDateTime(message.createdAt)),
            _Bubble(message: message, isMine: message.senderId == myUserId),
          ],
        );
      },
    );
  }
}

class _TimeDivider extends StatelessWidget {
  const _TimeDivider(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final maxWidth = (MediaQuery.sizeOf(context).width.clamp(0.0, AppSpacing.maxContentWidth)) * 0.78;
    const big = Radius.circular(18);
    const tail = Radius.circular(4);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          color: isMine ? AppTheme.coral : AppTheme.surfaceWhite,
          border: isMine ? null : Border.all(color: AppTheme.line),
          borderRadius: BorderRadius.only(
            topLeft: big,
            topRight: big,
            bottomLeft: isMine ? big : tail,
            bottomRight: isMine ? tail : big,
          ),
        ),
        child: Text(
          message.body,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: isMine ? Colors.white : AppTheme.ink),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.onSend});

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final canSend = controller.text.trim().isNotEmpty && !sending;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(hintText: "Write a message"),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 52,
            height: 52,
            child: IconButton.filled(
              tooltip: "Send",
              onPressed: canSend ? onSend : null,
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.coral,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.sand,
              ),
              icon: sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
