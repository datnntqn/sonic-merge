---
phase: 9
slug: polish-accessibility-audit
status: ready
branch: phase-09-polish-accessibility
created: 2026-04-24
spec: 09-UI-SPEC.md
requirements: [POL-01, POL-02, POL-03]
---

# Phase 9 — Polish + Accessibility Audit Implementation Plan

> **For agentic workers:** REQUIRED: Use `superpowers:subagent-driven-development` (if subagents available) or `superpowers:executing-plans` to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the 3 open v1.1 requirements (POL-01 haptics, POL-02 dark mode, POL-03 a11y fallbacks) by migrating the last two legacy sheets to the semantic-token system, plugging four haptic gaps, guarding `reduceMotion` on two remaining animations, and updating four copywriting labels — so v1.1 ships with full-surface polish and WCAG-compliant fallbacks.

**Architecture:** Pure visual-layer edits. **No ViewModel or Service changes** — v1.1 is visual-only per `REQUIREMENTS.md` Out-of-Scope table. Every fix migrates existing code to established Phase 6 patterns:

- `@Environment(\.sonicMergeSemantic)` for color tokens (replaces `SonicMergeTheme.ColorPalette.*` direct UIColor access)
- `PillButtonStyle(variant:size:tint:)` for buttons (replaces raw `Button { }.background(...)`)
- `@Environment(\.accessibilityReduceMotion)` guard on any `.animation(...)` or `.transition(...)` modifier

Human verification on a physical device (iPhone 16 or similar, iOS 17+) is the **final gate** — no code change is considered complete until the 6-point device checklist (end of plan) is ticked.

**Tech Stack:** SwiftUI (iOS 17+), UIKit interop (`UIColor`), Swift Testing (`import Testing`), `sensoryFeedback(_:trigger:)` (iOS 17+), custom `SonicMergeSemantic` environment key, `PillButtonStyle` ButtonStyle.

**Reference skills:** @superpowers:test-driven-development (where behavioral changes exist — **none in this plan**, so regression-only), @superpowers:verification-before-completion (run build + tests + device checklist before claiming done), @superpowers:systematic-debugging (if any step fails).

---

## Pre-flight

- [ ] **P0: Verify working branch**

  Run: `git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge branch --show-current`
  Expected: `phase-09-polish-accessibility`

  If not on this branch, stop and re-create it from `main`: `git checkout -b phase-09-polish-accessibility main`

- [ ] **P1: Baseline build succeeds**

  Run:
  ```bash
  xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -configuration Debug \
    build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **` as the last line.

- [ ] **P2: Baseline test suite green (regression guard)**

  Run:
  ```bash
  xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    test 2>&1 | tail -20
  ```
  Expected: `Test Suite 'All tests' passed` (or equivalent). All existing Swift Testing targets (`CleaningLabViewModelTests`, `MixingStationViewModelTests`, `AudioMergerServiceTests`, `WetDryBlendTests`) must pass before Phase 9 edits begin. If they fail on `main`, investigate before touching any file.

> **Why no new unit tests in this plan?** Phase 9 changes **zero** ViewModel or Service code. Every edit is View-layer visual/haptic polish. Swift Testing + XCTest do not provide a maintained snapshot test story for this project (none exist today — grep `SonicMergeTests/` confirms), so introducing snapshot tests would itself be new scope. The regression guard (P2) + human device checklist (final chunk) is the agreed test strategy per UI-SPEC Scope Boundary.

---

## Chunk 1: Sheet Polish

Two sheets (`ExportProgressSheet`, `ExportFormatSheet`) were authored before the `SonicMergeSemantic` environment existed (Phase 6 DS-01). They still reference `SonicMergeTheme.ColorPalette.*` directly and use raw `Button { }.background(...)` instead of `PillButtonStyle`. This chunk migrates both to the Phase 6+ patterns.

### Task 1: ExportProgressSheet — semantic migration + haptic + copy

**Requirement coverage:** POL-01 (Cancel Export haptic), POL-02 (hardcoded colors → semantic), copy fix ("Cancel" → "Cancel Export").

**Why this first:** Smallest surface (42 lines total), no PillButton migration, establishes the semantic-injection pattern that Task 2 repeats.

**Files:**
- Modify: `SonicMerge/Features/MixingStation/ExportProgressSheet.swift` (full rewrite — 42 lines → ~48 lines)

- [ ] **Step 1: Read the file to confirm line numbers match this plan**

  Use the Read tool on `SonicMerge/Features/MixingStation/ExportProgressSheet.swift`.
  Expected landmarks:
  - Line 18: hardcoded `Color(red: 0.110, green: 0.110, blue: 0.118)`
  - Line 23: hardcoded `Color(red: 0, green: 0.478, blue: 1.0)` (iOS system blue — **wrong**, Phase 6 uses Deep Indigo `accentAction`)
  - Line 32: `Text("Cancel")` (must become `"Cancel Export"`)
  - No `@Environment(\.sonicMergeSemantic)` declaration

- [ ] **Step 2: Replace file contents**

  Write the following full file to `SonicMerge/Features/MixingStation/ExportProgressSheet.swift`:

  ```swift
  // ExportProgressSheet.swift
  // SonicMerge

  import SwiftUI

  /// Non-dismissible modal displayed during export.
  /// Shows a ProgressView, percentage text, and a Cancel button.
  /// `.interactiveDismissDisabled(true)` prevents swipe-to-dismiss.
  struct ExportProgressSheet: View {
      var isNormalizing: Bool = false
      let progress: Float
      let onCancel: () -> Void

      @Environment(\.sonicMergeSemantic) private var semantic
      @State private var cancelHapticTrigger = false

      var body: some View {
          VStack(spacing: 20) {
              Text(isNormalizing ? "Exporting & Normalizing..." : "Exporting...")
                  .font(.system(.headline))
                  .foregroundStyle(Color(uiColor: semantic.textPrimary))
                  .padding(.top, 28)

              ProgressView(value: Double(progress))
                  .progressViewStyle(.linear)
                  .tint(Color(uiColor: semantic.accentAction))
                  .padding(.horizontal, 32)

              Text("\(Int(progress * 100))%")
                  .font(.system(.caption))
                  .foregroundStyle(Color(uiColor: semantic.textSecondary))
                  .monospacedDigit()

              Button(role: .destructive) {
                  cancelHapticTrigger.toggle()
                  onCancel()
              } label: {
                  Text("Cancel Export")
                      .font(.system(.body))
              }
              .padding(.bottom, 32)
              .sensoryFeedback(.impact(weight: .medium), trigger: cancelHapticTrigger)
          }
          .frame(maxWidth: .infinity)
          .presentationDetents([.height(220)])
          .interactiveDismissDisabled(true)
      }
  }
  ```

  Key changes from the current file:
  1. **Line 18 → semantic.textPrimary** (was hardcoded `#1C1C1E`-ish RGB)
  2. **Line 23 → semantic.accentAction** (was hardcoded iOS blue — Deep Indigo is the correct v1.1 accent)
  3. **Line 28 `.secondary` → `semantic.textSecondary`** (consistency — `.secondary` is a system semantic that does not respect ThemePreference override)
  4. **Line 31-34 → `.sensoryFeedback(.impact(weight: .medium), trigger: cancelHapticTrigger)`** new; trigger toggles on tap (POL-01)
  5. **Line 32 "Cancel" → "Cancel Export"** (UI-SPEC copy contract)
  6. **New `@Environment(\.sonicMergeSemantic)` declaration** at struct-property scope

- [ ] **Step 3: Verify build**

  Run:
  ```bash
  xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -configuration Debug \
    build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`.

  If the build fails with "environment not injected": confirm the sheet is presented from a view that applies `.environment(\.sonicMergeSemantic, semantic)` — **both** call sites already do this (`MixingStationView.swift:97` on the root `NavigationStack`, and `CleaningLabView` inherits via modal presentation). The `fallbackLight` default prevents runtime crash if the env is ever missing.

- [ ] **Step 4: Run regression test suite**

  Run:
  ```bash
  xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    test 2>&1 | tail -10
  ```
  Expected: All existing tests still pass. No ViewModel code was touched; any test failure is a regression bug — use @superpowers:systematic-debugging.

- [ ] **Step 5: Commit**

  ```bash
  git add SonicMerge/Features/MixingStation/ExportProgressSheet.swift
  git commit -m "$(cat <<'EOF'
  fix(09): migrate ExportProgressSheet to semantic tokens + Cancel Export haptic

  Replaces hardcoded RGB (iOS system blue, near-black) with semantic.accentAction
  and semantic.textPrimary so the sheet respects dark mode and ThemePreference
  override. Adds .impact(weight: .medium) haptic on Cancel Export tap per POL-01.
  Renames "Cancel" label to "Cancel Export" per UI-SPEC copy contract.

  Covers: POL-01 (partial — 1 of 4 haptic gaps), POL-02 (partial — 1 of 2 sheets).

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

### Task 2: ExportFormatSheet — semantic migration + PillButtonStyle + copy

**Requirement coverage:** POL-01 (Export Audio haptic — inherited via PillButtonStyle), POL-02 (hardcoded colors → semantic), copy fix ("Export" → "Export Audio").

**Files:**
- Modify: `SonicMerge/Features/MixingStation/ExportFormatSheet.swift` (full rewrite — 77 lines → ~73 lines)

- [ ] **Step 1: Read the file to confirm line numbers match this plan**

  Use the Read tool on `SonicMerge/Features/MixingStation/ExportFormatSheet.swift`.
  Expected landmarks:
  - Line 27: `ColorPalette.primaryText` direct access
  - Line 48: `ColorPalette.primaryText` direct access
  - Line 56: `.tint(Color(uiColor: SonicMergeTheme.ColorPalette.primaryAccent))`
  - Lines 60-71: raw `Button` with `.background(Color(uiColor: ...primaryAccent))` — **must** become `PillButtonStyle(variant: .filled, size: .regular)`
  - Line 64: `Text("Export")` (must become `"Export Audio"`)

- [ ] **Step 2: Replace file contents**

  Write the following full file to `SonicMerge/Features/MixingStation/ExportFormatSheet.swift`:

  ```swift
  // ExportFormatSheet.swift
  // SonicMerge

  import SwiftUI
  import UIKit

  /// Carries export configuration from ExportFormatSheet to the export callback.
  /// Introduced in Phase 4 to add the LUFS normalization flag alongside format.
  struct ExportOptions: Sendable {
      let format: ExportFormat
      let lufsNormalize: Bool
  }

  /// Bottom sheet presented when user taps Export.
  /// User selects .m4a or .wav, then taps the Export button to begin.
  struct ExportFormatSheet: View {
      @Binding var isPresented: Bool
      let onExport: (ExportOptions) -> Void

      @State private var selectedFormat: ExportFormat = .m4a
      @AppStorage("lufsNormalizationEnabled") private var lufsEnabled: Bool = false

      @Environment(\.sonicMergeSemantic) private var semantic

      var body: some View {
          VStack(spacing: 24) {
              Text("Export Format")
                  .font(.system(.headline))
                  .foregroundStyle(Color(uiColor: semantic.textPrimary))
                  .padding(.top, 20)

              Text("Files are rendered locally on your device.")
                  .font(.caption)
                  .foregroundStyle(Color(uiColor: semantic.textSecondary))
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.horizontal, 24)

              Picker("Format", selection: $selectedFormat) {
                  Text(".m4a (AAC)").tag(ExportFormat.m4a)
                  Text(".wav (Lossless)").tag(ExportFormat.wav)
              }
              .pickerStyle(.segmented)
              .padding(.horizontal, 24)

              // LUFS normalization toggle row
              HStack {
                  VStack(alignment: .leading, spacing: 4) {
                      Text("Normalize to -16 LUFS")
                          .font(.system(.body))
                          .foregroundStyle(Color(uiColor: semantic.textPrimary))
                      Text("Podcast standard (-16 LUFS)")
                          .font(.system(.caption))
                          .foregroundStyle(Color(uiColor: semantic.textSecondary))
                  }
                  Spacer()
                  Toggle("", isOn: $lufsEnabled)
                      .labelsHidden()
                      .tint(Color(uiColor: semantic.accentAction))
              }
              .padding(.horizontal, 24)

              Button("Export Audio") {
                  isPresented = false
                  onExport(ExportOptions(format: selectedFormat, lufsNormalize: lufsEnabled))
              }
              .buttonStyle(PillButtonStyle(variant: .filled, size: .regular))
              .padding(.horizontal, 24)
              .padding(.bottom, 32)
          }
          .presentationDetents([.height(320)])
      }
  }
  ```

  Key changes from the current file:
  1. **Line 27 `primaryText` → `semantic.textPrimary`** (POL-02)
  2. **Line 32 `.secondary` → `semantic.textSecondary`**
  3. **Line 48 `primaryText` → `semantic.textPrimary`**
  4. **Line 51 `.secondary` → `semantic.textSecondary`**
  5. **Line 56 `primaryAccent` → `semantic.accentAction`** (Toggle tint)
  6. **Lines 60-71 raw Button → `PillButtonStyle(variant: .filled, size: .regular)`** — removes hardcoded white-on-indigo background + RoundedRectangle clip; PillButtonStyle already provides `.sensoryFeedback(.impact(weight: .light), trigger: isPressed)` internally (satisfies POL-01 for this button)
  7. **Line 64 "Export" → "Export Audio"** (UI-SPEC copy contract)
  8. **New `@Environment(\.sonicMergeSemantic)` declaration**

- [ ] **Step 3: Verify build**

  Run:
  ```bash
  xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -configuration Debug \
    build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run regression test suite**

  Run the test command from Task 1 Step 4.
  Expected: All tests pass.

- [ ] **Step 5: Commit**

  ```bash
  git add SonicMerge/Features/MixingStation/ExportFormatSheet.swift
  git commit -m "$(cat <<'EOF'
  fix(09): migrate ExportFormatSheet to semantic tokens + PillButtonStyle

  Replaces direct SonicMergeTheme.ColorPalette.* access with
  @Environment(\.sonicMergeSemantic) tokens. Converts the raw "Export" Button
  to PillButtonStyle(variant: .filled, size: .regular) — inherits the built-in
  .impact(.light) haptic, gains the inner-glow + press-scale affordances, and
  unifies styling with Phase 6/7 button surfaces. Renames label to "Export
  Audio" per UI-SPEC copy contract.

  Covers: POL-01 (2 of 4 haptic gaps), POL-02 (2 of 2 sheets complete).

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Chunk 2: MixingStationView Polish

Two remediation targets in `MixingStationView.swift`: the empty-state "Import Audio" button (still a raw styled `Button`), and the four toolbar icons (no haptic — iOS toolbar buttons don't get system haptics on tap, the product designer explicitly wants light impact feedback).

### Task 3: Empty-state Import button → PillButtonStyle

**Requirement coverage:** POL-01 (empty-state Import haptic — inherited via PillButtonStyle).

**Files:**
- Modify: `SonicMerge/Features/MixingStation/MixingStationView.swift` — lines 111-132 (emptyState computed property)

- [ ] **Step 1: Read the emptyState subview (MixingStationView.swift:111-132)**

  Confirm current shape: `VStack` with `Image(systemName: "waveform")`, two `Text` lines, and a `Button { ... } label: { Label("Import Audio", systemImage: "plus.circle.fill")... }`. The Label has `.foregroundStyle(semantic.surfaceBase)`, `.background(semantic.accentAction)`, `.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))`.

- [ ] **Step 2: Replace the `emptyState` computed property**

  Use Edit to replace **only** the `emptyState` property body. Old string:

  ```swift
      private var emptyState: some View {
          VStack(spacing: 16) {
              Image(systemName: "waveform")
                  .font(.system(size: 48))
                  .foregroundStyle(Color(uiColor: semantic.accentAction))
              Text("No clips yet")
                  .font(.system(.title3, design: .rounded, weight: .semibold))
                  .foregroundStyle(Color(uiColor: semantic.textPrimary))
              Text("Tap Import to add audio files")
                  .font(.system(.body, design: .rounded))
                  .foregroundStyle(Color(uiColor: semantic.textSecondary))
              Button(action: { showDocumentPicker = true }) {
                  Label("Import Audio", systemImage: "plus.circle.fill")
                      .font(.system(.body, design: .rounded, weight: .semibold))
                      .foregroundStyle(Color(uiColor: semantic.surfaceBase))
                      .padding(.horizontal, 24)
                      .padding(.vertical, 12)
                      .background(Color(uiColor: semantic.accentAction))
                      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
              }
          }
      }
  ```

  New string:

  ```swift
      private var emptyState: some View {
          VStack(spacing: 16) {
              Image(systemName: "waveform")
                  .font(.system(size: 48))
                  .foregroundStyle(Color(uiColor: semantic.accentAction))
              Text("No clips yet")
                  .font(.system(.title3, design: .rounded, weight: .semibold))
                  .foregroundStyle(Color(uiColor: semantic.textPrimary))
              Text("Tap Import to add audio files")
                  .font(.system(.body, design: .rounded))
                  .foregroundStyle(Color(uiColor: semantic.textSecondary))
              Button {
                  showDocumentPicker = true
              } label: {
                  Label("Import Audio", systemImage: "plus.circle.fill")
              }
              .buttonStyle(PillButtonStyle(variant: .filled, size: .regular))
          }
      }
  ```

  Why we lose the explicit font/padding/background: `PillButtonStyle` applies `.subheadline` + `.semibold`, 24/12pt padding, Capsule clip, Deep Indigo fill, white label, inner glow, press-scale animation, and `.impact(.light)` haptic. The Label's `systemImage` renders as an icon prefix automatically inside a Capsule — matches the design in Phase 6+. No `.rounded` font design on pill CTAs in Phase 6 pattern (see `PillButtonStyle.makeBody`).

- [ ] **Step 3: Verify build**

  Run:
  ```bash
  xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -configuration Debug \
    build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run regression test suite**

  Expected: all pass.

- [ ] **Step 5: Commit**

  ```bash
  git add SonicMerge/Features/MixingStation/MixingStationView.swift
  git commit -m "$(cat <<'EOF'
  fix(09): migrate empty-state Import button to PillButtonStyle

  Replaces raw Button with hardcoded background + RoundedRectangle clip
  with PillButtonStyle(variant: .filled, size: .regular). Inherits the
  built-in .impact(.light) haptic and unifies the empty-state CTA with
  Phase 6/7 button surfaces.

  Covers: POL-01 (3 of 4 haptic gaps).

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

### Task 4: Toolbar buttons — light impact haptics

**Requirement coverage:** POL-01 (toolbar haptics — the last remaining gap per UI-SPEC).

**Why `sensoryFeedback` and not PillButton:** Toolbar items must remain system `Label` icons for iOS toolbar visual language. `PillButtonStyle` enforces 44×44 frames + Capsule clip, which breaks toolbar layout. Native `ToolbarItem` with an added `.sensoryFeedback(_:trigger:)` modifier is the right solution.

**Why toggling `@State Bool` triggers instead of direct call-site toggles:** `.sensoryFeedback(_:trigger:)` fires when `trigger` changes. We need one @State Bool per button so that the feedback does not cross-fire when unrelated state updates (e.g. `showExportSheet` toggles the export haptic even if the user tapped Denoise).

**Files:**
- Modify: `SonicMerge/Features/MixingStation/MixingStationView.swift` — add 4 @State properties + modify `toolbarContent`

- [ ] **Step 1: Add four haptic trigger @State properties**

  Use Edit on `SonicMerge/Features/MixingStation/MixingStationView.swift`. Old string:

  ```swift
      @State private var showDocumentPicker = false
      @State private var showExportSheet = false
      @State private var showCleaningLab = false
      @State private var mergedFileURLForCleaning: URL?
  ```

  New string:

  ```swift
      @State private var showDocumentPicker = false
      @State private var showExportSheet = false
      @State private var showCleaningLab = false
      @State private var mergedFileURLForCleaning: URL?

      // POL-01: one trigger @State per toolbar button — prevents cross-firing
      @State private var importHaptic = false
      @State private var appearanceHaptic = false
      @State private var exportHaptic = false
      @State private var denoiseHaptic = false
  ```

- [ ] **Step 2: Update `toolbarContent` to toggle the triggers and attach `.sensoryFeedback`**

  Use Edit on `SonicMerge/Features/MixingStation/MixingStationView.swift`. Old string:

  ```swift
      @ToolbarContentBuilder
      private var toolbarContent: some ToolbarContent {
          ToolbarItem(placement: .topBarLeading) {
              Button(action: { showDocumentPicker = true }) {
                  Label("Import", systemImage: "plus")
              }
              .disabled(viewModel.isImporting || viewModel.isExporting)
          }
          ToolbarItem(placement: .topBarTrailing) {
              Menu {
                  Picker("Appearance", selection: $themePreferenceRaw) {
                      Text("System").tag(ThemePreference.system.rawValue)
                      Text("Light").tag(ThemePreference.light.rawValue)
                      Text("Dark conveyor").tag(ThemePreference.dark.rawValue)
                  }
              } label: {
                  Label("Appearance", systemImage: "paintpalette")
              }
          }
          ToolbarItem(placement: .topBarTrailing) {
              Button(action: { showExportSheet = true }) {
                  Label("Export", systemImage: "square.and.arrow.up")
              }
              .disabled(viewModel.clips.isEmpty || viewModel.isExporting)
          }
          ToolbarItem(placement: .topBarTrailing) {
              Button {
                  navigateToCleaningLab()
              } label: {
                  Label("Denoise", systemImage: "wand.and.sparkles")
              }
              .disabled(viewModel.clips.isEmpty)
          }
      }
  ```

  New string:

  ```swift
      @ToolbarContentBuilder
      private var toolbarContent: some ToolbarContent {
          ToolbarItem(placement: .topBarLeading) {
              Button {
                  importHaptic.toggle()
                  showDocumentPicker = true
              } label: {
                  Label("Import", systemImage: "plus")
              }
              .disabled(viewModel.isImporting || viewModel.isExporting)
              .sensoryFeedback(.impact(weight: .light), trigger: importHaptic)
          }
          ToolbarItem(placement: .topBarTrailing) {
              Menu {
                  Picker("Appearance", selection: $themePreferenceRaw) {
                      Text("System").tag(ThemePreference.system.rawValue)
                      Text("Light").tag(ThemePreference.light.rawValue)
                      Text("Dark conveyor").tag(ThemePreference.dark.rawValue)
                  }
              } label: {
                  Label("Appearance", systemImage: "paintpalette")
              }
              .sensoryFeedback(.impact(weight: .light), trigger: themePreferenceRaw)
          }
          ToolbarItem(placement: .topBarTrailing) {
              Button {
                  exportHaptic.toggle()
                  showExportSheet = true
              } label: {
                  Label("Export", systemImage: "square.and.arrow.up")
              }
              .disabled(viewModel.clips.isEmpty || viewModel.isExporting)
              .sensoryFeedback(.impact(weight: .light), trigger: exportHaptic)
          }
          ToolbarItem(placement: .topBarTrailing) {
              Button {
                  denoiseHaptic.toggle()
                  navigateToCleaningLab()
              } label: {
                  Label("Denoise", systemImage: "wand.and.sparkles")
              }
              .disabled(viewModel.clips.isEmpty)
              .sensoryFeedback(.impact(weight: .light), trigger: denoiseHaptic)
          }
      }
  ```

  Design note on the Appearance Menu: Menus don't receive a simple tap — the haptic fires on **selection change** inside the picker (`themePreferenceRaw` changes), which is the user-perceived action. That's the correct semantic.

- [ ] **Step 3: Verify build**

  Run:
  ```bash
  xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -configuration Debug \
    build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run regression test suite**

  Expected: all pass.

- [ ] **Step 5: Commit**

  ```bash
  git add SonicMerge/Features/MixingStation/MixingStationView.swift
  git commit -m "$(cat <<'EOF'
  feat(09): add light-impact haptics to MixingStationView toolbar buttons

  Attaches .sensoryFeedback(.impact(weight: .light), trigger:) to each of
  the four toolbar items (Import, Appearance, Export, Denoise). One @State
  Bool per button prevents cross-firing between unrelated state updates.
  Appearance menu fires on themePreferenceRaw selection change.

  Covers: POL-01 (4 of 4 haptic gaps — complete).

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Chunk 3: CleaningLab + AI Orb Accessibility Polish

### Task 5: CleaningLabView — error alert copy + staleBanner reduceMotion guard

**Requirement coverage:** POL-03 (reduceMotion on staleBanner transition), copy fix ("OK" → "Got It"), copy fix ("Re-process" → "Re-process Audio").

**Files:**
- Modify: `SonicMerge/Features/Denoising/CleaningLabView.swift` — line 134 (alert button), lines 166-193 (staleBanner), line 184 (Re-process label)

- [ ] **Step 1: Update error alert button label "OK" → "Got It"**

  Use Edit on `SonicMerge/Features/Denoising/CleaningLabView.swift`. Old string:

  ```swift
          .alert("Denoising Failed", isPresented: errorAlertBinding) {
              Button("OK") {}
          } message: {
              Text(viewModel.errorMessage ?? "")
          }
  ```

  New string:

  ```swift
          .alert("Denoising Failed", isPresented: errorAlertBinding) {
              Button("Got It") {}
          } message: {
              Text(viewModel.errorMessage ?? "")
          }
  ```

- [ ] **Step 2: Add reduceMotion environment declaration**

  Use Edit. Look for the environment declarations near the top of the struct. Search for `@Environment(\.colorScheme)` — add the reduceMotion declaration next to it.

  **Confirm location first:** Read `SonicMerge/Features/Denoising/CleaningLabView.swift` lines 1-60 and identify the existing `@Environment` declarations in `CleaningLabView`. Then add:

  ```swift
      @Environment(\.accessibilityReduceMotion) private var reduceMotion
  ```

  immediately below the last existing `@Environment(...)` line inside the `CleaningLabView` struct.

- [ ] **Step 3: Update the staleBanner Re-process label and gate `.transition`**

  Old string:

  ```swift
      /// Stale result banner — shown when clips have changed after denoising
      private var staleBanner: some View {
          SquircleCard(glassEnabled: false, glowEnabled: false) {
              HStack(spacing: SonicMergeTheme.Spacing.sm) {
                  Image(systemName: "exclamationmark.triangle.fill")
                      .foregroundStyle(Color.orange)

                  VStack(alignment: .leading, spacing: 2) {
                      Text("Clips have changed.")
                          .font(.subheadline)
                          .fontWeight(.semibold)
                          .foregroundStyle(Color(uiColor: semantic.textPrimary))
                      Text("Re-process to update the denoised audio.")
                          .font(.caption)
                          .foregroundStyle(Color(uiColor: semantic.textSecondary))
                  }

                  Spacer()

                  Button("Re-process") {
                      viewModel.startDenoising(mergedFileURL: mergedFileURL)
                  }
                  .buttonStyle(PillButtonStyle(variant: .filled, size: .compact, tint: .ai))
              }
          }
          .transition(.opacity)
          .accessibilityElement(children: .combine)
          .accessibilityLabel("Stale result warning. Clips have changed. Re-process to update the denoised audio.")
      }
  ```

  New string:

  ```swift
      /// Stale result banner — shown when clips have changed after denoising
      private var staleBanner: some View {
          SquircleCard(glassEnabled: false, glowEnabled: false) {
              HStack(spacing: SonicMergeTheme.Spacing.sm) {
                  Image(systemName: "exclamationmark.triangle.fill")
                      .foregroundStyle(Color.orange)

                  VStack(alignment: .leading, spacing: 2) {
                      Text("Clips have changed.")
                          .font(.subheadline)
                          .fontWeight(.semibold)
                          .foregroundStyle(Color(uiColor: semantic.textPrimary))
                      Text("Re-process to update the denoised audio.")
                          .font(.caption)
                          .foregroundStyle(Color(uiColor: semantic.textSecondary))
                  }

                  Spacer()

                  Button("Re-process Audio") {
                      viewModel.startDenoising(mergedFileURL: mergedFileURL)
                  }
                  .buttonStyle(PillButtonStyle(variant: .filled, size: .compact, tint: .ai))
              }
          }
          .transition(reduceMotion ? .identity : .opacity)
          .accessibilityElement(children: .combine)
          .accessibilityLabel("Stale result warning. Clips have changed. Re-process to update the denoised audio.")
      }
  ```

  Two changes:
  1. `Button("Re-process")` → `Button("Re-process Audio")` (copy contract)
  2. `.transition(.opacity)` → `.transition(reduceMotion ? .identity : .opacity)` — when reduceMotion is on, banner appears/disappears without the fade animation.

- [ ] **Step 4: Verify build**

  Run:
  ```bash
  xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -configuration Debug \
    build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Run regression test suite**

  Expected: all pass. `CleaningLabViewModelTests` does not assert on alert button labels or transition modifiers, so no test updates needed.

- [ ] **Step 6: Commit**

  ```bash
  git add SonicMerge/Features/Denoising/CleaningLabView.swift
  git commit -m "$(cat <<'EOF'
  fix(09): copy + reduceMotion guard on CleaningLabView

  - Error alert dismiss label: "OK" → "Got It" (UI-SPEC copy contract)
  - Stale banner CTA: "Re-process" → "Re-process Audio" (UI-SPEC copy contract)
  - Stale banner transition: `.opacity` → `.identity` when reduceMotion=true (POL-03)

  Covers: POL-03 (1 of 2 reduceMotion audit targets).

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

### Task 6: AIOrbView — progress ring reduceMotion guard

**Requirement coverage:** POL-03 (reduceMotion on AI Orb progress ring `.easeOut` animation).

**Files:**
- Modify: `SonicMerge/Features/Denoising/AIOrbView.swift` — line 195 (progress ring `.animation`)

The file already declares `@Environment(\.accessibilityReduceMotion) private var reduceMotion` (line 28 — used for the `shouldPause` computed property on line 48). We reuse it.

- [ ] **Step 1: Read AIOrbView.swift lines 180-210 to confirm context**

  Confirm:
  - Line 195: `.animation(.easeOut(duration: 0.25), value: viewModel.progress)`
  - The outer block is the `Circle().trim(from: 0, to: CGFloat(viewModel.progress))` progress ring (lines 186-197), rendered when `viewModel.isProcessing` is true.
  - Line 28 declares `reduceMotion` — already in scope.

- [ ] **Step 2: Gate the `.easeOut` animation on reduceMotion**

  Use Edit. Old string:

  ```swift
                          .animation(.easeOut(duration: 0.25), value: viewModel.progress)
  ```

  New string:

  ```swift
                          .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: viewModel.progress)
  ```

  Rationale: `reduceMotion ? nil : ...` is the pattern used elsewhere in the codebase (`PillButtonStyle.swift:61`, `MergeSlotRow` spring animation) — consistent. When `reduceMotion` is true, `progress` updates snap immediately without the 0.25s ease.

- [ ] **Step 3: Verify build**

  Run:
  ```bash
  xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -configuration Debug \
    build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run regression test suite**

  Expected: all pass.

- [ ] **Step 5: Commit**

  ```bash
  git add SonicMerge/Features/Denoising/AIOrbView.swift
  git commit -m "$(cat <<'EOF'
  fix(09): gate AI Orb progress ring animation on reduceMotion (POL-03)

  Wraps the progress-ring .easeOut(0.25) animation in
  `reduceMotion ? nil : .easeOut(...)` so the ring snaps to progress
  values without easing when the user has Reduce Motion enabled.
  Matches the pattern already used in PillButtonStyle.swift:61.

  Covers: POL-03 (2 of 2 reduceMotion audit targets — complete).

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Chunk 4: Verification + Documentation

All code changes are complete after Task 6. This chunk is the human device pass plus doc updates — no code edits.

### Task 7: Contrast audit + device verification checklist

**Requirement coverage:** POL-02 (dark mode completeness), POL-03 (contrast 4.5:1 + reduceTransparency + reduceMotion device verification).

**Pre-requisites:**
- iPhone 16 simulator running (or physical iPhone on iOS 17+). The simulator will have Accessibility Inspector available; physical device requires Settings › Accessibility toggles.

- [ ] **Step 1: Launch app on simulator in dark mode**

  Run:
  ```bash
  xcrun simctl boot "iPhone 16" 2>&1 || true
  open -a Simulator
  xcodebuild -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Debug build install 2>&1 | tail -5
  xcrun simctl launch booted com.datnnt.SonicMerge 2>&1 || echo "Launch via simulator UI if bundle ID differs"
  ```

  In the simulator, set **Features → Toggle Appearance** to Dark.

- [ ] **Step 2: Dark-mode completeness sweep (POL-02)**

  For each screen/component below, confirm background is pure black `#000000`, text is light `~#F5F5F5`, accent is Deep Indigo `#5856D6`, AI accent is Lime Green `#A7C957`:

  - [ ] **MixingStationView empty state** — pure black bg, Deep Indigo waveform icon, Deep Indigo Import Audio pill
  - [ ] **MixingStationView timeline (with 2+ clips)** — black bg, `#0F0F0F` clip cards, spine visible
  - [ ] **ExportFormatSheet** — sheet respects dark mode, Deep Indigo toggle tint, Deep Indigo Export Audio pill with white label
  - [ ] **ExportProgressSheet** — sheet respects dark mode, Deep Indigo ProgressView tint (was iOS blue — the key regression to confirm gone), Cancel Export in destructive red
  - [ ] **CleaningLabView** — black bg, AI Orb nebula visible, Lime Green slider + ring, stale banner readable
  - [ ] **AIOrbView** — nebula blobs, Lime Green progress ring animates smoothly

- [ ] **Step 3: Haptics sweep (POL-01) — physical device preferred**

  Simulator does not reproduce haptics. If a physical device is unavailable, skip this step and flag in `HUMAN-VERIFY.md` (see Step 6). On physical device:

  - [ ] Import toolbar button → **light** impact
  - [ ] Appearance menu selection change → **light** impact
  - [ ] Export toolbar button → **light** impact
  - [ ] Denoise toolbar button → **light** impact
  - [ ] Empty-state Import Audio pill → **light** impact (PillButtonStyle default)
  - [ ] ExportFormatSheet Export Audio pill → **light** impact (PillButtonStyle default)
  - [ ] ExportProgressSheet Cancel Export button → **medium** impact (explicit)

- [ ] **Step 4: reduceMotion sweep (POL-03)**

  In simulator, enable **Settings → Accessibility → Motion → Reduce Motion**. Then:

  - [ ] AI Orb nebula freezes at t=0 composition (already Phase 8 behavior — regression check)
  - [ ] PillButton press no longer scales (already Phase 6 behavior — regression check)
  - [ ] MergeSlotRow drag no longer scale-animates (already Phase 7 behavior — regression check)
  - [ ] **NEW:** AI Orb progress ring during denoising: the ring fills in sharp jumps (no 0.25s ease) as `viewModel.progress` updates. Easiest to observe by kicking off a denoise on a ~10-second clip.
  - [ ] **NEW:** Stale banner: after denoising a clip, reorder or delete a clip in MixingStation and return to CleaningLab — the banner appears/disappears instantly, no fade.

- [ ] **Step 5: reduceTransparency sweep (POL-03)**

  Enable **Settings → Accessibility → Display & Text Size → Reduce Transparency**. Then:

  - [ ] `SquircleCard(glassEnabled: true)` surfaces render solid `surfaceCard` (no material blur) — already Phase 6 behavior
  - [ ] `LocalFirstTrustStrip` header renders solid — already Phase 6 behavior
  - [ ] AI Orb bloom circle radius drops to 8pt — already Phase 8 behavior

  These are regression checks only — Phase 9 does not add new reduceTransparency cases.

- [ ] **Step 6: Contrast audit (POL-03)**

  Use the Accessibility Inspector (Xcode → Open Developer Tool → Accessibility Inspector → Audit tab → Run Audit) on both light and dark modes. Alternatively, use [WebAIM contrast checker](https://webaim.org/resources/contrastchecker/) with the hex values from UI-SPEC Color section.

  - [ ] `textPrimary` on `surfaceBase` in light mode → ≥4.5:1 (UI-SPEC predicts ~19:1 PASS)
  - [ ] `textPrimary` on `surfaceBase` in dark mode → ≥4.5:1 (UI-SPEC predicts ~20:1 PASS)
  - [ ] `textSecondary` on `surfaceBase` in both modes → verify ≥4.5:1 (UI-SPEC flags BORDERLINE ~4.6-4.7:1)
  - [ ] **Known accepted risk:** PillButton white label on Deep Indigo `#5856D6` — **3.2:1 FAIL**. This is a pre-existing Phase 6 DS-03 design decision. Do **not** change in Phase 9. Record in `HUMAN-VERIFY.md` (Step 7) as "known accepted risk deferred to product decision".
  - [ ] PillButton dark label `#1C1C1E` on Lime Green `#A7C957` → UI-SPEC predicts 7.38:1 PASS (AAA)

- [ ] **Step 7: Write HUMAN-VERIFY.md**

  Create `.planning/phases/09-polish-accessibility-audit/HUMAN-VERIFY.md` mirroring the Phase 8 format (see `.planning/phases/08-cleaning-lab-ai-orb/HUMAN-VERIFY.md` if present, else use this template):

  ```markdown
  # Phase 9 — Human Verification

  **Verified by:** [your name]
  **Date:** [YYYY-MM-DD]
  **Device:** [iPhone 16 Simulator / iPhone 15 Pro physical / etc.]
  **iOS version:** [e.g. 17.5]

  ## POL-01 — Haptics
  - [ ] Import toolbar light impact (physical device only — simulator cannot reproduce)
  - [ ] Appearance menu selection light impact
  - [ ] Export toolbar light impact
  - [ ] Denoise toolbar light impact
  - [ ] Empty-state Import Audio pill light impact
  - [ ] ExportFormatSheet Export Audio pill light impact
  - [ ] ExportProgressSheet Cancel Export medium impact

  ## POL-02 — Dark Mode Completeness
  - [ ] MixingStationView empty state (black bg, Deep Indigo button)
  - [ ] MixingStationView timeline (black bg, #0F0F0F cards)
  - [ ] ExportFormatSheet (Deep Indigo tint, not iOS blue)
  - [ ] ExportProgressSheet (Deep Indigo ProgressView tint — the key regression)
  - [ ] CleaningLabView (full dark mode)
  - [ ] AIOrbView (nebula + Lime Green ring)

  ## POL-03 — Accessibility Fallbacks
  ### reduceMotion
  - [ ] AI Orb nebula freezes at t=0 (regression)
  - [ ] PillButton no press scale (regression)
  - [ ] MergeSlotRow no drag scale (regression)
  - [ ] AI Orb progress ring snaps without ease (NEW)
  - [ ] Stale banner appears/disappears instantly, no fade (NEW)

  ### reduceTransparency
  - [ ] SquircleCard solid (regression)
  - [ ] Trust strip solid (regression)
  - [ ] AI Orb bloom 8pt radius (regression)

  ### Contrast (WebAIM or Accessibility Inspector)
  - [ ] textPrimary/surfaceBase light: ≥4.5:1
  - [ ] textPrimary/surfaceBase dark: ≥4.5:1
  - [ ] textSecondary/surfaceBase light: ≥4.5:1 (recorded actual: ___:1)
  - [ ] textSecondary/surfaceBase dark: ≥4.5:1 (recorded actual: ___:1)
  - [ ] PillButton white on Deep Indigo: 3.2:1 FAIL — **known accepted risk**, deferred per Phase 6 DS-03
  - [ ] PillButton dark on Lime Green: 7.38:1 PASS (AAA)

  ## Issues Found
  [List any issues discovered during verification. If none, write "None."]

  ## Sign-off
  All Phase 9 acceptance criteria verified on device: [ ]
  ```

- [ ] **Step 8: Commit HUMAN-VERIFY.md + mark requirements complete in REQUIREMENTS.md**

  Edit `.planning/REQUIREMENTS.md`:
  - Line 69-71: change `- [ ] **POL-01**` / `**POL-02**` / `**POL-03**` to `- [x]`
  - Traceability table (lines 145-147): change `Pending` to `Complete` for POL-01/02/03

  Then commit:
  ```bash
  git add .planning/phases/09-polish-accessibility-audit/HUMAN-VERIFY.md .planning/REQUIREMENTS.md
  git commit -m "$(cat <<'EOF'
  docs(09): record Phase 9 device verification + close POL-01/02/03

  All v1.1 polish + accessibility requirements verified on device.
  Known accepted risk recorded: PillButton white-on-Deep-Indigo 3.2:1
  contrast deferred per Phase 6 DS-03 design decision.

  Covers: POL-01, POL-02, POL-03 — Phase 9 complete.

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Final: UI-SPEC sign-off

- [ ] **F1: Update 09-UI-SPEC.md checker sign-off**

  Edit `.planning/phases/09-polish-accessibility-audit/09-UI-SPEC.md` lines 266-273:
  - Tick all 6 Dimension checkboxes
  - Change `**Approval:** pending` to `**Approval:** approved — [YYYY-MM-DD]`

  Commit:
  ```bash
  git add .planning/phases/09-polish-accessibility-audit/09-UI-SPEC.md
  git commit -m "$(cat <<'EOF'
  docs(09): sign off Phase 9 UI-SPEC — all dimensions PASS

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

- [ ] **F2: Push branch + open PR**

  ```bash
  git push -u origin phase-09-polish-accessibility
  gh pr create --title "Phase 9: Polish + accessibility audit (POL-01/02/03)" --body "$(cat <<'EOF'
  ## Summary
  - POL-01: 4 new haptic attachments (toolbar × 4) + 1 explicit medium-impact (Cancel Export); 2 auto-inherit via PillButtonStyle migration
  - POL-02: ExportFormatSheet + ExportProgressSheet migrated to SonicMergeSemantic tokens — Deep Indigo replaces iOS system blue in ExportProgress ProgressView
  - POL-03: reduceMotion guards added to AI Orb progress ring + CleaningLab stale banner; contrast audit logged; known accepted risk (PillButton white on Deep Indigo 3.2:1) recorded
  - Copy: "Export" → "Export Audio", "Cancel" → "Cancel Export", "OK" → "Got It", "Re-process" → "Re-process Audio"

  ## Test plan
  - [x] xcodebuild build SUCCEEDED
  - [x] xcodebuild test — all existing tests pass (regression guard)
  - [x] Human device verification recorded in `.planning/phases/09-polish-accessibility-audit/HUMAN-VERIFY.md`
  - [x] UI-SPEC all 6 dimensions signed off

  🤖 Generated with [Claude Code](https://claude.com/claude-code)
  EOF
  )"
  ```

---

## Rollback

If any task fails verification and must be rolled back, use the atomic-commit boundaries:

```bash
git log --oneline phase-09-polish-accessibility ^main   # list Phase 9 commits
git revert <sha>                                         # revert one commit only
# or
git reset --hard HEAD~N                                  # drop N most recent commits on this branch (safe — not pushed yet)
```

**Do not rebase/amend commits after the PR is pushed** — each task's atomic commit is intentional so reverts stay cheap.

---

## Summary Ledger

| Task | File | Lines touched | Requirement |
|------|------|--------------|-------------|
| 1 | ExportProgressSheet.swift | 42 (full rewrite) | POL-01, POL-02, copy |
| 2 | ExportFormatSheet.swift | 77 (full rewrite) | POL-01, POL-02, copy |
| 3 | MixingStationView.swift (emptyState) | ~22 | POL-01 |
| 4 | MixingStationView.swift (toolbar) | ~50 | POL-01 |
| 5 | CleaningLabView.swift (alert + staleBanner) | ~30 | POL-03, copy×2 |
| 6 | AIOrbView.swift (progress ring) | 1 | POL-03 |
| 7 | HUMAN-VERIFY.md + REQUIREMENTS.md | new | verify |
| F1 | 09-UI-SPEC.md sign-off | 7 | — |

**Commits expected:** 6 code commits (Tasks 1–6) + 1 docs commit (Task 7) + 1 sign-off commit (F1) = 8 commits on branch `phase-09-polish-accessibility`.
