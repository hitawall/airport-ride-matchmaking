import "dart:async";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";
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

  @override
  void initState() {
    super.initState();
    _loadCounterpart();
    _poll(initial: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCounterpart() async {
    final api = ref.read(apiClientProvider);
    final myUserId = ref.read(authControllerProvider).userId;
    try {
      final match = await api.get("/api/matches/${widget.matchId}") as Map<String, dynamic>;
      final other = match["userAId"] == myUserId ? match["userBId"] : match["userAId"];
      if (mounted) setState(() => _counterpartUserId = other as String);
    } on ApiException {
      // non-fatal -- report/block menu just won't work until this resolves
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

  Future<void> _reportOrBlock(String action) async {
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
        title: const Text("Chat"),
        actions: [
          PopupMenuButton<String>(
            onSelected: _reportOrBlock,
            itemBuilder: (context) => const [
              PopupMenuItem(value: "report", child: Text("Report")),
              PopupMenuItem(value: "block", child: Text("Block")),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              "Meet at the official airport pickup zone. Verify their photo before you share a cab.",
              style: TextStyle(fontSize: 12),
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
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: const InputDecoration(hintText: "Message", border: OutlineInputBorder()),
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
