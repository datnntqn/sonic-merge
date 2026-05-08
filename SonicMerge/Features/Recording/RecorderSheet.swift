// SonicMerge/Features/Recording/RecorderSheet.swift
//
// Minimal in-app recorder. Tap Record → captures audio. Tap Stop → enables
// Save. Save → invokes onComplete(url) so the host view can route the file
// to its tab's import path. Cancel → discards the temp file.
//

import SwiftUI
import UIKit

struct RecorderSheet: View {

    let onComplete: (URL) -> Void

    @StateObject private var recorder = AudioRecorderService()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sonicMergeSemantic) private var semantic

    @State private var permissionDenied = false
    @State private var startError: AudioRecorderService.RecorderError?
    @State private var savedURL: URL?
    @State private var didSave = false

    var body: some View {
        VStack(spacing: 24) {
            topBar
            if permissionDenied {
                deniedState
            } else {
                Spacer()
                timer
                levelMeter
                Spacer()
                primaryButton
                Spacer().frame(height: 16)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .background(Color(uiColor: semantic.surfaceBase))
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(recorder.isRecording)
        .onDisappear {
            // Sheet may dismiss via swipe (when not recording) without Save.
            // If user didn't save, drop any temp file we produced.
            if !didSave, let url = savedURL ?? recorder.currentFileURL {
                try? FileManager.default.removeItem(at: url)
            }
            // No-op if recorder already stopped.
            recorder.cancel()
        }
    }

    // MARK: Subviews

    private var topBar: some View {
        HStack {
            Button("Cancel") {
                recorder.cancel()
                dismiss()
            }
            .foregroundStyle(Color(uiColor: semantic.accentAction))
            Spacer()
            Text("New Recording")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
            Spacer()
            Button("Save") {
                guard let url = savedURL else { return }
                didSave = true
                onComplete(url)
                dismiss()
            }
            .fontWeight(.semibold)
            .foregroundStyle(Color(uiColor: semantic.accentAction))
            .disabled(savedURL == nil)
        }
    }

    private var timer: some View {
        Text(format(recorder.elapsedSeconds))
            .font(.system(size: 56, weight: .ultraLight, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color(uiColor: semantic.textPrimary))
    }

    private var levelMeter: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<20, id: \.self) { i in
                Capsule()
                    .fill(Color(uiColor: semantic.accentAction))
                    .frame(width: 4, height: barHeight(for: i))
                    .opacity(recorder.isRecording ? 1.0 : 0.3)
            }
        }
        .frame(height: 56)
        // No .animation here — the 50ms polling already drives smooth-enough
        // updates. Adding implicit animation on a per-frame value triggers
        // SwiftUI to interpolate twice and over-renders.
    }

    private var primaryButton: some View {
        Button {
            primaryAction()
        } label: {
            ZStack {
                Circle()
                    .fill(recorder.isRecording ? Color(uiColor: .systemGray) : Color.red)
                    .frame(width: 88, height: 88)
                if recorder.isRecording {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                } else {
                    Circle().fill(Color.white).frame(width: 32, height: 32)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(savedURL != nil)  // can't restart after a save in Minimal UX
    }

    private var deniedState: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
                Text("Microphone access is off")
                    .font(.headline)
                Text("Enable microphone access for CleanCut in Settings to record audio.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(uiColor: semantic.accentAction))
                .padding(.top, 8)
            }
            .padding(.horizontal, 32)
            .padding(.top, 40)
            Spacer()
        }
    }

    // MARK: Logic

    private func primaryAction() {
        if recorder.isRecording {
            savedURL = recorder.stop()
        } else if savedURL == nil {
            Task { await beginRecording() }
        }
    }

    private func beginRecording() async {
        guard !recorder.isRecording, savedURL == nil else { return }
        do {
            try await recorder.start()
        } catch AudioRecorderService.RecorderError.micPermissionDenied {
            permissionDenied = true
        } catch let err as AudioRecorderService.RecorderError {
            startError = err
        } catch {
            startError = .startFailed
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        // Map [0, 1] level to a smooth bar pattern. Center bars peak higher
        // when level is high; outer bars stay lower so the meter reads as
        // an audio-level visualization rather than a flat row.
        let center = 9.5
        let distance = abs(Double(index) - center)
        let centerWeight = max(0, 1.0 - distance / 12.0)
        let scaled = Double(recorder.levelNormalized) * centerWeight
        return max(4, CGFloat(8 + scaled * 40))
    }

    private func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
