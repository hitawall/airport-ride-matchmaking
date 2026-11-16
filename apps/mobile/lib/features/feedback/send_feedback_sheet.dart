import "package:material_ui/material_ui.dart";
import "../../core/api_client.dart";
import "../../core/ui/app_buttons.dart";
import "../../core/ui/info_banner.dart";
import "../../core/ui/tokens.dart";
import "../../core/ui/tone.dart";

/// Shared feedback bottom sheet, reachable from both Settings and the home
/// screen so sending feedback never takes more than one tap to reach.
void showSendFeedbackSheet(BuildContext context, ApiClient api) {
  final messenger = ScaffoldMessenger.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _FeedbackSheet(
      api: api,
      onSent: () {
        Navigator.of(sheetContext).pop();
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(const SnackBar(content: Text("Thanks for the feedback!")));
      },
    ),
  );
}

const _types = [
  ("general", "General", Icons.chat_bubble_outline),
  ("feature_request", "Idea", Icons.lightbulb_outline),
  ("bug_report", "Bug", Icons.bug_report_outlined),
];

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet({required this.api, required this.onSent});

  final ApiClient api;
  final VoidCallback onSent;

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final _controller = TextEditingController();
  String _type = "general";
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _controller.text.trim();
    if (message.isEmpty) {
      setState(() => _error = "Tell us a little something first.");
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.api.post("/api/feedback", {"type": _type, "message": message});
      if (mounted) widget.onSent();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Got thoughts? We're all ears", style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              "Bug, brainwave, or just venting. It all helps.",
              style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final (value, label, icon) in _types)
                  ChoiceChip(
                    selected: _type == value,
                    avatar: Icon(icon, size: 18),
                    label: Text(label),
                    onSelected: _sending ? null : (_) => setState(() => _type = value),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _controller,
              maxLines: 4,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
                alignLabelWithHint: true,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              InfoBanner(tone: AppTone.error, message: _error!),
            ],
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(label: "Send feedback", loading: _sending, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
