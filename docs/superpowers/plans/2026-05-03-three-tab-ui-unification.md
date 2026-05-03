# Three-Tab UI Unification + CleanCut Rebrand — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify the three tab home screens (Smart Cut · Denoise · Merge) under one visual template (inline titles, indigo brand-level chrome, lime-green reserved for AI moments, single semantic `waveform.badge.plus` import button), add a binary Light/Dark theme toggle to all three home toolbars (default Light, no System option), and rebrand the user-facing app from SonicMerge to CleanCut (display name + UI strings only — bundle ID and Xcode scheme stay).

**Architecture:** Each home view stays in its current file; no shared scaffold component. One new design-system component (`ThemeToggleButton`) is introduced and used identically by all three home toolbars. `ThemePreference.system` is removed from the enum; existing installs migrate via a one-shot read in `SonicMergeApp.body.onAppear`. Two pure helpers (`ThemePreference.next(after:)` and `SonicMergeApp.migrateLegacyTheme(_:)`) absorb the only logic worth unit-testing.

**Tech Stack:** Swift 6, SwiftUI, `@AppStorage`, SF Symbols (iOS 17+), `XCTest` / `Swift Testing`, `xcodebuild` test runner.

**Spec:** `docs/superpowers/specs/2026-05-03-three-tab-ui-unification-design.md`.

> **Line-number policy:** Cited line numbers reflect `main` at plan-write time and may drift by 1–7 lines as Chunks land. Always locate the target block by **searching the code snippet provided**, not by jumping to the cited line.

---

## Chunk 0: Branch + baseline

### Task 0.1: Verify clean working tree and create branch

**Files:** none (git only)

- [ ] **Step 1: Confirm we're on `main` and the tree is clean except for the standing UI-state file.**

  Run: `git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge status`
  Expected: only `M  SonicMerge.xcodeproj/.../UserInterfaceState.xcuserstate` and untracked `.cursor/` / `.superpowers/`.

- [ ] **Step 2: Create the feature branch from main.**

  Run: `git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge checkout -b design/clean-cut-rebrand main`
  Expected: `Switched to a new branch 'design/clean-cut-rebrand'`.

- [ ] **Step 3: Baseline build + test.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/cc-baseline.log | tail -8
  echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/cc-baseline.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
  ```
  Expected: build SUCCEEDS. `FAIL=5` (pre-existing baseline: `compositionWithCrossfadeHasNonNilAudioMix`, `testFileCopyToClipsDirectory`, `testLargeFileCopyDoesNotCrash`, `testPendingKeyWrittenAndCleared`, `testPositionPreservedOnSwitch`). No new failures will be tolerated past Chunk 6.

---

## Chunk 1: ThemePreference enum + migration helper

This chunk drops `.system` from the enum, makes `.light` the default, and adds a pure migration helper. No view code yet — `MixingStationView`'s existing theme picker still references `.system` via raw string, which we'll intentionally break in this chunk and fix in Chunk 4 by removing the picker entirely. To keep the build green between chunks, we update `MixingStationView` minimally here (one-line raw-string change) so the project still compiles.

**Spec references:** §3 (architecture), §10 (migration).

### Task 1.1: Drop `.system` from `ThemePreference` enum + simplify resolver

**Files:**
- Modify: `SonicMerge/DesignSystem/SonicMergeTheme+Appearance.swift:10-14` (enum) and `:55-61` (resolver)

- [ ] **Step 1: Edit the enum to remove `.system`.**

  Open `SonicMerge/DesignSystem/SonicMergeTheme+Appearance.swift`. Replace lines 10–14:

  ```swift
  enum ThemePreference: String, CaseIterable, Sendable {
      case system
      case light
      case dark
  }
  ```

  with:

  ```swift
  enum ThemePreference: String, CaseIterable, Sendable {
      case light
      case dark

      /// The next state in the binary toggle cycle. Pure — easily unit-testable.
      static func next(after current: ThemePreference) -> ThemePreference {
          current == .light ? .dark : .light
      }
  }
  ```

- [ ] **Step 2: Simplify the resolver.**

  In the same file, find `static func resolved(...)` (currently lines 51–63). The `useDark` closure currently switches on three cases. Replace the closure body so `.system` is gone:

  ```swift
  let useDark: Bool = {
      switch preference {
      case .light: return false
      case .dark: return true
      }
  }()
  ```

  (The outer `static func resolved(...)` signature and return statement are unchanged.)

### Task 1.2: Add the legacy-value migration helper to `SonicMergeApp`

**Files:**
- Modify: `SonicMerge/SonicMergeApp.swift` (append a static helper to the struct, before the closing `}`)
- Test: `SonicMergeTests/ThemeMigrationTests.swift` (new)

- [ ] **Step 1: Write the failing test.**

  Create `SonicMergeTests/ThemeMigrationTests.swift`:

  ```swift
  import Testing
  import Foundation
  @testable import SonicMerge

  struct ThemeMigrationTests {

      @Test func migrateLegacySystemValueReturnsLight() {
          let result = SonicMergeApp.migrateLegacyTheme("system")
          #expect(result == ThemePreference.light.rawValue)
      }

      @Test func migrateRecognizedLightValueReturnsNil() {
          let result = SonicMergeApp.migrateLegacyTheme(ThemePreference.light.rawValue)
          #expect(result == nil)
      }

      @Test func migrateRecognizedDarkValueReturnsNil() {
          let result = SonicMergeApp.migrateLegacyTheme(ThemePreference.dark.rawValue)
          #expect(result == nil)
      }

      @Test func migrateUnknownValueReturnsLight() {
          // Future-proof: any unrecognized raw normalizes to .light.
          let result = SonicMergeApp.migrateLegacyTheme("garbage")
          #expect(result == ThemePreference.light.rawValue)
      }

      @Test func nextAfterLightIsDark() {
          #expect(ThemePreference.next(after: .light) == .dark)
      }

      @Test func nextAfterDarkIsLight() {
          #expect(ThemePreference.next(after: .dark) == .light)
      }
  }
  ```

- [ ] **Step 2: Run the test, expect compile failure (`migrateLegacyTheme` doesn't exist).**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:SonicMergeTests/ThemeMigrationTests \
    -parallel-testing-enabled NO test 2>&1 | tail -10
  ```
  Expected: `type 'SonicMergeApp' has no member 'migrateLegacyTheme'`.

- [ ] **Step 3: Add the migration helper.**

  Open `SonicMerge/SonicMergeApp.swift`. Just before the closing `}` of `struct SonicMergeApp: App {`, insert:

  ```swift
      // MARK: - Theme migration (binary toggle, drops .system)

      /// Returns the new raw value to write back to `@AppStorage("sonicMergeThemePreference")`,
      /// or `nil` if the stored value already matches a valid binary state. Pure — easily testable.
      ///
      /// Legacy `"system"` and any unrecognized raw both normalize to `"light"` (the new default).
      static func migrateLegacyTheme(_ raw: String) -> String? {
          if ThemePreference(rawValue: raw) != nil { return nil }
          return ThemePreference.light.rawValue
      }
  ```

- [ ] **Step 4: Run the test, expect PASS.**

  Run the same command from Step 2.
  Expected: 6 tests pass.

### Task 1.3: Wire the migration into the app entry

**Files:**
- Modify: `SonicMerge/SonicMergeApp.swift` (add `@AppStorage` + `.onAppear` migration call)

- [ ] **Step 1: Add the `@AppStorage` field at struct scope.**

  Open `SonicMerge/SonicMergeApp.swift`. Just below the existing `@UIApplicationDelegateAdaptor(SmartCutAppDelegate.self) private var smartCutAppDelegate`, add:

  ```swift
      @AppStorage("sonicMergeThemePreference") private var themePreferenceRaw: String = ThemePreference.light.rawValue
  ```

- [ ] **Step 2: Wrap `RootTabView()` with `.onAppear` that runs the migration.**

  In `body`, change:

  ```swift
  var body: some Scene {
      WindowGroup {
          RootTabView()
      }
      .modelContainer(modelContainer)
  }
  ```

  to:

  ```swift
  var body: some Scene {
      WindowGroup {
          RootTabView()
              .onAppear {
                  if let migrated = Self.migrateLegacyTheme(themePreferenceRaw) {
                      themePreferenceRaw = migrated
                  }
              }
      }
      .modelContainer(modelContainer)
  }
  ```

### Task 1.4: Keep MixingStationView compiling — temporary patch

`MixingStationView.swift:14` currently defaults to `ThemePreference.system.rawValue`, and `:175` references `ThemePreference.system.rawValue` in the picker. Both will fail to compile after Task 1.1. We patch them surgically here so the project builds; Chunk 4 deletes both pieces entirely.

**Files:**
- Modify: `SonicMerge/Features/MixingStation/MixingStationView.swift:14, :173-178`

- [ ] **Step 1: Change the `@AppStorage` default.**

  Open `MixingStationView.swift`. Line 14:

  ```swift
  @AppStorage("sonicMergeThemePreference") private var themePreferenceRaw: String = ThemePreference.system.rawValue
  ```

  Replace with:

  ```swift
  @AppStorage("sonicMergeThemePreference") private var themePreferenceRaw: String = ThemePreference.light.rawValue
  ```

- [ ] **Step 2: Delete the `Text("System").tag(...)` row from the Picker.**

  Find the picker block (currently `:173-178`):

  ```swift
  Picker("Appearance", selection: $themePreferenceRaw) {
      Text("System").tag(ThemePreference.system.rawValue)
      Text("Light").tag(ThemePreference.light.rawValue)
      Text("Dark conveyor").tag(ThemePreference.dark.rawValue)
  }
  ```

  Remove only the `Text("System")...` line:

  ```swift
  Picker("Appearance", selection: $themePreferenceRaw) {
      Text("Light").tag(ThemePreference.light.rawValue)
      Text("Dark conveyor").tag(ThemePreference.dark.rawValue)
  }
  ```

- [ ] **Step 3: Fix the resolver guard — `themePreference` computed property.**

  Find (currently `:28-30`):

  ```swift
  private var themePreference: ThemePreference {
      ThemePreference(rawValue: themePreferenceRaw) ?? .system
  }
  ```

  Replace with:

  ```swift
  private var themePreference: ThemePreference {
      ThemePreference(rawValue: themePreferenceRaw) ?? .light
  }
  ```

### Task 1.5: End-of-chunk verification + commit

- [ ] **Step 1: Run the full test suite, confirm baseline holds.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/cc-chunk1.log | tail -3
  echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/cc-chunk1.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
  ```
  Expected: `FAIL=5` (matches Chunk 0 baseline). The 6 new `ThemeMigrationTests` show as passes.

- [ ] **Step 2: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/DesignSystem/SonicMergeTheme+Appearance.swift \
    SonicMerge/SonicMergeApp.swift \
    SonicMerge/Features/MixingStation/MixingStationView.swift \
    SonicMergeTests/ThemeMigrationTests.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(theme): drop .system; binary toggle migration helper"
  ```

---

## Chunk 2: ThemeToggleButton component

A new self-contained design-system component used identically by all three home toolbars. The button reads/writes its own `@AppStorage` — no init args. Logic worth testing (next-state, raw-value tolerance) was already extracted to pure helpers in Chunk 1.

**Spec references:** §7 (API + behavior + legacy tolerance).

### Task 2.1: Create `ThemeToggleButton`

**Files:**
- Create: `SonicMerge/DesignSystem/ThemeToggleButton.swift`

- [ ] **Step 1: Create the file.**

  Create `SonicMerge/DesignSystem/ThemeToggleButton.swift`:

  ```swift
  // ThemeToggleButton.swift
  // SonicMerge
  //
  // Binary Light ↔ Dark toggle. Self-contained: reads/writes its own
  // @AppStorage("sonicMergeThemePreference"). Caller invokes as
  // `ThemeToggleButton()` with no args.

  import SwiftUI

  struct ThemeToggleButton: View {
      @Environment(\.sonicMergeSemantic) private var semantic

      @AppStorage("sonicMergeThemePreference") private var themePreferenceRaw: String = ThemePreference.light.rawValue

      private var current: ThemePreference {
          // Legacy-value tolerance (spec §7): unrecognized raw → render as .light.
          // The §10 .onAppear migration normalizes storage on first launch.
          ThemePreference(rawValue: themePreferenceRaw) ?? .light
      }

      var body: some View {
          Button {
              themePreferenceRaw = ThemePreference.next(after: current).rawValue
          } label: {
              Image(systemName: current == .light ? "sun.max.fill" : "moon.fill")
                  .font(.system(size: 17, weight: .semibold))
                  .symbolEffect(.bounce, value: themePreferenceRaw)
          }
          .tint(Color(uiColor: semantic.accentAction))
          .sensoryFeedback(.impact(weight: .light), trigger: themePreferenceRaw)
          .accessibilityLabel(current == .light ? "Theme: Light" : "Theme: Dark")
          .accessibilityHint(current == .light ? "Tap to switch to Dark theme" : "Tap to switch to Light theme")
      }
  }
  ```

- [ ] **Step 2: Build to confirm it compiles.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/DesignSystem/ThemeToggleButton.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(theme): ThemeToggleButton — binary Light/Dark toggle"
  ```

---

## Chunk 3: Smart Cut + Denoise home unification

Both views get the same diff applied: inline title, plus-icon-only CTA in empty state, pinned import button in loaded state, `ThemeToggleButton` in trailing toolbar. Two near-identical files; the diff is mechanical.

**Spec references:** §4.2 (title chrome), §5.1 (list variant), §6.1 (toolbars).

### Task 3.1: Smart Cut home

**Files:**
- Modify: `SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift`

- [ ] **Step 1: Change navigation title display mode to inline.**

  Open `SonicMergeHomeView.swift`. Line 37:

  ```swift
  .navigationBarTitleDisplayMode(.large)
  ```

  Change to:

  ```swift
  .navigationBarTitleDisplayMode(.inline)
  ```

- [ ] **Step 2: Add a trailing toolbar with `ThemeToggleButton`.**

  Immediately after `.navigationBarTitleDisplayMode(.inline)` (still inside the body modifiers), insert:

  ```swift
  .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
          ThemeToggleButton()
      }
  }
  ```

- [ ] **Step 3: Wrap the hero icon in a 76×76 rounded-rect background container (spec §5.1).**

  Find the `Image(systemName: "sparkles")` block in `emptyState` (currently around `:62-65`):

  ```swift
  Image(systemName: "sparkles")
      .font(.system(size: 56, weight: .bold))
      .foregroundStyle(Color(uiColor: semantic.accentAI))
      .accessibilityHidden(true)
  ```

  Replace with the spec's rounded-rect container:

  ```swift
  Image(systemName: "sparkles")
      .font(.system(size: 38, weight: .bold))
      .foregroundStyle(Color(uiColor: semantic.accentAI))
      .frame(width: 76, height: 76)
      .background(
          RoundedRectangle(cornerRadius: 24, style: .continuous)
              .fill(Color(uiColor: semantic.accentAI).opacity(0.18))
      )
      .accessibilityHidden(true)
  ```

- [ ] **Step 4: Replace the empty-state pill button with a circular plus-icon button.**

  Find the empty state Button block (currently around `:74-79`):

  ```swift
  Button {
      showFileImporter = true
  } label: {
      Label("Upload Audio", systemImage: "plus.circle.fill")
  }
  .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
  ```

  Replace with:

  ```swift
  Button {
      showFileImporter = true
  } label: {
      Image(systemName: "waveform.badge.plus")
          .font(.system(size: 24, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 60, height: 60)
          .background(Circle().fill(Color(uiColor: semantic.accentAction)))
          .shadow(color: Color(uiColor: semantic.accentAction).opacity(0.32), radius: 16, x: 0, y: 6)
  }
  .accessibilityLabel("Add audio file")
  ```

- [ ] **Step 5: Replace the loaded-state pinned pill with a small circular plus-icon.**

  Find the loaded-state Button block (currently around `:87-96`):

  ```swift
  Button {
      showFileImporter = true
  } label: {
      Label("Upload Audio", systemImage: "plus.circle.fill")
          .frame(maxWidth: .infinity)
  }
  .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
  .padding(.horizontal, 16)
  .padding(.top, 12)
  .padding(.bottom, 8)
  ```

  Replace with:

  ```swift
  HStack {
      Spacer()
      Button {
          showFileImporter = true
      } label: {
          Image(systemName: "waveform.badge.plus")
              .font(.system(size: 18, weight: .semibold))
              .foregroundStyle(.white)
              .frame(width: 44, height: 44)
              .background(Circle().fill(Color(uiColor: semantic.accentAction)))
              .shadow(color: Color(uiColor: semantic.accentAction).opacity(0.28), radius: 10, x: 0, y: 4)
      }
      .accessibilityLabel("Add audio file")
  }
  .padding(.horizontal, 16)
  .padding(.top, 12)
  .padding(.bottom, 8)
  ```

- [ ] **Step 6: Build.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`.

### Task 3.2: Denoise home — apply same diff

**Files:**
- Modify: `SonicMerge/Features/Denoising/Views/Home/DenoiseHomeView.swift`

- [ ] **Step 1: Change navigation title display mode to inline.**

  Line 34: `.navigationBarTitleDisplayMode(.large)` → `.navigationBarTitleDisplayMode(.inline)`.

- [ ] **Step 2: Add the trailing toolbar with `ThemeToggleButton`** immediately after `.navigationBarTitleDisplayMode(.inline)`:

  ```swift
  .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
          ThemeToggleButton()
      }
  }
  ```

- [ ] **Step 3: Wrap the Denoise hero icon in the 76×76 rounded-rect background container.**

  Find the `Image(systemName: "waveform.badge.minus")` block in `emptyState` (currently around `:57-60`):

  ```swift
  Image(systemName: "waveform.badge.minus")
      .font(.system(size: 56, weight: .bold))
      .foregroundStyle(Color(uiColor: semantic.accentAI))
      .accessibilityHidden(true)
  ```

  Replace with:

  ```swift
  Image(systemName: "waveform.badge.minus")
      .font(.system(size: 38, weight: .bold))
      .foregroundStyle(Color(uiColor: semantic.accentAI))
      .frame(width: 76, height: 76)
      .background(
          RoundedRectangle(cornerRadius: 24, style: .continuous)
              .fill(Color(uiColor: semantic.accentAI).opacity(0.18))
      )
      .accessibilityHidden(true)
  ```

- [ ] **Step 4: Replace the empty-state pill button** (currently around `:69-74`) with the circular `waveform.badge.plus` button — copy verbatim from Task 3.1 Step 4's "Replace with" block.

- [ ] **Step 5: Replace the loaded-state pinned pill** (currently around `:80-89`) with the small circular import button — copy verbatim from Task 3.1 Step 5's "Replace with" block.

- [ ] **Step 6: Build.** Same command as Task 3.1 Step 6. Expected: `** BUILD SUCCEEDED **`.

### Task 3.3: End-of-chunk verification + commit

- [ ] **Step 1: Run the full test suite.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/cc-chunk3.log | tail -3
  echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/cc-chunk3.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
  ```
  Expected: `FAIL=5`.

- [ ] **Step 2: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift \
    SonicMerge/Features/Denoising/Views/Home/DenoiseHomeView.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(home): inline title + waveform.badge.plus + theme toggle on Smart Cut/Denoise homes"
  ```

---

## Chunk 4: Merge home unification

Bigger surface change: drops the leading `+`, deletes the existing "Import Audio" pill in the empty state, replaces the More-menu theme picker with `ThemeToggleButton`, adds a circular hero button in the empty state, and pins a small circular import button above the timeline in the loaded state. Drag-drop and Export are preserved.

**Spec references:** §4.2 (title), §5.2 (workspace variant), §6.1 (toolbar).

### Task 4.1: Title string + remove leading `+`

**Files:**
- Modify: `SonicMerge/Features/MixingStation/MixingStationView.swift`

- [ ] **Step 1: Rename the navigation title.**

  Line 47:

  ```swift
  .navigationTitle("SonicMerge")
  ```

  Change to:

  ```swift
  .navigationTitle("Merge")
  ```

  (`.navigationBarTitleDisplayMode(.inline)` on the next line is already correct — leave it.)

- [ ] **Step 2: Remove the leading `+` toolbar item.**

  Find the `ToolbarItem(placement: .topBarLeading)` block (currently `:153-166`) — the entire block including the Import button:

  ```swift
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
  ```

  Delete the entire block.

- [ ] **Step 3: Remove the now-unused `@State` field and haptic trigger.**

  Line 26: `@State private var importHaptic = false` — delete.

### Task 4.2: Replace the More-menu picker with `ThemeToggleButton`

**Files:**
- Modify: `SonicMerge/Features/MixingStation/MixingStationView.swift`

- [ ] **Step 1: Replace the entire "More" `ToolbarItem`.**

  Find the trailing `ToolbarItem` containing the `Menu { Picker("Appearance", ...) }` (currently `:179-194`):

  ```swift
  ToolbarItem(placement: .topBarTrailing) {
      Menu {
          Picker("Appearance", selection: $themePreferenceRaw) {
              Text("Light").tag(ThemePreference.light.rawValue)
              Text("Dark conveyor").tag(ThemePreference.dark.rawValue)
          }
      } label: {
          Label("More options", systemImage: "ellipsis.circle")
      }
      .sensoryFeedback(.impact(weight: .light), trigger: themePreferenceRaw)
  }
  ```

  Replace with:

  ```swift
  ToolbarItem(placement: .topBarTrailing) {
      ThemeToggleButton()
  }
  ```

- [ ] **Step 2: Leave the `@AppStorage` declaration and `themePreference` computed property in place — do NOT delete them.**

  These are still needed: the `semantic` resolver downstream still reads `themePreference` to compute the `SonicMergeSemantic` palette (light vs dark). When `ThemeToggleButton` writes to the same `sonicMergeThemePreference` `@AppStorage` key from its own scope, this view re-renders because the keys match.

  No edit required for Step 2 — verify by reading the current file:

  ```bash
  grep -n "themePreferenceRaw\|themePreference\|sonicMergeThemePreference" \
    /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMerge/Features/MixingStation/MixingStationView.swift
  ```

  Expected: the `@AppStorage` declaration (currently `:14`), the `themePreference` computed property (currently `:28-30`), and the `semantic` resolver are all retained. Only the **picker UI inside the More menu** (deleted in Step 1 of this task) referenced `$themePreferenceRaw`'s binding directly; the resolver path is independent.

- [ ] **Step 3: Remove the appearance haptic.**

  Line 27: `@State private var appearanceHaptic = false` — delete (no longer referenced).

### Task 4.3: Add `PremiumBackground` + replace empty state

**Files:**
- Modify: `SonicMerge/Features/MixingStation/MixingStationView.swift`

- [ ] **Step 1: Wrap the existing `ZStack` content with `PremiumBackground`.**

  Find the body's outer ZStack (currently around `:38-46`):

  ```swift
  NavigationStack {
      ZStack {
          PremiumBackground()

          if viewModel.clips.isEmpty {
              emptyState
          } else {
              MergeTimelineView(onExportTap: { showExportSheet = true })
          }
      }
  ```

  This already has `PremiumBackground()` — good, no edit needed. (Verify with `grep -n "PremiumBackground" MixingStationView.swift` — if it's missing on your branch, add it as the first child of the ZStack.)

- [ ] **Step 2: Replace the empty-state body with the new circular hero pattern.**

  Find the `emptyState` private var (currently `:122-148` after Task 4.1's deletions):

  ```swift
  private var emptyState: some View {
      VStack(spacing: SonicMergeTheme.Spacing.md) {
          Image(systemName: "waveform")
              .font(.system(size: 48))
              .foregroundStyle(Color(uiColor: semantic.accentAction))
              .shadow(
                  color: Color(uiColor: semantic.accentGlow).opacity(0.35),
                  radius: 20,
                  x: 0,
                  y: 0
              )
              .accessibilityHidden(true)
          Text("No clips yet")
              .font(.system(.title3, design: .rounded, weight: .semibold))
              .foregroundStyle(Color(uiColor: semantic.textPrimary))
          Text("Tap + to add audio files\nor drop them here")
              .font(.system(.body, design: .rounded))
              .foregroundStyle(Color(uiColor: semantic.textSecondary))
              .multilineTextAlignment(.center)
          Button {
              showDocumentPicker = true
          } label: {
              Label("Import Audio", systemImage: "plus.circle.fill")
          }
          .buttonStyle(PillButtonStyle(variant: .filled, size: .regular))
      }
  }
  ```

  Replace with:

  ```swift
  private var emptyState: some View {
      VStack(spacing: SonicMergeTheme.Spacing.md) {
          Image(systemName: "rectangle.stack")
              .font(.system(size: 38, weight: .bold))
              .foregroundStyle(Color(uiColor: semantic.accentAction))
              .frame(width: 76, height: 76)
              .background(
                  RoundedRectangle(cornerRadius: 24, style: .continuous)
                      .fill(Color(uiColor: semantic.accentAction).opacity(0.14))
              )
              .accessibilityHidden(true)
          Text("No clips yet")
              .font(.system(.title3, design: .rounded, weight: .semibold))
              .foregroundStyle(Color(uiColor: semantic.textPrimary))
          Text("Tap below to add audio files,\nor drop them here.")
              .font(.system(.body, design: .rounded))
              .foregroundStyle(Color(uiColor: semantic.textSecondary))
              .multilineTextAlignment(.center)
          Button {
              showDocumentPicker = true
          } label: {
              Image(systemName: "waveform.badge.plus")
                  .font(.system(size: 24, weight: .semibold))
                  .foregroundStyle(.white)
                  .frame(width: 60, height: 60)
                  .background(Circle().fill(Color(uiColor: semantic.accentAction)))
                  .shadow(color: Color(uiColor: semantic.accentAction).opacity(0.32), radius: 16, x: 0, y: 6)
          }
          .accessibilityLabel("Add audio file")
      }
  }
  ```

  Note: The `Image(systemName: "waveform")` with `accentGlow` shadow is the **old** hero used because Merge wasn't an AI feature. The new spec keeps it as the hero icon but switches to `rectangle.stack` (a stack of clips) and uses the indigo `accentAction` background instead of green. This is per spec §5.2 (Merge hero is indigo, not lime — Merge is not an AI feature).

### Task 4.4: Add the pinned import button above the timeline

**Files:**
- Modify: `SonicMerge/Features/MixingStation/MixingStationView.swift`

- [ ] **Step 1: Wrap `MergeTimelineView` in a `VStack` with the pinned button on top.**

  Find the loaded-state `else` branch (currently `:43-46`):

  ```swift
  if viewModel.clips.isEmpty {
      emptyState
  } else {
      MergeTimelineView(onExportTap: { showExportSheet = true })
  }
  ```

  Replace with:

  ```swift
  if viewModel.clips.isEmpty {
      emptyState
  } else {
      VStack(spacing: 0) {
          HStack {
              Spacer()
              Button {
                  showDocumentPicker = true
              } label: {
                  Image(systemName: "waveform.badge.plus")
                      .font(.system(size: 18, weight: .semibold))
                      .foregroundStyle(.white)
                      .frame(width: 44, height: 44)
                      .background(Circle().fill(Color(uiColor: semantic.accentAction)))
                      .shadow(color: Color(uiColor: semantic.accentAction).opacity(0.28), radius: 10, x: 0, y: 4)
              }
              .accessibilityLabel("Add audio file")
          }
          .padding(.horizontal, 16)
          .padding(.top, 12)
          .padding(.bottom, 8)

          MergeTimelineView(onExportTap: { showExportSheet = true })
      }
  }
  ```

### Task 4.5: End-of-chunk verification + commit

- [ ] **Step 1: Build.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Run the full test suite.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/cc-chunk4.log | tail -3
  echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/cc-chunk4.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
  ```
  Expected: `FAIL=5`.

- [ ] **Step 3: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/Features/MixingStation/MixingStationView.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(merge): unify Merge home (drop +, theme toggle, circular import button)"
  ```

---

## Chunk 5: CleanCut rebrand — display strings only

Display name in both Info.plists, navigation title on Merge tab (already done as part of Chunk 4 Task 4.1 — recheck), audit user-facing Swift literals. Internal symbols, bundle ID, scheme, type names stay (per spec §9.2).

**Spec references:** §9 (rebrand scope), §11 audit policy.

### Task 5.1: Update `CFBundleDisplayName` in both Info.plists

**Files:**
- Modify: `SonicMerge/Info.plist`
- Modify: `SonicMergeShareExtension/Info.plist`

- [ ] **Step 1: Patch the main app's display name.**

  Open `SonicMerge/Info.plist`. The current value is `<string>$(PRODUCT_NAME)</string>` for `CFBundleDisplayName`. Replace **only** the `CFBundleDisplayName` value (leave `CFBundleName` as `$(PRODUCT_NAME)`):

  Find:
  ```xml
  <key>CFBundleDisplayName</key>
  <string>$(PRODUCT_NAME)</string>
  ```

  Replace with:
  ```xml
  <key>CFBundleDisplayName</key>
  <string>CleanCut</string>
  ```

- [ ] **Step 2: Patch the share extension's display name.**

  Open `SonicMergeShareExtension/Info.plist`. If the file has a `CFBundleDisplayName` key, replace its value with `CleanCut`. If it doesn't, **leave it alone** — the share extension inherits the main app's display name in the Share sheet.

  Run a quick check first:
  ```bash
  grep -A1 "CFBundleDisplayName" /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMergeShareExtension/Info.plist
  ```
  If empty: skip this step. If it returns a key+value: edit the value to `CleanCut`.

- [ ] **Step 3: Build.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`.

### Task 5.2: Audit + rename user-facing Swift literals

**Files:** discovered at execution time via `grep`

- [ ] **Step 1: Run the audit grep.**

  ```bash
  grep -rn "SonicMerge" /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMerge --include="*.swift" 2>/dev/null
  ```

- [ ] **Step 2: Triage hits using the spec §11 three-bucket policy.**

  Apply this policy to every line:

  | Bucket | Rule | Action |
  |---|---|---|
  | (a) User-facing literal | String shows up in UI / alert / share sheet / notification | Rename `"SonicMerge"` → `"CleanCut"` |
  | (b) Internal symbol | `SonicMergeApp`, `SonicMergeTheme*`, `SonicMergeSemantic`, `SonicMergeShareExtension`, `sonicMergeThemePreference`, `sonicMerge.hasImportedFirstClip`, `accentAction`, `Color.sonicMerge*`, type names, module references | Leave alone |
  | (c) Filename / temp-path prefix | Internal temp files like `"SonicMerge-Denoised-..."` (never shown to user) → leave alone. Export filenames the user sees in the share sheet (e.g. `"SonicMerge-DenoisedExport-..."`, `"SonicMerge-SmartCutExport-..."`, `"SonicMerge-CleaningLab-..."`) → rename to `"CleanCut-..."` | Rename only the user-visible export pattern |

- [ ] **Step 3: Apply renames based on triage.**

  Expected hit list (verify against current branch — line numbers may drift):

  | File | Line | Bucket | Action |
  |---|---|---|---|
  | `SmartCutViewModel.swift` | ~178 | (a) | `"Settings → SonicMerge."` → `"Settings → CleanCut."` |
  | `DenoiseSessionView.swift` | ~192 | (c) | `"SonicMerge-DenoisedExport-"` → `"CleanCut-Export-"` |
  | `SmartCutSessionView.swift` | search for `Export-` | (c) | If present, rename `"SonicMerge-SmartCutExport-"` → `"CleanCut-Export-"` |
  | `DenoiseSessionViewModel.swift` | ~193, ~215, ~273, ~303, ~319 | (c) | Internal temp paths only — **leave alone** (not shown to user) |
  | All other hits | — | (b) | Internal symbols — **leave alone** |

  For each (a) and (c) match: open the file, replace the literal, save.

- [ ] **Step 4: Re-run the grep to confirm only (b) hits remain.**

  ```bash
  grep -rn "SonicMerge" /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMerge --include="*.swift" 2>/dev/null | grep -v -E "SonicMergeApp|SonicMergeTheme|SonicMergeSemantic|SonicMergeShareExtension|sonicMerge\.|sonicMergeThemePreference|sonicMergeSemantic|SonicMerge-Denoised-|SonicMerge-Waveform-|SonicMerge-Blended-"
  ```
  Expected: empty output (no user-facing or export-filename hits remain).

- [ ] **Step 5: Build + smoke-test.**

  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`.

### Task 5.3: End-of-chunk verification + commit

- [ ] **Step 1: Run the full test suite.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/cc-chunk5.log | tail -3
  echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/cc-chunk5.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
  ```
  Expected: `FAIL=5`.

- [ ] **Step 2: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add -u
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(rebrand): SonicMerge → CleanCut (display name + user-facing strings)"
  ```

---

## Chunk 6: Final verification + manual QA

### Task 6.1: Full suite + clean tree

- [ ] **Step 1: Final suite run.**

  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/cc-final.log | tail -3
  echo "FAIL=$(grep -E '✘ Test [a-zA-Z_]+\(\) failed' /tmp/cc-final.log | grep -oE 'Test [a-zA-Z_]+\(\)' | sort -u | wc -l)"
  ```
  Expected: `FAIL=5` (matches Chunk 0 baseline).

- [ ] **Step 2: Verify tree is clean.**

  Run: `git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge status`
  Expected: only the standing `.xcuserstate` modification.

### Task 6.2: Manual QA on simulator

Run the app on the iPhone 17 simulator. Confirm each of the following:

- [ ] **Cold launch** opens on the **Smart Cut** tab. Title is inline ("Smart Cut"). Theme toggle (☀︎) is in the top-right.
- [ ] **Empty state** shows the lime-green sparkles hero, tagline, and a circular indigo `waveform.badge.plus` button. **No `+` icon on the Merge tab toolbar.**
- [ ] **Tap the import button** on Smart Cut → file picker opens → pick an `.m4a` → push to session view → studio renders. Existing flow unbroken.
- [ ] **Switch to Denoise tab** — same chrome (inline title, theme toggle), lime-green waveform hero, indigo plus button.
- [ ] **Switch to Merge tab** — title says "Merge" (not "SonicMerge"). Theme toggle + Export in trailing toolbar. Empty state shows indigo `rectangle.stack` hero + indigo plus button. **No leading `+`.**
- [ ] **Drop an audio file onto Merge** — drag-drop still works (preserved from prior behavior).
- [ ] **Tap the theme toggle** in any tab → app switches Light → Dark with the icon swap animation. Toggle persists across tab switches and across app restarts (force-quit + relaunch).
- [ ] **Existing user data** — confirm prior Smart Cut and Denoise recents still load (no data loss from migration).
- [ ] **App display name** — on the home screen and in Settings, the app shows as **CleanCut** (verify on the simulator's home screen icon label).

### Task 6.3: Final commit (if any QA fixes) + finishing-a-development-branch

- [ ] **Step 1: If any QA found issues, fix them in additional commits before this step. Re-run Task 6.1.**

- [ ] **Step 2: Use the `superpowers:finishing-a-development-branch` skill to merge or PR this work.**

  Announce: "I'm using the finishing-a-development-branch skill to complete this work."
