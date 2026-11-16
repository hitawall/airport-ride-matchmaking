import "package:material_ui/material_ui.dart";
import "tokens.dart";

/// Standard screen scaffold: centred max-width column, consistent gutter,
/// scrolling that never overflows, and an optional action bar pinned to the
/// bottom (above the keyboard and the system home indicator).
class AppPage extends StatelessWidget {
  const AppPage({
    required this.body,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    this.bottomBar,
    this.onRefresh,
    this.centered = false,
    this.showAppBar = true,
    this.padding,
    super.key,
  });

  final Widget body;
  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;

  /// Pinned below the scrolling content, usually a [PrimaryButton].
  final Widget? bottomBar;
  final Future<void> Function()? onRefresh;

  /// Vertically centre the body when it is shorter than the screen.
  final bool centered;
  final bool showAppBar;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final contentPadding = padding ?? const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.xl);

    Widget scrollArea = LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = (constraints.maxHeight - contentPadding.vertical).clamp(0.0, double.infinity);
        final content = ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: centered ? Center(child: body) : Align(alignment: Alignment.topCenter, child: body),
        );
        return SingleChildScrollView(
          padding: contentPadding,
          physics: onRefresh != null ? const AlwaysScrollableScrollPhysics() : null,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: SizedBox(width: double.infinity, child: content),
        );
      },
    );

    if (onRefresh != null) {
      scrollArea = RefreshIndicator(onRefresh: onRefresh!, child: scrollArea);
    }

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: titleWidget ?? (title == null ? null : Text(title!)),
              leading: leading,
              actions: actions,
            )
          : null,
      body: SafeArea(
        top: !showAppBar,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
            child: Column(
              children: [
                Expanded(child: scrollArea),
                if (bottomBar != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.sm,
                      AppSpacing.gutter,
                      AppSpacing.lg,
                    ),
                    child: bottomBar,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
