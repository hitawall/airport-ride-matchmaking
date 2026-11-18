import "package:material_ui/material_ui.dart";

/// A field label followed by a red asterisk, so what must be filled in is
/// obvious at a glance. Use it as an [InputDecoration.label] or on its own as a
/// heading for a group of choices.
class RequiredLabel extends StatelessWidget {
  const RequiredLabel(this.text, {this.style, super.key});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(text, style: style, overflow: TextOverflow.ellipsis)),
        Text(
          " *",
          semanticsLabel: " required",
          style: (style ?? const TextStyle()).copyWith(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
