# Smart Cut as Main Screen — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Promote Smart Cut from a sub-feature to the app's primary feature by replacing the single-root `MixingStationView` with a three-tab `RootTabView` (Smart Cut · Denoise · Merge, defaulting to Smart Cut). Each tab is a `NavigationStack` with list → detail navigation; sessions persist across launches via two new SwiftData entities. `CleaningLabView` retires; its halves split into `SmartCutSessionView` and `DenoiseSessionView`.

**Architecture:** Three independent `NavigationStack` tabs hosted under a `TabView` shell. Each session is a SwiftData `@Model` keyed by `UUID`, stored alongside its source audio under `<AppGroup>/<feature>/<id>/`. `RootTabView` polls App Group `UserDefaults` on `scenePhase == .active` for share-extension imports and background-transcription deep-links, routing them via the matching tab's NavigationStack `path` binding. `CleaningLabViewModel`'s embedded `SmartCutViewModel` and merged-URL bridging are deleted; per-session `SmartCutViewModel` instances now read input directly from a `SmartCutSession`.

**Tech Stack:** Swift 6, SwiftUI, SwiftData (`@Model`), `AVFoundation`, `CryptoKit` (existing `SourceHasher`), App Group `UserDefaults`, `XCTest`.

**Spec:** `docs/superpowers/specs/2026-04-28-smart-cut-main-screen-design.md`.

---

## Chunk 0: Branch + baseline

### Task 0.1: Verify clean working tree and create branch

**Files:** none (git only)

- [ ] **Step 1: Confirm we're on `main` and the tree is clean except for the standing UI-state file.**

  Run: `git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge status`
  Expected: only `M  SonicMerge.xcodeproj/.../UserInterfaceState.xcuserstate` and untracked `.cursor/` / `.superpowers/`. Anything else — investigate before continuing.

- [ ] **Step 2: Create the feature branch from main.**

  Run: `git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge checkout -b smart-cut-main-screen main`
  Expected: `Switched to a new branch 'smart-cut-main-screen'`.

- [ ] **Step 3: Baseline build + test.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/sm-baseline.log | tail -8
  echo "FAIL=$(grep -E '✘ Test .* failed' /tmp/sm-baseline.log | sort -u | wc -l)"
  ```
  Expected: build SUCCEEDS. Note the FAIL count — we'll re-check that no NEW failures appear after each chunk. (Existing failures from prior phases are tolerated as the baseline; record the exact set in the log so we don't conflate.)

---

## Chunk 1: Foundation — data models, AppConstants helpers, FillerLibraryStore

This chunk lays the persistence + filesystem groundwork the rest of the plan depends on. After this chunk the new schema is live but no view consumes it yet — the app still boots into `MixingStationView`.

### Task 1.1: Add `SmartCutSession` SwiftData model

**Files:**
- Create: `SonicMerge/Models/SmartCutSession.swift`
- Test: `SonicMergeTests/SmartCutSessionPersistenceTests.swift`

- [ ] **Step 1: Write the failing test for `SmartCutSession` round-trip persistence.**

  Create `SonicMergeTests/SmartCutSessionPersistenceTests.swift`:

  ```swift
  import XCTest
  import SwiftData
  @testable import SonicMerge

  @MainActor
  final class SmartCutSessionPersistenceTests: XCTestCase {

      func test_smartCutSessionRoundTripsThroughInMemoryModelContainer() throws {
          let schema = Schema([SmartCutSession.self])
          let config = ModelConfiguration(isStoredInMemoryOnly: true)
          let container = try ModelContainer(for: schema, configurations: config)
          let context = container.mainContext

          let id = UUID()
          let session = SmartCutSession(
              id: id,
              name: "Episode 14",
              sourceFilename: "source.m4a",
              sourceHashHex: "abc123",
              durationSeconds: 2520
          )
          context.insert(session)
          try context.save()

          let descriptor = FetchDescriptor<SmartCutSession>(
              predicate: #Predicate { $0.id == id }
          )
          let fetched = try context.fetch(descriptor).first
          XCTAssertNotNil(fetched)
          XCTAssertEqual(fetched?.name, "Episode 14")
          XCTAssertEqual(fetched?.sourceFilename, "source.m4a")
          XCTAssertEqual(fetched?.sourceHashHex, "abc123")
          XCTAssertEqual(fetched?.durationSeconds, 2520)
          XCTAssertNil(fetched?.editListJSON)
          XCTAssertNil(fetched?.transcriptCacheRef)
      }

      func test_editListJSONRoundTripsAsCodableBlob() throws {
          let schema = Schema([SmartCutSession.self])
          let config = ModelConfiguration(isStoredInMemoryOnly: true)
          let container = try ModelContainer(for: schema, configurations: config)
          let context = container.mainContext

          let edits = EditList(
              fillers: [],
              pauses: [PauseEdit(timeRange: 1.0...2.5, isEnabled: true)]
          )
          let json = try JSONEncoder().encode(edits)

          let session = SmartCutSession(
              id: UUID(),
              name: "Test",
              sourceFilename: "source.m4a",
              sourceHashHex: "deadbeef",
              durationSeconds: 60
          )
          session.editListJSON = json
          context.insert(session)
          try context.save()

          let fetched = try context.fetch(FetchDescriptor<SmartCutSession>()).first
          XCTAssertNotNil(fetched?.editListJSON)
          let decoded = try JSONDecoder().decode(EditList.self, from: fetched!.editListJSON!)
          XCTAssertEqual(decoded, edits)
      }
  }
  ```

- [ ] **Step 2: Run the test, expect compile failure (`SmartCutSession` doesn't exist).**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:SonicMergeTests/SmartCutSessionPersistenceTests \
    -parallel-testing-enabled NO test 2>&1 | tail -10
  ```
  Expected: build fails with `cannot find 'SmartCutSession' in scope`.

- [ ] **Step 3: Create the `SmartCutSession` model.**

  Create `SonicMerge/Models/SmartCutSession.swift`:

  ```swift
  import Foundation
  import SwiftData

  /// A persisted Smart Cut session: a single source audio file plus the user's
  /// in-progress edit list and transcript cache reference. Sessions live under
  /// `<AppGroup>/smart-cut/<id>/` on disk and are listed in `SmartCutHomeView`.
  ///
  /// `sourceHashHex` is the SHA-256 of the source file's bytes (no mode suffix);
  /// it lets `RootTabView` resolve background-transcription notifications back
  /// to the originating session via a single-column FetchDescriptor.
  @Model
  final class SmartCutSession {
      @Attribute(.unique) var id: UUID
      var name: String
      var sourceFilename: String
      var sourceHashHex: String
      var durationSeconds: Double
      var createdAt: Date
      var lastOpenedAt: Date
      var editListJSON: Data?
      var transcriptCacheRef: String?

      init(
          id: UUID = UUID(),
          name: String,
          sourceFilename: String,
          sourceHashHex: String,
          durationSeconds: Double
      ) {
          self.id = id
          self.name = name
          self.sourceFilename = sourceFilename
          self.sourceHashHex = sourceHashHex
          self.durationSeconds = durationSeconds
          self.createdAt = .now
          self.lastOpenedAt = .now
      }
  }
  ```

- [ ] **Step 4: Run the test, expect PASS.**

  Run the same `xcodebuild` command from Step 2.
  Expected: both tests pass.

- [ ] **Step 5: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/Models/SmartCutSession.swift \
    SonicMergeTests/SmartCutSessionPersistenceTests.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(smart-cut-tab): SmartCutSession SwiftData model"
  ```

### Task 1.2: Add `DenoiseSession` SwiftData model

**Files:**
- Create: `SonicMerge/Models/DenoiseSession.swift`
- Modify: `SonicMergeTests/SmartCutSessionPersistenceTests.swift` (rename + extend)

- [ ] **Step 1: Rename the test file to cover both models, rename the class, and add a `DenoiseSession` test inside the class body.**

  Run:
  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge mv \
    SonicMergeTests/SmartCutSessionPersistenceTests.swift \
    SonicMergeTests/SessionModelPersistenceTests.swift
  ```
  Then in the renamed file:
  1. Change the class declaration from `final class SmartCutSessionPersistenceTests: XCTestCase {` to `final class SessionModelPersistenceTests: XCTestCase {`. The `@MainActor` attribute on the class stays.
  2. Add the following test method **inside** the class body (alongside the existing two `test_smartCutSession*` methods, before the closing brace of the class):

  ```swift
  func test_denoiseSessionRoundTripsThroughInMemoryModelContainer() throws {
      let schema = Schema([DenoiseSession.self])
      let config = ModelConfiguration(isStoredInMemoryOnly: true)
      let container = try ModelContainer(for: schema, configurations: config)
      let context = container.mainContext

      let id = UUID()
      let session = DenoiseSession(
          id: id,
          name: "Lecture",
          sourceFilename: "source.wav",
          durationSeconds: 1800,
          intensity: 0.5
      )
      context.insert(session)
      try context.save()

      let fetched = try context.fetch(
          FetchDescriptor<DenoiseSession>(predicate: #Predicate { $0.id == id })
      ).first
      XCTAssertEqual(fetched?.name, "Lecture")
      XCTAssertEqual(fetched?.intensity, 0.5)
      XCTAssertNil(fetched?.processedFilename)
  }
  ```

- [ ] **Step 2: Run the test, expect compile failure (`DenoiseSession` doesn't exist).**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:SonicMergeTests/SessionModelPersistenceTests \
    -parallel-testing-enabled NO test 2>&1 | tail -10
  ```
  Expected: `cannot find 'DenoiseSession' in scope`.

- [ ] **Step 3: Create the `DenoiseSession` model.**

  Create `SonicMerge/Models/DenoiseSession.swift`:

  ```swift
  import Foundation
  import SwiftData

  /// A persisted Denoise session. Source audio at <AppGroup>/denoise/<id>/source.<ext>;
  /// processed (denoised) audio at <AppGroup>/denoise/<id>/processed.wav once apply
  /// completes. `intensity` is the last applied wet/dry blend (0–1).
  @Model
  final class DenoiseSession {
      @Attribute(.unique) var id: UUID
      var name: String
      var sourceFilename: String
      var processedFilename: String?
      var intensity: Double
      var durationSeconds: Double
      var createdAt: Date
      var lastOpenedAt: Date

      init(
          id: UUID = UUID(),
          name: String,
          sourceFilename: String,
          durationSeconds: Double,
          intensity: Double = 0.5
      ) {
          self.id = id
          self.name = name
          self.sourceFilename = sourceFilename
          self.durationSeconds = durationSeconds
          self.intensity = intensity
          self.createdAt = .now
          self.lastOpenedAt = .now
      }
  }
  ```

- [ ] **Step 4: Run the test, expect PASS.**

  Run the same `xcodebuild` command from Step 2.
  Expected: all three tests pass.

- [ ] **Step 5: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/Models/DenoiseSession.swift \
    SonicMergeTests/SessionModelPersistenceTests.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(denoise-tab): DenoiseSession SwiftData model"
  ```

### Task 1.3: Register the new models in the app schema

**Files:**
- Modify: `SonicMerge/SonicMergeApp.swift:27` (the `Schema([AudioClip.self, GapTransition.self])` literal inside the `modelContainer` closure)
- Test: `SonicMergeTests/SchemaMigrationTests.swift` (new)

- [ ] **Step 1: Write a failing test that builds a `ModelContainer` with the expanded schema and inserts one of each entity type.**

  Create `SonicMergeTests/SchemaMigrationTests.swift`:

  ```swift
  import XCTest
  import SwiftData
  @testable import SonicMerge

  @MainActor
  final class SchemaMigrationTests: XCTestCase {

      func test_expandedSchemaSupportsAllFourEntityTypes() throws {
          let schema = Schema([
              AudioClip.self,
              GapTransition.self,
              SmartCutSession.self,
              DenoiseSession.self
          ])
          let config = ModelConfiguration(isStoredInMemoryOnly: true)
          let container = try ModelContainer(for: schema, configurations: config)
          let context = container.mainContext

          // AudioClip insert (existing entity, must still load cleanly).
          let clip = AudioClip(
              displayName: "test.m4a",
              fileURLRelativePath: "test.m4a",
              duration: 30
          )
          context.insert(clip)

          // SmartCutSession insert.
          let smartCut = SmartCutSession(
              name: "smartcut",
              sourceFilename: "source.m4a",
              sourceHashHex: "abc",
              durationSeconds: 60
          )
          context.insert(smartCut)

          // DenoiseSession insert.
          let denoise = DenoiseSession(
              name: "denoise",
              sourceFilename: "source.wav",
              durationSeconds: 60
          )
          context.insert(denoise)

          try context.save()

          XCTAssertEqual(try context.fetch(FetchDescriptor<AudioClip>()).count, 1)
          XCTAssertEqual(try context.fetch(FetchDescriptor<SmartCutSession>()).count, 1)
          XCTAssertEqual(try context.fetch(FetchDescriptor<DenoiseSession>()).count, 1)
      }
  }
  ```

- [ ] **Step 2: Run the test, expect PASS already (the `Schema(...)` literal is local to the test).**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:SonicMergeTests/SchemaMigrationTests \
    -parallel-testing-enabled NO test 2>&1 | tail -10
  ```
  Expected: PASS. (This test guards against future regressions; it doesn't need a failing-first state because the schema-literal is self-contained.)

- [ ] **Step 3: Update the app-level `Schema` to include the two new types.**

  Open `SonicMerge/SonicMergeApp.swift`. At line 27 (inside the `modelContainer` closure) the current code reads:

  ```swift
  let schema = Schema([AudioClip.self, GapTransition.self])
  ```

  Replace with:

  ```swift
  let schema = Schema([
      AudioClip.self,
      GapTransition.self,
      SmartCutSession.self,
      DenoiseSession.self
  ])
  ```

- [ ] **Step 4: Build the full app target and run the full test suite.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/sm-1-3.log | tail -8
  echo "FAIL=$(grep -E '✘ Test .* failed' /tmp/sm-1-3.log | sort -u | wc -l)"
  ```
  Expected: build SUCCEEDS; FAIL count matches the baseline from Chunk 0 (no new regressions).

- [ ] **Step 5: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/SonicMergeApp.swift \
    SonicMergeTests/SchemaMigrationTests.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(schema): register SmartCutSession + DenoiseSession with app ModelContainer"
  ```

### Task 1.4: Add session-directory helpers in `AppConstants`

**Files:**
- Modify: `SonicMerge/App/AppConstants.swift` (append helpers)
- Test: `SonicMergeTests/AppConstantsSessionDirectoryTests.swift` (new)

Note: there are TWO `AppConstants.swift` files — one in `SonicMerge/App/` and one in `SonicMergeShareExtension/` (the share-extension target has its own copy because it can't share files across targets without careful target-membership setup). For now `smartCutSessionDirectory(for:)` is main-app-only; the share extension's mirror helper is added in Chunk 6, where the extension actually needs it. **This task does not modify the extension's copy.**

- [ ] **Step 1: Write the failing test.**

  Create `SonicMergeTests/AppConstantsSessionDirectoryTests.swift`:

  ```swift
  import XCTest
  @testable import SonicMerge

  final class AppConstantsSessionDirectoryTests: XCTestCase {

      func test_smartCutSessionDirectoryEndsWithExpectedSegments() throws {
          let id = UUID()
          // Skip if not entitled (e.g., test host without App Group).
          guard FileManager.default.containerURL(
              forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
          ) != nil else {
              throw XCTSkip("App Group not entitled in this test host")
          }

          let url = try AppConstants.smartCutSessionDirectory(for: id)
          XCTAssertTrue(url.path.hasSuffix("/smart-cut/\(id.uuidString)"))
          XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
      }

      func test_denoiseSessionDirectoryEndsWithExpectedSegments() throws {
          let id = UUID()
          guard FileManager.default.containerURL(
              forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
          ) != nil else {
              throw XCTSkip("App Group not entitled in this test host")
          }

          let url = try AppConstants.denoiseSessionDirectory(for: id)
          XCTAssertTrue(url.path.hasSuffix("/denoise/\(id.uuidString)"))
          XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
      }

      func test_containerNotFoundErrorDescriptionMatchesAppGroupID() {
          // Documents the user-facing error string used when entitlement is missing.
          // (The actual throw is exercised implicitly by the directory tests above
          // when they don't XCTSkip — i.e., on hosts without the entitlement those
          // tests would throw and fail rather than skip; the XCTSkip guard exists
          // because CI without entitlement is the default test environment.)
          XCTAssertEqual(
              AppGroupError.containerNotFound.errorDescription,
              "App Group container not found. Add the '\(AppConstants.appGroupID)' App Group entitlement to the target."
          )
      }
  }
  ```

- [ ] **Step 2: Run the test, expect compile failure (helpers missing).**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:SonicMergeTests/AppConstantsSessionDirectoryTests \
    -parallel-testing-enabled NO test 2>&1 | tail -10
  ```
  Expected: `type 'AppConstants' has no member 'smartCutSessionDirectory'`.

- [ ] **Step 3: Add the helpers.**

  Open `SonicMerge/App/AppConstants.swift`. After the existing `clipsDirectory()` method (currently ending at line 53), add:

  ```swift
  /// Returns the URL for the per-session Smart Cut directory inside the App Group
  /// container, creating it if it does not already exist. Layout:
  ///   <AppGroup>/smart-cut/<id.uuidString>/
  ///
  /// - Throws: `AppGroupError.containerNotFound` when running without the App
  ///   Group entitlement.
  static func smartCutSessionDirectory(for id: UUID) throws -> URL {
      guard let container = FileManager.default.containerURL(
          forSecurityApplicationGroupIdentifier: appGroupID
      ) else {
          throw AppGroupError.containerNotFound
      }
      let dir = container
          .appending(path: "smart-cut", directoryHint: .isDirectory)
          .appending(path: id.uuidString, directoryHint: .isDirectory)
      try FileManager.default.createDirectory(
          at: dir,
          withIntermediateDirectories: true,
          attributes: nil
      )
      return dir
  }

  /// Returns the URL for the per-session Denoise directory inside the App Group
  /// container, creating it if it does not already exist. Layout:
  ///   <AppGroup>/denoise/<id.uuidString>/
  ///
  /// - Throws: `AppGroupError.containerNotFound` when running without the App
  ///   Group entitlement.
  static func denoiseSessionDirectory(for id: UUID) throws -> URL {
      guard let container = FileManager.default.containerURL(
          forSecurityApplicationGroupIdentifier: appGroupID
      ) else {
          throw AppGroupError.containerNotFound
      }
      let dir = container
          .appending(path: "denoise", directoryHint: .isDirectory)
          .appending(path: id.uuidString, directoryHint: .isDirectory)
      try FileManager.default.createDirectory(
          at: dir,
          withIntermediateDirectories: true,
          attributes: nil
      )
      return dir
  }
  ```

- [ ] **Step 4: Run the test, expect PASS or skip-when-unentitled.**

  Run the same `xcodebuild` command from Step 2.
  Expected: all three tests pass (or `XCTSkip` for the directory tests if the simulator host lacks App Group entitlement; the third test always passes).

- [ ] **Step 5: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/App/AppConstants.swift \
    SonicMergeTests/AppConstantsSessionDirectoryTests.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(app-group): smartCutSessionDirectory + denoiseSessionDirectory helpers"
  ```

### Task 1.5: Add `FillerLibraryStore` (process-wide @Observable wrapper)

**Files:**
- Create: `SonicMerge/Services/FillerLibraryStore.swift`

This decouples `FillerLibrary` ownership from `CleaningLabViewModel`. Today the library is a `var` on `CleaningLabViewModel`; with per-session `SmartCutViewModel` instances and no shared parent, we need a process-wide home that:
- exposes a `Binding<FillerLibrary>` to the existing `SmartCutStudioContainer` (its init signature is `(vm:, library: Binding<FillerLibrary>)`);
- persists changes via the existing `FillerLibrary`'s UserDefaults backing (no schema change to `FillerLibrary`);
- can be installed on `RootTabView` via `.environment(\.fillerLibrary, store)` and read by session views.

This is a pure value-store wrapper — no audio logic.

- [ ] **Step 1: Create the store + environment key.**

  Create `SonicMerge/Services/FillerLibraryStore.swift`:

  ```swift
  import Foundation
  import SwiftUI
  import Observation

  /// Process-wide owner of the user's FillerLibrary. Installed on RootTabView and
  /// read by per-session SmartCutSessionView instances via the environment.
  ///
  /// FillerLibrary is itself UserDefaults-backed (see FillerLibrary.swift), so
  /// `library`'s mutations persist automatically; the store just provides one
  /// SwiftUI-observable instance with a Binding for SmartCutStudioContainer.
  @Observable
  @MainActor
  final class FillerLibraryStore {
      var library: FillerLibrary

      init(library: FillerLibrary = FillerLibrary()) {
          self.library = library
      }

      var binding: Binding<FillerLibrary> {
          Binding(
              get: { self.library },
              set: { self.library = $0 }
          )
      }
  }

  private struct FillerLibraryStoreKey: EnvironmentKey {
      @MainActor static let defaultValue: FillerLibraryStore = FillerLibraryStore()
  }

  extension EnvironmentValues {
      var fillerLibrary: FillerLibraryStore {
          get { self[FillerLibraryStoreKey.self] }
          set { self[FillerLibraryStoreKey.self] = newValue }
      }
  }
  ```

- [ ] **Step 2: Build the app target to verify it compiles.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -10
  ```
  Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/Services/FillerLibraryStore.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(filler-library): process-wide FillerLibraryStore + environment key"
  ```

### Task 1.6: End-of-chunk verification

- [ ] **Step 1: Run the full test suite, confirm no regressions.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/sm-chunk1.log | tail -8
  echo "FAIL=$(grep -E '✘ Test .* failed' /tmp/sm-chunk1.log | sort -u | wc -l)"
  ```
  Expected: FAIL count matches Chunk 0 baseline. Build succeeds.

- [ ] **Step 2: Verify the four new files are committed and tree is clean.**

  Run: `git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge status`
  Expected: only the standing `.xcuserstate` modification.

---

## Chunk 2: SmartCutViewModel session-aware init + persistence

This chunk adds an additive `init(session:library:coordinator:modelContext:)` to `SmartCutViewModel` plus a `persist(to:)` method. The existing `init(coordinator:library:service:cutter:)` stays so the in-tree `CleaningLabViewModel` and tests keep compiling — the new init is layered on top and lands the VM directly in `.results` when a cached transcript exists, or in `.error(message:)` when the source file is missing.

**Spec references:** §3.2 (SmartCutViewModel modification), §4.3 (persistence cadence), §5.1 (missing-source error), §5.2 (decode failure).

### Task 2.1: Add `persist(to:)` method (write side first, no init changes yet)

**Files:**
- Modify: `SonicMerge/Features/SmartCut/SmartCutViewModel.swift` (append a public method after the apply-block, around line 230)
- Test: `SonicMergeTests/SmartCutViewModelPersistTests.swift` (new)

- [ ] **Step 1: Write the failing test.**

  Create `SonicMergeTests/SmartCutViewModelPersistTests.swift`:

  ```swift
  import XCTest
  import SwiftData
  @testable import SonicMerge

  @MainActor
  final class SmartCutViewModelPersistTests: XCTestCase {

      private func makeContainer() throws -> ModelContainer {
          let schema = Schema([SmartCutSession.self])
          let config = ModelConfiguration(isStoredInMemoryOnly: true)
          return try ModelContainer(for: schema, configurations: config)
      }

      func test_persistWritesEditListJSONAndUpdatesLastOpenedAt() throws {
          let container = try makeContainer()
          let context = container.mainContext

          let session = SmartCutSession(
              name: "Test",
              sourceFilename: "source.m4a",
              sourceHashHex: "abc",
              durationSeconds: 30
          )
          context.insert(session)
          try context.save()

          let library = FillerLibrary(defaults: UserDefaults(suiteName: "test-\(UUID())")!)
          let coordinator = PlaybackCoordinator()
          let vm = SmartCutViewModel(coordinator: coordinator, library: library)

          // Inject a non-trivial editList via the existing test seam.
          let edits = EditList(
              fillers: [],
              pauses: [PauseEdit(timeRange: 1.0...2.5, isEnabled: true)]
          )
          vm._injectResultsForTesting(edits)

          let beforeOpenedAt = session.lastOpenedAt
          // Sleep one second so .now != beforeOpenedAt at observable resolution.
          Thread.sleep(forTimeInterval: 0.05)

          vm.persist(to: session)
          try context.save()

          XCTAssertNotNil(session.editListJSON)
          let decoded = try JSONDecoder().decode(EditList.self, from: session.editListJSON!)
          XCTAssertEqual(decoded, edits)
          XCTAssertGreaterThan(session.lastOpenedAt, beforeOpenedAt)
      }

      func test_persistWritesNilEditListJSONWhenEditListIsEmpty() throws {
          let container = try makeContainer()
          let context = container.mainContext

          let session = SmartCutSession(
              name: "Test",
              sourceFilename: "source.m4a",
              sourceHashHex: "abc",
              durationSeconds: 30
          )
          context.insert(session)

          let library = FillerLibrary(defaults: UserDefaults(suiteName: "test-\(UUID())")!)
          let coordinator = PlaybackCoordinator()
          let vm = SmartCutViewModel(coordinator: coordinator, library: library)
          // VM starts with empty editList — persist should write nil, not an
          // empty-list blob, so resume cleanly lands in .idle.
          vm.persist(to: session)

          XCTAssertNil(session.editListJSON)
      }
  }
  ```

- [ ] **Step 2: Run the test, expect compile failure (`persist(to:)` doesn't exist).**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:SonicMergeTests/SmartCutViewModelPersistTests \
    -parallel-testing-enabled NO test 2>&1 | tail -10
  ```
  Expected: `value of type 'SmartCutViewModel' has no member 'persist'`.

- [ ] **Step 3: Add the `persist(to:)` method.**

  Open `SonicMerge/Features/SmartCut/SmartCutViewModel.swift`. After the existing `apply()` method (currently lines 219–230), insert:

  ```swift
  // MARK: - Persistence (Smart Cut tab)

  /// Writes the current edit list (if non-empty) and `lastOpenedAt = .now` back
  /// onto the supplied SwiftData session record. Caller is responsible for
  /// `try modelContext.save()` if it wants the change durable immediately;
  /// SwiftData also auto-saves on context lifecycle. An empty edit list writes
  /// `editListJSON = nil` so a resumed session lands cleanly in `.idle`.
  func persist(to session: SmartCutSession) {
      let isMeaningful = !editList.fillers.isEmpty || !editList.pauses.isEmpty
      session.editListJSON = isMeaningful
          ? (try? JSONEncoder().encode(editList))
          : nil
      session.lastOpenedAt = .now
  }
  ```

  Note: `transcriptCacheRef` is set elsewhere (in the new init in Task 2.2 or by the analyze pipeline once that's wired); `persist(to:)` deliberately does NOT touch it because the cache file path is owned by the analyze pipeline, not by the edit-list mutation path.

- [ ] **Step 4: Run the test, expect PASS.**

  Run the same command from Step 2.
  Expected: both `SmartCutViewModelPersistTests` tests pass; the rest of the suite is untouched.

- [ ] **Step 5: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/Features/SmartCut/SmartCutViewModel.swift \
    SonicMergeTests/SmartCutViewModelPersistTests.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(smart-cut): SmartCutViewModel.persist(to: SmartCutSession)"
  ```

### Task 2.2: Add session-driven init

**Files:**
- Modify: `SonicMerge/Features/SmartCut/SmartCutViewModel.swift` (add a second init alongside the existing one, around line 50)
- Test: `SonicMergeTests/SmartCutViewModelSessionInitTests.swift` (new)

The new init resolves the source URL from `<AppGroup>/smart-cut/<id>/<sourceFilename>` (using `AppConstants.smartCutSessionDirectory(for:)`), calls existing `setInput(url:)` (which itself calls `SmartCutSourceLocator.register(hash:url:)`), decodes any persisted edit list, and lands in the right state:

- source missing → `.error(message: "Source file missing")`
- source present, no `editListJSON`, no `transcriptCacheRef` → `.idle`
- source present, valid `editListJSON` → load it; the VM stays in `.idle` until the user re-analyzes (we do NOT pre-fill `cachedSegments` from the edit list since the segments live separately in the transcript cache file)

The `transcriptCacheRef` plumbing — actually loading and parsing the cache file to land directly in `.results` without re-running analyze — is **out of scope for this chunk**. Reason: the cache file format and reader are owned by `TranscriptionService` which doesn't expose a public "load cached results from path" API today. Adding that API is a separate refactor and Chunk 6 covers wiring the deep-link case where it matters most. For now, `transcriptCacheRef` is stored but not consumed; the user re-analyzes on session resume, which is acceptable per spec §3.2 ("lands the VM in `.results` directly, not `.idle`" is the *aspirational* target — the spec also lists `.idle` as the fallback when the cache is missing/unreadable in §5.3).

**Open question note for the implementer:** if the spec author wants direct `.results` resume on first ship, surface this and add a `TranscriptionService.loadCachedResults(from: URL) -> EditList?` API as a precursor task. Otherwise `.idle` resume is the documented behavior.

- [ ] **Step 1: Write the failing test.**

  Create `SonicMergeTests/SmartCutViewModelSessionInitTests.swift`:

  ```swift
  import XCTest
  import SwiftData
  @testable import SonicMerge

  @MainActor
  final class SmartCutViewModelSessionInitTests: XCTestCase {

      private func makeContainer() throws -> ModelContainer {
          let schema = Schema([SmartCutSession.self])
          let config = ModelConfiguration(isStoredInMemoryOnly: true)
          return try ModelContainer(for: schema, configurations: config)
      }

      private func makeTempAudioFile() throws -> URL {
          let url = FileManager.default.temporaryDirectory
              .appending(path: "smartcut-init-test-\(UUID().uuidString).m4a")
          // Minimal placeholder bytes; the VM only checks existence here.
          try Data([0x00, 0x01, 0x02]).write(to: url)
          return url
      }

      func test_sessionInitWithMissingSourceLandsInError() throws {
          let container = try makeContainer()
          let context = container.mainContext

          let session = SmartCutSession(
              name: "Missing",
              sourceFilename: "does-not-exist.m4a",
              sourceHashHex: "deadbeef",
              durationSeconds: 30
          )
          context.insert(session)

          let library = FillerLibrary(defaults: UserDefaults(suiteName: "test-\(UUID())")!)
          let coordinator = PlaybackCoordinator()

          let vm = SmartCutViewModel(
              session: session,
              library: library,
              coordinator: coordinator,
              modelContext: context
          )

          if case .error(let message) = vm.state {
              XCTAssertEqual(message, "Source file missing")
          } else {
              XCTFail("Expected .error state, got \(vm.state)")
          }
      }

      /// Stages a real source file at the sandbox-fallback path the new init
      /// computes when the App Group entitlement is unavailable. This is the
      /// hook that lets the entitlement-free test host exercise the
      /// "source-present" branches of the init.
      private func stageSourceFileAtFallbackPath(for session: SmartCutSession) throws -> URL {
          let dir = FileManager.default.temporaryDirectory
              .appending(path: "smart-cut-fallback")
              .appending(path: session.id.uuidString)
          try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
          let url = dir.appending(path: session.sourceFilename)
          try Data([0x00, 0x01, 0x02]).write(to: url)
          return url
      }

      func test_sessionInitWithEmptyEditListLandsInIdle() throws {
          // Skip when App Group is entitled — this test exercises the sandbox
          // fallback path explicitly, and an entitled host would route to a
          // different (production) directory and miss the staged file.
          if FileManager.default.containerURL(
              forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
          ) != nil {
              throw XCTSkip("Sandbox-fallback test only runs on unentitled hosts")
          }

          let container = try makeContainer()
          let context = container.mainContext

          let session = SmartCutSession(
              name: "Empty",
              sourceFilename: "source.m4a",
              sourceHashHex: "deadbeef",
              durationSeconds: 30
          )
          context.insert(session)
          _ = try stageSourceFileAtFallbackPath(for: session)

          let library = FillerLibrary(defaults: UserDefaults(suiteName: "test-\(UUID())")!)
          let coordinator = PlaybackCoordinator()

          let vm = SmartCutViewModel(
              session: session,
              library: library,
              coordinator: coordinator,
              modelContext: context
          )

          XCTAssertEqual(vm.state, .idle)
          XCTAssertTrue(vm.editList.fillers.isEmpty)
          XCTAssertTrue(vm.editList.pauses.isEmpty)
      }

      func test_sessionInitWithValidEditListJSONDecodesIntoVM() throws {
          if FileManager.default.containerURL(
              forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
          ) != nil {
              throw XCTSkip("Sandbox-fallback test only runs on unentitled hosts")
          }

          let container = try makeContainer()
          let context = container.mainContext

          let session = SmartCutSession(
              name: "WithEdits",
              sourceFilename: "source.m4a",
              sourceHashHex: "abc",
              durationSeconds: 30
          )
          let edits = EditList(
              fillers: [],
              pauses: [PauseEdit(timeRange: 1.0...2.5, isEnabled: true)]
          )
          session.editListJSON = try JSONEncoder().encode(edits)
          context.insert(session)
          _ = try stageSourceFileAtFallbackPath(for: session)

          let library = FillerLibrary(defaults: UserDefaults(suiteName: "test-\(UUID())")!)
          let coordinator = PlaybackCoordinator()

          let vm = SmartCutViewModel(
              session: session,
              library: library,
              coordinator: coordinator,
              modelContext: context
          )

          XCTAssertEqual(vm.editList, edits)
          // State stays .idle until the user re-analyzes — see Task 2.2 design
          // note about transcript-cache resume being a follow-up.
          XCTAssertEqual(vm.state, .idle)
      }

      func test_sessionInitWithCorruptEditListJSONClearsBlobAndLandsInIdle() throws {
          if FileManager.default.containerURL(
              forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
          ) != nil {
              throw XCTSkip("Sandbox-fallback test only runs on unentitled hosts")
          }

          let container = try makeContainer()
          let context = container.mainContext

          let session = SmartCutSession(
              name: "Corrupt",
              sourceFilename: "source.m4a",
              sourceHashHex: "abc",
              durationSeconds: 30
          )
          // Garbage bytes that JSONDecoder cannot parse as EditList.
          session.editListJSON = Data([0xFF, 0xFE, 0xFD])
          context.insert(session)
          _ = try stageSourceFileAtFallbackPath(for: session)

          let library = FillerLibrary(defaults: UserDefaults(suiteName: "test-\(UUID())")!)
          let coordinator = PlaybackCoordinator()

          let vm = SmartCutViewModel(
              session: session,
              library: library,
              coordinator: coordinator,
              modelContext: context
          )

          XCTAssertEqual(vm.state, .idle)
          XCTAssertNil(session.editListJSON, "corrupt blob should be cleared on decode failure (spec §5.2)")
      }
  }
  ```

  Note: tests use the sandbox-fallback path the new init computes when App Group is unavailable, so they run on the default unentitled test host. They `XCTSkip` on entitled hosts (where the production App Group path would be used and the staged file wouldn't be visible). The missing-source test runs everywhere because it just checks the existence-gate behavior.

- [ ] **Step 2: Run the test, expect compile failure (no `init(session:...)` overload).**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:SonicMergeTests/SmartCutViewModelSessionInitTests \
    -parallel-testing-enabled NO test 2>&1 | tail -10
  ```
  Expected: `extra argument 'session' in call` or `cannot find 'session' parameter`.

- [ ] **Step 3: Add the new init.**

  Open `SonicMerge/Features/SmartCut/SmartCutViewModel.swift`. After the existing `init(coordinator:library:service:cutter:)` block (currently lines 50–59), insert:

  ```swift
  /// Session-driven init used by SmartCutSessionView. Resolves the source URL
  /// from the App Group container (or the sandbox fallback when entitlement is
  /// unavailable — see SonicMergeApp.swift's modelContainer for the same
  /// pattern), registers the source hash with SmartCutSourceLocator so a
  /// background-transcription task can find the file on resume, decodes any
  /// persisted edit list, and lands the VM in the appropriate state.
  ///
  /// State landing rules (spec §5.1, §5.2, §5.3):
  ///   - source file missing → .error(message: "Source file missing")
  ///   - source present, no editListJSON → .idle
  ///   - source present, valid editListJSON → editList loaded; state stays .idle
  ///     (re-analyze regenerates cachedSegments; transcript-cache resume is a
  ///     follow-up — see Task 2.2 design note in the plan)
  ///
  /// `modelContext` is captured for future use (currently unused; reserved for
  /// session lifecycle hooks Task 2.3+).
  convenience init(
      session: SmartCutSession,
      library: FillerLibrary,
      coordinator: PlaybackCoordinator,
      modelContext: ModelContext
  ) {
      self.init(coordinator: coordinator, library: library)

      // Resolve source URL. App Group path first; fall back to a deterministic
      // tmp directory if the entitlement is missing. The sandbox path is only
      // useful for unit tests — production always has the entitlement.
      let sourceURL: URL
      if let dir = try? AppConstants.smartCutSessionDirectory(for: session.id) {
          sourceURL = dir.appending(path: session.sourceFilename)
      } else {
          // Sandbox fallback (test-host path). Mirrors the production layout
          // so unit tests can stage source files at a predictable location
          // without needing the App Group entitlement.
          let dir = FileManager.default.temporaryDirectory
              .appending(path: "smart-cut-fallback")
              .appending(path: session.id.uuidString)
          try? FileManager.default.createDirectory(
              at: dir, withIntermediateDirectories: true
          )
          sourceURL = dir.appending(path: session.sourceFilename)
      }

      // Existence gate.
      guard FileManager.default.fileExists(atPath: sourceURL.path) else {
          state = .error(message: "Source file missing")
          return
      }

      // Spec §3.2: register the persisted source hash → URL mapping
      // synchronously, so a background-transcription notification arriving
      // immediately can resolve the source via SmartCutSourceLocator.
      // Note: setInput(url:) at line 68 also computes & registers an async
      // hash; that's a redundant write to the same key with the same value
      // (since session.sourceHashHex was computed from the same bytes) and
      // is harmless. Keeping both gives us synchronous-on-init guarantees
      // plus the existing setInput contract for callers that don't have a
      // pre-computed hash.
      SmartCutSourceLocator.register(hash: session.sourceHashHex, url: sourceURL)

      // Wire the input (also kicks off the async duration probe used by the
      // "Analyze ~N min" estimate label).
      setInput(url: sourceURL)

      // Decode any persisted edit list. On any decode failure we drop the
      // blob and leave the VM in .idle so the user can re-analyze.
      if let json = session.editListJSON {
          do {
              let decoded = try JSONDecoder().decode(EditList.self, from: json)
              editList = decoded
          } catch {
              session.editListJSON = nil
          }
      }
  }
  ```

- [ ] **Step 4: Run the test.**

  Run the same command from Step 2.
  Expected on the default unentitled test host: all four tests pass (`test_sessionInitWithMissingSourceLandsInError`, `test_sessionInitWithEmptyEditListLandsInIdle`, `test_sessionInitWithValidEditListJSONDecodesIntoVM`, `test_sessionInitWithCorruptEditListJSONClearsBlobAndLandsInIdle`). On an entitled host the three sandbox-fallback tests `XCTSkip`; the missing-source test passes everywhere. Build succeeds in both cases.

- [ ] **Step 5: Run the full test suite, confirm no regressions.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/sm-2-2.log | tail -8
  echo "FAIL=$(grep -E '✘ Test .* failed' /tmp/sm-2-2.log | sort -u | wc -l)"
  ```
  Expected: FAIL count matches Chunk 0 baseline.

- [ ] **Step 6: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/Features/SmartCut/SmartCutViewModel.swift \
    SonicMergeTests/SmartCutViewModelSessionInitTests.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(smart-cut): session-driven SmartCutViewModel init"
  ```

### Task 2.3: End-of-chunk verification

- [ ] **Step 1: Run the full test suite.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/sm-chunk2.log | tail -8
  echo "FAIL=$(grep -E '✘ Test .* failed' /tmp/sm-chunk2.log | sort -u | wc -l)"
  ```
  Expected: FAIL count matches Chunk 0 baseline.

- [ ] **Step 2: Confirm tree is clean.**

  Run: `git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge status`
  Expected: only the standing `.xcuserstate` modification.

---

## Chunk 3: Smart Cut tab views (Home + Session)

This chunk adds the two views the new Smart Cut tab needs: a recents-list home with an Upload Audio CTA, and a push-destination session view that wraps the existing `SmartCutStudioContainer`. Neither view is reachable yet — the app still boots into `MixingStationView`. The wiring happens in Chunk 5.

**Spec references:** §3.1 (file responsibilities), §4.3 (SmartCutSessionView), §4.6 (Upload Audio flow), §4.7 (empty vs loaded states), §4.8 (toolbar), §4.9 (FillerLibrary ownership).

### Task 3.1: `SmartCutSessionView` (push destination)

**Files:**
- Create: `SonicMerge/Features/SmartCut/Views/Home/SmartCutSessionView.swift`

`SmartCutSessionView` resolves a session by ID, builds a `SmartCutViewModel`, hosts `SmartCutStudioContainer`, persists edit-list mutations on disappear, and exposes a delete-session action.

- [ ] **Step 1: Create the view.**

  Create `SonicMerge/Features/SmartCut/Views/Home/SmartCutSessionView.swift`:

  ```swift
  // SmartCutSessionView.swift
  // SonicMerge
  //
  // Push destination from SmartCutHomeView. Resolves a SmartCutSession by ID,
  // owns a per-session SmartCutViewModel, and renders SmartCutStudioContainer
  // as its body. Persists edit-list state back to the session on disappear.
  //
  // Spec: §4.3 (lifecycle), §4.6 (created from upload), §4.8 (toolbar).

  import SwiftUI
  import SwiftData

  struct SmartCutSessionView: View {
      let sessionId: UUID

      @Environment(\.modelContext) private var modelContext
      @Environment(\.dismiss) private var dismiss
      @Environment(\.fillerLibrary) private var libraryStore

      @State private var viewModel: SmartCutViewModel?
      @State private var session: SmartCutSession?
      @State private var showDeleteConfirm = false

      var body: some View {
          Group {
              if let viewModel, let session {
                  SmartCutStudioContainer(vm: viewModel, library: libraryStore.binding)
                      .navigationTitle(session.name)
                      .navigationBarTitleDisplayMode(.inline)
                      .toolbar { toolbarContent }
              } else {
                  ProgressView()
                      .frame(maxWidth: .infinity, maxHeight: .infinity)
              }
          }
          .task { await load() }
          .onDisappear {
              if let vm = viewModel, let session {
                  vm.cancelAnalyze()
                  vm.persist(to: session)
                  try? modelContext.save()
              }
          }
          .confirmationDialog(
              "Delete this Smart Cut session?",
              isPresented: $showDeleteConfirm,
              titleVisibility: .visible
          ) {
              Button("Delete", role: .destructive) { performDelete() }
              Button("Cancel", role: .cancel) {}
          } message: {
              Text("The source audio and any saved edits will be removed.")
          }
      }

      @ToolbarContentBuilder
      private var toolbarContent: some ToolbarContent {
          ToolbarItem(placement: .topBarTrailing) {
              Menu {
                  Button(role: .destructive) {
                      showDeleteConfirm = true
                  } label: {
                      Label("Delete session", systemImage: "trash")
                  }
              } label: {
                  Label("More", systemImage: "ellipsis.circle")
              }
          }
      }

      private func load() async {
          let descriptor = FetchDescriptor<SmartCutSession>(
              predicate: #Predicate { $0.id == sessionId }
          )
          guard let fetched = try? modelContext.fetch(descriptor).first else {
              dismiss()
              return
          }
          fetched.lastOpenedAt = .now
          try? modelContext.save()

          let coordinator = PlaybackCoordinator()
          let vm = SmartCutViewModel(
              session: fetched,
              library: libraryStore.library,
              coordinator: coordinator,
              modelContext: modelContext
          )
          self.session = fetched
          self.viewModel = vm
      }

      private func performDelete() {
          guard let session else { return }
          // Best-effort filesystem cleanup; SwiftData delete is the source of truth.
          if let dir = try? AppConstants.smartCutSessionDirectory(for: session.id) {
              try? FileManager.default.removeItem(at: dir)
          }
          modelContext.delete(session)
          try? modelContext.save()
          dismiss()
      }
  }
  ```

- [ ] **Step 2: Build to confirm it compiles.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -10
  ```
  Expected: `** BUILD SUCCEEDED **`. The view isn't presented yet — Chunk 5 wires it in.

- [ ] **Step 3: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/Features/SmartCut/Views/Home/SmartCutSessionView.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(smart-cut): SmartCutSessionView push destination"
  ```

### Task 3.2: `SmartCutHomeView` (recents + Upload Audio)

**Files:**
- Create: `SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift`

The home view's job:
- `@Query` recents sorted by `lastOpenedAt` desc, limit 20.
- Empty state when no sessions: orb, tagline, large Upload Audio button.
- Loaded state: Upload Audio CTA pinned at top, scrollable list of recents below.
- Tap a recent → push the matching `UUID` onto the parent NavigationStack's path.
- Swipe-left to delete.
- The Upload Audio flow is exactly the 10 steps from spec §4.6.

The view does NOT own the NavigationStack path — it's bound from the parent (`RootTabView`) and passed through the environment via a closure (simpler than threading a path binding). The `onUpload` and `onSelect` closures are the seams.

- [ ] **Step 1: Create the view.**

  Create `SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift`:

  ```swift
  // SmartCutHomeView.swift
  // SonicMerge
  //
  // Smart Cut tab root. Recents list + Upload Audio CTA. Push-on-tap is
  // implemented via the `onSelect` closure passed in by RootTabView (which
  // owns the NavigationStack path binding for this tab).
  //
  // Spec: §4.6 (Upload Audio flow), §4.7 (empty vs loaded), §4.8 (toolbar).

  import SwiftUI
  import SwiftData
  import UniformTypeIdentifiers
  import AVFoundation

  struct SmartCutHomeView: View {
      /// Called with the freshly created (or tapped) session ID. RootTabView
      /// appends it onto the Smart Cut tab's NavigationStack path.
      let onSelect: (UUID) -> Void

      @Environment(\.modelContext) private var modelContext
      @Environment(\.sonicMergeSemantic) private var semantic

      @Query(sort: \SmartCutSession.lastOpenedAt, order: .reverse, animation: .default)
      private var sessions: [SmartCutSession]

      @State private var showFileImporter = false
      @State private var importErrorMessage: String?

      var body: some View {
          ZStack {
              PremiumBackground()
              if sessions.isEmpty {
                  emptyState
              } else {
                  loadedState
              }
          }
          .navigationTitle("Smart Cut")
          .navigationBarTitleDisplayMode(.large)
          .fileImporter(
              isPresented: $showFileImporter,
              allowedContentTypes: UTType.audioImportTypes,
              allowsMultipleSelection: false
          ) { result in
              Task { await handleImport(result: result) }
          }
          .alert(
              "Couldn't import this file",
              isPresented: Binding(
                  get: { importErrorMessage != nil },
                  set: { if !$0 { importErrorMessage = nil } }
              )
          ) {
              Button("OK") {}
          } message: {
              Text(importErrorMessage ?? "")
          }
      }

      // MARK: - Empty state (no sessions)

      private var emptyState: some View {
          VStack(spacing: SonicMergeTheme.Spacing.md) {
              Image(systemName: "sparkles")
                  .font(.system(size: 56, weight: .bold))
                  .foregroundStyle(Color(uiColor: semantic.accentAI))
                  .accessibilityHidden(true)
              Text("Cut fillers in seconds")
                  .font(.system(.title3, design: .rounded, weight: .semibold))
                  .foregroundStyle(Color(uiColor: semantic.textPrimary))
              Text("Upload a recording and we'll find every \"um,\" \"uh,\" and long pause.")
                  .font(.system(.body, design: .rounded))
                  .foregroundStyle(Color(uiColor: semantic.textSecondary))
                  .multilineTextAlignment(.center)
                  .padding(.horizontal, 32)
              Button {
                  showFileImporter = true
              } label: {
                  Label("Upload Audio", systemImage: "plus.circle.fill")
              }
              .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
          }
      }

      // MARK: - Loaded state (has sessions)

      private var loadedState: some View {
          VStack(spacing: 0) {
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

              List {
                  ForEach(sessions) { session in
                      SmartCutRecentRow(session: session)
                          .contentShape(Rectangle())
                          .onTapGesture { onSelect(session.id) }
                          .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                              Button(role: .destructive) {
                                  delete(session)
                              } label: {
                                  Label("Delete", systemImage: "trash")
                              }
                          }
                  }
              }
              .listStyle(.plain)
              .scrollContentBackground(.hidden)
          }
      }

      // MARK: - Upload flow (spec §4.6)

      private func handleImport(result: Result<[URL], Error>) async {
          switch result {
          case .success(let urls):
              guard let pickedURL = urls.first else { return }
              await createSession(from: pickedURL)
          case .failure(let error):
              importErrorMessage = error.localizedDescription
          }
      }

      private func createSession(from pickedURL: URL) async {
          // 1. Security-scoped resource handling (the URL from .fileImporter is sandboxed).
          let didStart = pickedURL.startAccessingSecurityScopedResource()
          defer { if didStart { pickedURL.stopAccessingSecurityScopedResource() } }

          let sessionId = UUID()
          let ext = pickedURL.pathExtension.isEmpty ? "m4a" : pickedURL.pathExtension.lowercased()
          let basename = pickedURL.deletingPathExtension().lastPathComponent

          // 2. Resolve session directory (creates if missing).
          let dir: URL
          do {
              dir = try AppConstants.smartCutSessionDirectory(for: sessionId)
          } catch {
              importErrorMessage = error.localizedDescription
              return
          }

          let destURL = dir.appending(path: "source.\(ext)")

          // 3. Copy the picked file into the session dir. Wrap in do/catch so a
          //    disk-full or permission-revoked failure doesn't leave us with a
          //    half-created session record.
          do {
              if FileManager.default.fileExists(atPath: destURL.path) {
                  try FileManager.default.removeItem(at: destURL)
              }
              try FileManager.default.copyItem(at: pickedURL, to: destURL)
          } catch {
              try? FileManager.default.removeItem(at: dir) // orphan cleanup
              importErrorMessage = "Couldn't import this file. \(error.localizedDescription)"
              return
          }

          // 4. Probe duration.
          let duration: Double
          do {
              duration = try await AVURLAsset(url: destURL).load(.duration).seconds
          } catch {
              try? FileManager.default.removeItem(at: dir)
              importErrorMessage = "This file isn't a valid audio recording."
              return
          }

          // 5. Compute source hash.
          let sourceHash: String
          do {
              sourceHash = try await SourceHasher.sha256Hex(of: destURL)
          } catch {
              try? FileManager.default.removeItem(at: dir)
              importErrorMessage = "Couldn't read this file."
              return
          }

          // 6. Insert SwiftData record + push.
          let session = SmartCutSession(
              id: sessionId,
              name: basename,
              sourceFilename: "source.\(ext)",
              sourceHashHex: sourceHash,
              durationSeconds: duration
          )
          modelContext.insert(session)
          do {
              try modelContext.save()
          } catch {
              try? FileManager.default.removeItem(at: dir)
              importErrorMessage = "Couldn't save the session. \(error.localizedDescription)"
              return
          }

          onSelect(sessionId)
      }

      private func delete(_ session: SmartCutSession) {
          if let dir = try? AppConstants.smartCutSessionDirectory(for: session.id) {
              try? FileManager.default.removeItem(at: dir)
          }
          modelContext.delete(session)
          try? modelContext.save()
      }
  }

  // MARK: - SmartCutRecentRow

  private struct SmartCutRecentRow: View {
      let session: SmartCutSession
      @Environment(\.sonicMergeSemantic) private var semantic

      var body: some View {
          HStack(spacing: 12) {
              RoundedRectangle(cornerRadius: 9, style: .continuous)
                  .fill(LinearGradient(
                      colors: [Color(uiColor: semantic.accentAI), Color(uiColor: semantic.accentAction)],
                      startPoint: .topLeading,
                      endPoint: .bottomTrailing
                  ))
                  .frame(width: 36, height: 36)
                  .overlay(
                      Image(systemName: "play.fill")
                          .font(.system(size: 12, weight: .bold))
                          .foregroundStyle(.white)
                  )
              VStack(alignment: .leading, spacing: 2) {
                  Text(session.name)
                      .font(.subheadline.weight(.semibold))
                      .lineLimit(1)
                      .truncationMode(.middle)
                      .foregroundStyle(Color(uiColor: semantic.textPrimary))
                  Text(formatSubtitle(session))
                      .font(.caption)
                      .foregroundStyle(Color(uiColor: semantic.textSecondary))
              }
              Spacer()
          }
          .padding(.vertical, 6)
      }

      private func formatSubtitle(_ session: SmartCutSession) -> String {
          let duration = formatDuration(session.durationSeconds)
          let relative = RelativeDateTimeFormatter().localizedString(
              for: session.lastOpenedAt, relativeTo: .now
          )
          return "\(duration) · \(relative)"
      }

      private func formatDuration(_ seconds: Double) -> String {
          let total = Int(seconds)
          let m = total / 60
          let s = total % 60
          return m > 0 ? "\(m) min" : "\(s) s"
      }
  }
  ```

- [ ] **Step 2: Build to confirm it compiles.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -10
  ```
  Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(smart-cut): SmartCutHomeView with recents + Upload Audio flow"
  ```

### Task 3.3: End-of-chunk verification

- [ ] **Step 1: Full test suite passes.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/sm-chunk3.log | tail -8
  echo "FAIL=$(grep -E '✘ Test .* failed' /tmp/sm-chunk3.log | sort -u | wc -l)"
  ```
  Expected: FAIL count matches Chunk 0 baseline.

- [ ] **Step 2: Tree clean.**

  Run: `git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge status`
  Expected: only `.xcuserstate`.

---

## Chunk 4: Denoise tab — strip and split CleaningLabViewModel; new home + session views

Largest chunk. We rename `CleaningLabViewModel` → `DenoiseSessionViewModel` and remove its embedded `SmartCutViewModel`, the merged-URL Smart Cut bridging, the Smart Cut-aware `exportSource` fallback, and the `onIntensityChanged` Smart Cut notification. We then create the Denoise tab views (mirror of Smart Cut). `CleaningLabView` itself is NOT deleted in this chunk — it still imports `CleaningLabViewModel` indirectly via `MixingStationView`. Both go away in Chunk 5.

**Spec references:** §3.1, §3.2 (CleaningLabViewModel rename), §3.3 (CleaningLabView retires).

### Task 4.1: Rename `CleaningLabViewModel` → `DenoiseSessionViewModel` and strip Smart Cut

**Files:**
- Modify (via rename): `SonicMerge/Features/Denoising/CleaningLabViewModel.swift` → `SonicMerge/Features/Denoising/DenoiseSessionViewModel.swift`
- Modify: `SonicMerge/Features/Denoising/CleaningLabView.swift` (line ~61: type ref)
- Modify: `SonicMergeTests/CleaningLabViewModelTests.swift` (rename type references)

This is a multi-step edit. Do all the renames in one commit so the build is never broken at HEAD.

- [ ] **Step 1: Move the file and rename the class.**

  Run: `git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge mv SonicMerge/Features/Denoising/CleaningLabViewModel.swift SonicMerge/Features/Denoising/DenoiseSessionViewModel.swift`

  Then in the renamed file, change `final class CleaningLabViewModel {` → `final class DenoiseSessionViewModel {`. Also rename the `extension CleaningLabViewModel: PlaybackParticipant` at the bottom of the file → `extension DenoiseSessionViewModel: PlaybackParticipant`.

- [ ] **Step 2: Strip Smart Cut wiring.**

  In `DenoiseSessionViewModel.swift`, delete:
  - The `private(set) var smartCutVM: SmartCutViewModel!` declaration (currently line 98).
  - The `func setMergedFileURL(_ url: URL)` method (lines 128–131).
  - The `func notifySmartCutOfDenoiseChange()` private method (lines 134–140).
  - The `var exportSource: URL?` computed (lines 102–104) — replace with `var exportSource: URL? { denoisedTempURL ?? mergedFileURL }`.
  - In `init`, delete `self.smartCutVM = SmartCutViewModel(coordinator: ..., library: ...)` (lines 120–121).
  - In `startDenoising`, delete the closing-block call to `notifySmartCutOfDenoiseChange()` (line 232).
  - In `onIntensityChanged`, delete the closing-block call to `notifySmartCutOfDenoiseChange()` (line 310).
  - The `var fillerLibrary = FillerLibrary()` field (line 92) — Denoise no longer owns the library; it lives on `FillerLibraryStore` (Chunk 1.5).

- [ ] **Step 3: Update consumers.**

  In `SonicMerge/Features/Denoising/CleaningLabView.swift` line 61:

  ```swift
  @State private var viewModel = CleaningLabViewModel()
  ```

  → change to:

  ```swift
  @State private var viewModel = DenoiseSessionViewModel()
  ```

  Then remove every reference to `viewModel.smartCutVM` and `viewModel.fillerLibrary` from `CleaningLabView.swift`. The exact call sites (verified against current HEAD via `grep -n "smartCutVM\|fillerLibrary" CleaningLabView.swift`):

  | Line(s) | What to do |
  |---|---|
  | 211–212 | The `SmartCutStudioContainer(vm: viewModel.smartCutVM, library: $viewModel.fillerLibrary)` inside `smartCutContent` — replaced wholesale by the placeholder shown below. |
  | 225 | `let s = viewModel.smartCutVM.state` inside `shouldShowFloatingBar` — change `shouldShowFloatingBar` to `case .denoise: return true` only and drop the `.smartCut` case. |
  | 228 | `case .applied: return viewModel.smartCutVM.hasDirtyEditsSinceApply` — drop with the `.smartCut` case. |
  | 262 | `let vm: SmartCutViewModel = viewModel.smartCutVM` inside the floating-bar's Smart Cut branch — drop the entire Smart Cut floating-bar branch. |
  | 299 | `let inputURL = viewModel.smartCutVM.inputURL` — drop with the Smart Cut branch. |
  | 308 | `viewModel.smartCutVM.analyze()` — drop with the Smart Cut branch. |
  | 506 (comment only) | Remove the `sc-t19` source-resolution comment line. |

  Replace `smartCutContent` (the body around line 210) with:

  ```swift
  @ViewBuilder
  private var smartCutContent: some View {
      Text("Smart Cut moved to its own tab")
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
  ```

  Delete the call to `viewModel.setMergedFileURL(mergedFileURL)` in `.onAppear`. Delete the deep-link `handlePendingSmartCutOpenIfNeeded()` body or stub it to a no-op (Chunk 6 reroutes it through `RootTabView`).

  In `SonicMergeTests/CleaningLabViewModelTests.swift`, rename every `CleaningLabViewModel` → `DenoiseSessionViewModel` (class references only — the file name can stay until Chunk 5 retires it alongside `CleaningLabView`).

- [ ] **Step 4: Build, run tests.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/sm-4-1.log | tail -8
  echo "FAIL=$(grep -E '✘ Test .* failed' /tmp/sm-4-1.log | sort -u | wc -l)"
  ```
  Expected: build succeeds. FAIL count matches Chunk 0 baseline. (`CleaningLabViewModelTests` may need adjusted assertions for any tests that exercised the embedded Smart Cut wiring — strip those test methods if so.)

- [ ] **Step 5: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add -A
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "refactor(denoise): rename CleaningLabViewModel → DenoiseSessionViewModel; strip Smart Cut wiring"
  ```

### Task 4.2: Add session-driven init to `DenoiseSessionViewModel`

**Files:**
- Modify: `SonicMerge/Features/Denoising/DenoiseSessionViewModel.swift`
- Test: `SonicMergeTests/DenoiseSessionViewModelInitTests.swift` (new)

The new init takes a `DenoiseSession`, resolves the source URL from `<AppGroup>/denoise/<id>/<sourceFilename>`, sets `mergedFileURL = sourceURL` (so the existing `startDenoising(mergedFileURL:)` path works), and restores `intensity` and `processedFilename` from the session if present.

- [ ] **Step 1: Write the failing test.**

  Create `SonicMergeTests/DenoiseSessionViewModelInitTests.swift`:

  ```swift
  import XCTest
  import SwiftData
  @testable import SonicMerge

  @MainActor
  final class DenoiseSessionViewModelInitTests: XCTestCase {

      func test_sessionInitRestoresIntensityAndExposesSourceAsMergedFileURL() throws {
          if FileManager.default.containerURL(
              forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
          ) != nil {
              throw XCTSkip("Sandbox-fallback test only runs on unentitled hosts")
          }

          let schema = Schema([DenoiseSession.self])
          let config = ModelConfiguration(isStoredInMemoryOnly: true)
          let container = try ModelContainer(for: schema, configurations: config)
          let context = container.mainContext

          let session = DenoiseSession(
              name: "Lecture",
              sourceFilename: "source.wav",
              durationSeconds: 60,
              intensity: 0.62
          )
          context.insert(session)

          // Stage source at sandbox-fallback path.
          let dir = FileManager.default.temporaryDirectory
              .appending(path: "denoise-fallback")
              .appending(path: session.id.uuidString)
          try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
          let url = dir.appending(path: "source.wav")
          try Data([0x00, 0x01, 0x02]).write(to: url)

          let vm = DenoiseSessionViewModel(session: session, modelContext: context)

          XCTAssertEqual(vm.intensity, 0.62, accuracy: 0.0001)
          XCTAssertEqual(vm.mergedFileURL?.lastPathComponent, "source.wav")
      }
  }
  ```

- [ ] **Step 2: Run, expect compile failure.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:SonicMergeTests/DenoiseSessionViewModelInitTests \
    -parallel-testing-enabled NO test 2>&1 | tail -10
  ```
  Expected: `extra argument 'session' in call` or `cannot find ... in scope`.

- [ ] **Step 3: Add the new init.**

  In `DenoiseSessionViewModel.swift`, after the existing `init(...)` block (now slimmed by Step 4.1), add:

  ```swift
  /// Session-driven init used by DenoiseSessionView. Resolves the source URL
  /// from the App Group container (or sandbox fallback) and primes the VM so
  /// the existing startDenoising / A/B / blend pipeline works as before.
  ///
  /// `processedFilename` is restored to `denoisedTempURL` if the file still
  /// exists on disk, so resuming a session shows the prior denoise result
  /// without re-running the pipeline. Intensity is restored from the session.
  convenience init(session: DenoiseSession, modelContext: ModelContext) {
      self.init()

      let sourceURL: URL
      if let dir = try? AppConstants.denoiseSessionDirectory(for: session.id) {
          sourceURL = dir.appending(path: session.sourceFilename)
      } else {
          let dir = FileManager.default.temporaryDirectory
              .appending(path: "denoise-fallback")
              .appending(path: session.id.uuidString)
          try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
          sourceURL = dir.appending(path: session.sourceFilename)
      }

      guard FileManager.default.fileExists(atPath: sourceURL.path) else {
          errorMessage = "Source file missing"
          return
      }

      mergedFileURL = sourceURL
      intensity = Float(session.intensity)

      // Restore prior processed (denoised) audio if it still exists. The view
      // can show A/B comparison immediately on resume.
      if let processedFilename = session.processedFilename,
         let dir = try? AppConstants.denoiseSessionDirectory(for: session.id) {
          let processedURL = dir.appending(path: processedFilename)
          if FileManager.default.fileExists(atPath: processedURL.path) {
              denoisedTempURL = processedURL
              hasDenoisedResult = true
          }
      }
  }

  /// Persist current intensity and (if present) processed filename back to
  /// the session record. Caller saves modelContext.
  func persist(to session: DenoiseSession) {
      session.intensity = Double(intensity)
      session.processedFilename = denoisedTempURL?.lastPathComponent
      session.lastOpenedAt = .now
  }
  ```

- [ ] **Step 4: Run the test, expect PASS.**

  Run the same command from Step 2.
  Expected: PASS.

- [ ] **Step 5: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/Features/Denoising/DenoiseSessionViewModel.swift \
    SonicMergeTests/DenoiseSessionViewModelInitTests.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(denoise): session-driven DenoiseSessionViewModel init + persist"
  ```

### Task 4.3: `DenoiseSessionView` (push destination, hosts existing denoise content)

**Files:**
- Create: `SonicMerge/Features/Denoising/Views/Home/DenoiseSessionView.swift`

`DenoiseSessionView` resolves a `DenoiseSession` by ID, owns a `DenoiseSessionViewModel`, and renders the existing denoise content (currently inside `CleaningLabView`'s `denoiseContent` body). For now we lift those subviews structurally — they reference `viewModel` properties that haven't moved.

The cleanest approach: copy the `denoiseContent` body and floating-bar block from `CleaningLabView.swift` into `DenoiseSessionView.swift` and adapt the `viewModel` reference. `CleaningLabView.swift` will be deleted in Chunk 5; until then both views exist with similar bodies, which is OK because the new one isn't reachable yet.

- [ ] **Step 1: Create the view.**

  Create `SonicMerge/Features/Denoising/Views/Home/DenoiseSessionView.swift`:

  ```swift
  // DenoiseSessionView.swift
  // SonicMerge
  //
  // Push destination from DenoiseHomeView. Resolves a DenoiseSession by ID,
  // owns a per-session DenoiseSessionViewModel, and renders the denoise UI
  // (orb + intensity + A/B + waveform + floating Apply CTA).
  //
  // Body is structurally identical to CleaningLabView's denoiseContent +
  // floating-bar block; CleaningLabView retires in Chunk 5.

  import SwiftUI
  import SwiftData
  import AVFoundation

  struct DenoiseSessionView: View {
      let sessionId: UUID

      @Environment(\.modelContext) private var modelContext
      @Environment(\.dismiss) private var dismiss
      @Environment(\.sonicMergeSemantic) private var semantic

      @State private var viewModel: DenoiseSessionViewModel?
      @State private var session: DenoiseSession?
      @State private var showDeleteConfirm = false
      @State private var showExportSheet = false

      // Same trust-strip flag as Mixing Station / former Cleaning Lab.
      @AppStorage("sonicMerge.hasImportedFirstClip") private var hasImportedFirstClip: Bool = false

      var body: some View {
          Group {
              if let viewModel, let session {
                  ScrollView {
                      VStack(spacing: SonicMergeTheme.Spacing.md) {
                          // Trust strip / on-device-AI banner — first launch only,
                          // mirrors the Mixing Station / former Cleaning Lab gate.
                          if !hasImportedFirstClip {
                              Text("Runs on-device. Audio never leaves your phone.")
                                  .font(.caption)
                                  .foregroundStyle(.secondary)
                                  .frame(maxWidth: .infinity)
                                  .padding(.top, 8)
                          }
                          // Orb / intensity / A/B / waveform — copy these from
                          // CleaningLabView's existing aiWorkstation + waveformSection
                          // bodies during implementation. See CleaningLabView.swift
                          // for the canonical layout.
                          DenoiseStudioBody(viewModel: viewModel)
                      }
                      .padding(.horizontal, 16)
                      .padding(.bottom, 96)
                  }
                  .navigationTitle(session.name)
                  .navigationBarTitleDisplayMode(.inline)
                  .toolbar { toolbarContent }
              } else {
                  ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
              }
          }
          .background { PremiumBackground() }
          .task { await load() }
          .onDisappear {
              if let vm = viewModel, let session {
                  vm.persist(to: session)
                  try? modelContext.save()
              }
          }
          .confirmationDialog(
              "Delete this Denoise session?",
              isPresented: $showDeleteConfirm,
              titleVisibility: .visible
          ) {
              Button("Delete", role: .destructive) { performDelete() }
              Button("Cancel", role: .cancel) {}
          }
      }

      @ToolbarContentBuilder
      private var toolbarContent: some ToolbarContent {
          // Spec §4.8: Denoise session toolbar mirrors Smart Cut — Export +
          // a "more" menu with destructive Delete. The Export sheet chain
          // (ExportFormatSheet → ExportProgressSheet → ActivityViewController)
          // is identical to the one in CleaningLabView's existing toolbar
          // (lines ~131–162 of CleaningLabView.swift) — copy that wiring
          // and adapt the source-URL resolution to use viewModel.exportSource.
          ToolbarItem(placement: .topBarTrailing) {
              Button {
                  showExportSheet = true
              } label: {
                  Label("Export", systemImage: "square.and.arrow.up")
              }
              .disabled(viewModel?.exportSource == nil)
          }
          ToolbarItem(placement: .topBarTrailing) {
              Menu {
                  Button(role: .destructive) { showDeleteConfirm = true } label: {
                      Label("Delete session", systemImage: "trash")
                  }
              } label: {
                  Label("More", systemImage: "ellipsis.circle")
              }
          }
      }

      private func load() async {
          let descriptor = FetchDescriptor<DenoiseSession>(
              predicate: #Predicate { $0.id == sessionId }
          )
          guard let fetched = try? modelContext.fetch(descriptor).first else {
              dismiss()
              return
          }
          fetched.lastOpenedAt = .now
          try? modelContext.save()
          self.session = fetched
          self.viewModel = DenoiseSessionViewModel(session: fetched, modelContext: modelContext)
      }

      private func performDelete() {
          guard let session else { return }
          if let dir = try? AppConstants.denoiseSessionDirectory(for: session.id) {
              try? FileManager.default.removeItem(at: dir)
          }
          modelContext.delete(session)
          try? modelContext.save()
          dismiss()
      }
  }

  /// Placeholder body that hosts the existing denoise studio UI. During
  /// implementation, copy the relevant subview bodies from CleaningLabView.swift
  /// (aiWorkstation, waveformSection, FloatingActionBar with the Denoise CTA)
  /// into here, replacing the `Text(...)` placeholder. This keeps the work
  /// mechanical: copy + change `viewModel` reference.
  private struct DenoiseStudioBody: View {
      @Bindable var viewModel: DenoiseSessionViewModel

      var body: some View {
          VStack(spacing: 16) {
              AIOrbView(progress: viewModel.progress, isProcessing: viewModel.isProcessing)
                  .frame(height: 200)
              if viewModel.hasDenoisedResult {
                  LimeGreenSlider(value: Binding(
                      get: { viewModel.intensity },
                      set: { viewModel.onIntensityChanged($0) }
                  ))
              }
              if let url = viewModel.mergedFileURL, !viewModel.hasDenoisedResult {
                  Button {
                      viewModel.startDenoising(mergedFileURL: url)
                  } label: {
                      Label("Denoise Audio", systemImage: "waveform.badge.minus")
                          .frame(maxWidth: .infinity)
                  }
                  .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
                  .disabled(viewModel.isProcessing)
              }
          }
      }
  }
  ```

  **Implementation note (mechanical copy from CleaningLabView.swift, current HEAD):** The `DenoiseStudioBody` skeleton above is intentionally minimal. To reach feature parity, copy each of the following sub-views from `SonicMerge/Features/Denoising/CleaningLabView.swift` into `DenoiseSessionView.swift` as private computed properties on `DenoiseStudioBody` (or as `private struct` siblings within the same file):

  | CleaningLabView.swift symbol | Lines | Where in DenoiseStudioBody |
  |---|---|---|
  | `denoiseContent` body | 180–204 | The body of `DenoiseStudioBody.body` — replace the placeholder VStack with this. |
  | `onDeviceAIHero` | 317–335 | Used by `denoiseContent` when `!hasImportedFirstClip`. Copy verbatim. |
  | `staleBanner` | 337–368 | Used by `denoiseContent` when `viewModel.showsStaleResultBanner && viewModel.hasDenoisedResult`. Copy verbatim. |
  | `aiWorkstation` | 398–~470 | The orb + intensity slider + A/B "Hold to Listen Original" button (with its `.onLongPressGesture(minimumDuration:)`-based `holdBegan` / `holdEnded` wiring). Copy verbatim. |
  | `waveformSection` | 370–396 | Used by `denoiseContent` when `shouldShowWaveformSection`. Copy verbatim. |
  | `floatingBarContent` (Denoise branch only) | within ~270–~316 | The Denoise CTA inside `FloatingActionBar`. Copy ONLY the `.denoise` branch — the `.smartCut` branch is dropped. |
  | Export sheets `.sheet(isPresented: $showExportSheet)` etc. | ~131–~162 | The full Export sheet chain. Copy into `DenoiseSessionView`'s body modifiers (NOT inside `DenoiseStudioBody`), since the toolbar Export button (added above) toggles `showExportSheet`. |

  After copy, every reference to `selectedTab` (the segmented-pill state inside `CleaningLabView`) is dropped — `DenoiseSessionView` is unconditionally the denoise studio. Every reference to `viewModel.smartCutVM`, `viewModel.fillerLibrary`, or the Smart Cut floating-bar branch is dropped (those went away in Task 4.1). The `@State private var hudShowing` etc. flags carry over as plain `@State` on `DenoiseSessionView`.

  This is mechanical copy, not redesign. After the copy, run the build; expect no functional drift from today's Cleaning Lab denoise tab.

- [ ] **Step 2: Build to confirm it compiles.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -10
  ```
  Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/Features/Denoising/Views/Home/DenoiseSessionView.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(denoise): DenoiseSessionView push destination skeleton"
  ```

### Task 4.4: `DenoiseHomeView`

**Files:**
- Create: `SonicMerge/Features/Denoising/Views/Home/DenoiseHomeView.swift`

Mirror of `SmartCutHomeView` — recents @Query (`DenoiseSession`), upload flow targeted at `<AppGroup>/denoise/<id>/`, empty/loaded states with a waveform glyph instead of sparkles.

- [ ] **Step 1: Create the view.**

  Create `SonicMerge/Features/Denoising/Views/Home/DenoiseHomeView.swift`. Structurally a sibling to `SmartCutHomeView` (Task 3.2) with three concrete differences: `DenoiseSession` instead of `SmartCutSession`, `denoiseSessionDirectory` instead of `smartCutSessionDirectory`, and no `sourceHashHex` field on the model (deep-link routing is Smart Cut-only). The full file:

  ```swift
  // DenoiseHomeView.swift
  // SonicMerge
  //
  // Denoise tab root. Recents list + Upload Audio CTA. Push-on-tap is
  // implemented via the `onSelect` closure passed in by RootTabView.
  //
  // Spec: §4.6 (Upload Audio flow), §4.7 (empty vs loaded), §4.8 (toolbar).

  import SwiftUI
  import SwiftData
  import UniformTypeIdentifiers
  import AVFoundation

  struct DenoiseHomeView: View {
      let onSelect: (UUID) -> Void

      @Environment(\.modelContext) private var modelContext
      @Environment(\.sonicMergeSemantic) private var semantic

      @Query(sort: \DenoiseSession.lastOpenedAt, order: .reverse, animation: .default)
      private var sessions: [DenoiseSession]

      @State private var showFileImporter = false
      @State private var importErrorMessage: String?

      var body: some View {
          ZStack {
              PremiumBackground()
              if sessions.isEmpty {
                  emptyState
              } else {
                  loadedState
              }
          }
          .navigationTitle("Denoise")
          .navigationBarTitleDisplayMode(.large)
          .fileImporter(
              isPresented: $showFileImporter,
              allowedContentTypes: UTType.audioImportTypes,
              allowsMultipleSelection: false
          ) { result in
              Task { await handleImport(result: result) }
          }
          .alert(
              "Couldn't import this file",
              isPresented: Binding(
                  get: { importErrorMessage != nil },
                  set: { if !$0 { importErrorMessage = nil } }
              )
          ) {
              Button("OK") {}
          } message: {
              Text(importErrorMessage ?? "")
          }
      }

      // MARK: - Empty state

      private var emptyState: some View {
          VStack(spacing: SonicMergeTheme.Spacing.md) {
              Image(systemName: "waveform.badge.minus")
                  .font(.system(size: 56, weight: .bold))
                  .foregroundStyle(Color(uiColor: semantic.accentAI))
                  .accessibilityHidden(true)
              Text("Clean noisy recordings")
                  .font(.system(.title3, design: .rounded, weight: .semibold))
                  .foregroundStyle(Color(uiColor: semantic.textPrimary))
              Text("Upload audio and remove background noise on-device.")
                  .font(.system(.body, design: .rounded))
                  .foregroundStyle(Color(uiColor: semantic.textSecondary))
                  .multilineTextAlignment(.center)
                  .padding(.horizontal, 32)
              Button {
                  showFileImporter = true
              } label: {
                  Label("Upload Audio", systemImage: "plus.circle.fill")
              }
              .buttonStyle(PillButtonStyle(variant: .filled, size: .regular, tint: .ai))
          }
      }

      // MARK: - Loaded state

      private var loadedState: some View {
          VStack(spacing: 0) {
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

              List {
                  ForEach(sessions) { session in
                      DenoiseRecentRow(session: session)
                          .contentShape(Rectangle())
                          .onTapGesture { onSelect(session.id) }
                          .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                              Button(role: .destructive) {
                                  delete(session)
                              } label: {
                                  Label("Delete", systemImage: "trash")
                              }
                          }
                  }
              }
              .listStyle(.plain)
              .scrollContentBackground(.hidden)
          }
      }

      // MARK: - Upload flow (spec §4.6 mirror)

      private func handleImport(result: Result<[URL], Error>) async {
          switch result {
          case .success(let urls):
              guard let pickedURL = urls.first else { return }
              await createSession(from: pickedURL)
          case .failure(let error):
              importErrorMessage = error.localizedDescription
          }
      }

      private func createSession(from pickedURL: URL) async {
          let didStart = pickedURL.startAccessingSecurityScopedResource()
          defer { if didStart { pickedURL.stopAccessingSecurityScopedResource() } }

          let sessionId = UUID()
          let ext = pickedURL.pathExtension.isEmpty ? "wav" : pickedURL.pathExtension.lowercased()
          let basename = pickedURL.deletingPathExtension().lastPathComponent

          let dir: URL
          do {
              dir = try AppConstants.denoiseSessionDirectory(for: sessionId)
          } catch {
              importErrorMessage = error.localizedDescription
              return
          }

          let destURL = dir.appending(path: "source.\(ext)")
          do {
              if FileManager.default.fileExists(atPath: destURL.path) {
                  try FileManager.default.removeItem(at: destURL)
              }
              try FileManager.default.copyItem(at: pickedURL, to: destURL)
          } catch {
              try? FileManager.default.removeItem(at: dir)
              importErrorMessage = "Couldn't import this file. \(error.localizedDescription)"
              return
          }

          let duration: Double
          do {
              duration = try await AVURLAsset(url: destURL).load(.duration).seconds
          } catch {
              try? FileManager.default.removeItem(at: dir)
              importErrorMessage = "This file isn't a valid audio recording."
              return
          }

          let session = DenoiseSession(
              id: sessionId,
              name: basename,
              sourceFilename: "source.\(ext)",
              durationSeconds: duration
          )
          modelContext.insert(session)
          do {
              try modelContext.save()
          } catch {
              try? FileManager.default.removeItem(at: dir)
              importErrorMessage = "Couldn't save the session. \(error.localizedDescription)"
              return
          }

          onSelect(sessionId)
      }

      private func delete(_ session: DenoiseSession) {
          if let dir = try? AppConstants.denoiseSessionDirectory(for: session.id) {
              try? FileManager.default.removeItem(at: dir)
          }
          modelContext.delete(session)
          try? modelContext.save()
      }
  }

  // MARK: - DenoiseRecentRow

  private struct DenoiseRecentRow: View {
      let session: DenoiseSession
      @Environment(\.sonicMergeSemantic) private var semantic

      var body: some View {
          HStack(spacing: 12) {
              RoundedRectangle(cornerRadius: 9, style: .continuous)
                  .fill(LinearGradient(
                      colors: [Color(uiColor: semantic.accentAI), Color(uiColor: semantic.accentAction)],
                      startPoint: .topLeading,
                      endPoint: .bottomTrailing
                  ))
                  .frame(width: 36, height: 36)
                  .overlay(
                      Image(systemName: "waveform")
                          .font(.system(size: 12, weight: .bold))
                          .foregroundStyle(.white)
                  )
              VStack(alignment: .leading, spacing: 2) {
                  Text(session.name)
                      .font(.subheadline.weight(.semibold))
                      .lineLimit(1)
                      .truncationMode(.middle)
                      .foregroundStyle(Color(uiColor: semantic.textPrimary))
                  Text(formatSubtitle(session))
                      .font(.caption)
                      .foregroundStyle(Color(uiColor: semantic.textSecondary))
              }
              Spacer()
          }
          .padding(.vertical, 6)
      }

      private func formatSubtitle(_ session: DenoiseSession) -> String {
          let duration = formatDuration(session.durationSeconds)
          let relative = RelativeDateTimeFormatter().localizedString(
              for: session.lastOpenedAt, relativeTo: .now
          )
          return "\(duration) · \(relative)"
      }

      private func formatDuration(_ seconds: Double) -> String {
          let total = Int(seconds)
          let m = total / 60
          let s = total % 60
          return m > 0 ? "\(m) min" : "\(s) s"
      }
  }
  ```

- [ ] **Step 2: Build.**

  Same `xcodebuild build` command as before. Expected `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/Features/Denoising/Views/Home/DenoiseHomeView.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(denoise): DenoiseHomeView with recents + Upload Audio flow"
  ```

### Task 4.5: End-of-chunk verification

- [ ] **Step 1: Test suite passes.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/sm-chunk4.log | tail -8
  echo "FAIL=$(grep -E '✘ Test .* failed' /tmp/sm-chunk4.log | sort -u | wc -l)"
  ```
  Expected: FAIL count matches Chunk 0 baseline.

---

## Chunk 5: Root shell — RootTabView, MixingStation cleanup, retire CleaningLabView

This chunk wires everything together. After this chunk the app boots into the Smart Cut tab.

**Spec references:** §3.2 (MixingStationView mechanical removals + SonicMergeApp body swap), §3.3 (CleaningLabView retires), §4.2 (RootTabView).

### Task 5.1: Create `RootTabView` (without share-extension/deep-link routing — that's Chunk 6)

**Files:**
- Create: `SonicMerge/App/RootTabView.swift`

- [ ] **Step 1: Create the view.**

  Create `SonicMerge/App/RootTabView.swift`:

  ```swift
  // RootTabView.swift
  // SonicMerge
  //
  // Three-tab shell: Smart Cut · Denoise · Merge. Default selection is Smart
  // Cut. Each tab is a NavigationStack with list → detail navigation.
  //
  // Owns:
  //   - FillerLibraryStore — read by SmartCutSessionView via the environment.
  //   - MixingStationViewModel — read by MixingStationView and MergeTimelineView
  //     via @Environment(MixingStationViewModel.self). The VM was previously
  //     created in SonicMergeApp.body; we move that ownership here so the
  //     Merge tab continues to work after the app-entry swap (Chunk 5 Task 5.4).
  //
  // Share-extension routing and background-transcription deep-link rerouting
  // are wired in Chunk 6.

  import SwiftUI
  import SwiftData

  struct RootTabView: View {
      enum Tab: Hashable { case smartCut, denoise, merge }

      @Environment(\.modelContext) private var modelContext

      @State private var selection: Tab = .smartCut
      @State private var smartCutPath = NavigationPath()
      @State private var denoisePath = NavigationPath()
      @State private var mergePath = NavigationPath()

      @State private var fillerLibraryStore = FillerLibraryStore()

      // Lazy-init: created on first appear, after modelContext is available.
      // MixingStationViewModel.init takes ModelContext and cannot use a
      // default-arg @State initializer that runs before the environment is
      // resolved.
      @State private var mixingStationViewModel: MixingStationViewModel?

      var body: some View {
          TabView(selection: $selection) {
              NavigationStack(path: $smartCutPath) {
                  SmartCutHomeView { sessionId in
                      smartCutPath.append(sessionId)
                  }
                  .navigationDestination(for: UUID.self) { sessionId in
                      SmartCutSessionView(sessionId: sessionId)
                  }
              }
              .tabItem { Label("Smart Cut", systemImage: "sparkles") }
              .tag(Tab.smartCut)

              NavigationStack(path: $denoisePath) {
                  DenoiseHomeView { sessionId in
                      denoisePath.append(sessionId)
                  }
                  .navigationDestination(for: UUID.self) { sessionId in
                      DenoiseSessionView(sessionId: sessionId)
                  }
              }
              .tabItem { Label("Denoise", systemImage: "waveform.badge.minus") }
              .tag(Tab.denoise)

              NavigationStack(path: $mergePath) {
                  Group {
                      if let vm = mixingStationViewModel {
                          MixingStationView()
                              .environment(vm)
                      } else {
                          ProgressView()
                      }
                  }
              }
              .tabItem { Label("Merge", systemImage: "rectangle.stack") }
              .tag(Tab.merge)
          }
          .environment(\.fillerLibrary, fillerLibraryStore)
          .onAppear {
              if mixingStationViewModel == nil {
                  mixingStationViewModel = MixingStationViewModel(modelContext: modelContext)
              }
          }
      }
  }
  ```

- [ ] **Step 2: Build.**

  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -10
  ```
  Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add SonicMerge/App/RootTabView.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(root): RootTabView shell with three NavigationStack tabs"
  ```

### Task 5.2: Strip Cleaning Lab navigation from `MixingStationView`

**Files:**
- Modify: `SonicMerge/Features/MixingStation/MixingStationView.swift`

Mechanical removal list per spec §3.2. Each line number references the current main HEAD as of plan authorship; if the file has drifted, search for the symbol instead.

- [ ] **Step 1: Apply the removals.**

  Open `SonicMerge/Features/MixingStation/MixingStationView.swift`. Delete each of the following (search by symbol if line numbers have drifted):

  1. Line 22: `@State private var showCleaningLab = false`
  2. Line 23: `@State private var mergedFileURLForCleaning: URL?`
  3. Line 29: `@State private var denoiseHaptic = false`
  4. Lines 53–57: the `.navigationDestination(isPresented: $showCleaningLab) { ... }` modifier block.
  5. Lines 107–112: the `.onChange(of: showCleaningLab) { _, isShowing in ... }` cleanup hook.
  6. Lines 170–184: the entire `ToolbarItem(placement: .topBarTrailing)` for the **Denoise** button (the one that toggles `denoiseHaptic` and calls `navigateToCleaningLab()`).
  7. Lines 211–230: the entire `private func navigateToCleaningLab() { ... }` method.

  After removal: build to confirm no dangling references.

- [ ] **Step 2: Build.**

  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -10
  ```
  Expected: `** BUILD SUCCEEDED **`. If a reference to `CleaningLabView` or `showCleaningLab` lingers, search and remove it.

- [ ] **Step 3: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/Features/MixingStation/MixingStationView.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "refactor(merge): remove Cleaning Lab navigation from Mixing Station"
  ```

### Task 5.3: Retire `CleaningLabView`

**Files:**
- Delete: `SonicMerge/Features/Denoising/CleaningLabView.swift`
- Audit: any remaining references

- [ ] **Step 1: Confirm no remaining references.**

  Run:
  ```bash
  grep -rn "CleaningLabView" \
    /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMerge \
    /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMergeTests \
    /Users/datnnt/Desktop/DatNNT/App/SonicMerge/SonicMergeUITests \
    --include="*.swift" || echo "no references"
  ```
  Expected: only references inside the file itself, plus possibly a stale test file (delete or rewrite in Step 3 if so).

- [ ] **Step 2: Delete the file.**

  Run:
  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge rm SonicMerge/Features/Denoising/CleaningLabView.swift
  ```

- [ ] **Step 3: Build.**

  Same `xcodebuild build` command. Expected `** BUILD SUCCEEDED **`. If there's still a test file referencing `CleaningLabView`, delete or rewrite it (e.g., a UI test).

- [ ] **Step 4: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "refactor: retire CleaningLabView"
  ```

### Task 5.4: Swap `SonicMergeApp.body` from `MixingStationView` to `RootTabView`

**Files:**
- Modify: `SonicMerge/SonicMergeApp.swift`

- [ ] **Step 1: Replace the `WindowGroup` body.**

  Open `SonicMerge/SonicMergeApp.swift`. The current body (lines ~62–104) hosts `MixingStationView` with a `MixingStationViewModel` and the share-extension scenePhase / onOpenURL handlers.

  Replace the `var body: some Scene { ... }` block with:

  ```swift
  var body: some Scene {
      WindowGroup {
          RootTabView()
      }
      .modelContainer(modelContainer)
  }
  ```

  Delete the `@State private var viewModel: MixingStationViewModel?` declaration. The share-extension routing and onOpenURL handlers move into `RootTabView` in Chunk 6 — they're temporarily gone, but no released code path depends on them in this chunk's HEAD because the share extension hasn't shipped yet.

- [ ] **Step 2: Build, run tests.**

  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO test 2>&1 | tee /tmp/sm-5-4.log | tail -8
  echo "FAIL=$(grep -E '✘ Test .* failed' /tmp/sm-5-4.log | sort -u | wc -l)"
  ```
  Expected: build succeeds. FAIL count matches Chunk 0 baseline. If the share-extension test (`ShareExtensionTests`) starts failing because of the missing handler, mark it `XCTSkip` until Chunk 6 wires the new routing.

- [ ] **Step 3: Smoke test on simulator.**

  Run the app target on `iPhone 17` simulator. Expected:
  - App opens on the **Smart Cut** tab.
  - Empty state shows the orb, tagline, "Upload Audio" button.
  - Tapping the **Merge** tab shows the existing Mixing Station UI (timeline, drag-reorder).
  - Tapping the **Denoise** tab shows the empty Denoise home view.
  - Tapping Upload Audio in Smart Cut → file picker opens → picking an `.m4a` → push to session view → studio renders.

- [ ] **Step 4: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add SonicMerge/SonicMergeApp.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(root): swap app entry from MixingStationView to RootTabView"
  ```

### Task 5.5: End-of-chunk verification

- [ ] **Step 1: Test suite + cold-launch smoke.**

  Run the full suite and a cold-launch on simulator. Expected: all green.

---

## Chunk 6: Share extension routing + deep-link rerouting + integration tests

Final chunk. The share extension copies inbound audio to `<AppGroup>/smart-cut/<id>/` (instead of `<AppGroup>/clips/`) and writes three keys; `RootTabView` reads them on `scenePhase == .active` and routes accordingly. Background-transcription deep-link rerouting wires `PendingSmartCutOpen` → tab switch + push.

**Spec references:** §4.4 (share extension routing), §4.5 (deep-link rerouting), §4.10 (legacy backward-compat), §6.1 (DeepLinkReroutingTests).

### Task 6.1: Add `smartCutSessionDirectory` mirror to share extension's `AppConstants`

**Files:**
- Modify: `SonicMergeShareExtension/AppConstants.swift`

The share extension target has its own copy of `AppConstants` (it can't import from the main target without target-membership wiring that hasn't been done). Add a minimal mirror — only the helper the extension needs.

- [ ] **Step 1: Add the helper.**

  Open `SonicMergeShareExtension/AppConstants.swift`. After the existing `clipsDirectory()` (or equivalent) method, add the same `smartCutSessionDirectory(for:)` body from the main `AppConstants.swift` (Task 1.4 Step 3). Keep it identical — the path layout must match.

- [ ] **Step 2: Build the extension target.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMergeShareExtension \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug build 2>&1 | tail -10
  ```
  Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMergeShareExtension/AppConstants.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(share-ext): mirror smartCutSessionDirectory helper"
  ```

### Task 6.2: Update share extension to write to `smart-cut/<id>/` and emit three keys

**Files:**
- Modify: `SonicMergeShareExtension/ShareExtensionViewController.swift`

The current code copies to `clips/<basename>` and writes `pendingImportFilename`. Replace with: copy to `smart-cut/<newId>/source.<ext>`; write `pendingImportFilename`, `pendingImportSessionId`, `pendingImportDestination`.

- [ ] **Step 1: Modify `loadAndCopyFile`.**

  Open `SonicMergeShareExtension/ShareExtensionViewController.swift`. In the file-copy closure (currently lines 75–89), replace:

  ```swift
  let clipsDir = try AppConstants.clipsDirectory()
  let originalFilename = tempURL.lastPathComponent
  let dest = clipsDir.appending(path: originalFilename)

  // Overwrite if exists (dedup by displayName happens in main app per D-10)
  if FileManager.default.fileExists(atPath: dest.path) {
      try FileManager.default.removeItem(at: dest)
  }
  try FileManager.default.copyItem(at: tempURL, to: dest)

  continuation.resume(returning: originalFilename)
  ```

  with:

  ```swift
  let sessionId = UUID()
  let dir = try AppConstants.smartCutSessionDirectory(for: sessionId)
  let ext = tempURL.pathExtension.isEmpty ? "m4a" : tempURL.pathExtension.lowercased()
  let dest = dir.appending(path: "source.\(ext)")
  if FileManager.default.fileExists(atPath: dest.path) {
      try FileManager.default.removeItem(at: dest)
  }
  try FileManager.default.copyItem(at: tempURL, to: dest)

  // Resume with the routing payload — filename is relative to the session dir.
  continuation.resume(returning: ShareImportPayload(
      filename: "source.\(ext)",
      sessionId: sessionId,
      originalBasename: tempURL.deletingPathExtension().lastPathComponent
  ))
  ```

  Add a small payload struct at the top of the file:

  ```swift
  private struct ShareImportPayload {
      let filename: String
      let sessionId: UUID
      let originalBasename: String
  }
  ```

  Update the continuation type from `String` to `ShareImportPayload`. Update the awaiting `let filename = ...` site to `let payload = ...`.

  Replace the UserDefaults-write block (currently lines 99–102):

  ```swift
  let defaults = UserDefaults(suiteName: AppConstants.appGroupID)
  defaults?.set(filename, forKey: "pendingImportFilename")
  defaults?.synchronize()
  ```

  with:

  ```swift
  let defaults = UserDefaults(suiteName: AppConstants.appGroupID)
  defaults?.set(payload.filename, forKey: "pendingImportFilename")
  defaults?.set(payload.sessionId.uuidString, forKey: "pendingImportSessionId")
  defaults?.set("smart-cut", forKey: "pendingImportDestination")
  defaults?.set(payload.originalBasename, forKey: "pendingImportBasename")
  defaults?.synchronize()
  ```

  Update the HUD update block to use `payload.originalBasename` instead of the old filename-derived display name. Note: `ShareHUDModel.filename` currently takes a `URL` (`hudModel.filename = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent`). Replace that line with `hudModel.filename = URL(fileURLWithPath: payload.originalBasename)` if the field is still a `URL`, OR `hudModel.filename = payload.originalBasename` if it's a `String`. Inspect `ShareHUDModel.swift` and pick the matching shape — don't blindly wrap the basename in a `URL` if the field is already a `String`.

- [ ] **Step 2: Build the extension.**

  Same `xcodebuild` command as Task 6.1 Step 2. Expected `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMergeShareExtension/ShareExtensionViewController.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(share-ext): write to smart-cut/<id>/ + emit destination keys"
  ```

### Task 6.3: Add share-extension import + deep-link routing to `RootTabView`

**Files:**
- Modify: `SonicMerge/App/RootTabView.swift`

- [ ] **Step 1: Add the routing handlers.**

  Open `SonicMerge/App/RootTabView.swift`. Add after the existing `body`:

  ```swift
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.modelContext) private var modelContext
  ```

  Then on the `body`'s outermost view, attach:

  ```swift
  .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      handlePendingShareExtensionImport()
      handlePendingSmartCutOpenIfNeeded()
  }
  .onAppear {
      handlePendingShareExtensionImport()
      handlePendingSmartCutOpenIfNeeded()
  }
  .onOpenURL { url in handleDeepLink(url) }
  ```

  Add the three handler methods to the struct:

  ```swift
  private func handlePendingShareExtensionImport() {
      let defaults = UserDefaults(suiteName: AppConstants.appGroupID)
      guard let filename = defaults?.string(forKey: "pendingImportFilename") else { return }
      defaults?.removeObject(forKey: "pendingImportFilename")
      let destination = defaults?.string(forKey: "pendingImportDestination") ?? "merge"
      defaults?.removeObject(forKey: "pendingImportDestination")
      let sessionIdString = defaults?.string(forKey: "pendingImportSessionId")
      defaults?.removeObject(forKey: "pendingImportSessionId")
      let basename = defaults?.string(forKey: "pendingImportBasename") ?? URL(fileURLWithPath: filename)
          .deletingPathExtension().lastPathComponent
      defaults?.removeObject(forKey: "pendingImportBasename")

      Task { @MainActor in
          await routeShareImport(
              filename: filename,
              destination: destination,
              sessionIdString: sessionIdString,
              basename: basename
          )
      }
  }

  private func routeShareImport(
      filename: String,
      destination: String,
      sessionIdString: String?,
      basename: String
  ) async {
      switch destination {
      case "smart-cut":
          guard let idStr = sessionIdString, let id = UUID(uuidString: idStr) else { return }
          guard let dir = try? AppConstants.smartCutSessionDirectory(for: id) else { return }
          let url = dir.appending(path: filename)
          guard FileManager.default.fileExists(atPath: url.path) else { return }
          let duration = (try? await AVURLAsset(url: url).load(.duration).seconds) ?? 0
          let hash = (try? await SourceHasher.sha256Hex(of: url)) ?? ""
          let session = SmartCutSession(
              id: id,
              name: basename,
              sourceFilename: filename,
              sourceHashHex: hash,
              durationSeconds: duration
          )
          modelContext.insert(session)
          try? modelContext.save()
          selection = .smartCut
          smartCutPath.append(id)

      case "merge":
          // Backward-compat: legacy share extension wrote to clips/. Re-emit
          // the legacy key and switch to the Merge tab; MixingStationView's
          // .onAppear reader (added in Task 6.4) consumes it. Caveat:
          // .onAppear does NOT refire on subsequent re-entries to an already-
          // instantiated view, so a *second* legacy share within the same
          // app session silently loses its import. This is acceptable as a
          // one-cycle migration — once a user upgrades and the share
          // extension is rebuilt, all subsequent shares use the smart-cut
          // destination key and the new RootTabView path. Documented limit.
          let defaults = UserDefaults(suiteName: AppConstants.appGroupID)
          defaults?.set(filename, forKey: "pendingImportFilename") // re-emit for MixingStation
          selection = .merge

      default:
          // Unknown destination — drop silently.
          return
      }
  }

  private func handlePendingSmartCutOpenIfNeeded() {
      guard let session = Self.resolveSessionForPendingHash(in: modelContext) else { return }
      selection = .smartCut
      // Spec §4.5: append unconditionally is fine — NavigationPath doesn't
      // expose its last element; double-push is rare (notifications fire
      // once, hash is cleared inside the helper). The session view handles
      // a redundant push gracefully — it just re-binds to the same session.
      smartCutPath.append(session.id)
  }

  /// Pure routing helper extracted for testability. Reads
  /// `PendingSmartCutOpen.shared.hash`, strips the `#cloud`/`#local`
  /// suffix, and resolves to a `SmartCutSession`. Always clears the
  /// pending hash — even on miss — so an orphan deep-link doesn't re-fire
  /// on the next `scenePhase == .active`.
  static func resolveSessionForPendingHash(in context: ModelContext) -> SmartCutSession? {
      guard let raw = PendingSmartCutOpen.shared.hash else { return nil }
      PendingSmartCutOpen.shared.hash = nil
      let bareHash = raw.split(separator: "#").first.map(String.init) ?? raw
      let descriptor = FetchDescriptor<SmartCutSession>(
          predicate: #Predicate { $0.sourceHashHex == bareHash }
      )
      return try? context.fetch(descriptor).first
  }

  private func handleDeepLink(_ url: URL) {
      guard url.scheme == "sonicmerge",
            url.host() == "import",
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let filename = components.queryItems?.first(where: { $0.name == "file" })?.value
      else { return }
      // Legacy deep link — route to Merge tab for backward-compat.
      guard let clipsDir = try? AppConstants.clipsDirectory() else { return }
      let fileURL = clipsDir.appending(path: filename)
      guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
      // Set the legacy pending key and switch to Merge.
      UserDefaults(suiteName: AppConstants.appGroupID)?
          .set(filename, forKey: "pendingImportFilename")
      selection = .merge
  }
  ```

  Add the imports `AVFoundation`, `SwiftData` to the top of `RootTabView.swift`.

- [ ] **Step 2: Build.**

  Same `xcodebuild build` command. Expected `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add SonicMerge/App/RootTabView.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(root): share-extension import + deep-link rerouting in RootTabView"
  ```

### Task 6.4: Restore the `pendingImportFilename` reader in `MixingStationView` for backward-compat

**Files:**
- Modify: `SonicMerge/Features/MixingStation/MixingStationView.swift`

`RootTabView`'s legacy backward-compat path re-emits `pendingImportFilename` and switches to the Merge tab. `MixingStationView` needs to read that key on appear and route through `MixingStationViewModel.importFiles`.

- [ ] **Step 1: Add the reader.**

  Open `MixingStationView.swift`. After the body's `.task { await viewModel.fetchAll() }`, add:

  ```swift
  .onAppear {
      let defaults = UserDefaults(suiteName: AppConstants.appGroupID)
      guard let filename = defaults?.string(forKey: "pendingImportFilename") else { return }
      defaults?.removeObject(forKey: "pendingImportFilename")
      guard let clipsDir = try? AppConstants.clipsDirectory() else { return }
      let fileURL = clipsDir.appending(path: filename)
      guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
      viewModel.importFiles([fileURL])
  }
  ```

- [ ] **Step 2: Build.**

  Same command. Expected `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMerge/Features/MixingStation/MixingStationView.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "feat(merge): restore pendingImportFilename reader for legacy share-ext"
  ```

### Task 6.5: Add `DeepLinkReroutingTests`

**Files:**
- Test: `SonicMergeTests/DeepLinkReroutingTests.swift` (new)

The tests verify the suffix-stripping behavior of the `bareHash = raw.split(separator: "#").first` algorithm and the FetchDescriptor predicate.

- [ ] **Step 1: Write the tests.**

  Create `SonicMergeTests/DeepLinkReroutingTests.swift`:

  ```swift
  import XCTest
  import SwiftData
  @testable import SonicMerge

  @MainActor
  final class DeepLinkReroutingTests: XCTestCase {

      private func makeContainer() throws -> ModelContainer {
          let schema = Schema([SmartCutSession.self])
          let config = ModelConfiguration(isStoredInMemoryOnly: true)
          return try ModelContainer(for: schema, configurations: config)
      }

      func test_cloudSuffixIsStrippedAndMatches() throws {
          let container = try makeContainer()
          let context = container.mainContext

          let session = SmartCutSession(
              name: "Episode",
              sourceFilename: "source.m4a",
              sourceHashHex: "abc123",
              durationSeconds: 60
          )
          context.insert(session)
          try context.save()

          let raw = "abc123#cloud"
          let bareHash = raw.split(separator: "#").first.map(String.init) ?? raw

          let descriptor = FetchDescriptor<SmartCutSession>(
              predicate: #Predicate { $0.sourceHashHex == bareHash }
          )
          let matched = try context.fetch(descriptor).first
          XCTAssertEqual(matched?.id, session.id)
      }

      func test_localSuffixIsStrippedAndMatches() throws {
          let container = try makeContainer()
          let context = container.mainContext
          let session = SmartCutSession(
              name: "Local",
              sourceFilename: "source.m4a",
              sourceHashHex: "deadbeef",
              durationSeconds: 30
          )
          context.insert(session)

          let bareHash = "deadbeef#local".split(separator: "#").first.map(String.init) ?? ""
          let descriptor = FetchDescriptor<SmartCutSession>(
              predicate: #Predicate { $0.sourceHashHex == bareHash }
          )
          XCTAssertNotNil(try context.fetch(descriptor).first)
      }

      func test_unknownHashReturnsNoMatch() throws {
          let container = try makeContainer()
          let context = container.mainContext
          context.insert(SmartCutSession(
              name: "X",
              sourceFilename: "source.m4a",
              sourceHashHex: "real",
              durationSeconds: 30
          ))

          let bareHash = "ghost#cloud".split(separator: "#").first.map(String.init) ?? ""
          let descriptor = FetchDescriptor<SmartCutSession>(
              predicate: #Predicate { $0.sourceHashHex == bareHash }
          )
          XCTAssertNil(try context.fetch(descriptor).first)
      }

      func test_hashWithNoSuffixIsAccepted() throws {
          let container = try makeContainer()
          let context = container.mainContext
          context.insert(SmartCutSession(
              name: "NoSuffix",
              sourceFilename: "source.m4a",
              sourceHashHex: "plainhash",
              durationSeconds: 30
          ))

          let raw = "plainhash"
          let bareHash = raw.split(separator: "#").first.map(String.init) ?? raw
          XCTAssertEqual(bareHash, "plainhash")
      }

      // The above tests cover the bareHash split + FetchDescriptor predicate in
      // isolation. Spec §6.1 also calls for a router-level test that asserts
      // `selection = .smartCut`, the path append, and the hash clear. Because
      // RootTabView's router methods are private, we extract the routing
      // algorithm into a small testable helper. If RootTabView grows a
      // `static func resolveSession(forHash:in:) -> SmartCutSession?`
      // (recommended; pure function — no SwiftUI dependency), the test below
      // exercises it. Add this helper as part of Task 6.3 if it isn't already.

      func test_resolveSessionForHashClearsPendingHashAndResolvesMatch() throws {
          let container = try makeContainer()
          let context = container.mainContext
          let session = SmartCutSession(
              name: "Episode",
              sourceFilename: "source.m4a",
              sourceHashHex: "abc",
              durationSeconds: 60
          )
          context.insert(session)

          PendingSmartCutOpen.shared.hash = "abc#cloud"
          let resolved = RootTabView.resolveSessionForPendingHash(in: context)
          XCTAssertEqual(resolved?.id, session.id)
          XCTAssertNil(PendingSmartCutOpen.shared.hash, "router must clear pending hash after read")
      }

      func test_resolveSessionForHashClearsPendingHashEvenOnMiss() throws {
          let container = try makeContainer()
          let context = container.mainContext
          context.insert(SmartCutSession(
              name: "Other",
              sourceFilename: "source.m4a",
              sourceHashHex: "real",
              durationSeconds: 30
          ))

          PendingSmartCutOpen.shared.hash = "ghost#local"
          let resolved = RootTabView.resolveSessionForPendingHash(in: context)
          XCTAssertNil(resolved)
          XCTAssertNil(PendingSmartCutOpen.shared.hash, "router must clear pending hash on miss too — otherwise the same orphan re-fires next scene-active")
      }
  }
  ```

  Note: the last two tests reference `RootTabView.resolveSessionForPendingHash(in:)`. Refactor `RootTabView.handlePendingSmartCutOpenIfNeeded()` (added in Task 6.3) to extract a `static func resolveSessionForPendingHash(in context: ModelContext) -> SmartCutSession?` helper that does the bareHash split, the fetch, and the `PendingSmartCutOpen.shared.hash = nil` clear; the inner method then calls `if let session = Self.resolveSessionForPendingHash(in: modelContext) { selection = .smartCut; smartCutPath.append(session.id) }`. This keeps the testable surface pure — no SwiftUI / `@State` dependency — and lets `XCTest` assert the side effects on `PendingSmartCutOpen` and the FetchDescriptor result without driving a TabView host.

- [ ] **Step 2: Run tests, expect PASS.**

  Run:
  ```bash
  set -o pipefail; xcodebuild -scheme SonicMerge \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:SonicMergeTests/DeepLinkReroutingTests \
    -parallel-testing-enabled NO test 2>&1 | tail -10
  ```
  Expected: 4 tests pass.

- [ ] **Step 3: Commit.**

  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge add \
    SonicMergeTests/DeepLinkReroutingTests.swift
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge commit -m "test(deep-link): DeepLinkReroutingTests for suffix-stripping + FetchDescriptor"
  ```

### Task 6.6: End-to-end manual QA

- [ ] **Step 1: Cold-launch on simulator.**

  Run app. Expected: opens on Smart Cut tab, empty state.

- [ ] **Step 2: Upload Audio flow.**

  Tap Upload Audio → pick a fixture audio (e.g., the Voice Memos sample) → push into session view → tap Analyze → wait for `.results` → tap Apply Cuts → verify export sheet flows.

- [ ] **Step 3: Recents persistence.**

  Force-quit app (slide-up from app switcher). Relaunch. Expected: the just-created session appears at the top of recents in the Smart Cut tab.

- [ ] **Step 4: Share-extension flow.**

  From Voice Memos, share an `.m4a` to SonicMerge. Expected: the share extension shows the success HUD; switching to SonicMerge launches it on the Smart Cut tab with the new session pushed and ready to analyze.

- [ ] **Step 5: Cross-tab independence.**

  Smart Cut tab: start an analyze, opt into "Run in BG". Switch to Merge tab; perform an action (e.g., import a clip). Switch back to Smart Cut. Expected: Smart Cut session is unchanged or completed; no crashes.

- [ ] **Step 6: Delete session.**

  Swipe-left on a recent → Delete. Expected: row disappears; `<AppGroup>/smart-cut/<id>/` is removed (verify via Xcode → Window → Devices and Simulators → app container).

- [ ] **Step 7: Final commit + push.**

  No code changes; this step is just confirming the branch is shippable.

  Run:
  ```bash
  git -C /Users/datnnt/Desktop/DatNNT/App/SonicMerge log --oneline main..HEAD
  ```
  Expected: a clean ladder of feature commits across all six chunks.

---

## Open questions for the implementer

These are flagged in the spec (§7) but worth surfacing during implementation:

1. **Transcript-cache resume to `.results` directly.** The new `SmartCutViewModel.init(session:...)` lands in `.idle` even when a `transcriptCacheRef` exists, because the existing `TranscriptionService` doesn't expose a "load cached results" API. If users complain about re-analyze on every resume, add `TranscriptionService.loadCachedResults(from: URL) async throws -> EditList?` and have the new init call it.

2. **Session rename UX.** `SmartCutSession.name` is mutable but no UI exposes it. A long-press → rename action on the recents row is the natural follow-up.

3. **Storage management view.** No bulk-delete or aggregate disk view. If users accumulate sessions, this becomes a real problem.

4. **Share-extension destination picker.** The `pendingImportDestination` key is reserved; the picker UI is a follow-up.

5. **Cross-tab handoff.** No "denoise this then Smart Cut it" path. A separate project (Approach 3 in the brainstorm).
