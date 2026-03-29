# Phase 5: Share Extension - Research

**Researched:** 2026-03-29
**Domain:** iOS App Extension (Share Extension), NSItemProvider, App Group file handoff, URL scheme deep linking
**Confidence:** HIGH (core mechanics), MEDIUM (extensionContext.open workaround strategy)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Extension UI**
- D-01: Minimal auto-dismiss UI — "Adding to SonicMerge..." HUD with filename and spinner. No user confirmation step.
- D-02: Extension dismisses after file copy + main app open succeeds, or on error (silent fail, extension just dismisses).

**File Handoff Strategy**
- D-03: Extension copies raw audio file into App Group container (`AppConstants.clipsDirectory()`), then calls `extensionContext.open(URL("sonicmerge://import?file=..."))` to hand off. (**SEE CRITICAL PITFALL below — this API is not supported for Share Extensions. Research recommends an alternative. Planner MUST resolve this.**)
- D-04: Deep link URL: `sonicmerge://import?file=<percent-encoded-filename>`. Main app reads filename, resolves via `AppConstants.clipsDirectory()`, calls `importFiles([url])`.
- D-05: Extension copies the raw file — no normalization in extension. Normalization runs in main app via `AudioNormalizationService`.
- D-06: Extension does NOT write SwiftData. Only main app writes SwiftData records.

**URL Scheme Registration**
- D-07: Register custom URL scheme `sonicmerge` in main app target's Info.plist (`CFBundleURLTypes`).

**Main App Refresh**
- D-08: Use SwiftUI `.onOpenURL` on `SonicMergeApp`'s `WindowGroup` to receive deep link. Extract file path, call `viewModel.importFiles([fileURL])`.
- D-09: No additional refresh mechanism (no scenePhase polling, no Darwin notifications).

**Duplicate Detection**
- D-10: Deduplicate by `displayName` inside `importFiles()` before normalization. If existing `AudioClip` has same `displayName`, skip silently.
- D-11: Duplicate check in main app inside `importFiles()` — not in extension.

### Claude's Discretion
- Share Extension target configuration (bundle ID suffix, deployment target, entitlements matching main app App Group)
- NSExtensionPrincipalClass choice: `UIViewController` subclass hosting SwiftUI view
- Error handling: if `NSItemProvider.loadFileRepresentation()` fails, dismiss extension silently
- Memory management: use `loadFileRepresentation` (streams to temp file) not `loadDataRepresentation` (loads into memory)
- Exact HUD layout and animation for auto-dismiss UI
- Staging directory for raw copied files (reuse `clipsDirectory()` or separate `pendingDirectory()`)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| IMP-02 | User can receive audio files (.m4a, .wav, .aac) via iOS Share Sheet from other apps | NSExtensionActivationRule predicate for `public.audio` UTType covers all three formats; `loadFileRepresentation` handles large files without memory crash; App Group file copy + deep-link or scenePhase polling triggers `importFiles()` |
</phase_requirements>

---

## Summary

Phase 5 adds a Share Extension target that acts as a thin file relay: it accepts audio files from the iOS Share Sheet, copies the raw file to the App Group shared container, hands control back to the main app for normalization and SwiftData persistence. The extension is the thinnest possible process — no AVFoundation processing, no SwiftData writes, no network activity — to stay within the 120 MB extension process memory ceiling.

The primary technical challenge is correctly implementing the file handoff from the extension to the main app. Decision D-03 and D-04 specify `extensionContext.open(URL("sonicmerge://import?file=..."))` to trigger the main app. **This is a critical pitfall**: Apple's official documentation explicitly restricts `NSExtensionContext.open(_:completionHandler:)` to Today widgets only; Share Extensions calling this method receive `success == false` and the main app never opens. The planner must resolve this with the UserDefaults-based pending-file marker approach documented below, which is the standard ecosystem pattern.

The secondary technical area is the `NSExtensionActivationRule` predicate — the extension must appear only when the shared item is a supported audio file. Using a custom `SUBQUERY` predicate with `UTI-CONFORMS-TO "public.audio"` is the correct approach; the pre-defined dictionary keys (`NSExtensionActivationSupportsAttachmentsWithMaxCount`) do not filter by UTType.

**Primary recommendation:** Implement the extension as a `UIViewController` subclass (`ShareExtensionViewController`) that hosts a SwiftUI HUD view via `UIHostingController`. For main-app handoff, write a pending-file key to `UserDefaults(suiteName: appGroupID)` instead of calling `extensionContext.open()`, then in the main app read and clear this key on `scenePhase == .active`. This overrides D-09 (the planner must note the locked decision conflict and use scenePhase polling rather than `onOpenURL`).

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Foundation (NSItemProvider) | iOS 26.2 SDK | Load file from Share Sheet input | Only API for reading shared items in extensions |
| UniformTypeIdentifiers (UTType) | iOS 14+ | Type-safe UTType for audio filtering | Modern replacement for string-based UTI; already used in `UTType+Audio.swift` |
| UIKit (UIViewController, UIHostingController) | iOS 26.2 SDK | Share Extension principal class must be UIViewController | NSExtension host requires UIKit principal class |
| SwiftUI | iOS 26.2 SDK | HUD view rendered inside UIHostingController | Consistent with app's SwiftUI architecture |
| Foundation (FileManager) | iOS 26.2 SDK | Copy raw file to App Group container | Standard file I/O |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| UserDefaults (App Group suite) | iOS 26.2 SDK | Write pending-file key so main app can pick up after extension dismisses | Required because `extensionContext.open()` is unsupported for Share Extensions |
| AppConstants (existing) | — | Resolve App Group container URL and clips directory | Both targets must use identical constant — no duplication |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| UserDefaults pending-key | Darwin notifications (`CFNotificationCenterGetDarwinNotifyCenter`) | Darwin notifications are a known cross-process signal mechanism on iOS, but UserDefaults with App Groups is simpler, requires no extra framework, and survives cold app launch |
| UserDefaults pending-key + scenePhase | `extensionContext.open(URL)` (D-03) | `extensionContext.open()` is officially unsupported for Share Extensions (Today widget only); returns `success == false` in practice on iOS 17+ |
| UIViewController + UIHostingController | Pure SwiftUI ShareViewController | NSExtension host requires a UIViewController subclass as principal class; SwiftUI alone cannot be the NSExtensionPrincipalClass |

**Installation:** No new packages. Extension target reuses project frameworks and `AppConstants.swift` via shared framework or direct file inclusion.

---

## Architecture Patterns

### Recommended Project Structure

```
SonicMerge/                          (main app target — existing)
  App/AppConstants.swift             (shared — extension must include in target membership)
  Extensions/UTType+Audio.swift      (shared — extension must include in target membership)

SonicMergeShareExtension/            (NEW Xcode target — Share Extension)
  ShareExtensionViewController.swift  (NSExtensionPrincipalClass, UIViewController subclass)
  ShareHUDView.swift                  (SwiftUI HUD — hosted by UIHostingController)
  Info.plist                          (NSExtension config, NSExtensionActivationRule)
  SonicMergeShareExtension.entitlements  (App Group: group.com.yourteam.SonicMerge)
```

### Pattern 1: Extension Target with UIViewController + SwiftUI HUD

**What:** `ShareExtensionViewController` inherits from `UIViewController`. In `viewDidLoad`, it embeds a `UIHostingController<ShareHUDView>` as a child view controller. The SwiftUI view is passed a binding or `@Observable` state object that drives the HUD's state machine (copying → success/error).

**When to use:** Always — this is the only architecture that satisfies NSExtension's principal class requirement while using SwiftUI.

**Example:**
```swift
// Source: Apple App Extension Programming Guide + UIHostingController docs
@objc(ShareExtensionViewController)
final class ShareExtensionViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let hudModel = ShareHUDModel()
        let hudView = ShareHUDView(model: hudModel)
        let hosting = UIHostingController(rootView: hudView)
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hosting.didMove(toParent: self)
        // Begin file load asynchronously
        Task { await loadAndCopyFile(model: hudModel) }
    }
}
```

Note: `@objc(ShareExtensionViewController)` must match `NSExtensionPrincipalClass` in the extension's Info.plist.

### Pattern 2: NSItemProvider File Loading (Memory-Safe)

**What:** Use `loadFileRepresentation(forTypeIdentifier:completionHandler:)` (the string-UTI variant) or the modern UTType overload on iOS 16+. The system streams the file to a temporary URL. Copy it immediately inside the completion handler before the temp URL is invalidated.

**When to use:** Always. Never use `loadDataRepresentation` — it loads the entire file into memory, which violates the 120 MB extension ceiling for 30 MB+ audio files.

**Example:**
```swift
// Source: Apple Developer Documentation — NSItemProvider.loadFileRepresentation
guard let itemProvider = (extensionContext?.inputItems.first as? NSExtensionItem)?
    .attachments?.first else { return }

itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.audio.identifier) { tempURL, error in
    guard let tempURL, error == nil else {
        // signal error to HUD
        return
    }
    do {
        let clipsDir = try AppConstants.clipsDirectory()
        let filename = tempURL.lastPathComponent  // preserve original extension
        let dest = clipsDir.appending(path: filename)
        // Overwrite if exists (dedup by displayName happens in main app)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: tempURL, to: dest)
        // Write pending-file key so main app picks up on next scenePhase .active
        let defaults = UserDefaults(suiteName: AppConstants.appGroupID)
        defaults?.set(filename, forKey: "pendingImportFilename")
        // Signal success to HUD
    } catch {
        // Signal error to HUD
    }
}
```

**Critical:** `tempURL` is invalidated when the completion handler returns. All file system operations must complete synchronously inside this block before returning.

### Pattern 3: Main App Pickup via scenePhase

**What:** Since `extensionContext.open()` is unsupported for Share Extensions, the main app must proactively check the App Group UserDefaults for a pending import file whenever it becomes active. Use SwiftUI's `scenePhase` environment value observed in `SonicMergeApp`.

**When to use:** Required — replaces D-09's `onOpenURL`-only approach. The `onOpenURL` modifier can remain as a fallback but is not the primary trigger.

**Example:**
```swift
// In SonicMergeApp.swift or MixingStationView
@Environment(\.scenePhase) private var scenePhase

.onChange(of: scenePhase) { _, newPhase in
    guard newPhase == .active else { return }
    let defaults = UserDefaults(suiteName: AppConstants.appGroupID)
    if let filename = defaults?.string(forKey: "pendingImportFilename") {
        defaults?.removeObject(forKey: "pendingImportFilename")
        if let url = try? AppConstants.clipsDirectory().appending(path: filename) {
            viewModel.importFiles([url])
        }
    }
}
```

### Pattern 4: NSExtensionActivationRule Predicate for Audio

**What:** A custom `SUBQUERY` predicate ensures the extension appears only for audio files. Use `UTI-CONFORMS-TO "public.audio"` — the parent type that `.wav`, `.m4a`, and `.aac` all conform to. This is the correct filter for IMP-02.

**Info.plist entry (extension target):**
```xml
<key>NSExtensionActivationRule</key>
<string>SUBQUERY (
    extensionItems,
    $extensionItem,
    SUBQUERY (
        $extensionItem.attachments,
        $attachment,
        ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.audio"
    ).@count == $extensionItem.attachments.@count
).@count >= 1</string>
```

**App Store requirement:** `TRUEPREDICATE` (the default template value) causes App Store rejection. Replace with the above predicate before submission.

### Pattern 5: Extension Entitlements

The Share Extension target needs its own `.entitlements` file with the **identical** App Group entry:

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.yourteam.SonicMerge</string>
</array>
```

Both entitlement files must use `AppConstants.appGroupID` = `"group.com.yourteam.SonicMerge"`.

### Anti-Patterns to Avoid

- **Calling `extensionContext.open(URL)`:** This method is documented for Today widgets only. On Share Extensions it either crashes, is ignored, or returns `success == false`. Do not use it.
- **`loadDataRepresentation` for large files:** Loads entire file into memory. For 30 MB audio, this will hit the 120 MB extension memory ceiling and crash. Use `loadFileRepresentation` instead.
- **Processing audio in the extension:** AVFoundation audio processing is expensive. The extension is a thin relay — copy the raw file only. Normalization belongs in the main app.
- **Writing SwiftData in the extension:** Per D-06. SwiftData model setup in a memory-constrained extension process risks corruption and adds unnecessary overhead.
- **Using `TRUEPREDICATE`:** Will cause App Store rejection.
- **Accessing `tempURL` after completion handler returns:** The temp file URL provided by `loadFileRepresentation` is invalidated immediately on completion handler exit. Copy must happen synchronously inside the handler.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| UTType-based audio filtering | Custom file extension checking (`.m4a`, `.wav`) | `UTI-CONFORMS-TO "public.audio"` predicate | Extension conformance is the iOS standard; custom extension checks miss renaming, future formats |
| File streaming from share payload | `loadDataRepresentation` + manual write | `loadFileRepresentation` | loadFileRepresentation streams to disk, never loads full file into memory; eliminates OOM crash risk |
| Inter-process notification | Darwin notification, XPC, or socket | `UserDefaults(suiteName:)` App Group | Simplest IPC for this use case; survives cold launch; synchronizes automatically |
| Extension principal class | Pure SwiftUI `@main` | `UIViewController` subclass | NSExtension host requires UIViewController; SwiftUI cannot be NSExtensionPrincipalClass |

**Key insight:** A Share Extension is not an app — it has a 120 MB memory ceiling, no `@main`, and cannot call `UIApplication` methods. Every architectural choice must respect these process constraints.

---

## Common Pitfalls

### Pitfall 1: extensionContext.open() Does Not Work for Share Extensions

**What goes wrong:** `extensionContext?.open(URL("sonicmerge://import?file=...")) { success in ... }` is called and `success` is `false`. The main app never opens. The file is in the App Group container but the main app never knows about it.

**Why it happens:** Apple explicitly restricts `NSExtensionContext.open(_:completionHandler:)` to Today widgets (now called Widgets). The method exists on `NSExtensionContext` but the OS does not honor it from Share Extensions. This is documented in the App Extension Programming Guide: "A Today widget (and no other app extension type) can ask the system to open its containing app by calling the openURL:completionHandler: method."

**How to avoid:** Write a `pendingImportFilename` key to `UserDefaults(suiteName: AppConstants.appGroupID)`. In the main app, observe `scenePhase == .active` and drain this key. This correctly handles both cold launch (app was not running — scenePhase fires `.active` on first appearance) and hot launch (app in foreground or background — scenePhase fires `.active` on return to foreground).

**Warning signs:** `success == false` in the extensionContext.open callback; main app never receives `onOpenURL` callback.

**Decision conflict:** CONTEXT.md D-03 specifies `extensionContext.open()` and D-09 says "No additional refresh mechanism." Research overrides D-03 and D-09: the planner MUST implement the `UserDefaults` + `scenePhase` approach. D-08 (`onOpenURL`) can be retained as a complementary path if desired but cannot be the sole mechanism.

### Pitfall 2: loadFileRepresentation tempURL Invalidation

**What goes wrong:** The file URL from `loadFileRepresentation` completion handler is copied to a variable and used after the completion handler exits. The file no longer exists, causing a silent copy failure or crash.

**Why it happens:** The system deletes the temp file immediately after the completion handler returns. This is documented behavior.

**How to avoid:** Complete `FileManager.copyItem(at:to:)` synchronously inside the completion handler before returning.

**Warning signs:** Intermittent "No such file" errors during import; works for small files but fails for large ones (timing).

### Pitfall 3: App Group Entitlement Mismatch

**What goes wrong:** The extension cannot access `AppConstants.clipsDirectory()` because the extension target's entitlement file has a different App Group identifier, or the App Group capability was not added to the extension target in Xcode.

**Why it happens:** Xcode's Share Extension template creates a new target without inheriting the main target's capabilities. The entitlement file must be created manually and the App Group must be added under Signing & Capabilities for the extension target.

**How to avoid:** Add `com.apple.security.application-groups` with `group.com.yourteam.SonicMerge` to both the extension's `.entitlements` file and via Xcode > Extension Target > Signing & Capabilities > App Groups.

**Warning signs:** `AppConstants.clipsDirectory()` throws `AppGroupError.containerNotFound` in the extension; extension crashes on any file operation.

### Pitfall 4: NSExtensionPrincipalClass Name Mismatch

**What goes wrong:** The extension launches but immediately crashes or shows a black screen. The system cannot instantiate the principal class.

**Why it happens:** `NSExtensionPrincipalClass` in Info.plist must match the Objective-C runtime name of the principal class. In Swift, the runtime name is mangled unless `@objc(ClassName)` is used.

**How to avoid:** Annotate the principal view controller with `@objc(ShareExtensionViewController)` and set `NSExtensionPrincipalClass` to `$(PRODUCT_MODULE_NAME).ShareExtensionViewController` or the bare `ShareExtensionViewController` depending on how the template resolves it. Verify after first build.

**Warning signs:** Extension appears in Share Sheet but crashes immediately upon selection.

### Pitfall 5: TRUEPREDICATE in App Store Build

**What goes wrong:** App Store submission is rejected because the extension's `NSExtensionActivationRule` is still set to `TRUEPREDICATE` (Xcode template default).

**Why it happens:** Xcode's Share Extension template inserts `TRUEPREDICATE` as a placeholder, which makes the extension appear for all content types. Apple requires a specific activation rule.

**How to avoid:** Replace `TRUEPREDICATE` with the `SUBQUERY ... UTI-CONFORMS-TO "public.audio"` predicate from Pattern 4.

**Warning signs:** Extension appears in the Share Sheet for non-audio content (images, URLs, text) — this is the signal that `TRUEPREDICATE` is still active.

### Pitfall 6: Memory Limit Exceeded on Large Files

**What goes wrong:** Sharing a 30 MB+ audio file crashes the Share Extension with `EXC_RESOURCE RESOURCE_TYPE_MEMORY`.

**Why it happens:** Share Extensions have a hard 120 MB memory limit. `loadDataRepresentation` loads the entire file into memory at once, pushing a 30 MB+ file into violation territory when combined with the extension baseline memory usage.

**How to avoid:** Always use `loadFileRepresentation` (streams to a temp file on disk). The file is never fully in memory; only the copy operation runs through FileManager. Success criterion SC-2 requires this.

**Warning signs:** Extension crashes specifically with large files; fine with small test files.

### Pitfall 7: AppConstants.swift Not in Extension Target Membership

**What goes wrong:** Extension fails to compile because `AppConstants` is not found.

**Why it happens:** Files in the main app target are not automatically shared with the extension target. Each file must explicitly have the extension target checked in Xcode's Target Membership panel.

**How to avoid:** In `AppConstants.swift` and `UTType+Audio.swift`, open File Inspector in Xcode, check `SonicMergeShareExtension` under Target Membership. Do not duplicate the files.

**Warning signs:** Compile error in the extension target: `use of unresolved identifier 'AppConstants'`.

---

## Code Examples

### NSExtension Info.plist configuration

```xml
<!-- Source: Apple App Extension Programming Guide + NSExtensionActivationRule docs -->
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <string>SUBQUERY (
    extensionItems,
    $extensionItem,
    SUBQUERY (
        $extensionItem.attachments,
        $attachment,
        ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.audio"
    ).@count == $extensionItem.attachments.@count
).@count >= 1</string>
    </dict>
    <key>NSExtensionMainStoryboard</key>
    <!-- Remove this line — using NSExtensionPrincipalClass instead -->
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).ShareExtensionViewController</string>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
</dict>
```

### Pending-file handoff via UserDefaults (replaces extensionContext.open)

```swift
// Source: standard App Group UserDefaults pattern
// In extension after successful file copy:
let defaults = UserDefaults(suiteName: AppConstants.appGroupID)
defaults?.set(filename, forKey: "pendingImportFilename")
defaults?.synchronize()  // flush before extension process suspends
extensionContext?.completeRequest(returningItems: nil)
```

### Main app pickup via scenePhase (replaces D-09 "no polling")

```swift
// Source: standard scenePhase pattern for extension-to-app handoff
// In SonicMergeApp.swift WindowGroup body:
WindowGroup {
    MixingStationView()
        .environment(viewModel)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            let defaults = UserDefaults(suiteName: AppConstants.appGroupID)
            guard let filename = defaults?.string(forKey: "pendingImportFilename") else { return }
            defaults?.removeObject(forKey: "pendingImportFilename")
            guard let clipsDir = try? AppConstants.clipsDirectory() else { return }
            let fileURL = clipsDir.appending(path: filename)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
            viewModel.importFiles([fileURL])
        }
}
@Environment(\.scenePhase) private var scenePhase
```

### Duplicate detection inside importFiles (for D-10/D-11)

```swift
// Add this guard inside MixingStationViewModel.performImport, before normalizationService.normalize:
let displayName = url.deletingPathExtension().lastPathComponent
let isDuplicate = clips.contains { $0.displayName == displayName }
guard !isDuplicate else { continue }
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SLComposeServiceViewController (simple post UI) | Custom UIViewController + SwiftUI HUD | iOS 14+ | Full control over UI; required for non-social share use cases |
| loadItem(forTypeIdentifier:) with String UTI | loadFileRepresentation(forTypeIdentifier:) + UTType | iOS 16+ | Type-safe, streams to disk, no memory spike |
| TRUEPREDICATE activation rule | SUBQUERY predicate with UTI-CONFORMS-TO | App Store review requirement | Prevents rejection; limits extension to intended content |
| NSUserDefaults synchronize | synchronize() still useful before extension suspends | Deprecated as primary cache management but reliable for this use case | Must call before `completeRequest` to ensure defaults are flushed |

**Deprecated/outdated:**
- `SLComposeServiceViewController`: Simple post-style sheet. Not suitable here — provides no control over the file copy workflow.
- `loadItem(forTypeIdentifier: kUTTypeAudio as String)`: String-based UTI API. iOS 16+ has a UTType overload; use `UTType.audio.identifier` as the string if targeting below iOS 16, or the UTType overload at iOS 16+.

---

## Open Questions

1. **extensionContext.open() vs scenePhase polling — which is more reliable for cold launch?**
   - What we know: When the main app is not running, sharing completes and the file is in the App Group container. When the user is returned to the source app (Voice Memos, Files), if they then manually open SonicMerge, `scenePhase` fires `.active`, and the pending key is read.
   - What's unclear: Whether there is a way to automatically switch the user to SonicMerge after sharing without requiring a manual tap. Apple's design intent is that the user closes the Share Sheet and continues in the source app.
   - Recommendation: Accept Apple's UX pattern. The extension completes, the file is stored, the user opens SonicMerge and sees the new clip. This is the standard pattern (Working Copy, Reeder, Notchmeister all use this flow). No automatic app switch is needed.

2. **Bundle ID for the extension target**
   - What we know: Main app is `com.dtech.SonicMerge`. Extension bundle ID should be a suffix: `com.dtech.SonicMerge.ShareExtension`.
   - What's unclear: No constraint in CONTEXT.md. Planner should use this suffix.
   - Recommendation: `com.dtech.SonicMerge.ShareExtension` — standard Apple convention.

3. **Filename collision in clipsDirectory when extension copies raw file**
   - What we know: `performImport` in the main app always generates a new UUID filename. The extension copies the raw file with the original filename (or a UUID prefixed copy). If the user shares "voice_memo.m4a" twice before the main app opens, the second share will overwrite the first in clipsDirectory.
   - What's unclear: D-10 deduplicates by displayName, so the second import is silently skipped anyway. The overwrite is not a correctness issue.
   - Recommendation: Extension should write with the original filename (no UUID). If a file with that name already exists in clipsDirectory, overwrite it (remove + copy). The main app's dedup by displayName prevents double-import.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (`import Testing`) — established in Phase 01 |
| Config file | No explicit config file — PBXFileSystemSynchronizedRootGroup (zero-config) |
| Quick run command | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SonicMergeTests/ShareExtensionTests` |
| Full suite command | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| IMP-02 | File copy into App Group container succeeds | unit | `xcodebuild test ... -only-testing:SonicMergeTests/ShareExtensionTests/testFileCopyToClipsDirectory` | ❌ Wave 0 |
| IMP-02 | 30 MB+ file copy does not OOM (uses loadFileRepresentation pathway) | unit (simulated large file) | `xcodebuild test ... -only-testing:SonicMergeTests/ShareExtensionTests/testLargeFileCopyDoesNotCrash` | ❌ Wave 0 |
| IMP-02 | Duplicate displayName is skipped in importFiles | unit | `xcodebuild test ... -only-testing:SonicMergeTests/MixingStationViewModelTests/testDuplicateFilenameIsSkipped` | ❌ Wave 0 |
| IMP-02 | Pending import key is written and cleared | unit | `xcodebuild test ... -only-testing:SonicMergeTests/ShareExtensionTests/testPendingKeyWrittenAndCleared` | ❌ Wave 0 |
| IMP-02 | Main app picks up pending file on scenePhase .active | unit | `xcodebuild test ... -only-testing:SonicMergeTests/MixingStationViewModelTests/testPendingImportPickedUpOnActive` | ❌ Wave 0 |

Note: The extension target itself (`SonicMergeShareExtension`) cannot be directly unit tested from `SonicMergeTests`. Tests for file-copy logic should extract pure functions/services into the main app target (or a shared framework) and test them there. The ShareExtensionViewController wiring is validated by human review (SC-1, SC-2, SC-3 success criteria).

### Sampling Rate
- **Per task commit:** Run `xcodebuild test -only-testing:SonicMergeTests/ShareExtensionTests` + `SonicMergeTests/MixingStationViewModelTests/testDuplicateFilenameIsSkipped`
- **Per wave merge:** Full suite green
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `SonicMergeTests/ShareExtensionTests.swift` — covers IMP-02 file copy, pending key, large file
- [ ] `SonicMergeTests/MixingStationViewModelTests.swift` — add `testDuplicateFilenameIsSkipped` + `testPendingImportPickedUpOnActive`
- [ ] Large file fixture (~1 MB representative, not 30 MB) — synthetic WAV generated via existing Python/afconvert pattern

---

## Sources

### Primary (HIGH confidence)
- Apple App Extension Programming Guide (https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html) — Share Extension structure, NSExtensionActivationRule, completeRequest pattern
- Apple App Extension Programming Guide: Scenarios (https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html) — App Group UserDefaults pattern; confirmed `extensionContext.open()` restriction
- Apple Developer Docs — NSItemProvider.loadFileRepresentation (https://developer.apple.com/documentation/foundation/nsitemprovider/loadfilerepresentation(fortypeidentifier:completionhandler:)) — file streaming to temp URL, invalidation on handler exit
- Project source — `AppConstants.swift`, `SonicMerge.entitlements`, `MixingStationViewModel.swift`, `UTType+Audio.swift` — verified existing App Group ID, import pipeline, UTType declarations

### Secondary (MEDIUM confidence)
- Apple Developer Forums thread on extensionContext.open() for Share Extensions — multiple reports confirming `success == false` on iOS 17+; consistent with official docs restricting to Today widgets
- humancode.us "All about Item Providers" (https://www.humancode.us/2023/07/08/all-about-nsitemprovider.html) — iOS 16+ UTType extension on NSItemProvider; temp URL lifecycle
- NSExtensionActivationRule predicate pattern — verified via Apple documentation entry + iosdevnuggets.com article; `UTI-CONFORMS-TO "public.audio"` confirmed as correct parent UTType for wav/m4a/aac
- Memory limit 120 MB — verified via Apple Developer Forums thread (https://developer.apple.com/forums/thread/73148) and multiple engineering blog reports

### Tertiary (LOW confidence)
- liman.io responder chain UIApplication workaround — NOT recommended; potential App Store violation; mentioned only for completeness
- Multiple unverified blog posts on `extensionContext.open()` — consistent with primary sources confirming unsupported status

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries are standard iOS SDK; no third-party dependencies
- Architecture: HIGH — UIViewController + UIHostingController + UserDefaults pending key is the established ecosystem pattern; verified against Apple docs
- Pitfalls: HIGH for extensionContext.open() restriction (primary source verified); HIGH for loadFileRepresentation lifecycle; MEDIUM for exact NSExtensionActivationRule predicate syntax (verified from multiple secondary sources)
- extensionContext.open() workaround: MEDIUM — the pattern is correct but the exact scenePhase behavior on cold launch (app not running at all) depends on the user manually opening the app; no automated launch is possible

**Research date:** 2026-03-29
**Valid until:** 2026-09-29 (iOS Share Extension API is stable; no significant changes expected)
