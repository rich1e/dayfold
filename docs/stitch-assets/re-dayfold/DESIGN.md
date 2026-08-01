---
name: dayfold-design-system
description: Dayfold iOS SwiftUI diary app — warm dark paper aesthetic with serif typography, midnight blue-gray base, ember orange accent, and Hardcover-inspired notebook covers
colors:
  warmPaper: 3C3C44
  warmCream: 4A4A58
  warmLight: 434350
  warmGray: 52525F
  warmBrown: 9090A0
  warmDark: E8E8EC
  warmAccent: E05A3A
  drawerBg: 2D2D33
  drawerAccent: F27359
  cyanAccent: 5BC8D8
  coverLeather: 2C1A0A
  coverCream: E8D5B8
---

# Design System: Dayfold

**Platform:** iOS (SwiftUI)
**Reference inspiration:** Hardcover, Day One
**Project ID:** dayfold-demo (Stitch)

## 1. Visual Theme & Atmosphere

Dayfold is a private journaling app wrapped in a **warm, dimly-lit reading-room aesthetic**. The whole interface is set in a midnight blue-gray — like the inside of a leather journal at nightfall — with one ember-orange spark (warmAccent `#E05A3A`) that punctuates the screen like a candle flame or a ribbon bookmark. The atmosphere is *contemplative and tactile*, never clinical or bright.

The visual language borrows heavily from physical notebooks. Cards feel like paper laid on a desk: soft `16pt` corners, a top-down gradient that suggests fiber texture, drop shadows that imply a slight lift off the page. Typography mixes **serif body text** (system serif, STSongti-SC for titles) with **rounded utility text** (system rounded for captions, footnotes, metadata) — the same pairing you'd find in a printed book where headlines are set in a traditional Chinese serif and running matter sits in a clean humanist sans.

Information density is **generous, not compact**. Cards breathe with `20pt` horizontal padding, `14–20pt` vertical section breaks, and a single column of meaningful content. Whitespace carries emotion here: empty space is rest, not waste. The drawer that opens from the left (`85%` of screen width) reinforces this — it slides in like pulling a leather cover aside, with a `0.38s ease-out` motion and a soft inward shadow.

## 2. Color Palette & Roles

### Primary Foundation (midnight blue-gray)
- **warmPaper `#3C3C44`** — Main app background. Blue-gray, slightly desaturated, ~14% luminance. The "desk" the journal sits on.
- **warmCream `#4A4A58`** — Divider/border lines. A subtle 1-step lift off the paper; never stark contrast.
- **warmLight `#434350`** — Card and panel surface. Half a step darker than dividers; the "paper" laid on the desk.
- **warmGray `#52525F`** — Card shadow base, disabled backgrounds. Used for elevation shadows (`opacity 0.12`) and inactive chrome.

### Accent & Interactive (ember orange)
- **warmAccent `#E05A3A`** — Primary CTA, active selection, page indicators. The signature ember-orange spark. Used sparingly: confirm buttons, the active pagination dot, the Face ID unlock button, location/weather metadata.
- **drawerAccent `#F27359`** — A slightly warmer, brighter variant for the drawer's "DAYFOLD" wordmark and active sidebar rows. Picks up warm light.

### Secondary Accent (cool cyan)
- **cyanAccent `#5BC8D8`** — Used in the notebook cover palette chevronTeal, top-bar back chevrons, and selected toolbar icons. Provides a cool counterpoint to ember; appears in photo-overlay tints and the lock-screen branding line.

### Typography & Text Hierarchy
- **warmDark `#E8E8EC`** — Primary text. Near-white with a faint blue-gray cast; reads as "ink on cream" rather than "white on black".
- **warmBrown `#9090A0`** — Secondary text. ~56% luminance. Used for date stamps, captions, footer labels, disabled tab icons.
- **Drawer group labels `#5BC8D8`** — Cyan small-caps for "日记" / "更多" group headings; intentionally cool to contrast with the warm body.

### Drawer Sub-palette (SidebarView)
The drawer uses its own tightly-controlled set to differentiate it from the content area behind it:
- `drawerBg` — `(0.18, 0.18, 0.20)` — slightly darker than warmPaper
- `drawerRowBg` — `(0.22, 0.22, 0.24)` — pressed-row highlight
- `drawerDivider` — `(0.28, 0.28, 0.30)` — subtle row separators
- `drawerText` — `(0.92, 0.92, 0.92)` — off-white text

### Functional States
- **Destructive** — `C03828` (deep brick red, TrashView action buttons)
- **Cover Leather** — `2C1A0A` (rich espresso brown, leather notebook spine)
- **Cover Cream** — `E8D5B8` (parchment cream, leather cover accent circles)

### Tag Color Presets (per-category identity)
Seven preset tag colors travel with the tag system, distinct from the UI palette:
- 工作 (Work) `#4A90E2` — corporate blue
- 生活 (Life) `#7ED321` — fresh green
- 旅行 (Travel) `#F5A623` — amber
- 美食 (Food) `#D0021B` — chili red
- 运动 (Sport) `#BD10E0` — magenta
- 学习 (Study) `#50E3C2` — mint cyan
- 娱乐 (Fun) `#FF6B6B` — coral pink

### Notebook Cover Palette (5 hardcovers)
- `chevronTeal` `#8A8A90` — cool gray with chevron pattern
- `triangleRed` `#C04030` — heritage red with triangle motif
- `stripesBlack` `#303035` — near-black with stripe pattern
- `leatherBrown` `#2C1A0A` — espresso leather, embossed
- `diagonalGray` `#606065` — neutral gray, diagonal grain

## 3. Typography Rules

### Hierarchy & Weights
- **warmTitle** — `STSongti-SC-Bold`, 24pt — Screen-level titles, "Dayfold" wordmark on lock screen. Songti (宋体) is a Chinese traditional serif; its bold variant has the look of a woodblock-printed journal title page.
- **warmHeadline** — `STSongti-SC-Regular`, 18pt — Section headings, card titles within the card.
- **System bold weight** — `.system(size: 26, weight: .black)` with `tracking(3)` — The "UNTITLED" cover name; uppercase, wide tracking, almost typographic poster-like.
- **warmBody** — `system size:16 weight:.regular design:.serif` — Body copy, journal entries, button labels. Serif body gives the diary a printed-book feel rather than app-like.
- **warmCaption** — `system size:13 weight:.regular design:.rounded` — Date stamps, secondary metadata, "—" placeholders.
- **warmFootnote** — `system size:11 weight:.regular design:.rounded` — Tertiary labels: location names, weather degrees, tag pills, watermarks.

### Inline Size Variants
- 10pt rounded — tag pill text (the smallest legible size, paired with `cornerRadius(10)`)
- 11pt rounded — timestamps, weather °C, location name, "Dayfold" watermark
- 13pt rounded — full dates like "2024年3月14日 星期四"
- 14pt serif — preview content (lineLimit 6, lineSpacing 4 — gives journal text room)
- 16pt serif — button text, drawer row labels
- 17pt Songti Bold — card title within EntryCardView
- 22pt system bold + tracking(2) — "DAYFOLD" sidebar wordmark
- 24pt Songti Bold — lock screen title
- 26pt black weight + tracking(3) — cover-name title on notebook

### Spacing Principles
- **Letter-spacing (`tracking`)** is used to evoke printed type: `tracking(3)` on uppercase cover titles, `tracking(2)` on the "DAYFOLD" wordmark, `tracking(1.5)` on small-caps group labels, `tracking(1)` on metadata subtitles.
- **Line spacing** in body text: `lineSpacing(4)` for multi-line journal preview — creates breath between sentences without breaking line height.
- **Two-family pairing**: serif for content (titles, body, card titles), rounded for utility (dates, tags, metadata). This single rule carries the entire typographic system.

## 4. Component Stylings

### Cards (WarmCardView / EntryCardView)
- **Corner radius:** `16pt` everywhere. Signals softness without being playful.
- **Background:** `Color.warmLight` (`#434350`) with a top-leading → bottom-trailing `LinearGradient` of `warmCream.opacity(0.3)` → clear → `warmCream.opacity(0.15)`. The gradient is so faint it's barely perceptible, but it adds subtle "fiber" texture.
- **Shadow:** `Color.black.opacity(0.35)`, radius `8`, offset `(0, 4)` (in WarmCardModifier). EntryCardView uses a softer variant: `warmDark.opacity(0.12)`, radius `12`, offset `(0, 4)`. Shadows always drop *down*, never up.
- **Inner padding:** `16pt` universal via `.warmCard()` modifier. Larger sections (EntryCard) use `20pt horizontal` with section-specific vertical breaks of `14–20pt`.
- **Section dividers:** `Divider().background(Color.warmGray.opacity(0.5))` — barely-there horizontal rules.

### Buttons
- **Primary CTA (Unlock / Confirm):** `Color.warmAccent` background, white text, `cornerRadius(12)`, `padding(.vertical, 16)`, full width. Carries weight.
- **Circle action buttons (HomeView cover mode):** `60×60pt` circular buttons in either `cream bg + dark icon` (secondary) or `accent bg + white icon` (primary). Used as floating action buttons in cover swiping.
- **Sidebar drawer rows:** `padding(.horizontal, 20)`, `padding(.vertical, 15)`. Icon `22pt` fixed-width gutter. Active state: text/icon flip to `drawerAccent`. Pressed state: `drawerRowBg` highlight.
- **Top-bar icon buttons:** `44×44pt` touch target with `Image(systemName:)` icon, `padding(.horizontal, 8)`.

### Navigation
- **Drawer pattern (not TabBar):** `MainTabView` shows `DrawerView` on the left at `85%` screen width, content slides right by the same amount with a `spring(response: 0.38, dampingFraction: 0.82)` animation. A `Color.black.opacity(0.01)` overlay closes the drawer on tap.
- **Drawer content hierarchy:** Top brand mark → primary group (日记: 全部日记/相册/地图) → Spacer → divider → secondary group (更多: 回收箱/数据统计/设置).
- **Active state on drawer rows:** ember-orange text + icon + chevron; inactive rows show neutral text + dimmed chevron.
- **Section transitions:** `AnyTransition.paperDrop` — content appears with a 3D rotate-from-above effect (`-8°` X-axis) and 12pt vertical drop, fading in. Creates a "page settling onto the desk" feeling.

### Inputs & Forms
- **Markdown editor** uses `UITextView`-backed SwiftUI wrapper with custom toolbar.
- **Formatting toolbar** floats above the keyboard with quick formatting actions.
- **Media picker** opens `PhotosPicker` (iOS 16+) with thumbnail previews in `cornerRadius(6)` cells, `6pt` gaps.

### Domain-Specific Components

#### Notebook Cover (HomeView cover mode)
A 3D-style representation of a physical notebook:
- **Spine shadow:** thin left edge in `notebook.spineColor` (`#C04030`, `#2C1A0A`, etc.) for chevron/triangle/stripes/leather/diagonal styles.
- **Front face:** large rounded rectangle with cover-style-specific decoration drawn in SwiftUI (chevrons, triangles, stripes, leather grain).
- **Embossed title:** the notebook name on the front face in `Color(hex: "4A3020")` (dark espresso) for cream covers, with subtle emboss/shadow.
- **Selection dot row:** below the cover, `5BC8D8` cyan dots for multi-notebook paginators, with `E05A3A` ember for the current page indicator.

#### EntryCardView (shareable card)
A wide `340pt` card that mirrors a single diary entry, used for export/share:
- **Header:** full date (`yyyy年M月d日  EEEE`) in warmBrown 13pt, then time + weather °C + location pill row in warmAccent.
- **Divider** in warmGray, 50% opacity.
- **Title:** STSongti-SC-Bold 17pt, warmDark, max 2 lines.
- **Preview:** serif 14pt, warmDark.opacity(0.85), lineLimit 6, lineSpacing 4. Strips Markdown characters first.
- **Images:** up to 3 thumbnails, equal width inside 300pt container with 6pt gaps, `cornerRadius(6)`.
- **Footer divider** + footer with tag chips and "Dayfold" watermark in warmAccent.opacity(0.6).

#### Tag Pill
- `padding(.horizontal, 8)`, `padding(.vertical, 4)`
- `background(tag.displayColor.opacity(0.2))`
- `foregroundColor(tag.displayColor)` (saturated tag color)
- `cornerRadius(10)`
- 10pt rounded font + 9pt system icon
- Color comes from the tag's stored hex, not the UI palette.

#### EntryHeader
Inline header used in detail views:
- Long-form datetime → warmCaption + warmBrown
- Location + weather HStack → warmFootnote + warmAccent
- Horizontal-scrolling tag pills

## 5. Layout Principles

### Grid & Structure
- **Single-column mobile** throughout — no multi-column desktop layout despite the design system's broader ambitions.
- **Standard mobile width:** card content centers at `340pt` for share cards; full-bleed views use safe-area insets with `8–20pt` horizontal padding.
- **iPad-style multi-card grid:** the home view's cover mode lays out a single 3D-floating notebook with a paginator below — not a tile grid.

### Whitespace Strategy
- **Vertical rhythm in cards:** `20pt` top, `14pt` to divider, `14pt` after divider, `14pt` to bottom. Generous breathing.
- **Section gap values:** 4, 6, 8, 10, 12, 14, 16, 20, 24, 32 — almost no odd numbers. Strongly 8-point-grid-aligned, with `4pt` allowed for tight metadata rows.
- **Drawer vertical rhythm:** `60pt` top padding (under status bar), `24pt` bottom of brand, `6pt` between group label and rows, `15pt` vertical padding per row, `32pt` bottom of fixed group.
- **Notebook detail top area:** `100pt` top padding to leave room for status bar + visual breathing above the cover.

### Alignment & Visual Balance
- **Left-aligned text** is the default — never centered body copy. Even titles in detail views are left-aligned.
- **Center-aligned** reserved for the cover name + meta line, the lock-screen app icon/title block, and the loading/empty states.
- **HStack with Spacer()** is the canonical horizontal layout pattern (e.g., header has back-button | Spacer | icon-button | icon-button).
- **Right-aligned metadata** in EntryCardView footer (tag chips on left, "Dayfold" watermark on right) — gives cards a balanced, book-like layout.

### Responsive Behavior & Touch
- **Touch targets:** 44×44pt minimum for all icon buttons (per Apple HIG).
- **Drawer width:** 85% of screen width via `GeometryReader` — leaves a 15% sliver of content visible as a hint that the drawer is dismissable.
- **Spring animations:** `response: 0.38, dampingFraction: 0.82` is the canonical drawer/sheet motion. `response: 0.42, dampingFraction: 0.85` for the dismiss-back-button.
- **Card transitions:** `paperDrop` — 3D rotate + drop + opacity, `0.38s` ease-out.

## 6. Design System Notes for Stitch Generation

### Language to Use
When prompting Stitch for new screens, lean on these descriptive phrases:

- **Atmosphere:** "midnight blue-gray reading-room aesthetic", "warm leather journal lit by candlelight", "tactile and contemplative", "soft shadows on warm paper".
- **Surface:** "deep blue-gray paper background", "off-white ink text", "ember-orange accent for emphasis only", "faint cyan secondary accent".
- **Cards:** "softly rounded paper cards with a 16-point corner radius and a subtle gradient suggesting fiber", "warm shadow dropping downward, never upward".
- **Typography:** "Chinese traditional serif (Songti) for titles, system serif for body, system rounded for utility text and metadata", "wide letter-tracking on uppercase titles".
- **Motion:** "spring-eased transitions, paper-drop transition for switching sections, drawer that slides from the left covering 85% of the screen".

### Color References
Always pass the full warm palette when generating a new screen so the theme carries through. The minimum to include:

```
warmPaper #3C3C44     — main background
warmLight #434350     — card surface
warmDark  #E8E8EC     — primary text
warmBrown #9090A0     — secondary text
warmAccent #E05A3A    — ember accent (CTA, active)
cyanAccent #5BC8D8    — cool secondary accent
```

### Component Prompts
Example prompts to recreate key components in Stitch:

1. **Notebook detail header:** "A mobile journal app screen with a deep blue-gray background. Top bar has a cyan back chevron on the left, two icon buttons (photo grid, calendar) on the right. Below: a large uppercase title 'UNTITLED' in heavy black weight with 3pt letter-spacing, colored warm amber #D4A574. Subtitle reads '2026.07.27 / 12 ENTRIES' in 12pt regular, muted gray #7A7A88, with 1pt tracking."

2. **Entry card:** "A 340pt-wide diary card on a deep midnight background. Top: full date in Chinese ('2026年3月14日 星期五') in 13pt rounded, muted brown. Below: a row with time '14:32', location pin + '北京市朝阳区', sun icon + '12°C', all in ember-orange. Divider. Title in Songti-Bold 17pt. Body preview in serif 14pt, opacity 85%, 6 lines, line spacing 4. Three square image thumbnails. Footer divider. Tag pills in their own colors. Right-aligned 'Dayfold' watermark with book icon."

3. **Sidebar drawer:** "An 85%-width left drawer over a deep blue-gray (0.18, 0.18, 0.20) background. Top: 'DAYFOLD' wordmark in 22pt bold tracking(2), ember-orange. Group label '日记' (DIARY) in 11pt semibold cyan small-caps, tracking 1.5. Rows with 22pt SF icon, 16pt label, chevron-right, 20pt horizontal padding 15pt vertical padding. Active row: text + icon + chevron all in ember-orange. Pressed: row background lifts to slightly lighter gray."

### Incremental Iteration
- **Add new sections by reusing `.warmCard()`** — the gradient background and 16pt radius carry the entire look.
- **Add interactive states with warmAccent** — anything selected or in-progress flips from warmBrown to warmAccent.
- **Add new tag categories** by registering a new `(name, color, icon)` triple in `Tag.presetTags()`; tag colors live outside the UI palette intentionally.
- **Add a new notebook cover style** by adding a `CoverStyle` case + `spineColor` + drawn decoration in `HomeView.swift`.
- **Avoid:** bright white backgrounds, harsh 1px borders, accent colors other than the defined palette, center-aligned body copy.