// OnboardingFlow.swift
// SonicMerge
//
// First-launch onboarding. 5 steps: brand opener → trust primer →
// speech recognition permission → hands-on Smart Cut on bundled
// sample → result + Denoise reveal. Gated by @AppStorage flag in
// RootTabView. Spec: docs/superpowers/specs/2026-05-03-cleancut-onboarding-design.md

import AVFoundation
import SwiftUI
import Speech
import UIKit

struct OnboardingFlow: View {
    enum Step: Int { case brand = 0, trust, permission, sample, result }

    @AppStorage("sonicMerge.hasOnboarded") private var hasOnboarded: Bool = false
    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.fillerLibrary) private var libraryStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var step: Step = .brand
    // Carried into step 5 — populated by step 4's analyze + apply.
    @State private var speechGranted: Bool = false
    @State private var sampleEditList: EditList?
    @State private var sampleCleanedURL: URL?
    @State private var sampleOriginalURL: URL? = Bundle.main.url(forResource: "onboarding-sample", withExtension: "m4a")
    // Re-entry guard: SwiftUI may re-fire `.task` on view re-render
    // (e.g. scenePhase change while the OS permission dialog is up).
    // SFSpeechRecognizer.requestAuthorization is idempotent post-decision,
    // but `advance(to: .sample)` is not — guard against double-advance.
    @State private var permissionRequested: Bool = false

    var body: some View {
        ZStack {
            PremiumBackground()
            VStack(spacing: 0) {
                StepProgressIndicator(step: step)
                    .padding(.top, 16)

                Group {
                    switch step {
                    case .brand:
                        BrandOpenerStep(
                            semantic: semantic,
                            reduceMotion: reduceMotion,
                            onContinue: { advance(to: .trust) },
                            onSkip: { advance(to: .trust) }   // skip → trust per spec §5 step 1
                        )
                    case .trust:
                        TrustPrimerStep(
                            semantic: semantic,
                            reduceTransparency: reduceTransparency,
                            onContinue: { advance(to: .permission) }
                        )
                    case .permission:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .accessibilityLabel("Requesting Speech Recognition permission")
                            .task {
                                guard !permissionRequested else { return }
                                permissionRequested = true
                                speechGranted = await Self.requestSpeechAuthorization()
                                advance(to: .sample)
                            }
                    case .sample:
                        SampleStep(
                            semantic: semantic,
                            libraryStore: libraryStore,
                            speechGranted: speechGranted,
                            sampleURL: sampleOriginalURL,
                            onCompleted: { editList, cleanedURL in
                                sampleEditList = editList
                                sampleCleanedURL = cleanedURL
                                advance(to: .result)
                            },
                            onSkipToHome: { hasOnboarded = true }
                        )
                    case .result:
                        ResultStep(
                            semantic: semantic,
                            editList: sampleEditList,
                            originalURL: sampleOriginalURL,
                            cleanedURL: sampleCleanedURL,
                            onDone: {
                                hasOnboarded = true
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            }
                        )
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func advance(to next: Step) {
        if reduceMotion {
            step = next
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { step = next }
        }
    }

    private static func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

// MARK: - Step progress indicator

private struct StepProgressIndicator: View {
    let step: OnboardingFlow.Step

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { index in
                let isActive = index == step.rawValue
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isActive ? Color(uiColor: .systemIndigo) : Color(uiColor: .systemGray3))
                    .frame(width: isActive ? 24 : 14, height: 4)
                    .animation(.easeInOut(duration: 0.2), value: step)
            }
        }
        .accessibilityHidden(true)  // per-step .accessibilityLabel covers position
    }
}

// MARK: - Step 1: Brand opener

private struct BrandOpenerStep: View {
    let semantic: SonicMergeSemantic
    let reduceMotion: Bool
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var bounceTrigger: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: onSkip)
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
            }
            .padding(.top, 8)

            Spacer(minLength: 0)

            // Hero badge — fire gradient frame at 20% alpha, SmartCutMark inside,
            // gentle one-shot scale-bounce on appear.
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(
                        colors: semantic.accentAIGradientStops.map { Color(uiColor: $0).opacity(0.20) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                SmartCutMark(size: .hero)
                    .frame(width: 56, height: 56)
                    .phaseAnimator([0.95, 1.08, 1.0], trigger: bounceTrigger) { content, phase in
                        content.scaleEffect(phase)
                    } animation: { phase in
                        phase == 1.08 ? .spring(response: 0.32, dampingFraction: 0.55) : .easeOut(duration: 0.18)
                    }
            }
            .frame(width: 80, height: 80)
            .accessibilityHidden(true)
            .padding(.bottom, 20)
            .onAppear { if !reduceMotion { bounceTrigger.toggle() } }

            Text("Cut. Clean. Merge.")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            Text("Your audio toolkit, all on this device.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .padding(.bottom, 24)

            VStack(spacing: 10) {
                FeaturePill(icon: "sparkles", iconBg: Color(uiColor: semantic.accentAI),
                            title: "Smart Cut", subtitle: "remove fillers", semantic: semantic)
                FeaturePill(icon: "waveform.badge.minus", iconBg: Color(uiColor: semantic.accentAI),
                            title: "Denoise", subtitle: "clean noisy clips", semantic: semantic)
                FeaturePill(icon: "rectangle.stack", iconBg: Color(uiColor: semantic.accentAction),
                            title: "Merge", subtitle: "combine audio", semantic: semantic)
            }

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color(uiColor: semantic.accentAction)))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step 1 of 5: Cut. Clean. Merge. Your audio toolkit, all on this device.")
    }
}

private struct FeaturePill: View {
    let icon: String
    let iconBg: Color
    let title: String
    let subtitle: String
    let semantic: SonicMergeSemantic

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(iconBg)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))
                Text(subtitle).font(.caption)
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: semantic.surfaceCard))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(uiColor: .systemGray5), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Step 2: Trust primer

private struct TrustPrimerStep: View {
    let semantic: SonicMergeSemantic
    let reduceTransparency: Bool
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 32)  // matches step 1's skip-row height
            Spacer(minLength: 0)

            // Hero badge — indigo at 14% alpha, lock.shield.fill inside
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(uiColor: semantic.accentAction).opacity(0.14))
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Color(uiColor: semantic.accentAction))
            }
            .frame(width: 80, height: 80)
            .accessibilityHidden(true)
            .padding(.bottom, 20)

            Text("Your audio\nnever leaves\nthis device.")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            Text("No upload. No cloud. No account.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)

            VStack(spacing: 10) {
                TrustRow(text: "Apple's on-device AI handles every cut",
                         semantic: semantic,
                         reduceTransparency: reduceTransparency)
                TrustRow(text: "Files stay in CleanCut's private folder",
                         semantic: semantic,
                         reduceTransparency: reduceTransparency)
            }

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color(uiColor: semantic.accentAction)))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step 2 of 5: Your audio never leaves this device. No upload. No cloud. No account.")
    }
}

private struct TrustRow: View {
    let text: String
    let semantic: SonicMergeSemantic
    let reduceTransparency: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(Color(uiColor: semantic.accentAction))
                .font(.system(size: 16, weight: .semibold))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var background: some View {
        if reduceTransparency {
            Color(uiColor: semantic.surfaceCard)
        } else {
            ZStack {
                Color(uiColor: semantic.accentGlow).opacity(0.06)
                Rectangle().fill(.ultraThinMaterial)
            }
        }
    }
}

// MARK: - Step 4: Hands-on first cut

private struct SampleStep: View {
    enum Phase { case ready, analyzing, cutting, error(String) }

    let semantic: SonicMergeSemantic
    let libraryStore: FillerLibraryStore
    let speechGranted: Bool
    let sampleURL: URL?
    let onCompleted: (EditList, URL) -> Void
    let onSkipToHome: () -> Void

    @State private var phase: Phase = .ready
    @State private var attemptCount: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 32)

            VStack(alignment: .leading, spacing: 6) {
                Text(speechGranted ? "Try it on a sample" : "Sample loaded")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))
                Text(speechGranted
                     ? "A 30-second podcast clip is loaded for you."
                     : "Smart Cut needs Speech Recognition access. Enable it in Settings → CleanCut.")
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
            .padding(.bottom, 16)

            SampleCard(semantic: semantic, phase: phase)

            if speechGranted {
                TipKitHint(
                    text: "💡 Tap Smart Cut to remove filler words and long pauses from this clip.",
                    semantic: semantic
                )
                .padding(.top, 12)
            }

            Spacer()

            if speechGranted {
                grantedFooter
            } else {
                deniedFooter
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step 4 of 5: \(speechGranted ? "Try Smart Cut on a sample audio clip" : "Sample loaded — Speech Recognition required to analyze")")
    }

    // MARK: - Granted path

    @ViewBuilder
    private var grantedFooter: some View {
        switch phase {
        case .ready:
            Button { Task { await runAnalyze() } } label: {
                Label("Smart Cut This Sample", systemImage: "sparkles")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color(uiColor: semantic.accentAI)))
            }
            .accessibilityHint("Removes filler words and long pauses from the bundled audio sample.")
        case .analyzing:
            ProgressView("Analyzing…").tint(Color(uiColor: semantic.accentAI))
                .padding(.vertical, 14)
        case .cutting:
            ProgressView("Applying cuts…").tint(Color(uiColor: semantic.accentAI))
                .padding(.vertical, 14)
        case .error(let message):
            VStack(spacing: 8) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
                    .multilineTextAlignment(.center)
                HStack {
                    Button("Try again") { Task { await runAnalyze() } }
                        .buttonStyle(.bordered)
                    Button("Skip to home") { onSkipToHome() }
                        .buttonStyle(.borderless)
                }
            }
        }
    }

    // MARK: - Denied path

    private var deniedFooter: some View {
        VStack(spacing: 12) {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color(uiColor: semantic.accentAction))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(
                        Capsule().strokeBorder(Color(uiColor: semantic.accentAction), lineWidth: 1.5)
                    )
            }
            Button("Skip to home", action: onSkipToHome)
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
        }
    }

    // MARK: - Pipeline

    private func runAnalyze() async {
        guard let url = sampleURL else {
            phase = .error("Couldn't find the sample. Tap Skip to continue.")
            return
        }
        attemptCount += 1
        phase = .analyzing
        let service = SmartCutService(library: libraryStore.library)
        do {
            var resolvedEditList: EditList?
            for try await update in service.analyze(input: url, pauseThreshold: 1.5) {
                if case .completed(let list, _, _) = update {
                    resolvedEditList = list
                }
            }
            guard let editList = resolvedEditList else {
                bumpError("Couldn't analyze the sample. Tap to try again or skip.")
                return
            }
            phase = .cutting
            let cleanedURL = try await AudioCutter().apply(input: url, editList: editList)
            onCompleted(editList, cleanedURL)
        } catch {
            #if DEBUG
            print("[Onboarding] analyze failed: \(error)")
            #endif
            bumpError("Couldn't analyze the sample. Tap to try again or skip.")
        }
    }

    private static let maxAttempts = 3   // spec §5 step 4: initial + 2 retries

    private func bumpError(_ message: String) {
        if attemptCount >= Self.maxAttempts {
            // After maxAttempts (initial + 2 retries), force-skip so the user
            // is never trapped on a stuck analyze.
            onSkipToHome()
        } else {
            phase = .error(message)
        }
    }
}

// MARK: - Sample card

private struct SampleCard: View {
    let semantic: SonicMergeSemantic
    let phase: SampleStep.Phase

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SAMPLE AUDIO")
                .font(.caption.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
            Text("Podcast snippet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(LinearGradient(
                    colors: [
                        Color(uiColor: semantic.accentAction).opacity(0.35),
                        Color(uiColor: semantic.accentAction).opacity(0.55)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 24)
                .opacity(phase.busy ? 1.0 : 0.85)
            Text("0:00 — 0:32")
                .font(.caption)
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: semantic.surfaceCard))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(uiColor: .systemGray5), lineWidth: 0.5)
                )
        )
    }
}

private extension SampleStep.Phase {
    var busy: Bool {
        if case .analyzing = self { return true }
        if case .cutting = self { return true }
        return false
    }
}

// MARK: - TipKit-style decorative hint

private struct TipKitHint: View {
    let text: String
    let semantic: SonicMergeSemantic

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Color(uiColor: semantic.textPrimary))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(uiColor: semantic.accentAction).opacity(0.08))
            .overlay(
                Rectangle()
                    .fill(Color(uiColor: semantic.accentAction))
                    .frame(width: 3),
                alignment: .leading
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Step 5: Result + soft Denoise reveal

private struct ResultStep: View {
    let semantic: SonicMergeSemantic
    let editList: EditList?
    let originalURL: URL?
    let cleanedURL: URL?
    let onDone: () -> Void

    enum Track { case original, cleaned }

    @State private var selectedTrack: Track = .cleaned
    @State private var originalPlayer: AVAudioPlayer?
    @State private var cleanedPlayer: AVAudioPlayer?

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 32)

            VStack(alignment: .leading, spacing: 6) {
                Text(headline)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))
                if hasResult {
                    Text("Tap Cleaned or Original to compare.")
                        .font(.subheadline)
                        .foregroundStyle(Color(uiColor: semantic.textSecondary))
                } else {
                    Text("Open the Smart Cut tab anytime to start.")
                        .font(.subheadline)
                        .foregroundStyle(Color(uiColor: semantic.textSecondary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
            .padding(.bottom, 16)

            if hasResult, let editList {
                ResultCard(semantic: semantic, editList: editList)
                    .padding(.bottom, 12)

                ABToggle(semantic: semantic,
                         selected: $selectedTrack,
                         onChange: handleTrackChange)
                    .padding(.bottom, 12)

                TipKitHint(
                    text: "💡 Try Denoise on this clip — the AI orb removes background hiss.",
                    semantic: semantic
                )
            }

            Spacer()

            Button(action: {
                stopAllPlayback()
                onDone()
            }) {
                Label("Done · Open Smart Cut", systemImage: "checkmark.circle.fill")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color(uiColor: semantic.accentAction)))
            }
        }
        .onAppear { preparePlayers() }
        .onDisappear { stopAllPlayback() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step 5 of 5: \(headline)")
    }

    private var hasResult: Bool { editList != nil && cleanedURL != nil }

    private var headline: String {
        guard let editList else { return "You're all set" }
        let n = editList.fillers.filter(\.isEnabled).count
        return n > 0 ? "\(n) fillers found" : "Smart Cut applied"
    }

    private func preparePlayers() {
        // Onboarding intentionally uses standalone AVAudioPlayer instances
        // rather than registering with PlaybackCoordinator (spec §5). The
        // .fullScreenCover blocks the rest of the app's players, so the
        // single-active-player invariant is preserved by presentation context.
        // If onboarding ever moves to a sheet or inline presentation, register
        // these players as PlaybackParticipants.
        //
        // Activate the shared audio session before the first AVAudioPlayer
        // call. Without this, prepareToPlay() succeeds silently but play()
        // produces no audible output on real devices.
        PlaybackAudioSession.activateIfNeeded()
        if let url = originalURL {
            originalPlayer = try? AVAudioPlayer(contentsOf: url)
            originalPlayer?.prepareToPlay()
        }
        if let url = cleanedURL {
            cleanedPlayer = try? AVAudioPlayer(contentsOf: url)
            cleanedPlayer?.prepareToPlay()
        }
    }

    private func handleTrackChange(_ track: Track) {
        switch track {
        case .original:
            cleanedPlayer?.pause()
            originalPlayer?.currentTime = 0
            originalPlayer?.play()
        case .cleaned:
            originalPlayer?.pause()
            cleanedPlayer?.currentTime = 0
            cleanedPlayer?.play()
        }
    }

    private func stopAllPlayback() {
        originalPlayer?.stop()
        cleanedPlayer?.stop()
    }
}

// MARK: - Result card

private struct ResultCard: View {
    let semantic: SonicMergeSemantic
    let editList: EditList

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SMART CUT SUMMARY")
                .font(.caption.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Color(uiColor: semantic.accentAction))
            Text("Podcast snippet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
            HStack(spacing: 8) {
                if !editList.fillers.isEmpty {
                    Text("\(editList.fillers.count) fillers")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Color(uiColor: semantic.accentAction).opacity(0.14)))
                        .foregroundStyle(Color(uiColor: semantic.accentAction))
                }
                if !editList.pauses.isEmpty {
                    Text("\(editList.pauses.count) pauses")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Color(uiColor: semantic.accentAction).opacity(0.14)))
                        .foregroundStyle(Color(uiColor: semantic.accentAction))
                }
                Spacer()
                Text("saves ~\(Int(editList.enabledSavings.rounded()))s")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(Color(uiColor: semantic.accentAI)))
                    .foregroundStyle(.white)
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: semantic.surfaceCard))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(uiColor: .systemGray5), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - A/B toggle

private struct ABToggle: View {
    let semantic: SonicMergeSemantic
    @Binding var selected: ResultStep.Track
    let onChange: (ResultStep.Track) -> Void

    var body: some View {
        HStack(spacing: 8) {
            segment(track: .original, label: "Original")
            segment(track: .cleaned, label: "Cleaned")
        }
    }

    @ViewBuilder
    private func segment(track: ResultStep.Track, label: String) -> some View {
        let isSelected = selected == track
        Button {
            selected = track
            onChange(track)
        } label: {
            Text(label)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(isSelected ? .white : Color(uiColor: semantic.textPrimary))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Capsule().fill(isSelected
                                   ? Color(uiColor: semantic.accentAction)
                                   : Color(uiColor: semantic.surfaceCard))
                )
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? Color.clear : Color(uiColor: .systemGray5),
                        lineWidth: 1
                    )
                )
        }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityLabel("\(label) audio\(isSelected ? ", selected" : "")")
    }
}
