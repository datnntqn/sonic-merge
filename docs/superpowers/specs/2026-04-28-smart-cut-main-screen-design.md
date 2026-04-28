# Smart Cut as Main Screen — Design Spec

**Status:** Draft (brainstorming phase complete; awaiting spec review + user read-through)
**Date:** 2026-04-28
**Owner:** DATNNT
**Implements:** Promote Smart Cut from a sub-feature inside Cleaning Lab to the app's primary feature on the main screen. Restructure the app shell from a single `MixingStationView` root into a three-tab `RootTabView` (Smart Cut · Denoise · Merge) with the Smart Cut tab opened by default. Each tab follows an iOS-native list → detail navigation pattern: a home view with a recents list and an Upload Audio CTA, pushing into a per-session detail view. Sessions persist across launches via SwiftData. The existing `CleaningLabView` retires; its two halves split into `SmartCutSessionView` and `DenoiseSessionView`. The existing Mixing Station UI, viewmodel, and SwiftData entities (`AudioClip`, `GapTransition`) carry over largely unchanged into the Merge tab.

---

## 1. Overview

The app's positioning is shifting from "Pro Audio Joiner & AI Denoiser" to a Smart Cut-first tool — uploading a recording and removing fillers + long silences becomes the primary user journey. Today, Smart Cut is two screens deep: open the app to the Mixing Station, tap the **Denoise** toolbar button, the app exports a temp WAV and pushes `CleaningLabView`, and Smart Cut is one of two tabs inside that view. This spec promotes Smart Cut to the app's main screen by replacing the single-root architecture with a tab-based shell where Smart Cut is the default tab.

The redesign keeps Merge and Denoise as first-class peer features (both reachable from the tab bar) but reframes them as separate destinations rather than a coupled pipeline. Smart Cut, Denoise, and Merge each get their own input model: an Upload Audio CTA on each tab's home view, plus a recents list of prior sessions persisted in SwiftData. Tapping Upload or a recent row pushes the user into a detail view scoped to that session. The detail views reuse the existing `SmartCutStudioContainer` (Smart Cut) and the Denoise half of `CleaningLabView` (Denoise) almost verbatim — the studio polish from Phase 12 is preserved.

`CleaningLabView` retires entirely. Its denoise content moves into a new `DenoiseSessionView`; its Smart Cut content (already encapsulated as `SmartCutStudioContainer`) becomes the body of a new `SmartCutSessionView`. The two halves no longer share a viewmodel or a merged-URL input. The Denoise toolbar button on Mixing Station and the `navigateToCleaningLab()` merge-then-push path are deleted.

The share extension's default destination becomes the Smart Cut tab. A new App Group UserDefaults key (`pendingImportDestination`) is reserved for a future destination picker; for now, all incoming shared audio creates a new Smart Cut session and deep-links into it.

## 2. Goals and non-goals

**Goals:**

- Replace the single-root `MixingStationView` app entry with a `RootTabView` containing three independent tabs (Smart Cut · Denoise · Merge), with Smart Cut as the default selection.
- Add a list → detail navigation pattern to the Smart Cut and Denoise tabs: a home view with a recents list + Upload Audio CTA, pushing into a session detail view via `NavigationStack`.
- Persist Smart Cut and Denoise sessions across launches via two new SwiftData `@Model` types (`SmartCutSession`, `DenoiseSession`) added to the existing schema. Recents list is `@Query`-driven, sorted by `lastOpenedAt` desc, limit 20.
- Move per-session source audio and transcript caches under stable App Group paths (`<AppGroup>/smart-cut/<id>/`, `<AppGroup>/denoise/<id>/`) so resume works after device reboot and across launches.
- Refactor `SmartCutViewModel` to support session-driven init: load source URL from `session.sourceFilename`, restore `editList` from `session.editListJSON`, restore transcript cache from `session.transcriptCacheRef`. Add a `persist()` method that writes edit-list JSON back debounced (~300ms) on mutation.
- Split `CleaningLabViewModel` into `DenoiseSessionViewModel` (denoise-only). Remove its embedded `SmartCutViewModel` and the merged-URL plumbing that hands input from one half to the other.
- Retire `CleaningLabView` and `MixingStationView.navigateToCleaningLab()` plus the `Denoise` toolbar button on Mixing Station. The Merge tab toolbar keeps Import + Export + Theme menu only.
- Update the share extension to write incoming audio to `<AppGroup>/smart-cut/<newId>/source.<ext>` by default, set `pendingImportSessionId` and `pendingImportDestination = "smart-cut"`, and have `RootTabView` route on `scenePhase == .active` by switching tabs and pushing the matching session ID.
- Wire the existing `PendingSmartCutOpen` background-transcription deep-link through `RootTabView`: switch to Smart Cut tab, append session ID to its NavigationStack path. Verify the session still exists in SwiftData before pushing.
- Reuse `SmartCutStudioContainer` as the body of `SmartCutSessionView` without functional changes. Reuse the denoise content (orb, intensity, A/B, waveform, floating bar) as the body of `DenoiseSessionView` with no logic rewrite — only its container changes.
- Preserve the existing `AudioClip` / `GapTransition` SwiftData models and the Mixing Station merge timeline in the Merge tab unchanged. Existing user data on upgrade is not migrated, just hosted under a tab.

**Non-goals:**

- No cross-tab document model. Smart Cut, Denoise, and Merge sessions are independent entities with no chaining (e.g., "denoise this, then send to Smart Cut"). That's a later project (Approach 3 in the brainstorm) and out of scope here.
- No share-extension destination picker UI. The `pendingImportDestination` key is reserved for it, but initial scope hard-codes `"smart-cut"`.
- No multi-file upload on the Smart Cut tab. Single-file dedicated upload only (Q3-A); users wanting custom multi-file merges go to the Merge tab.
- No rename UI for sessions. `SmartCutSession.name` defaults to source basename and is editable in the data model, but no field/sheet exposes it in this round.
- No bulk delete or session count cap. Swipe-to-delete only. Disk usage is the user's to manage; a future polish pass can add a "manage storage" view.
- No changes to `SmartCutStudioContainer`'s internals (Phase 12 just shipped). No changes to the merge timeline, drag-reorder, gap controls, or merge export.
- No changes to the existing background-transcription pipeline (`BackgroundTranscriptionTask`) beyond rerouting the deep-link target through `RootTabView`.
- No new tests for `SmartCutStudioContainer` or `MixingStationView` rendering — these are unchanged.

## 3. Scope

### 3.1 New files (5 view files + 2 model files + 2 viewmodel files)

| Path | Role |
|---|---|
| `SonicMerge/App/RootTabView.swift` | TabView shell. Three tabs, default selection = `.smartCut`. Owns `@State private var smartCutPath: NavigationPath`, `denoisePath`, `mergePath`. Reads pending share-extension imports on `scenePhase == .active` and on `.onOpenURL` for the `sonicmerge://` scheme. |
| `SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeView.swift` | Smart Cut tab root. `@Query` over `SmartCutSession` sorted by `lastOpenedAt` desc, limit 20. Empty state (orb + tagline + Upload button) when query is empty; recents list with Upload CTA on top otherwise. Uses `.fileImporter` to accept a single audio file from `UTType.audioImportTypes`. |
| `SonicMerge/Features/SmartCut/Views/Home/SmartCutSessionView.swift` | Push destination from `SmartCutHomeView`. Owns a `SmartCutViewModel` initialized from a `SmartCutSession`. Hosts `SmartCutStudioContainer` as its body. Toolbar: Export + delete-session. Persists edit-list mutations back to the session. Updates `lastOpenedAt = .now` on appear. |
| `SonicMerge/Features/Denoising/Views/Home/DenoiseHomeView.swift` | Denoise tab root. Mirror of `SmartCutHomeView` for `DenoiseSession`. |
| `SonicMerge/Features/Denoising/Views/Home/DenoiseSessionView.swift` | Push destination from `DenoiseHomeView`. Owns a `DenoiseSessionViewModel` initialized from a `DenoiseSession`. Hosts the denoise content (`onDeviceAIHero`, `staleBanner`, `aiWorkstation`, `waveformSection`, `FloatingActionBar`) currently inside `CleaningLabView`. |
| `SonicMerge/Models/SmartCutSession.swift` | `@Model` SwiftData entity (see §4.1). |
| `SonicMerge/Models/DenoiseSession.swift` | `@Model` SwiftData entity (see §4.1). |
| `SonicMerge/Features/SmartCut/Views/Home/SmartCutHomeViewModel.swift` *(optional, only if logic exceeds what fits in the view)* | Encapsulates upload-and-create-session, copy-to-App-Group, error mapping. May merge into the view if small. |
| `SonicMerge/Features/Denoising/DenoiseSessionViewModel.swift` | Renamed/stripped `CleaningLabViewModel`. Owns just the denoise pipeline. Init takes a `DenoiseSession`. |

### 3.2 Modified files

| Path | Change |
|---|---|
| `SonicMerge/SonicMergeApp.swift` | Body's `WindowGroup` content swaps from `MixingStationView`-with-`MixingStationViewModel` to `RootTabView`. Remove the `viewModel` `@State` and the two scene-phase / onOpenURL handlers (those handlers move into `RootTabView`). Schema gains `SmartCutSession` and `DenoiseSession`. |
| `SonicMerge/Features/SmartCut/SmartCutViewModel.swift` | Add `init(session: SmartCutSession, modelContext: ModelContext)`. Decode `session.editListJSON` → `EditList` if present. Resolve `session.transcriptCacheRef` → cached transcript if present (lands the VM in `.results` directly, not `.idle`). Add `persist()` writing `editListJSON` and `transcriptCacheRef` back debounced ~300ms on mutation, and on view dismiss. Existing init paths (used by tests) remain; the new init is additive. |
| `SonicMerge/Features/Denoising/CleaningLabViewModel.swift` | Renamed `DenoiseSessionViewModel`. Remove the embedded `smartCutVM` property and the merged-URL Smart Cut wiring (lines that call `smartCutVM.setInputURL` and the `setMergedFileURL` Smart Cut bridging). Init takes a `DenoiseSession`. Persist `intensity` and `processedFilename` back to the session on apply / on dismiss. |
| `SonicMerge/Features/MixingStation/MixingStationView.swift` | Remove the `Denoise` toolbar button (lines ~170–184), the `showCleaningLab` and `mergedFileURLForCleaning` state, the `navigationDestination(isPresented:)` for Cleaning Lab, the `denoiseHaptic` state, and the `navigateToCleaningLab()` method. Keep everything else (timeline, drag-reorder, import, export, theme menu, drop zone). Title stays "SonicMerge"; it's now hosted under the Merge tab. |
| `SonicMergeShareExtension/ShareViewController.swift` | Change copy destination from `clips/` to `<AppGroup>/smart-cut/<newId>/source.<ext>`. Generate a session ID; write `pendingImportFilename`, `pendingImportSessionId`, `pendingImportDestination = "smart-cut"` to App Group UserDefaults. (Exact filename-key contract is documented in §4.4.) |
| `SonicMerge/App/AppConstants.swift` | Add `smartCutSessionDirectory(for: UUID) throws -> URL` and `denoiseSessionDirectory(for: UUID) throws -> URL` next to the existing `clipsDirectory()`. Both create the directory on first call. |
| `SonicMerge/Features/Denoising/AIOrbView.swift` and the denoise content sub-views | Move from being subviews of `CleaningLabView` to being subviews of `DenoiseSessionView`. No code changes — just a relocation of file ownership / their host view. |

### 3.3 Retired files

| Path | Reason |
|---|---|
| `SonicMerge/Features/Denoising/CleaningLabView.swift` | Body splits into `DenoiseSessionView` (denoise half) and `SmartCutSessionView` (Smart Cut half via `SmartCutStudioContainer`). With Denoise and Smart Cut now in different tabs, no shared host view exists. |

## 4. Detailed design

### 4.1 SwiftData models

Two new `@Model` types added to the existing schema. Schema becomes `[AudioClip, GapTransition, SmartCutSession, DenoiseSession]`. SwiftData auto-migrates by adding the two new tables; existing `AudioClip` data is untouched.

```swift
@Model final class SmartCutSession {
    @Attribute(.unique) var id: UUID
    var name: String                 // editable display name; defaults to source basename
    var sourceFilename: String       // path under <AppGroup>/smart-cut/<id>/, e.g. "source.m4a"
    var durationSeconds: Double
    var createdAt: Date
    var lastOpenedAt: Date
    var editListJSON: Data?          // serialized EditList (filler edits + pause edits)
    var transcriptCacheRef: String?  // path under <AppGroup>/smart-cut/<id>/, e.g. "transcript-cache.json"

    init(id: UUID = UUID(), name: String, sourceFilename: String, durationSeconds: Double) {
        self.id = id
        self.name = name
        self.sourceFilename = sourceFilename
        self.durationSeconds = durationSeconds
        self.createdAt = .now
        self.lastOpenedAt = .now
    }
}

@Model final class DenoiseSession {
    @Attribute(.unique) var id: UUID
    var name: String
    var sourceFilename: String         // <AppGroup>/denoise/<id>/source.<ext>
    var processedFilename: String?     // <AppGroup>/denoise/<id>/processed.wav, when applied
    var intensity: Double              // last applied intensity (0–1)
    var durationSeconds: Double
    var createdAt: Date
    var lastOpenedAt: Date

    init(id: UUID = UUID(), name: String, sourceFilename: String, durationSeconds: Double, intensity: Double = 0.5) {
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

**Why JSON for `editListJSON` instead of child `@Model` records.** The edit list is always loaded as a unit when a session opens; there's no cross-session query that benefits from relational storage. JSON keeps the migration story trivial (one column, no foreign keys) and matches how `SmartCutViewModel` already operates internally on `EditList` as a value type. If a later feature needs filler-occurrence-level queries, child models can be added without breaking this schema.

**Encoding contract.** `EditList` already conforms to `Codable` for transcript-cache serialization. Reuse the same encoder/decoder. Schema drift (e.g., adding a `disfluencies` field to `FillerEdit`) handled by `Codable` defaulting; on decode failure, fall back to `nil` and land the VM in `.idle` (covered in §5.1).

### 4.2 RootTabView

```swift
struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    enum Tab: Hashable { case smartCut, denoise, merge }

    @State private var selection: Tab = .smartCut
    @State private var smartCutPath = NavigationPath()
    @State private var denoisePath = NavigationPath()
    @State private var mergePath = NavigationPath()

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack(path: $smartCutPath) {
                SmartCutHomeView()
                    .navigationDestination(for: UUID.self) { sessionId in
                        SmartCutSessionView(sessionId: sessionId)
                    }
            }
            .tabItem { Label("Smart Cut", systemImage: "sparkles") }
            .tag(Tab.smartCut)

            NavigationStack(path: $denoisePath) { /* Denoise mirror */ }
                .tabItem { Label("Denoise", systemImage: "waveform.badge.minus") }
                .tag(Tab.denoise)

            NavigationStack(path: $mergePath) {
                MixingStationView()
            }
            .tabItem { Label("Merge", systemImage: "rectangle.stack") }
            .tag(Tab.merge)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            handlePendingShareExtensionImport()
        }
        .onOpenURL { url in handleDeepLink(url) }
        .onAppear { handlePendingShareExtensionImport() }
        .onReceive(PendingSmartCutOpen.shared.$hash) { hash in
            // Background transcription completion deep-link.
            // Verify the session exists; switch tab; push.
        }
    }

    private func handlePendingShareExtensionImport() {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupID)
        guard let filename = defaults?.string(forKey: "pendingImportFilename") else { return }
        defaults?.removeObject(forKey: "pendingImportFilename")
        let destination = defaults?.string(forKey: "pendingImportDestination") ?? "smart-cut"
        defaults?.removeObject(forKey: "pendingImportDestination")
        let sessionIdRaw = defaults?.string(forKey: "pendingImportSessionId")
        defaults?.removeObject(forKey: "pendingImportSessionId")
        // Routing logic — see §4.4
    }
}
```

**Why `NavigationPath` keyed on `UUID`.** Sessions are stable, identifiable, and pushable by their primary key. `navigationDestination(for: UUID.self)` resolves the ID back to the model in the destination view via `FetchDescriptor`. This avoids carrying `@Model` instances across navigation boundaries (which has lifecycle issues across context invalidation).

**Tab switch preserves stack.** Each `NavigationStack` keeps its own `path` binding. Switching tabs does not reset state — a half-edited session in Smart Cut survives a hop to Merge and back. (This is `TabView`'s default behavior; called out because it matters for the share-extension routing case in §4.4.)

### 4.3 SmartCutSessionView (and its Denoise mirror)

```swift
struct SmartCutSessionView: View {
    let sessionId: UUID
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SmartCutViewModel?

    var body: some View {
        Group {
            if let viewModel {
                SmartCutStudioContainer(vm: viewModel, library: $library)
            } else {
                ProgressView()
            }
        }
        .toolbar { /* Export, delete-session */ }
        .task {
            // Fetch session by id; init VM; mark lastOpenedAt = .now.
        }
        .onDisappear {
            viewModel?.cancelAnalyze() // unless background-mode opted-in
            viewModel?.persist()
        }
    }
}
```

**ViewModel lifecycle.** Each session view instantiates its own `SmartCutViewModel`. Multiple sessions can be open across tabs but only one is rendered at a time per tab; pushing a new session from the recents list creates a new VM and tears down the previous one on disappear. Background analyze opt-in (`Run in BG`) keeps the previous VM's task alive via the existing `BackgroundTranscriptionTask` mechanism — this is unchanged.

**Persistence cadence.** Edit-list mutations on the VM publish via `@Observable`. A debounced subscriber (300ms) calls `persist()` to write `editListJSON` back. On disappear, an immediate `persist()` flushes any pending debounce. `transcriptCacheRef` is set once on `.results` and not re-written. `lastOpenedAt` updates on appear, persisted same time as the first `editListJSON` write or via an explicit `modelContext.save()` on appear.

### 4.4 Share extension routing

**Today's behavior.** Extension copies the file to `<AppGroup>/clips/<basename>` and writes `pendingImportFilename` to App Group UserDefaults. Main app (in `SonicMergeApp.body`) reads it on `scenePhase == .active`, builds `URL` for the file, and calls `viewModel?.importFiles([fileURL])` which inserts an `AudioClip`.

**New behavior.** Extension generates a new UUID, copies the file to `<AppGroup>/smart-cut/<id>/source.<ext>`, and writes:

| Key | Value |
|---|---|
| `pendingImportFilename` | The basename inside the session dir, e.g. `"source.m4a"`. |
| `pendingImportSessionId` | The UUID's string form. |
| `pendingImportDestination` | `"smart-cut"` (hard-coded for now; reserved for a future picker). |

`RootTabView.handlePendingShareExtensionImport` reads all three keys, clears them, and routes:

```
switch destination {
case "smart-cut":
    // Verify file exists at <AppGroup>/smart-cut/<id>/source.<ext>.
    // Probe duration via AVURLAsset.
    // Insert SmartCutSession{id, name=basename, sourceFilename, duration}.
    // selection = .smartCut
    // smartCutPath.append(id)
case "denoise":
    // Mirror for DenoiseSession (future destination picker).
case "merge":
    // Backward-compat path: the legacy clips/ flow. Read from clips/, route to Merge tab.
default:
    // Unknown destination — log + drop.
}
```

**Backward compatibility on upgrade.** A user upgrading mid-share (rare but possible) may have a `pendingImportFilename` key set without `pendingImportDestination`. In that case, treat it as `"merge"` — that's where the file would have gone before — and route it to `MixingStationViewModel.importFiles`. This preserves the old contract.

**Why two filesystem roots.** The Merge tab keeps its `clips/` directory and `AudioClip` model unchanged. Smart Cut sessions live under `smart-cut/` so the two storage layouts can evolve independently and so deletion of a Smart Cut session never touches Merge data.

### 4.5 Deep-link rerouting (background-transcription completion)

`PendingSmartCutOpen.shared.hash` today is consumed by `CleaningLabView.handlePendingSmartCutOpenIfNeeded()` which switches the inner tab to Smart Cut. With Cleaning Lab gone, the deep-link must reroute through `RootTabView`:

1. `RootTabView` observes `PendingSmartCutOpen.shared.$hash`.
2. On a non-nil hash, find the `SmartCutSession` whose `transcriptCacheRef`'s file content matches the hash (or whose source-file hash matches — depends on what `PendingSmartCutOpen` stores; current code stores a hash of the input URL's hash). If no session matches, drop the deep-link.
3. If a match exists, set `selection = .smartCut`, append `session.id` to `smartCutPath`. Clear `PendingSmartCutOpen.shared.hash`.

**Why the existence check.** A user can delete a session before the background transcription completes; without the check, we'd push into a session view that immediately errors on missing-source. Better to drop silently.

### 4.6 Empty state vs. recents-loaded state on home views

Two layout modes on each tab's home view, switched by `@Query` result:

- **Empty (`sessions.isEmpty`)** — centered orb (`✨` for Smart Cut, `🌊`/waveform for Denoise) + one-line tagline + large "Upload Audio" pill button + small "or import from Voice Memos" subtext. Matches Q4 mockup variant B's layout but without the recents block.
- **Loaded** — Upload Audio CTA at top (smaller, full-width pill). Below: a grouped list of session rows. Each row: thumbnail (gradient square with playhead glyph), session name, secondary line `"<duration> · <relative time>"`. Tap → push session view. Swipe-left → destructive Delete.

Both states share the same navigation title ("Smart Cut" or "Denoise") and toolbar.

### 4.7 Toolbar contents per tab

- **Smart Cut tab — Home:** no toolbar items beyond the title. (Upload is the primary CTA in the body.)
- **Smart Cut tab — Session view:** Export button (presents `ExportFormatSheet` → `ExportProgressSheet` → `ActivityViewController`, identical chain to today's Cleaning Lab toolbar). A `Menu` "more" with **Delete session** (destructive role).
- **Denoise tab:** mirror of Smart Cut.
- **Merge tab:** existing Mixing Station toolbar minus the Denoise button. Import (+), Export, Theme menu (`ellipsis.circle`).

### 4.8 Migration of existing user data on upgrade

- Existing `AudioClip` and `GapTransition` records are untouched. The Merge tab opens to the user's existing timeline.
- Smart Cut and Denoise tabs are empty on first launch post-upgrade — no historical sessions exist.
- The `hasImportedFirstClip` `@AppStorage` flag (used to gate trust banners on Mixing Station and Cleaning Lab) is repurposed: it now flips to `true` on the first session created in *any* tab. The flag's meaning ("user has used this app at least once") is preserved without renaming.
- The legacy `pendingImportFilename` UserDefaults key (without `pendingImportDestination`) is treated as a Merge-tab import for one upgrade cycle. After that cycle, the share extension always writes the destination key.

## 5. Edge cases and error handling

### 5.1 Session source file missing on resume

`SmartCutViewModel.init(session:)` resolves the source URL from `<AppGroup>/smart-cut/<session.id>/<session.sourceFilename>` and checks `FileManager.fileExists(atPath:)`. If missing (iCloud purge, manual deletion, App Group reentitlement):

- VM does not enter `.idle` — it enters a new `.error("Source file missing")` state with two affordances: **Delete session** (calls `modelContext.delete(session)`, pops the view) and **Pop back** (no SwiftData mutation; the user can manually delete from the recents list later).
- Do not auto-delete the SwiftData record. The user owns that decision.

Same applies to `DenoiseSession.sourceFilename` for `DenoiseSessionView`.

### 5.2 `editListJSON` decode failure

On `JSONDecoder().decode(EditList.self, from: data)` throwing:

- Log the error (file + reason).
- Set `editListJSON = nil` on the session (clearing the corrupt blob).
- Land the VM in `.idle`. User re-analyzes; the run produces a fresh `editListJSON`.
- No user-facing error; this is a recovery path, not a failure.

### 5.3 `transcriptCacheRef` points at a missing or unreadable file

Treat as a cache miss. VM lands in `.idle`; the next analyze re-runs recognition. The stale ref remains in `editListJSON` — overwritten on the next `.results` write.

### 5.4 File copy fails on Upload Audio (disk full, permission revoked)

In `SmartCutHomeView.fileImporter` callback:

- Wrap the copy in a `do/catch`. On error, present an alert ("Couldn't import this file") and abort.
- Do **not** insert a `SmartCutSession` record. No partial state, no ghost rows in recents.

### 5.5 App Group not entitled

The existing fallback in `SonicMergeApp` (sandbox-mode `ModelContainer`) keeps the main app working — Smart Cut and Denoise sessions still persist and run, but inside the app sandbox instead of the App Group. Share extension delivery does not work in this configuration (extension can't reach the sandbox container); the existing comment block in `SonicMergeApp.swift` already documents this as a development-only fallback. No new code is needed; the new `smartCutSessionDirectory(for:)` helper uses the same App-Group-or-sandbox resolution as `clipsDirectory()`.

### 5.6 Analyze in flight when user pops back to home

`SmartCutSessionView.onDisappear` calls `viewModel.cancelAnalyze()` unconditionally. The user can re-enter the session and re-tap Analyze; cached partial state is discarded. The opt-in `Run in BG` button is the explicit path to keep analyze running in the background — that path uses `BackgroundTranscriptionTask` and is unchanged.

### 5.7 Background-transcription completion for a deleted session

`RootTabView`'s deep-link handler verifies the session exists in SwiftData (`FetchDescriptor` predicate on the matching hash) before pushing. Missing → drop silently. The `PendingSmartCutOpen.shared.hash` is still cleared so the same orphan deep-link doesn't re-fire on the next scene-active.

### 5.8 Two sessions opened from the same source file

User uploads the same file twice. Each gets its own UUID, its own session dir, and its own copy of the source. No dedup attempt — trivial cost (the file is already on disk; one extra copy isn't disastrous), and the user can swipe-delete the dup. A future feature could hash-and-dedup, but it's not in scope here.

### 5.9 Rapid tab switches during analyze

`TabView`'s default behavior keeps each tab's view tree alive across switches. `SmartCutSessionView` is not torn down when the user switches to Merge. The analyze task continues. When the user returns, the VM is still bound and progress is current.

### 5.10 Long session names in recents

Truncate with `lineLimit(1)` and middle-truncation in row body. Full name renders in the session view's nav title (which iOS already truncates appropriately).

## 6. Testing strategy

### 6.1 Unit tests (`SonicMergeTests/`)

- **`SmartCutSessionPersistenceTests.swift`** — Round-trip an `EditList` through `editListJSON`: encode → decode → `XCTAssertEqual`. Cover both an empty list and one with mixed filler/pause edits.
- **`SmartCutViewModelSessionInitTests.swift`** — Three cases:
  1. Session with `editListJSON = nil` and `transcriptCacheRef = nil` → VM lands in `.idle`.
  2. Session with valid `editListJSON` and a present transcript-cache file → VM lands in `.results` with the decoded edit list, no analyze run.
  3. Session whose source file is missing → VM lands in `.error` with the "Source file missing" message.
- **`AppConstantsSessionDirectoryTests.swift`** — `smartCutSessionDirectory(for:)` returns a stable path under App Group when entitled; falls back to sandbox when not. Same for `denoiseSessionDirectory(for:)`.
- **`SchemaMigrationTests.swift`** — Building a `ModelContainer` with the expanded schema and pre-existing `AudioClip` records loads cleanly. Inserting `SmartCutSession` works without affecting `AudioClip` queries.

### 6.2 Integration / UI tests (existing UI test target)

- **`RootTabViewLaunchTests.swift`** — Cold launch: app opens on Smart Cut tab (`Smart Cut` label visible in tab bar with selected indicator). Empty state visible. Upload Audio button reachable.
- **`SmartCutSessionRecentsTests.swift`** — Drive a flow: tap Upload, pick a fixture audio, return to home, verify the new session row appears at the top of recents with correct duration formatting. Force-quit and relaunch; verify the row persists.
- **`SmartCutPushPopTests.swift`** — Tap a recent → session view appears with the source name in the nav title. Tap Back → recents list visible; the just-opened row is at the top (lastOpenedAt updated).
- **`CrossTabIndependenceTests.swift`** — Start an analyze in Smart Cut, opt into `Run in BG`. Switch to Merge, perform an unrelated operation. Switch back; the Smart Cut analyze continues (or completed) without disruption.

### 6.3 Manual QA pass

- Share an `.m4a` from Voice Memos → app launches directly into the Smart Cut tab on a new session view for the shared file.
- Delete a session via swipe-left → confirm `<AppGroup>/smart-cut/<id>/` is deleted on disk.
- Run with App Group disabled (dev simulator without entitlement) → app falls back to sandbox; sessions persist locally; share extension delivery is no-op (acceptable per existing `SonicMergeApp` comment block).
- Force-quit during an analyze → relaunch → session opens in `.idle` (analyze does not auto-resume; user re-taps Analyze). Persisted edit list (if any) is preserved.
- Upgrade-from-old-app simulation: pre-populate `<AppGroup>/clips/foo.m4a` and `pendingImportFilename = "foo.m4a"` (without `pendingImportDestination`) → relaunch → routes to Merge tab, imports as `AudioClip`. Backward-compat path verified.

## 7. Open questions

- **Session rename UX.** The data model supports it (`name` is `var`); the UI doesn't expose it in this round. Worth doing in a follow-up — a long-press → rename action in the recents row, or a rename button in the session view's "more" menu.
- **Storage management.** No bulk-delete or "manage storage" view. If sessions accumulate, users have no aggregate way to see disk use. Probably fine until anecdata says otherwise.
- **Cross-tab handoff.** Currently no path from a Denoise session to a Smart Cut session (e.g., "denoise this clip then run Smart Cut on the result"). Approach 3 in the brainstorm captures this; it's a separate project.
- **Share-extension destination picker.** The `pendingImportDestination` key is plumbed but always `"smart-cut"`. A future extension UI letting the user pick Smart Cut / Denoise / Merge before sharing is straightforward to add on top.
