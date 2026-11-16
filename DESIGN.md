# Design system: "Golden hour on the airport road"

Nature (hills, trees, sun), cars (the road, headlights) and airplanes (contrails, boarding passes) meet in one warm, organic world. Everything is drawn in code (`CustomPainter`); no downloaded illustration assets.

## Colour
Keep the existing identity, refine it, add restrained accents. All tokens live in `apps/mobile/lib/core/app_theme.dart`.

| Token | Role |
|---|---|
| coral `#E8604B` | primary action, active states |
| plum `#4A2545` | secondary, headings accents, outlined actions |
| cream `#FBF3E7` | page background |
| surfaceWhite `#FFFDF9` | cards, inputs |
| ink `#241F21` | body text |
| moss (new) | success, active, verified |
| sky (new) | info banners, illustration sky |
| amber (new) | ratings, warnings (headlight) |
| asphalt (new) | illustration road, scanner overlay |

Each accent has an explicit container tint. Screens never use seed-derived `secondaryContainer` or `tertiaryContainer` directly. Destructive actions use an error-toned button, never coral primary.

## Type (google_fonts)
- Display and headlines: Fraunces (soft serif). Screen headlines, match names, big numbers.
- UI and body: DM Sans.
- Full Material 3 text scale is defined in the theme. Screens never set `fontSize` inline.

## Space and shape
- Spacing scale 4 / 8 / 12 / 16 / 24 / 32. Page gutter 24. Max content width 480, centred on wide web.
- Radii: sm 12, md 16, lg 24, pill. Cards lg, inputs md, buttons pill.

## Components (`apps/mobile/lib/core/ui/`)
AppPage (scrollable, max-width, sticky bottom action bar in SafeArea), Primary/Secondary/DestructiveButton (loading built in), AppCard, SectionHeader, InfoBanner (info, safety, test), StatusPill, LoadingView, EmptyState, ErrorState (with retry), AppAvatar (fallback, edit badge), ActionTile, confirm dialogs, snack helper, friendly date/time formatters.

## Signature motifs
- HorizonScene: layered hills, curving road with dashed centre line, sun, plane on a dotted contrail arc. Static header on welcome, home and mutual match; animated loader (car on road, plane on arc) on the awaiting screen.
- BoardingPassCard: ticket shape with notches and a perforated divider for ride summaries and candidate cards.
- Road-line dividers; plane-path progress for onboarding.
- Motion: fade-through page transitions, one celebration on mutual match, reduced motion respected.

## Forms
Filled inputs, no local border overrides, label above or floating consistently, helper text only when it adds information, errors always attached to their field.
