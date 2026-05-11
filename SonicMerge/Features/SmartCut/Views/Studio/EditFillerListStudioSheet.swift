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
    let locale: Locale
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(EntitlementService.self) private var entitlements
    @State private var newWord: String = ""
    @State private var paywallReason: PaywallReason?
    /// Persisted via UserDefaults under the key TranscriptionService reads.
    /// Default true: on-device SFSpeechRecognizer returns zero-valued per-word
    /// timestamps for many configurations, which breaks Smart Cut's filler
    /// detection and long-pause cutting. Cloud recognition fixes both. Users
    /// who care about strict on-device privacy can still toggle off — and
    /// `TranscriptionService.useCloudRecognitionDefault()` mirrors this default.
    @AppStorage(TranscriptionService.useCloudRecognitionDefaultsKey)
    private var useCloudRecognition: Bool = true

    private var removedCount: Int { library.removedDefaults.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Smart Cut scans your recording for these filler words and removes them. Tap ✕ to skip a word, or add your own below.")
                        .font(.subheadline)
                        .foregroundStyle(Color(uiColor: semantic.textSecondary))
                        .padding(.horizontal, 16)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("ALL FILLER WORDS")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(uiColor: semantic.textSecondary))
                        .padding(.horizontal, 16)
                    StudioFlowLayout(spacing: 8) {
                        ForEach(library.allWords(for: locale), id: \.self) { word in
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
                    if #unavailable(iOS 26) {
                        cloudRecognitionToggle
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    }
                    languageFooter
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
            .paywall(reason: $paywallReason)
        }
    }

    private var languageFooter: some View {
        VStack(spacing: 4) {
            Text("Showing default words for ")
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
            + Text(Locale(identifier: "en")
                .localizedString(forIdentifier: locale.identifier)
                ?? locale.identifier)
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
                .fontWeight(.semibold)
            Text("Switch language in the studio to see a different list.")
                .foregroundStyle(Color(uiColor: semantic.textSecondary))
        }
        .font(.caption)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .padding(.horizontal, 16)
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
            Text("Better results via Apple's secure cloud. Audio stays private.")
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
                    if case .requiresPro(let reason) = entitlements.gate(.customFillerLibrary) {
                        paywallReason = reason
                        return
                    }
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

/// Frosted-glass capsule for one filler word. When `onRemove` is non-nil,
/// renders a trailing ✕ that calls it (used by the editor sheet). When nil,
/// renders read-only (used by the idle-screen filler summary card).
struct WordCapsule: View {
    let word: String
    let onRemove: (() -> Void)?

    @Environment(\.sonicMergeSemantic) private var semantic

    var body: some View {
        HStack(spacing: 6) {
            Text(word)
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(uiColor: semantic.accentAction).opacity(0.6))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(word)")
            }
        }
        .padding(.vertical, 5)
        .padding(.leading, 12)
        .padding(.trailing, onRemove == nil ? 12 : 4)
        .studioFrostedCapsule(cornerRadius: 14)
    }
}
