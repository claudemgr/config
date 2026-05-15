---
name: UI/UX conventions
description: Designer-level UI/UX standards for web, desktop, mobile, and TUI — theme system, accessibility, layout, interaction
type: user
---

## Designer Mindset

Every UI surface — web, desktop, mobile, TUI — must be built with designer-level intent. "It works" is not enough. Aim for clarity, consistency, and delight. When implementing any UI:

- Think in user flows, not in code paths
- Every state must be handled: loading, empty, error, success
- Copy matters — no "Error occurred", no "Feature 1, Feature 2", no placeholder text
- Spacing, alignment, and hierarchy are not optional polish

---

## Theme System (all surfaces)

**Default: dark. Always.**

Every UI must support three modes:

| Mode | Behaviour |
|------|-----------|
| `dark` | Dark background, light text — the default |
| `light` | Light background, dark text |
| `auto` | Follows the OS/system preference (`prefers-color-scheme`) |

**Rules:**
- Ship dark mode first; light mode is not an afterthought
- `auto` must react to live OS preference changes without reload (web: `prefers-color-scheme` media query or `matchMedia` listener; desktop: `dark-light` crate or equivalent; mobile: system API)
- User override is always respected and persisted (localStorage for web; config file or OS keystore for desktop/mobile)
- Never hardcode colors inline — use CSS custom properties (web), a shared theme struct (desktop/TUI), or a design token system

---

## Web UI

### Rendering
- Server-side rendering only (Go templates, Jinja2, ERB, etc.) — never React/Vue/Angular for core content
- Progressive enhancement: every page works without JavaScript
- No client-side routing (SPAs); no business logic in JS
- No inline CSS or JavaScript; no `<style>` blocks in templates
- No JavaScript `alert()` / `confirm()` — use toast notifications or modal dialogs

### Layout — mobile-first
- Write CSS for mobile first; expand with media queries
- Never desktop-first CSS

**Breakpoints:**

| Target | Media query |
|--------|-------------|
| Mobile (base) | none |
| Tablet | `@media (min-width: 768px)` |
| Desktop | `@media (min-width: 1024px)` |
| Wide | `@media (min-width: 1440px)` |

### Accessibility — WCAG 2.1 AA minimum
- Semantic HTML — headings in order, landmarks (`<main>`, `<nav>`, `<aside>`), buttons are `<button>`
- All images have `alt` text; decorative images use `alt=""`
- Touch targets minimum **44×44 px**
- Keyboard navigable — every interactive element reachable and operable by keyboard
- Focus indicators always visible — never `outline: none` without a custom replacement
- Color is never the only differentiator (always pair with icon, label, or pattern)
- Sufficient contrast: 4.5:1 for normal text, 3:1 for large text (WCAG AA)
- `lang` attribute on `<html>`; `dir` attribute when supporting RTL

### Long strings (REQUIRED CSS)
```css
.long-string, .ip-address, .onion-address, .api-token, .hash, .uuid {
  word-break: break-all;
  overflow-wrap: break-word;
  font-family: monospace;
}
```
Apply to: IPv6, onion addresses, API tokens, hashes, UUIDs, Base64 blobs.

### Theme implementation (web)
```css
:root[data-theme="dark"]  { --bg: #0d1117; --fg: #e6edf3; --accent: #58a6ff; }
:root[data-theme="light"] { --bg: #ffffff; --fg: #1f2328; --accent: #0969da; }

@media (prefers-color-scheme: dark)  { :root { --bg: #0d1117; --fg: #e6edf3; --accent: #58a6ff; } }
@media (prefers-color-scheme: light) { :root { --bg: #ffffff; --fg: #1f2328; --accent: #0969da; } }
```
- `data-theme` attribute on `<html>` set by JS from user preference (localStorage)
- Default (no JS): CSS media query handles `auto` automatically
- Theme toggle button updates `data-theme` and persists to localStorage instantly (no page reload)

### Server vs client responsibility
| Task | Where |
|------|-------|
| Validation | Server — server is authoritative |
| HTML rendering | Server — works without JS |
| Business logic | Server — security and consistency |
| Theme toggle | Client JS — instant feedback |
| Copy to clipboard | Client JS — browser API |
| Form feedback | Client JS — UX enhancement only |

---

## Desktop UI (native)

### Surface priority (auto-detect at runtime)
1. **GUI** — preferred when a display server is available and the invocation is interactive
2. **TUI** — fallback for capable terminals without a display server
3. **CLI** — non-interactive or when `NO_COLOR`/plain-output is requested

### Display backends (Linux/BSD) — both required
- X11 and Wayland are first-class; neither is a fallback of the other
- Preferred Rust crates: `x11rb` or `x11-dl` for X11; `wayland-client` with `dlopen` for Wayland
- GUI toolkit: `egui`, `iced`, `slint`, `floem`, or `dioxus` (native renderer mode) — all pure Rust
- TUI: `ratatui` + `crossterm`
- Theme detection: `dark-light` crate (pure Rust, no C libs)

### Assets
- All assets embedded at build time — fonts, icons, theme data, default config, schemas, locales
- User is never required to install support files separately
- No CDN or network fetch on first run

### Accessibility (desktop)
- Keyboard-only navigation required; mouse is an enhancement
- Touch targets minimum 44×44 px (for touch-capable devices)
- High-contrast mode support where the toolkit allows
- Screen reader compatibility where the toolkit exposes accessibility APIs

### Theme implementation (desktop/TUI)
- Detect at startup via `dark-light` crate or OS API
- React to live changes without restart where the OS API supports it
- User override stored in config file, takes precedence over detection
- TUI: respect `NO_COLOR` — strip all ANSI color when set

---

## Mobile apps

### Layout
- Mobile-first is native — design for the smallest screen first
- Use platform layout primitives (SwiftUI `VStack`/`HStack`, Jetpack Compose `Column`/`Row`, Flutter `Column`/`Row`)
- Respect safe areas (notch, home indicator, system bars)
- Minimum touch target: **44×44 pt/dp**

### Theme implementation (mobile)
- iOS: `@Environment(\.colorScheme)` + `Color(uiColor: .systemBackground)` semantic colors
- Android: Material You / Dynamic Color + `isSystemInDarkTheme()`
- Flutter: `ThemeData` with `brightness` from `MediaQuery.platformBrightness`
- User override: explicit dark/light setting in app preferences, persisted via platform storage

### Accessibility (mobile)
- VoiceOver (iOS) and TalkBack (Android) labels on all interactive elements
- Dynamic Type / font scaling respected — no hardcoded font sizes
- Sufficient color contrast (WCAG AA minimum)
- No color-only indicators

---

## TUI

- Use alternate screen buffer — restores terminal cleanly on exit
- Keyboard-only navigation; mouse support is an enhancement
- Respect `NO_COLOR` — if set, strip all ANSI colors and use plain text rendering
- Minimum readable width: 80 columns; gracefully degrade at narrower widths
- Show a spinner or progress indicator for operations >300 ms
- Escape / `q` always exits a view; `?` always shows help

---

## Universal rules (all surfaces)

- **No placeholder content** — every page/screen ships with real, functional content; no "coming soon", "Feature 1", or empty states without a meaningful message
- **Every state handled** — loading, empty, error, success each have a distinct, informative UI
- **i18n-ready** — no hardcoded user-visible strings; use a translation key from the first commit
- **No feature gating** — GUI, TUI, and CLI surfaces expose the same core capabilities
- **Feedback for every action** — button press, form submit, background task — user always knows something happened
- **Consistent spacing** — use a spacing scale (e.g. 4 px base unit: 4, 8, 12, 16, 24, 32, 48); never arbitrary pixel values

---

## Dynamic Interaction (all surfaces)

### Gestures

- **Tap** — primary action on an element; must have a visible pressed/active state
- **Long-press** — reveals contextual options (context menu, drag handle, selection mode); always show a visual affordance (highlight, scale, or haptic) to confirm recognition
- **Swipe (horizontal)** — navigation between peers (tabs, pages, cards) or destructive/action reveal on list rows; always provide a snap point and a cancel path (release before threshold = no action)
- **Swipe (vertical)** — scroll; pull-to-refresh when at the top of a scrollable list; dismiss a modal when at the top of the sheet
- **Pinch / spread** — zoom in/out on zoomable content only; never hijack pinch on non-zoomable surfaces
- **Edge swipe** — reserved for OS-level navigation (back, app switcher); never override or intercept edge gestures
- **Drag** — reorder, move, or resize; always show a drag indicator (handle icon or elevated state); snap to valid drop zones; animate to final position on release
- **Two-finger tap / three-finger tap** — reserved for accessibility (zoom, undo); never bind custom actions to these
- Gesture conflicts must be resolved with a clear priority order: scroll > swipe-action > long-press > tap; never let two gestures silently compete
- Every gesture must have a non-gesture equivalent (button, menu item, keyboard shortcut) — gestures are an enhancement, not the only path

### Haptics

- Use haptics only on touch-capable hardware; never assume haptic availability — always check at runtime and degrade gracefully
- **Selection / light** — item selection, toggle, radio button, segmented control change
- **Impact / medium** — completing a drag-and-drop, snapping to a grid, confirming a reorder
- **Impact / heavy** — destructive action confirmation (delete, archive), pull-to-refresh trigger point
- **Notification / success** — task completed successfully
- **Notification / warning** — recoverable error, validation failure
- **Notification / error** — unrecoverable error, rejected action
- Never fire haptics on passive scroll or hover — only on deliberate, discrete user actions
- Never chain haptics back-to-back faster than 100ms; multiple rapid haptics feel like a glitch
- Respect system accessibility settings — if the user has disabled haptics or vibration, honor it

### Animations & Transitions

- **Duration scale** (all surfaces):

  | Type | Duration |
  |------|----------|
  | Micro (state change, toggle) | 100–150ms |
  | Standard (element enter/exit) | 200–300ms |
  | Emphasis (modal, page) | 300–400ms |
  | Complex (shared element, hero) | 400–500ms |

- **Easing**:
  - Enter: ease-out (fast start, gentle settle)
  - Exit: ease-in (gentle start, fast exit)
  - Repositioning / reorder: ease-in-out
  - Never use linear for UI transitions — it reads as mechanical
- **Enter** — elements slide or fade in from their natural origin; never pop in from nowhere
- **Exit** — elements fade or slide toward their origin; never disappear instantly
- **Shared element / hero** — when an element is the subject of a navigation (e.g. tapping a thumbnail to open detail), it must animate continuously from source to destination; no cut
- Respect `prefers-reduced-motion` (web) and the system reduced-motion accessibility flag (mobile/desktop) — when set, replace motion with instant transitions or simple opacity fades; never disable all feedback, just reduce motion
- Never animate layout-affecting properties (width, height, top, left) on the web — animate `transform` and `opacity` only; these are GPU-composited and do not cause reflow
- Skeleton screens replace spinners for content that has a known shape; spinners are for indeterminate-duration operations only

### Custom Keyboards & Input Extensions

- The input area (keyboard + toolbar) must never obscure focused input fields — reflow the layout when the keyboard is visible; use the platform's keyboard-avoidance primitive rather than hardcoding offsets
- Keyboard height is dynamic — it changes with language, orientation, hardware keyboard attachment, and accessibility settings; always read it from the platform notification/event, never hardcode it
- The accessory / autocomplete bar above the keyboard is part of the keyboard height — account for it in layout math
- Custom keyboard extensions must respect the same safe area and inset rules as the host app
- Dismiss behavior: tapping outside an input, pressing a hardware `Escape` or `Back`, or swiping down on a sheet that contains an input must dismiss the keyboard first, then (on a second gesture if needed) dismiss the sheet
- Custom keyboards must support all system text traits: autocorrect, autocapitalize, secure text (password), numeric, email, URL — never assume the default traits are correct for all fields
- Input accessory toolbars (formatting bar, emoji button, attachment picker) must be keyboard-height-aware on every orientation change
- If a custom keyboard has a `Done` / `Return` action, it must be wired to the form's primary submit action — never a no-op

### Dynamic Layout Adaptation

- **Orientation** — all layouts must be tested in portrait and landscape; neither is the "real" layout; content must reflow, not just rescale
- **Split-screen / multi-window** — assume the app can run at any width from ~320 pt to full screen simultaneously; use relative units and flexible containers, never fixed-width columns that only work full-screen
- **Foldables** — if a fold crease runs through the content area, shift content to avoid the hinge; never place interactive elements on the crease
- **Keyboard-up reflow** — when the software keyboard appears, the visible content area shrinks; scroll the focused field into view within the reduced area; do not zoom or scale the layout
- **Dynamic Type / font scaling** — all text must scale with the system font size setting; no hardcoded `px`/`pt`/`sp` font sizes; test at minimum and maximum scale factors
- **Display density** — use density-independent units everywhere (`dp`, `pt`, `rem`, `em`); never raw pixels except for single-pixel hairlines
- **Notch / punch-hole / safe areas** — all content and interactive elements must respect the safe area insets on all four sides; backgrounds may extend behind system bars (edge-to-edge), but tappable targets must not

### Scroll Behavior

- **Momentum** — scroll must have natural deceleration; never snap-stop on release unless snapping to a defined snap point
- **Snap points** — use snap points only when content is paged (carousels, full-screen cards, tab pagers); never on a plain list
- **Sticky headers** — section headers may stick to the top of a scroll container; they must not obscure the top-most visible item when sticky; unstick when scrolling back past their natural position
- **Parallax** — decorative only; hero images may scroll at 0.5× the content speed; interactive elements must never be inside a parallax layer
- **Pull-to-refresh** — only valid at scroll position = 0 (top); trigger point must have a clear visual threshold indicator; show a spinner/progress indicator while refreshing; dismiss the indicator when data is loaded, not when the request is sent
- **Infinite scroll** — load the next page when the user is within 2–3 screen-heights of the end; show a loading indicator at the bottom while fetching; show an end-of-list message when no more pages exist; never silently stop loading
- **Overscroll** — rubber-band (iOS-style) or glow (Android-style) at both ends of a scrollable list; never a hard stop with no visual feedback
- Scroll containers must not be nested in the same axis — horizontal list inside horizontal scroll, or vertical inside vertical, causes gesture conflicts and is prohibited

### Context Menus & Drag-and-Drop

- **Context menu trigger** — long-press on mobile; right-click on desktop; `⋮` / `…` menu button always present as a non-gesture fallback
- Context menus must show only actions relevant to the specific item — never a generic global menu
- Destructive actions (delete, remove, archive) must be visually distinct in the menu (red label or warning icon) and must be the last item
- **Drag-and-drop**:
  - Show a drag preview (a "ghost" of the item) attached to the pointer/finger during drag
  - Valid drop zones highlight on hover; invalid zones show no highlight (never a red X)
  - Drop snaps to the closest valid position; animate the item into its final slot
  - If the drag is cancelled (released outside a valid zone, `Escape` pressed), the item animates back to its origin
  - Multi-select drag: all selected items travel together in a stacked preview with a count badge
- Drag handles on reorderable lists must be visible (not hidden behind a long-press); an explicit handle icon is required when the list has both tap-to-open and drag-to-reorder behaviors on the same row

### State Persistence Across Interruptions

- **Background / app switch** — save all unsaved user input (forms, compose views, search queries) to a draft store before the app leaves the foreground; restore on return
- **Phone call / system overlay** — treat the same as backgrounding; never discard in-progress state because of a transient overlay
- **Rotation / resize** — UI state (scroll position, selected item, expanded/collapsed sections, modal open/closed) must survive orientation changes and window resizes without resetting to defaults
- **Process kill / crash recovery** — any user-authored content (typed text, drawn content, partially filled form) must be auto-saved at least every 30 seconds to a recoverable draft; on next launch, offer to restore
- **Network interruption** — in-flight actions (form submit, file upload, send message) must be queued and retried automatically; user must see a clear status: sending → queued → sent/failed; never silently drop
- **Session expiry** — if authentication expires mid-session, preserve all unsaved state, redirect to login, then restore state after re-authentication; never discard work
