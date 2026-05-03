# Three-Tab UI Unification + CleanCut Rebrand — Design

**Date:** 2026-05-03
**Status:** Approved (awaiting user review of written spec)
**Branch target:** `main`

---

## 1. Goals

1. Make the three tabs (Smart Cut · Denoise · Merge) feel like one app — same chrome, same spacing, same color discipline.
2. Reduce wasted vertical space — drop large navigation titles in favor of inline.
3. Establish color discipline at the brand level: indigo `#5856D6` is the navigation/CTA brand color; lime green `#A7C957` is reserved for AI moments only (not "every CTA on a tab that contains AI features").
4. Replace the bare `+` import button with a single semantic icon — `waveform.badge.plus` — that reads as "add audio file" without a text label.
5. Add a binary Light/Dark theme toggle to **all three** home tabs. Default = Light. Drop the System option.
6. Remove the redundant `+` import icon from the Merge top-leading toolbar (import access flows through the empty-state hero CTA + drag-drop).
7. Rename the user-facing app from **SonicMerge** to **CleanCut**. Display name + in-app strings only — bundle ID, scheme, App Group, and target rename are deferred (see §11 Non-goals).

## 2. Non-goals

- Bundle identifier rename (`com.dtech.SonicMerge` → `…CleanCut`)
- Xcode scheme/target rename
- App Group identifier migration
- Tab order changes / IA changes
- Session-detail screen redesigns (Smart Cut Studio, Denoise Studio bodies)
- New design tokens — we work with the existing `accentAction` / `accentAI` palette
- A new shared `HomeTabScaffold` component (defer until a fourth tab demands it; YAGNI)

## 3. Architecture overview

The three home views (`SmartCutHomeView`, `DenoiseHomeView`, `MixingStationView`) keep their existing files and ownership. Each is independently edited to match the unified template. No new shared component is introduced — three small files remain three small files.

A single new `ThemeToggleButton` view is added to the design system (`SonicMerge/DesignSystem/ThemeToggleButton.swift`), used by all three home toolbars. It encapsulates the binary toggle, animation, and haptic.

`ThemePreference.system` is removed from the enum. Existing users who had it stored in `@AppStorage("sonicMergeThemePreference")` get migrated to `.light` on next launch via a one-line read-and-write in `SonicMergeApp.body`.

The app display name (`CFBundleDisplayName`) changes to `CleanCut`. In-app user-facing strings drop "SonicMerge" → "CleanCut". Internal type names (`SonicMergeApp`, `SonicMergeTheme`, etc.) stay — they're build-time symbols, not user-facing.

## 4. Visual identity

### 4.1 Color discipline

| Token | Hex | Used for |
|---|---|---|
| `accentAction` | `#5856D6` Deep Indigo | Tab bar selected tint; primary CTAs (import button, Add Clip, Export, theme toggle); back-chevrons; system semantic indigo throughout the chrome |
| `accentAI` | `#A7C957` Lime Green | AI hero icons (empty-state sparkles/waveform), AI Orb in Denoise studio, lime intensity slider, AI moment CTAs ("Apply Cuts" / "Re-denoise" floating bar buttons), AI summary card accent |

**The user-felt rule:** *indigo = navigation/move data; lime green = AI is doing something now.*

The "Upload Audio" / "Import Audio" entry point is **navigation** (you're moving a file into the app), not an AI moment — so it's indigo. AI buttons appear *after* you've imported and entered a session.

### 4.2 Title chrome

All three tab roots:

```swift
.navigationBarTitleDisplayMode(.inline)
```

Titles: `"Smart Cut"`, `"Denoise"`, `"Merge"`.

- `SmartCutHomeView`: change `.large` → `.inline`. Title string `"Smart Cut"` unchanged.
- `DenoiseHomeView`: change `.large` → `.inline`. Title string `"Denoise"` unchanged.
- `MixingStationView`: title display mode is **already** `.inline` (line 48 of current file) — only the title string changes from `"SonicMerge"` → `"Merge"`.

### 4.3 Background

`PremiumBackground()` on all three home roots (Smart Cut + Denoise already have it; Merge gains it). Existing `MergeTimelineView` continues to render on top.

## 5. Home-screen template

Two variants under one shared chrome (same background, title style, fonts, vertical rhythm, plus-button style):

### 5.1 List variant (Smart Cut, Denoise)

**Empty state:**
- Vertically centered `VStack` containing:
  - Lime hero icon — 76×76 rounded-rect, `accentAI` background at 18% alpha, lime SF Symbol foreground
    - Smart Cut: `sparkles`
    - Denoise: `waveform.badge.minus`
  - Hero title (`.title3` rounded semibold, `textPrimary`)
    - Smart Cut: "Cut fillers in seconds"
    - Denoise: "Clean noisy recordings"
  - Tagline (`.body` rounded, `textSecondary`, multiline-centered, max 240pt)
    - Smart Cut: "Upload a recording — we'll find every \"um,\" \"uh,\" and long pause."
    - Denoise: "Upload audio and remove background noise on-device."
  - **Import button** — circular indigo `accentAction` background, 60×60, single SF Symbol `waveform.badge.plus` (white, 26pt), shadow `0 6pt 16pt rgba(88,86,214,0.32)`. No text label.

**Loaded state** (recents present):
- A small (44×44) circular indigo import button **pinned at the top-trailing of the recents list section**, same `waveform.badge.plus` icon. Sits 16pt from the leading edge of the title bar bottom.
- Below it: scrollable recents list (current `SmartCutRecentRow` / `DenoiseRecentRow`), unchanged.
- Drag-and-drop zone covers the entire `ZStack`.

**Wiring:** Both the empty-state hero button and the loaded-state pinned button trigger the same existing `@State private var showFileImporter` flag (`SmartCutHomeView` line 24, `DenoiseHomeView` line 21). The downstream `.fileImporter(...) { result in handleImport(...) }` modifier and `createSession(from:)` flow are unchanged. The change is purely visual — same state, same behavior, different button shape.

### 5.2 Workspace variant (Merge)

**The existing `MixingStationView.emptyState` "Import Audio" pill button (current file lines ~141–146, `Label("Import Audio", systemImage: "plus.circle.fill")` + `PillButtonStyle(variant: .filled, size: .regular)`) is removed and replaced with the new circular hero pattern.** Both the existing empty-state pill and the leading-toolbar `+` are deleted in the same diff — this avoids leaving two import affordances.

**Empty state (new):**
- Same hero pattern as list variant.
- Hero icon: `rectangle.stack` on a 14% indigo background (uses `accentAction` because Merge is not an AI feature).
- Hero title: "No clips yet"
- Tagline: "Tap below to add audio files,\nor drop them here."
- Import button: identical 60×60 circular indigo `waveform.badge.plus` — semantically the same action as Smart Cut/Denoise, just lands the file into the timeline instead of creating a new session.

**Loaded state** (timeline present):
- Same 44×44 circular indigo import button pinned top-trailing of the timeline section.
- Below it: existing `MergeTimelineView`, unchanged.

**Wiring:** Both the empty-state hero button and the loaded-state pinned button toggle the same existing `@State private var showDocumentPicker` flag (`MixingStationView` line 21). The downstream `.fileImporter(...)` and `viewModel.importFiles(urls)` flow are unchanged. Drag-drop (`.onDrop(of: UTType.audioDropTypes, ...)`) is preserved on the same `ZStack`.

The pinned-button-above-content pattern is the unifying gesture across all three loaded states.

## 6. Toolbars

### 6.1 Home toolbars

| Tab | Leading | Trailing |
|---|---|---|
| Smart Cut | — | `ThemeToggleButton` |
| Denoise | — | `ThemeToggleButton` |
| Merge | — | `ThemeToggleButton` · Export |

The existing `+` (Import) on Merge's top-leading is **removed**. Import access flows through the empty-state hero button (first launch) or the pinned import button above the timeline (loaded state). Drag-drop still works.

The existing trailing "More menu (theme picker + Picker)" on Merge is **replaced** by the new `ThemeToggleButton`. The picker UI is gone entirely.

### 6.2 Session-detail toolbars (push destinations)

Already correct from prior work. Unchanged.

| Screen | Leading | Trailing | Title |
|---|---|---|---|
| `SmartCutSessionView` | system back | Export (disabled until `outputURL`) · More menu (Delete) | inline session name |
| `DenoiseSessionView` | system back | Export (disabled until denoise result) · More menu (Delete) | inline session name |

## 7. ThemeToggleButton

**File:** `SonicMerge/DesignSystem/ThemeToggleButton.swift` (new)

**API surface (caller contract):**

```swift
struct ThemeToggleButton: View {
    init() {}   // zero-arg; reads/writes its own @AppStorage internally
    var body: some View { ... }
}
```

The button is fully self-contained — callers in all three home views invoke it identically as `ThemeToggleButton()`. No bindings, no closures, no state passed in. This keeps the call sites trivial and lets us wrap chrome around it (e.g. `.toolbar { ToolbarItem(placement: .topBarTrailing) { ThemeToggleButton() } }`).

**Behavior:**
- Binary state: `.light` ↔ `.dark`. Reads from `@AppStorage("sonicMergeThemePreference")`.
- Default value: `.light` (was `.system`).
- **Legacy-value tolerance:** if `@AppStorage` returns an unrecognized raw value (e.g. `"system"` from a pre-migration install), `ThemePreference(rawValue:)` returns `nil`; the button treats nil as `.light` for display purposes. The §10 migration will then write `"light"` back on next launch, normalizing storage.
- One tap flips state. Animates icon swap with `.symbolEffect(.bounce, value: themePreference)` for iOS 17+.
- Haptic: `.sensoryFeedback(.impact(weight: .light), trigger: themePreference)`.

**Icon mapping:**

| State | SF Symbol |
|---|---|
| `.light` (currently shown) | `sun.max.fill` |
| `.dark` (currently shown) | `moon.fill` |

The icon shown represents the **current state**, not the next state — matches Apple HIG's "show what you have" pattern (Voice Memos toggle, Maps appearance toggle).

**Accessibility:**
- `.accessibilityLabel("Theme: \(currentLabel)")`
- `.accessibilityHint("Tap to switch to \(otherLabel) theme")`

**Tint:** `accentAction` (indigo) in both states — the toggle is brand-level chrome, not AI.

## 8. Tab bar

Standard SwiftUI `TabView` (no custom shell). Three tabs in order: Smart Cut, Denoise, Merge. Selected tint applied via `.tint(Color(uiColor: semantic.accentAction))` at the `TabView` level in `RootTabView`.

| Tab | SF Symbol | Label |
|---|---|---|
| Smart Cut | `sparkles` | "Smart Cut" |
| Denoise | `waveform.badge.minus` | "Denoise" |
| Merge | `rectangle.stack` | "Merge" |

## 9. CleanCut rebrand — display-only scope

### 9.1 What changes

- `CFBundleDisplayName` in `SonicMerge/Info.plist` (and `SonicMergeShareExtension/Info.plist`): `"SonicMerge"` → `"CleanCut"`. This is what users see on the home screen and in Settings.
- `MixingStationView` navigation title `"SonicMerge"` → `"Merge"` (already covered in §4.2).
- Any user-visible string containing "SonicMerge" → "CleanCut". Audit list:
  - `MixingStationView.swift` line 47: `.navigationTitle("SonicMerge")` → already changing to `"Merge"`
  - Error messages, alerts, share sheets, About box — `grep -rn "SonicMerge" --include="*.swift"` and replace user-facing literals only
  - Export filenames: `"SonicMerge-DenoisedExport-…"` → `"CleanCut-Export-…"` (cosmetic; users see this on shared files)
- App icon retains its current artwork (visual rebrand outside this spec).

### 9.2 What does NOT change

- Bundle identifier: stays `com.dtech.SonicMerge` (rename later in dedicated spec — requires App Store Connect + provisioning + App Group migration)
- Xcode scheme name `SonicMerge`
- Module name `SonicMerge` (Swift target)
- Type names: `SonicMergeApp`, `SonicMergeTheme`, `SonicMergeSemantic`, `SonicMergeShareExtension`, etc.
- `@AppStorage` keys: `sonicMerge.hasImportedFirstClip`, `sonicMergeThemePreference` (key migration is risky; defer)
- `AppConstants.appGroupID`: `group.com.yourteam.SonicMerge` (App Group rename is a separate exercise — would invalidate existing user data)

This split lets the user-facing rebrand ship now while the internal rename happens later as a dedicated, riskier project.

## 10. Migration / backward compatibility

**Theme preference:** Existing installs may have `@AppStorage("sonicMergeThemePreference") = "system"`. On first launch after this change, the migration runs once.

The `@AppStorage` is declared at the `SonicMergeApp` struct scope (the `App` conformer), and the `.onAppear` hook is attached to the root view inside `WindowGroup { RootTabView() }`:

```swift
@main
struct SonicMergeApp: App {
    @AppStorage("sonicMergeThemePreference") private var themePreferenceRaw: String = ThemePreference.light.rawValue

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .onAppear {
                    if themePreferenceRaw == "system" {
                        themePreferenceRaw = ThemePreference.light.rawValue
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
```

One-line, idempotent, runs once per launch (cost negligible). `ThemeToggleButton`'s legacy-value tolerance (§7) means even if a user's `@AppStorage` still has `"system"` *between* launch and the `.onAppear` firing, the button renders sanely.

**App Group + SwiftData:** Untouched. All existing user sessions / clips / timelines remain accessible.

**Tests:** Existing 5 baseline failures (pre-existing on `main`) stay tolerated. No new regressions expected because we're not changing logic — only chrome.

## 11. Files to change

| File | Change | Approx. lines |
|---|---|---|
| `SonicMerge/DesignSystem/ThemeToggleButton.swift` | **NEW** — binary toggle component | ~60 |
| `SonicMerge/DesignSystem/SonicMergeTheme+Appearance.swift` | Remove `case system` from `ThemePreference` enum + `themeName` switch | ~5 |
| `SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift` | `.large` → `.inline`; pill button → `Button` w/ `waveform.badge.plus` SF Symbol; remove text label; add `ThemeToggleButton` to toolbar trailing; loaded-state pinned button | ~30 |
| `SonicMerge/Features/Denoising/Views/Home/DenoiseHomeView.swift` | Same as Smart Cut home | ~30 |
| `SonicMerge/Features/MixingStation/MixingStationView.swift` | Add `PremiumBackground`; `.large` → keep `.inline` but title `"SonicMerge"` → `"Merge"`; remove leading `+` toolbar item; replace trailing More-menu (theme picker) with `ThemeToggleButton`; keep Export; empty state → new hero pattern with `waveform.badge.plus` button; loaded-state pinned import button above timeline | ~80 |
| `SonicMerge/SonicMergeApp.swift` | Add one-shot ThemePreference migration (system → light) | ~3 |
| `SonicMerge/Info.plist` | `CFBundleDisplayName` → `CleanCut` | ~1 |
| `SonicMergeShareExtension/Info.plist` | `CFBundleDisplayName` → `CleanCut` | ~1 |
| Other user-facing strings | Audit + replace `SonicMerge` → `CleanCut` (export filenames, alerts) | ~5–10 |

**Total surface:** one new file (~60 lines) plus diffs across ~6 existing files, ~150–200 line changes total. All changes are scoped, no architectural shifts.

**Audit policy for §9.1 strings:** the implementation plan should run `grep -rn "SonicMerge" --include="*.swift"` as its first step in the rebrand task and triage hits into three buckets — (a) user-facing literal → rename to "CleanCut"; (b) internal symbol / type / `@AppStorage` key / module reference → leave alone per §9.2; (c) export-or-temp filename pattern → rename. The plan enumerates the actual hits at planning time so the implementer isn't interpreting matches one at a time during execution.

## 12. Test strategy

- **`ThemeToggleButton`:** unit-test the toggle state cycle (light → dark → light) and the legacy-value tolerance (`ThemePreference(rawValue: "system")` → `nil` → button renders as `.light`).
- **Migration test:** verify the `.onAppear` migration normalizes a stored `"system"` raw value to `"light"` exactly once.
- **No new view tests required** — the existing home views' tests don't exercise toolbar chrome; visual changes are manually verified.
- **Manual QA** (after build):
  - Cold launch → Smart Cut tab opens with new icon-only import button
  - Tap import button → file picker opens, picking a file pushes to session
  - Switch tabs — chrome looks identical across all three
  - Tap theme toggle in any tab → app switches Light ↔ Dark, icon swaps with bounce animation
  - Force-quit + relaunch → theme persists
  - Existing user: confirm session lists still load (no migration breakage)

## 13. Rollout

Single PR, single branch (`design/clean-cut-rebrand` or similar). No feature flag — these are atomic visual changes that should ship together. Manual QA on simulator before merge.

## 14. Open questions

None at design-approval time. If the implementation surfaces any (e.g., `symbolEffect.bounce` regression on iOS 17 simulator, App Store metadata rename timing), capture them as plan-level decisions during implementation.

## 15. References

- `docs/superpowers/specs/2026-04-28-smart-cut-main-screen-design.md` — three-tab shell that introduced the current state.
- Apple HIG — Tab Bars, Toolbars, Symbol Effects (iOS 17+).
- CapCut — naming pattern (verb + Cut); bottom-tab IA reference.
- Voice Memos / Notes / Files — single-icon toolbar minimalism reference.
- `.planning/PROJECT.md` — current product positioning context.
