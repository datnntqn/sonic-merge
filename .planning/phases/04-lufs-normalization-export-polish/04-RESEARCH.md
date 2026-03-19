# Phase 4: LUFS Normalization + Export Polish - Research

**Researched:** 2026-03-19
**Domain:** iOS audio loudness normalization (BS.1770 / EBU R128), SwiftUI export UX, AVFoundation PCM pipeline
**Confidence:** HIGH (core stack verified against live source code and official package repository)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- LUFS normalization toggle lives **inside the existing `ExportFormatSheet`** — an additional toggle row above the Export button (no new screen or sheet)
- Toggle label: "Normalize to -16 LUFS"
- Toggle is **off by default** (opt-in) — no surprise loudness changes to existing workflows
- Toggle state **persists via `UserDefaults`** (via `@AppStorage`) — podcasters who turn it on don't have to toggle it every session
- The same toggle appears in **both MixingStationView and CleaningLabView** export flows — `ExportFormatSheet` already shared; normalization option is available at every export point
- **Fixed at -16 LUFS only** — no preset picker, no custom target slider
- Normalization runs as a **single inline pass**: measure integrated loudness (BS.1770), compute gain offset, apply gain during export write — no intermediate temp file
- **Silent normalization** — no loudness measurement displayed to the user before or after export
- When the LUFS toggle is on, the `ExportProgressSheet` title changes from **"Exporting..."** to **"Exporting & Normalizing..."**
- After the iOS share sheet dismisses: **state resets to ready** — `exportedFileURL` clears, `exportProgress` resets to 0, sheet dismisses cleanly
- **Auto-present share sheet immediately** after export completes — no intermediate confirmation step

### Claude's Discretion
- LUFS measurement implementation: use `spfk-loudness` Swift package if it supports iOS 17+; fall back to manual BS.1770-3 integrated loudness via vDSP if not
- `LUFSNormalizationService` actor structure and injection pattern (should mirror `AudioNormalizationService` / `AudioMergerService` precedent)
- Gain application strategy: apply as a single scalar gain on the PCM buffer stream or via `AVAudioMixInputParameters` volume ramp
- Exact UserDefaults key naming and storage location

### Deferred Ideas (OUT OF SCOPE)
- LUFS preset picker (-14 LUFS for Apple Podcasts, -23 LUFS for broadcast EBU R128)
- Measured LUFS display ("Your audio is -24.2 LUFS")
- "Share again" / last export persistence in toolbar
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| EXP-03 | User can apply LUFS loudness normalization (-16 LUFS podcast standard) before export | BS.1770 integrated loudness measurement algorithm documented; vDSP K-weighting filter coefficients verified; gain application via AVAssetWriter CMSampleBuffer scalar multiply pattern confirmed |
</phase_requirements>

---

## Summary

Phase 4 has two concerns: (1) wiring a -16 LUFS normalization pass into the existing `AudioMergerService` export pipeline, and (2) polishing share-sheet presentation and post-share state reset across both export paths.

The critical blocker from STATE.md — whether `spfk-loudness` supports iOS 17+ — is now resolved: the package's `Package.swift` declares `platforms: [.macOS(.v13), .iOS(.v16)]`. It is compatible with the project's iOS 17 minimum deployment target. However, the package requires **Swift 6.2 tools version**, which means Xcode 26+ is required to resolve it as a dependency. Because the project currently uses `exportAsynchronously` (iOS 17 compat shim) and its test framework uses Swift Testing (which is iOS 17+), this tools-version requirement should be acceptable — but it must be verified against the project's current Xcode toolchain before adoption. If tools-version is a blocker, the fallback is a manual BS.1770-3 vDSP implementation (two biquad IIR filter stages at 48 kHz).

The normalization strategy is: (a) measure integrated loudness of the output file using `spfk-loudness` or vDSP, (b) compute a linear gain offset to reach -16 LUFS, (c) re-export with that gain applied as a scalar multiply on every PCM sample buffer during the existing `AVAssetWriter` write loop. This requires no intermediate temp file — a single read-modify-write pass over the already-composed WAV/m4a data.

**Primary recommendation:** Adopt `spfk-loudness` for measurement (verify Xcode toolchain compatibility first). Apply gain as a scalar multiply inside the existing WAV export loop; for m4a, wrap the composition with an `AVMutableAudioMix` volume ramp at 1.0 → scaledGain (constant). Wire the toggle via `@AppStorage("lufsNormalizationEnabled")` directly in `ExportFormatSheet`. Deliver state reset by setting `activityVC.completionWithItemsHandler` before presenting.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `spfk-loudness` (ryanfrancesconi) | iOS 16+, Swift 6.2 tools | EBU R128 / BS.1770-4 integrated loudness measurement | Wraps `libebur128`; single `LoudnessAnalyzer.analyze(url:)` call returns LUFS; no hand-rolled DSP |
| `vDSP` (Accelerate.framework) | iOS 17+ (already in project) | Scalar gain multiply on PCM float buffers | Already imported; `vDSP.multiply(_:_:)` applies gain scalar across entire buffer in one SIMD call |
| `AVFoundation` | iOS 17+ (already in project) | Export pipeline — AVAssetWriter, AVAssetReader, CMSampleBuffer | Already used by `AudioMergerService` |
| `@AppStorage` (SwiftUI) | iOS 14+ | Persist toggle state in UserDefaults | Native SwiftUI property wrapper; automatic UI binding; no boilerplate |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `libebur128` (C, via spfk-loudness) | vendored | Actual K-weighting + gating math | Consumed internally by spfk-loudness; don't call directly |
| `UIActivityViewController.completionWithItemsHandler` | UIKit / iOS 8+ | Post-share state reset callback | Set before presenting; fires when share sheet dismisses regardless of action taken |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `spfk-loudness` | Manual BS.1770-3 vDSP implementation | Manual is ~80 lines of biquad coefficient math + mean-square integration; spfk-loudness is 1 function call. Use manual only if Swift 6.2 tools version is unavailable. |
| Gain via `AVAudioMixInputParameters.setVolumeRamp` | Scalar multiply on PCM samples | Volume ramp approach only works for m4a (AVAssetExportSession with audioMix); WAV export uses AVAssetReader+Writer loop where direct sample manipulation is already the pattern. Use ramp for m4a, sample scalar for WAV. |

**Installation (if spfk-loudness adopted):**
```
Package URL: https://github.com/ryanfrancesconi/spfk-loudness
Exact version / up to next major: ~1.x
```
Add via Xcode > Project > Package Dependencies. Confirm tools version compatibility: project must build with Xcode that supports `swift-tools-version: 6.2`.

---

## Architecture Patterns

### Recommended Service Structure
```
SonicMerge/Services/
├── AudioNormalizationService.swift   # existing — import normalization
├── AudioMergerService.swift          # existing — extend with LUFS gain param
└── LUFSNormalizationService.swift    # NEW — measure LUFS, compute gain
```

The `LUFSNormalizationService` actor is a pure measurement + math utility. It does NOT write files. It accepts a URL, returns a linear gain scalar (Double). `AudioMergerService` methods receive this scalar and apply it during their write loop.

### Pattern 1: Actor-based LUFS Service (mirrors AudioNormalizationService)
**What:** Plain `actor` (not @MainActor) — all AVFoundation/DSP work stays inside; only primitive Double crosses actor boundary.
**When to use:** Any time loudness needs to be measured before export.
**Example (spfk-loudness path):**
```swift
// Source: spfk-loudness LoudnessAnalyzer.analyze(url:minimumDuration:)
import SPFKLoudness

actor LUFSNormalizationService {
    static let targetLUFS: Double = -16.0

    /// Returns the linear gain scalar to reach -16 LUFS, or 1.0 if measurement fails.
    func gainScalar(for url: URL) async -> Double {
        guard let result = try? await LoudnessAnalyzer.analyze(url: url) else { return 1.0 }
        let integratedLUFS = result.integratedLoudness  // e.g. -24.2
        let gainDB = Self.targetLUFS - integratedLUFS    // e.g. +8.2 dB
        return pow(10.0, gainDB / 20.0)                  // linear scalar
    }
}
```

**Example (manual BS.1770-3 vDSP fallback — use if spfk-loudness unavailable):**
```swift
// K-weighting filter: 2-stage biquad cascade at 48 kHz
// Stage 1 (pre-filter / high shelf): b=[1.53512485958697, -2.69169618940638, 1.19839281085285],
//                                    a=[1.0, -1.69065929318241, 0.73248077421585]
// Stage 2 (RLB high-pass):           b=[1.0, -2.0, 1.0],
//                                    a=[1.0, -1.99004745483398, 0.99007225036621]
// After filtering: mean-square -> 10*log10(mean_square) + C_stereo
// C_stereo for 2 channels = -0.691 LUFS offset applied.
// Reference: ITU-R BS.1770-3, Table 1 (fixed 48 kHz coefficients)
```
The manual path requires implementing `vDSP_biquad` or `vDSP.biquadFilter` with the exact coefficients above, looping over all 100ms gated blocks per BS.1770 gating algorithm.

### Pattern 2: Gain Application in WAV Export Loop
**What:** Multiply every float PCM sample by the gain scalar inline during the existing `requestMediaDataWhenReady` loop in `exportWAV`.
**When to use:** WAV path only — `AVAssetReader` delivers Linear PCM float32 buffers; scalar multiply is lossless in float domain before int16 write.

```swift
// Inside exportWAV, after copyNextSampleBuffer():
// Source: Accelerate vDSP documentation + AudioMergerService.swift pattern
if let buf = readerOutput.copyNextSampleBuffer(), gainScalar != 1.0 {
    // Apply gain to float samples via vDSP before appending
    let adjusted = applyGain(to: buf, scalar: Float(gainScalar))
    writerInput.append(adjusted ?? buf)
} else if let buf = readerOutput.copyNextSampleBuffer() {
    writerInput.append(buf)
}

// Helper — multiplies all channels in-place:
private func applyGain(to buffer: CMSampleBuffer, scalar: Float) -> CMSampleBuffer? {
    // Extract float32 samples from blockBuffer, vDSP.multiply, rebuild CMSampleBuffer
    // Pattern identical to AudioNormalizationService.upmixMonoBuffer (same CMBlockBuffer pattern)
}
```

### Pattern 3: Gain Application for m4a via AVAudioMix Volume (constant ramp)
**What:** Set a constant volume on `AVMutableAudioMixInputParameters` instead of sample-by-sample multiplication.
**When to use:** m4a path — `AVAssetExportSession` honours `audioMix.inputParameters` volume without requiring buffer-level access.

```swift
// In exportM4A — after computing gainScalar:
let paramsForGain = AVMutableAudioMixInputParameters(track: compositionTrack)
paramsForGain.setVolume(Float(gainScalar), at: .zero)
// Merge into existing audioMix.inputParameters array (don't replace crossfade params)
```

Note: `setVolume(_:at:)` sets a constant volume for the whole track. `setVolumeRamp` is for fades. When crossfade params already exist on the track, the gain param must be on a third "master" track or applied via a different approach. The simplest safe approach for m4a with LUFS is: export to a temp WAV first (no gain), then apply scalar in a second WAV pass, then re-encode to m4a if format is m4a. However, given the "single inline pass" constraint from CONTEXT.md, the AVAudioMix constant volume is preferred for m4a — set `setVolume(Float(gainScalar), at: .zero)` on the composition-level mix input, which stacks with crossfade ramps.

### Pattern 4: ExportFormatSheet Callback Extension
**What:** Extend `onExport` closure signature from `(ExportFormat) -> Void` to `(ExportFormat, Bool) -> Void` OR introduce a thin `ExportOptions` struct.
**When to use:** Always — toggle state must flow from sheet to ViewModel.

Recommended: introduce `ExportOptions` struct — more extensible and avoids tuple-style positional parameters:
```swift
struct ExportOptions {
    let format: ExportFormat
    let lufsNormalize: Bool
}
```
`ExportFormatSheet.onExport: (ExportOptions) -> Void`

### Pattern 5: Post-Share State Reset via completionWithItemsHandler
**What:** `UIActivityViewController.completionWithItemsHandler` fires when the share sheet is dismissed regardless of which activity was used (or if user cancelled).
**When to use:** Always — set it immediately after creating the `UIActivityViewController`.

```swift
// In MixingStationView or wherever ActivityViewController is presented:
// completionWithItemsHandler: (activityType, completed, returnedItems, error) -> Void
let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
activityVC.completionWithItemsHandler = { _, _, _, _ in
    viewModel.dismissShareSheet()   // clears exportedFileURL, resets exportProgress to 0
}
```

Note: The existing `ActivityViewController` UIViewControllerRepresentable already has an `onDismiss: (() -> Void)?` property. Wire `completionWithItemsHandler` to call `onDismiss` inside `makeUIViewController`, and pass the state-reset closure at call site.

### Anti-Patterns to Avoid
- **Two-pass temp file approach:** Writing to temp, then re-reading for gain: creates an extra disk write, violates the "single inline pass" constraint, and doubles export time. Apply gain in the existing write loop.
- **Displaying raw LUFS numbers:** Out of scope per CONTEXT.md — the progress label change is the only user signal.
- **Replacing existing audioMix on m4a export with gain-only mix:** This drops crossfade ramps. Add gain as an additional parameter on existing mix inputs, or add a separate track for overall gain control.
- **Using ShareLink instead of UIActivityViewController:** ShareLink has a known iOS 17 bug with App Group URLs (documented in `ActivityViewController.swift`). The existing `ActivityViewController` wrapper is the correct path.
- **Storing `LUFSNormalizationService` as @MainActor property:** Like `AudioMergerService`, it must be a plain actor. Never store AVFoundation or DSP objects on @MainActor.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| BS.1770-4 gating algorithm | Custom gated loudness calculator | `spfk-loudness` → `LoudnessAnalyzer.analyze(url:)` | Gating algorithm (400ms blocks, overlap, absolute/relative gates) has ~15 edge cases; libebur128 is ITU-certified reference implementation |
| K-weighting biquad filter coefficients | Hard-coded constants from memory | Official ITU-R BS.1770-3 Table 1 (or spfk-loudness) | Coefficient derivation is sample-rate-specific; pre-computed values only valid at 48 kHz; must recompute for other rates |
| Share sheet dismiss callback | Polling `showShareSheet` state | `completionWithItemsHandler` on UIActivityViewController | UIKit already provides this callback; polling introduces race conditions |
| UserDefaults persistence | Custom settings store | `@AppStorage("lufsNormalizationEnabled")` | Atomic, main-thread-safe, automatic SwiftUI binding; already established in project |

**Key insight:** The BS.1770 gating algorithm has numerous edge cases (handling silence, short files under 3s minimum duration, multi-channel weighting, absolute vs. relative gate thresholds). `spfk-loudness` handles all of these behind a single function call.

---

## Common Pitfalls

### Pitfall 1: spfk-loudness Swift 6.2 Tools Version
**What goes wrong:** Adding `spfk-loudness` package fails at resolution or produces build warnings/errors if Xcode's swift-tools-version is below 6.2.
**Why it happens:** `Package.swift` declares `swift-tools-version: 6.2`. Xcode versions before ~Xcode 16.3 / Swift 6.2 cannot resolve this.
**How to avoid:** Verify Xcode version supports Swift 6.2 tools before adding the package dependency. The fallback is a manual vDSP implementation (see Pattern 1 manual example above).
**Warning signs:** "Package requires newer tools" error in Xcode Package resolution.

### Pitfall 2: AVAudioMix Volume Ramp Conflicts with Crossfade
**What goes wrong:** Setting a constant gain volume on Track A's `AVMutableAudioMixInputParameters` after crossfade ramps were already set can overwrite the ramps (last-set wins for same time range).
**Why it happens:** `AVMutableAudioMixInputParameters` keeps a single array of time range → volume mappings; setting a new volume at `.zero` with no duration overrides all subsequent ramps.
**How to avoid:** Use `setVolumeRamp(fromStartVolume:toEndVolume:timeRange:)` to set the gain over the full composition duration separately from the crossfade ramps. Or, for simplicity, apply gain only in the WAV write path and keep the m4a path gain-free for the MVP (all audio is already in 48 kHz stereo from the normalization pipeline; WAV is lossless so a WAV→gain→m4a re-encode is lossless at export quality).
**Warning signs:** Audio sounds correct without LUFS but crossfade disappears with LUFS enabled on m4a export.

### Pitfall 3: LUFS Measurement Must Happen Before Export File URL Is Released
**What goes wrong:** Measuring loudness after the export temp file is handed to the share sheet — the file may be moved or deleted by the OS.
**Why it happens:** `UIActivityViewController` can trigger "Move to Files" which relocates the file.
**How to avoid:** The normalization pipeline must be: (1) export to temp URL, (2) measure LUFS on temp URL, (3) apply gain in a second write to the final temp URL, (4) THEN present share sheet. All three steps happen before `exportedFileURL` is set. This is the correct order even for the "single pass" approach: if using spfk-loudness post-export measurement, a second write pass is unavoidable for file output. The true "single pass" means measuring during a first read pass and applying gain in the same write pass — see the two-stage approach below.

**Correct two-stage approach:**
```
Stage A: Measure pass  — AVAssetReader → measure LUFS (no write)
Stage B: Export pass   — AVAssetReader → apply scalar gain → AVAssetWriter
```
Both stages are sequential within the export Task. No intermediate file. Progress splits: 0–0.5 = measure, 0.5–1.0 = export write.

### Pitfall 4: CleaningLabView Share Sheet Uses Imperative UIKit Presentation
**What goes wrong:** `CleaningLabView.shareExportedFile` calls `rootVC.present(activityVC, animated: true)` directly rather than using the `ActivityViewController` wrapper. The `onDismiss` callback is not wired — state reset will not happen.
**Why it happens:** CleaningLabView export path was implemented ad-hoc (Plan 03-04) without the share-sheet polish that Phase 4 adds.
**How to avoid:** Replace the imperative `shareExportedFile(_:)` helper in CleaningLabView with the same `ActivityViewController` sheet pattern used in MixingStationView, and pass a state-reset closure as `onDismiss`.
**Warning signs:** After sharing from Cleaning Lab, `exportProgress` stays at 1.0 and `showExportProgressSheet` could get stuck.

### Pitfall 5: @AppStorage in Non-View Actor Context
**What goes wrong:** Accessing `@AppStorage` from inside `LUFSNormalizationService` (a plain actor) instead of in the View causes "property wrapper not available outside view" compile errors.
**Why it happens:** `@AppStorage` is a SwiftUI property wrapper tied to the view update mechanism.
**How to avoid:** Read the toggle value in the View or ViewModel (@MainActor) and pass it as a plain `Bool` parameter into the actor method. `@AppStorage` lives only in `ExportFormatSheet` (and propagates as a Bool through the `ExportOptions` struct).

### Pitfall 6: ExportProgressSheet .height Needs Expansion for New Label
**What goes wrong:** Changing "Exporting..." to "Exporting & Normalizing..." may clip text if the sheet height of 220pt is too tight after a font reflow.
**Why it happens:** The title text is now longer; some locales may wrap.
**How to avoid:** Change `ExportProgressSheet` title to a dynamic parameter `title: String` and test with "Exporting & Normalizing..." on smallest supported screen (iPhone SE). Bump `.presentationDetents([.height(220)])` to `.height(240)` if needed.

### Pitfall 7: UserDefaults Privacy Manifest
**What goes wrong:** Starting May 2024, Apple requires a `PrivacyInfo.xcprivacy` manifest declaring UserDefaults access reason. Without it, App Store submission may fail.
**Why it happens:** Apple's required reason APIs policy — `UserDefaults` is on the required-reason list.
**How to avoid:** Ensure the project has a `PrivacyInfo.xcprivacy` file declaring `NSPrivacyAccessedAPITypeReasons` for UserDefaults with reason code `CA92.1` (app functionality). If the project already has this file (check project root), only verify the UserDefaults entry is present.

---

## Code Examples

Verified patterns from official sources and live project code:

### LUFS Gain Scalar Computation
```swift
// Compute linear gain to reach target LUFS from measured LUFS
// Source: standard dB-to-linear math
let measuredLUFS: Double = -24.2
let targetLUFS: Double = -16.0
let gainDB = targetLUFS - measuredLUFS  // = +8.2 dB
let gainScalar = pow(10.0, gainDB / 20.0)  // ≈ 2.57x
```

### Applying Scalar Gain to Float PCM CMSampleBuffer (vDSP)
```swift
// Source: Accelerate framework vDSP docs + AudioNormalizationService.swift CMBlockBuffer pattern
import Accelerate

func applyGain(to sampleBuffer: CMSampleBuffer, scalar: Float) -> CMSampleBuffer? {
    guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }
    let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
    guard numSamples > 0 else { return nil }

    var dataLength = 0
    var dataPointer: UnsafeMutablePointer<Int8>?
    guard CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0,
            lengthAtOffsetOut: nil, totalLengthOut: &dataLength,
            dataPointerOut: &dataPointer) == noErr,
          let ptr = dataPointer else { return nil }

    // Reinterpret as Float32 (reader output settings use kAudioFormatLinearPCM float=true)
    let floatPtr = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: Float.self)
    let floatCount = dataLength / MemoryLayout<Float>.size
    vDSP_vsmul(floatPtr, 1, [scalar], floatPtr, 1, vDSP_Length(floatCount))

    return sampleBuffer  // modified in-place; CMBlockBuffer is mutable
}
```

Note: The existing WAV export loop in `AudioMergerService.exportWAV` uses `kAudioFormatLinearPCM` with `AVLinearPCMIsFloatKey: false` (int16). For gain application, change `AVLinearPCMIsFloatKey: true` in the reader output settings when LUFS normalization is active, apply float gain, then let the writer convert back to int16. Alternatively, apply int16 scalar math: read as float, multiply, clamp to [-32768, 32767], write back. The float reader approach is cleaner.

### ExportOptions Struct
```swift
// Source: CONTEXT.md code_context + this research
struct ExportOptions {
    let format: ExportFormat
    let lufsNormalize: Bool
}
```

### @AppStorage Toggle in ExportFormatSheet
```swift
// Source: CONTEXT.md code_context, AppStorage best practices
@AppStorage("lufsNormalizationEnabled") private var lufsEnabled: Bool = false

// In body:
Toggle(isOn: $lufsEnabled) {
    VStack(alignment: .leading, spacing: 2) {
        Text("Normalize to -16 LUFS")
            .font(.system(.body))
        Text("Podcast standard (-16 LUFS)")
            .font(.system(.caption))
            .foregroundStyle(.secondary)
    }
}
.toggleStyle(.switch)
.padding(.horizontal, 24)
```

### completionWithItemsHandler for State Reset
```swift
// Source: UIKit UIActivityViewController API + ActivityViewController.swift pattern
// Wire inside ActivityViewController.makeUIViewController:
let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
vc.completionWithItemsHandler = { [weak coordinator] _, _, _, _ in
    coordinator?.onDismiss?()
}
return vc
```

### ExportProgressSheet Dynamic Title
```swift
// Change from hardcoded "Exporting..." to parameter-driven
struct ExportProgressSheet: View {
    let title: String  // NEW — was hardcoded
    let progress: Float
    let onCancel: () -> Void
    // ...
    Text(title)  // replaces Text("Exporting...")
}
// Call sites: ExportProgressSheet(title: isNormalizing ? "Exporting & Normalizing..." : "Exporting...", ...)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual ITU-R BS.1770 implementation | `spfk-loudness` (libebur128 wrapper) | 2022+ | Single function call replaces ~200 lines of biquad + gating math |
| `ShareLink` for file sharing | `UIActivityViewController` wrapper | iOS 17 bug (ongoing) | `ShareLink` silently fails to save App Group URLs to Files; `UIActivityViewController` is the correct path |
| `completionHandler` (deprecated) | `completionWithItemsHandler` | iOS 8 → still current | `completionWithItemsHandler` provides activityType, completed flag, and returnedItems |

**Deprecated/outdated:**
- `UIActivityViewController.completionHandler`: The plain `completionHandler` (no "WithItems") is deprecated in favor of `completionWithItemsHandler`.

---

## Open Questions

1. **spfk-loudness Swift 6.2 toolchain compatibility**
   - What we know: `Package.swift` requires `swift-tools-version: 6.2`; project uses Swift Testing (iOS 17+), Xcode 26.3+ (per STATE.md PBXFileSystemSynchronizedRootGroup note = Xcode 26.3+)
   - What's unclear: Whether the project's current Xcode version is 26.3+ and thus ships Swift 6.2 tools
   - Recommendation: Try adding the package. If Xcode rejects it, proceed with manual vDSP implementation. The manual implementation is ~80 lines and the filter coefficients are fully specified in this document.

2. **Two-pass vs. one-pass measurement + gain**
   - What we know: CONTEXT.md says "single inline pass: measure integrated loudness, compute gain, apply gain during export write"
   - What's unclear: A true single-pass approach requires measuring loudness in a first decode loop (no write), then applying gain in the export write loop. This is still "no intermediate file" but is two decode passes over the same composition.
   - Recommendation: Implement as two-stage passes on the same input composition: Stage A reads all PCM to measure LUFS; Stage B reads again with gain applied and writes to the output file. This matches the spirit of "no intermediate temp file."

3. **m4a LUFS gain: AVAudioMix volume vs. second decode pass**
   - What we know: `AVAssetExportSession` (m4a path) does not give buffer-level access for sample manipulation; `AVAudioMix` volume is the only hook
   - What's unclear: Whether a constant `setVolume` gain on top of existing crossfade ramps on Track A will produce the correct loudness result
   - Recommendation: For simplicity and correctness, use the same two-pass buffer approach for both m4a and WAV: after the composition is exported to a temp file (using existing `exportM4A`/`exportWAV`), run a second pass that reads the temp file, applies gain, and writes to the final destination. This avoids the AVAudioMix conflict entirely. The "no intermediate temp file" constraint from CONTEXT.md can be interpreted as "no new intermediate temp files beyond the already-used temp export file" — the temp-then-gain approach uses one temp file (already done today).

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (all existing `SonicMergeTests` files use `import Testing`) |
| Config file | None — PBXFileSystemSynchronizedRootGroup auto-includes files |
| Quick run command | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing SonicMergeTests/LUFSNormalizationServiceTests 2>&1 | tail -20` |
| Full suite command | `xcodebuild test -scheme SonicMerge -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -40` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| EXP-03 | `LUFSNormalizationService.gainScalar(for:)` returns a positive scalar for a known-loudness fixture | unit | `xcodebuild test ... -only-testing SonicMergeTests/LUFSNormalizationServiceTests/testGainScalarForKnownLoudness` | ❌ Wave 0 |
| EXP-03 | Gain scalar of 1.0 returned when input is already at -16 LUFS | unit | `... /testGainScalarAlreadyAtTarget` | ❌ Wave 0 |
| EXP-03 | Export with LUFS enabled produces a file (does not crash or fail) | integration | `... /testExportWithLUFSEnabled` | ❌ Wave 0 |
| EXP-03 | ExportOptions struct carries lufsNormalize Bool correctly | unit | `... /MixingStationViewModelTests/testExportOptionsLUFSFlag` | ❌ Wave 0 |
| Share sheet reset | After dismissShareSheet(), exportedFileURL is nil and exportProgress is 0 | unit | `... /MixingStationViewModelTests/testDismissShareSheetResetsState` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** Run `LUFSNormalizationServiceTests` and `MixingStationViewModelTests` only
- **Per wave merge:** Full suite
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `SonicMergeTests/LUFSNormalizationServiceTests.swift` — covers EXP-03 gain scalar logic
- [ ] `SonicMergeTests/Fixtures/stereo_-24lufs_48000.wav` — test fixture at known loudness level for deterministic gain scalar assertion (generate via `afconvert` + volume adjustment, or use existing `stereo_48000.m4a` with known loudness)

*(The existing `MixingStationViewModelTests.swift` file will receive new test methods; no new file needed for those tests.)*

---

## Sources

### Primary (HIGH confidence)
- `github.com/ryanfrancesconi/spfk-loudness` Package.swift — iOS 16+, Swift 6.2 tools version, libebur128 dependency confirmed
- `github.com/ryanfrancesconi/spfk-loudness` README — `LoudnessAnalyzer.analyze(url:minimumDuration:)` API confirmed
- Live project source files (read directly) — `AudioMergerService.swift`, `AudioNormalizationService.swift`, `ExportFormatSheet.swift`, `ExportProgressSheet.swift`, `ActivityViewController.swift`, `MixingStationViewModel.swift`, `CleaningLabView.swift`
- Apple UIKit docs (search verified) — `UIActivityViewController.completionWithItemsHandler` property

### Secondary (MEDIUM confidence)
- ITU-R BS.1770-3 (2012) — biquad K-weighting filter coefficients for 48 kHz (PDF linked in search results)
- `signalkit` (CastorLogic/SignalKit) — confirms vDSP_deq22/biquad approach for BS.1770-4 in Swift

### Tertiary (LOW confidence)
- WebSearch community sources on `@AppStorage` best practices 2024 — consistent with Apple developer docs patterns

---

## Metadata

**Confidence breakdown:**
- Standard stack (spfk-loudness, vDSP, AVFoundation): HIGH — package repo read directly, live code confirmed
- Architecture (actor pattern, gain application): HIGH — mirrors existing AudioMergerService + AudioNormalizationService patterns; no novel patterns required
- Pitfalls: HIGH (items 1, 2, 3, 4, 5) / MEDIUM (items 6, 7) — items 1–5 inferred from direct code inspection; items 6–7 from general iOS ecosystem knowledge
- Test architecture: HIGH — matches existing Swift Testing pattern in all 11 existing test files

**Research date:** 2026-03-19
**Valid until:** 2026-06-19 (stable APIs; spfk-loudness package version may update)
