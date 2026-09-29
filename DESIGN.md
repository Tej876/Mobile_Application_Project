# DESIGN.md — QueueLess Visual System

## Visual Direction
- **Surface Mode:** `Operate` (Clinical Dispatch & Patient Pass)
- **Emotional Temperature:** Warm, tactile, calm editorial palette built from the pinned 6-swatch brief: **Blush • Peach • Nude • Plum • Maroon • Charcoal**.

## Pinned 6-Swatch Palette & Role Tokens (`lib/theme/app_theme.dart`)
1. **Blush (`#F6E7E2`)** — `backgroundColor` (App canvas & splash base)
2. **Peach (`#E6CFC8`)** — `surfaceMuted` (Segmented control tracks, queue count pills, splash subtitle)
3. **Nude (`#BF9B8E`)** — `accentColor` (Warm borders `#DCC2BA` and secondary highlights)
4. **Plum (`#7E6570` / `#6B535D`)** — `textSecondary` & secondary splash wave trail
5. **Maroon (`#593E47`)** — `primaryColor` (Primary action buttons, active pass header, token number display)
6. **Charcoal (`#33252B`)** — `textPrimary` & `primaryDark` (Headings, body ink, active pass banner, floating notifications)
- **Elevated Card Surface (`surfaceColor`):** `#FFFBFA` (Warm blush-porcelain with `1px` `#DCC2BA` border)
- **Semantic States:**
  - `successColor`: `#2E6F54` (Called / Served / Clear Queue)
  - `errorColor`: `#9E2A3B` (Cancel / No-Show / Validation Alert)

## Typography
- **Primary Family:** `Plus Jakarta Sans` for headings, labels, body copy, and controls (`rule:product-typo-one-family`).
- **Numeric / Tabular Data:** `JetBrains Mono` strictly reserved for live queue numbers (`#01`, `#02`), wait-time measurements (`~15 min`), and timestamps (`14:05`) (`rule:skill-reflex-mono-as-technical`).

## Craft Floor Rules Enforced
- No eyebrow kickers above headings (`rule:skill-ban-eyebrow-on-every-section`).
- No decorative numbered section markers (`rule:skill-ban-numbered-section-markers`).
- Elevation declared once via `1px` warm Peach-Nude borders (`#DCC2BA`), never border + wide blur shadow (`rule:skill-ban-codex-ghost-card`).
