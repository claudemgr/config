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
