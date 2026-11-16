import "package:material_ui/material_ui.dart";
import "../app_theme.dart";

Widget _buttonChild(String label, bool loading, Color spinnerColor) {
  if (!loading) return Text(label);
  return SizedBox(
    width: 22,
    height: 22,
    child: CircularProgressIndicator(strokeWidth: 2.5, color: spinnerColor),
  );
}

Widget _wrap(bool expand, Widget button) {
  if (!expand) return button;
  return SizedBox(width: double.infinity, child: button);
}

/// The one main action on a screen. Shows a spinner and ignores taps while
/// [loading]; disabled when [onPressed] is null.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final handler = loading ? () {} : onPressed;
    final child = _buttonChild(label, loading, Colors.white);
    final button = (icon == null || loading)
        ? FilledButton(onPressed: handler, child: child)
        : FilledButton.icon(onPressed: handler, icon: Icon(icon), label: child);
    return _wrap(expand, button);
  }
}

/// A supporting action next to or under a [PrimaryButton].
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final handler = loading ? () {} : onPressed;
    final child = _buttonChild(label, loading, AppTheme.plum);
    final button = (icon == null || loading)
        ? OutlinedButton(onPressed: handler, child: child)
        : OutlinedButton.icon(onPressed: handler, icon: Icon(icon), label: child);
    return _wrap(expand, button);
  }
}

/// For irreversible actions (unmatch, delete, log out). Error-toned so it is
/// never mistaken for the coral primary action.
class DestructiveButton extends StatelessWidget {
  const DestructiveButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      onPressed: loading ? () {} : onPressed,
      style: FilledButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
      child: _buttonChild(label, loading, Colors.white),
    );
    return _wrap(expand, button);
  }
}
