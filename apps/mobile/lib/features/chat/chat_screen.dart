import "dart:async";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";
import "../../core/home_leading_button.dart";
import "../../core/pusher_client.dart";
import "../../data/models.dart";

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
  String? _matchStatus;
  late final String _channelName = "match-${widget.matchId}";

  bool get _isActive => _matchStatus == null || _matchStatus == "mutual";

  @override
  void initState() {
    super.initState();
    _loadCounterpart();
    _poll(initial: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _poll());
    PusherClientService.instance.addHandler(_onPusherEvent);
    PusherClientService.instance.subscribe(_channelName);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    PusherClientService.instance.removeHandler(_onPusherEvent);
    PusherClientService.instance.unsubscribe(_channelName);
    super.dispose();
  }

  void _onPusherEvent(String channelName, String eventName, Map<String, dynamic> data) {
    if (channelName != _channelName || eventName != "new-message" || !mounted) return;
    final message = ChatMessage.fromJson(data);
    if (_messages.any((m) => m.id == message.id)) return;
    setState(() => _messages.add(message));
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
          _matchStatus = match["status"] as String?;
        });
      }
    } on ApiException {
      // non-fatal -- report/block menu just won't work until this resolves
    }
  }

  Future<void> _unmatch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Unmatch?"),
        content: const Text(
          "You'll both lose access to this chat going forward. This can't be undone.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Unmatch")),
        ],
      ),
    );
    if (confirmed != true) return;

    final api = ref.read(apiClientProvider);
    try {
      await api.post("/api/matches/${widget.matchId}/unmatch");
      if (mounted) setState(() => _matchStatus = "unmatched");
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _poll({bool initial = false}) async {
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
      if (fetched.isNotEmpty && mounted) {
        setState(() => _messages.addAll(fetched));
      }
    } on ApiException {
      // transient -- retried on the next tick
    }
  }

  Future<void> _send() async {
    final body = _inputController.text.trim();
    if (body.isEmpty) return;
    _inputController.clear();
    final api = ref.read(apiClientProvider);
    try {
      final message = await api.post("/api/matches/${widget.matchId}/messages", {"body": body});
      setState(() => _messages.add(ChatMessage.fromJson(message as Map<String, dynamic>)));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _onMenuAction(String action) async {
    if (action == "unmatch") {
      await _unmatch();
      return;
    }
    if (_counterpartUserId == null) return;
    final api = ref.read(apiClientProvider);
    try {
      if (action == "report") {
        await api.post("/api/reports", {
          "reportedUserId": _counterpartUserId,
          "matchId": widget.matchId,
          "reason": "other",
        });
      } else {
        await api.post("/api/blocks", {"blockedUserId": _counterpartUserId});
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(action == "report" ? "Report submitted" : "User blocked")),
        );
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = ref.watch(authControllerProvider).userId;

    return Scaffold(
      appBar: AppBar(
        leading: homeLeadingButton(context),
        title: const Text("Chat"),
        actions: [
          PopupMenuButton<String>(
            onSelected: _onMenuAction,
            itemBuilder: (context) => [
              if (_isActive) const PopupMenuItem(value: "unmatch", child: Text("Unmatch")),
              const PopupMenuItem(value: "report", child: Text("Report")),
              const PopupMenuItem(value: "block", child: Text("Block")),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              _isActive
                  ? "Meet at the official airport pickup zone. Verify their photo before you share a cab."
                  : "This match has ended -- you can still see your past messages, but can't send new ones.",
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final message = _messages[_messages.length - 1 - i];
                final isMine = message.senderId == myUserId;
                return Align(
                  alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMine
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(message.body),
                  ),
                );
              },
            ),
          ),
          if (_isActive)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(
                        hintText: "Message",
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send), onPressed: _send),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
