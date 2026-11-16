import "package:material_ui/material_ui.dart";
import "package:go_router/go_router.dart";
import "../../core/app_config.dart";
import "../../core/ui/app_page.dart";
import "../../core/ui/info_banner.dart";
import "../../core/ui/tokens.dart";
import "../../core/ui/tone.dart";
import "legal_content.dart";

/// A public (no login) page showing the privacy policy or the terms.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({required this.document, super.key});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AppPage(
      title: document.title,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: "Back",
        onPressed: () => context.canPop() ? context.pop() : context.go("/"),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!AppConfig.legalReviewed) ...[
            const InfoBanner(
              tone: AppTone.warning,
              title: "Draft",
              message:
                  "This text has not been reviewed yet and may change. Placeholders in square brackets are filled in at release.",
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(document.title, style: textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(document.intro, style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
          for (final section in document.sections) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(section.title, style: textTheme.titleMedium),
            for (final paragraph in section.paragraphs) ...[
              const SizedBox(height: AppSpacing.sm),
              SelectableText(paragraph, style: textTheme.bodyMedium),
            ],
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
