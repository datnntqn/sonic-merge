// EditFillerListStudioSheet.swift
// SonicMerge
//
// Phase 12 (Smart Cut Studio Refactor): replaces the flat-List
// EditFillerListSheet. Single section "ALL FILLER WORDS"; wrap-flow of
// frosted-glass capsules (one per word in library.allWords); every
// capsule has a trailing Deep Indigo ✕ that calls library.remove(_:).
// For default words, remove adds to removedDefaults (persisted; can be
// undone via the "Restore default words" link). For custom words,
// remove permanently deletes. Capsule add input at the bottom.

import SwiftUI

struct EditFillerListStudioSheet: View {
    @Binding var library: FillerLibrary
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sonicMergeSemantic) private var semantic
    @State private var newWord: String = ""
    /// Persisted via UserDefaults under the key TranscriptionService reads.
    /// Default false (on-device, privacy-preserving). Toggle takes effect on
    /// the next analyze run.
    @AppStorage(TranscriptionService.useCloudRecognitionDefaultsKey)
    private var useCloudRecognition: Bool = false

    private var removedCount: Int { library.removedDefaults.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("ALL FILLER WORDS")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(uiColor: semantic.textSecondary))
                        .padding(.horizontal, 16)
                    StudioFlowLayout(spacing: 8) {
                        ForEach(library.allWords, id: \.self) { word in
                            WordCapsule(word: word) {
                                withAnimation(.spring(response: 0.30, dampingFraction: 0.8)) {
                                    library.remove(word)
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 16)
                    if removedCount > 0 {
                        Button {
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.8)) {
                                library.restoreAllDefaults()
                            }
                        } label: {
                            Text("Restore default words (\(removedCount))")
                                .font(.subheadline)
                                .foregroundStyle(Color(uiColor: semantic.accentAction).opacity(0.5))
                        }
                        .padding(.horizontal, 16)
                    }
                    addInputCapsule
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    cloudRecognitionToggle
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("Edit filler list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .presentationBackground(.ultraThinMaterial)
        }
    }

    /// Toggle row sitting below the add-word input. Flips
    /// SmartCut.useCloudRecognition in UserDefaults; TranscriptionService
    /// picks it up on the next analyze run. Helper copy explains the
    /// privacy trade-off in plain language.
    private var cloudRecognitionToggle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $useCloudRecognition) {
                Text("Better filler detection")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))
            }
            .tint(Color(uiColor: semantic.accentAction))
            Text(useCloudRecognition
                 ? "Audio is sent to Apple's speech servers. Catches more lexical fillers (sort of, actually). Requires internet. Apple's English models still drop short hesitations (um/uh/ah)."
                 : "On-device recognition. Private and offline. Apple's speech model drops short hesitations (um/uh/ah) — only lexical fillers and pauses are detected.")
                .font(.caption)
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .studioFrostedCapsule(cornerRadius: 14)
    }

    private var addInputCapsule: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .foregroundStyle(Color(uiColor: semantic.accentAction))
            TextField("Add a word…", text: $newWord)
                .submitLabel(.done)
                .onSubmit {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        library.addCustom(newWord)
                    }
                    newWord = ""
                }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .studioFrostedCapsule(cornerRadius: 14)
    }
}

private struct WordCapsule: View {
    let word: String
    let onRemove: () -> Void

    @Environment(\.sonicMergeSemantic) private var semantic

    var body: some View {
        HStack(spacing: 6) {
            Text(word)
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(uiColor: semantic.accentAction).opacity(0.6))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(word)")
        }
        .padding(.vertical, 5)
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .studioFrostedCapsule(cornerRadius: 14)
    }
}
