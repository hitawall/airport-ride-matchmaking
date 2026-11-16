import "package:material_ui/material_ui.dart";
import "../../core/api_client.dart";
import "../../core/app_theme.dart";
import "../../core/ui/app_buttons.dart";
import "../../core/ui/info_banner.dart";
import "../../core/ui/tokens.dart";
import "../../core/ui/tone.dart";

const _starLabels = ["Not great", "Could be better", "It was fine", "Good company", "Great match"];

/// Shows a 1-5 star picker and saves the rating for [matchId]. Shared by the
/// chat screen and the match list so rating a past match never takes more
/// than this one dialog to reach. [onRated] only fires once a rating is
/// actually stored (or the server says one already exists).
Future<void> showRateMatchDialog(
  BuildContext context,
  ApiClient api,
  String matchId, {
  VoidCallback? onRated,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => _RateDialog(api: api, matchId: matchId),
  );
  if (saved != true) return;
  onRated?.call();
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(const SnackBar(content: Text("Thanks for rating your match!")));
}

class _RateDialog extends StatefulWidget {
  const _RateDialog({required this.api, required this.matchId});

  final ApiClient api;
  final String matchId;

  @override
  State<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends State<_RateDialog> {
  int _selected = 0;
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.post("/api/matches/${widget.matchId}/rating", {"score": _selected});
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      // A rating already exists for this match: nothing more to do.
      if (e.statusCode == 409) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text("Rate your match"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var star = 1; star <= 5; star++)
                IconButton(
                  tooltip: "$star star${star == 1 ? "" : "s"}",
                  onPressed: _saving ? null : () => setState(() => _selected = star),
                  icon: Icon(
                    star <= _selected ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 34,
                    color: star <= _selected ? context.appColors.amber : AppTheme.mutedInk,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 22,
            child: Text(
              _selected == 0 ? "Tap a star" : _starLabels[_selected - 1],
              style: textTheme.titleSmall,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            InfoBanner(tone: AppTone.error, message: _error!),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text("Cancel"),
        ),
        PrimaryButton(
          label: "Submit",
          expand: false,
          loading: _saving,
          onPressed: _selected == 0 ? null : _submit,
        ),
      ],
    );
  }
}
