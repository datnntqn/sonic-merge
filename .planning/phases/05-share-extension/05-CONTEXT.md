# Phase 5: Share Extension - Context

**Gathered:** 2026-03-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Add an iOS Share Extension target so users can send audio files from Voice Memos, Files, or any app to SonicMerge via the iOS Share Sheet. The shared file appears as a clip ready for editing in the Mixing Station — no extra steps required.

Scope: Share Extension Xcode target, extension UI, file handoff pipeline, URL scheme registration, duplicate detection, and main app deep-link handler. No new Mixing Station features, no UI changes to existing screens.

</domain>

<decisions>
## Implementation Decisions

### Extension UI
- **D-01:** Minimal auto-dismiss UI — show a brief "Adding to SonicMerge..." HUD with the filename and a spinner, then auto-dismiss on completion. No user confirmation step required.
- **D-02:** Extension dismisses itself after successfully copying the file and opening the main app (or on error — silent fail for v1, extension just dismisses).

### File Handoff Strategy
- **D-03:** Extension copies the raw audio file into the App Group container (same `AppConstants.clipsDirectory()` path), then calls `extensionContext.open(URL("sonicmerge://import?file=..."))` to hand off to the main app.
- **D-04:** The file path is embedded in the deep link URL as a query parameter: `sonicmerge://import?file=<percent-encoded-filename>`. The main app reads the filename, resolves the full URL via `AppConstants.clipsDirectory()`, and calls `importFiles([url])`.
- **D-05:** The extension copies the **raw file** (no normalization in extension). All normalization runs inside `AudioNormalizationService` in the main app, via the existing `importFiles()` pipeline — same path as the document picker import.
- **D-06:** The extension does NOT write to SwiftData. Only the main app writes SwiftData records, after normalization completes.

### URL Scheme Registration
- **D-07:** Register custom URL scheme `sonicmerge` in the main app target's Info.plist (`CFBundleURLTypes`). This is required for `extensionContext.open()` to work and for the main app to receive `onOpenURL` callbacks.

### Main App Refresh
- **D-08:** Use SwiftUI's `.onOpenURL` modifier on `MixingStationView` (or `SonicMergeApp`'s `WindowGroup`) to receive the deep link. When the scheme is `sonicmerge` and the host is `import`, extract the file path and call `viewModel.importFiles([fileURL])`.
- **D-09:** No additional refresh mechanism (no scenePhase polling, no Darwin notifications). `onOpenURL` handles both cold launch (app was not running) and hot launch (app already in foreground) correctly.

### Duplicate Detection
- **D-10:** Deduplicate by **filename** (`displayName`): inside `importFiles()`, before normalization, check if any existing `AudioClip` in SwiftData has the same `displayName`. If a match exists, skip that URL silently (no error shown to user).
- **D-11:** Duplicate check runs in the **main app** inside `importFiles()` — not in the extension. Keeps all dedup logic co-located with the import pipeline.

### Claude's Discretion
- Share Extension target configuration details (bundle ID suffix, deployment target, entitlements — must match main app's App Group)
- NSExtensionPrincipalClass choice: `UIViewController` subclass or `ShareExtensionViewController` with a SwiftUI hosting view
- Error handling: if `NSItemProvider.loadFileRepresentation()` fails (unsupported type, load error), dismiss extension silently
- Memory management for large files: use `loadFileRepresentation` (streams to temp file) rather than `loadDataRepresentation` (loads into memory) to satisfy SC-2 (30 MB+ files must not crash)
- Exact HUD layout and animation for the auto-dismiss UI
- Staging directory for raw copied files before normalization (reuse `clipsDirectory()` or a separate `pendingDirectory()`)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — IMP-02 (Share Sheet import requirement)

### App Group & Import Infrastructure (read before implementing)
- `SonicMerge/App/AppConstants.swift` — App Group ID, `clipsDirectory()` path resolution; extension must use the same constants
- `SonicMerge/SonicMerge.entitlements` — App Group entitlement (`group.com.yourteam.SonicMerge`); Share Extension target needs an identical entitlement
- `SonicMerge/SonicMergeApp.swift` — ModelContainer setup with App Group container; `onOpenURL` handler wires in here
- `SonicMerge/Features/Import/ImportViewModel.swift` — Existing import ViewModel (may contain reusable import logic)
- `SonicMerge/Features/MixingStation/MixingStationViewModel.swift` — `importFiles([URL])` — the main import entry point the deep link will call
- `SonicMerge/Services/AudioNormalizationService.swift` — Actor-based normalization pipeline; all shared audio processing runs through this

### Pattern References
- `.planning/phases/01-foundation-import-pipeline/01-CONTEXT.md` — Phase 1 decisions that set up the App Group foundation this phase depends on
- `.planning/phases/02-merge-pipeline-mixing-station-ui/02-CONTEXT.md` — MixingStationViewModel and import pipeline patterns

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AppConstants.appGroupID` + `AppConstants.clipsDirectory()`: both the extension and the main app must use this to resolve the shared clips directory. Already handles directory creation.
- `MixingStationViewModel.importFiles([URL])`: drop-in entry point for the deep-link handler — no new import logic needed in the main app, only a URL scheme handler wired to this method.
- `AudioNormalizationService`: handles the heavy normalization work on a background actor — extension does NOT need to replicate this.
- `UTType+Audio.swift`: audio UTType declarations reusable in the extension's `NSExtensionActivationRule` / `NSItemProvider` type filtering.

### Established Patterns
- Actor-based background services (`AudioNormalizationService`, `AudioMergerService`) with `@MainActor` ViewModel actor-hopping — follow this for any new work in the extension.
- SwiftData `ModelConfiguration(groupContainer: .identifier(AppConstants.appGroupID))` — the extension should NOT write SwiftData; the main app's existing container handles all persistence.
- MVVM: `@Observable @MainActor` ViewModel pattern — if the extension needs a ViewModel for its HUD state, follow the same pattern.

### Integration Points
- `SonicMergeApp.swift` `WindowGroup` body: add `.onOpenURL { url in ... }` here (or on `MixingStationView`) to handle `sonicmerge://import?file=...`
- `SonicMerge/Info.plist` (or Xcode target Build Settings): register `CFBundleURLTypes` with scheme `sonicmerge`
- Share Extension target needs its own `Info.plist`, `Entitlements.plist` (matching App Group), and `NSExtension` configuration declaring `NSExtensionActivationRule` for audio UTTypes

</code_context>

<specifics>
## Specific Ideas

- The auto-dismiss HUD should match the app's "Minimalist Soft Professional" aesthetic — white card, #007AFF accent, San Francisco font, 2pt corner radius — consistent with the rest of the app even though it's a separate process.
- `extensionContext.open()` only works if the URL scheme is registered in the main app target AND the device has the app installed. This is the standard Share Extension → main app handoff pattern used by apps like Working Copy, Reeder, etc.
- Use `NSItemProvider.loadFileRepresentation(forTypeIdentifier:completionHandler:)` (not `loadDataRepresentation`) to ensure large files are streamed to a temp file rather than loaded into memory — satisfies SC-2 (30 MB+ must not crash).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 05-share-extension*
*Context gathered: 2026-03-29*
