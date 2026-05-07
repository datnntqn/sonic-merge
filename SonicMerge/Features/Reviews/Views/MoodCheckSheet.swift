import SwiftUI

/// Three-emoji mood-check sheet. Pure UI — `SKStoreReviewController` is
/// invoked by the caller's onSelect closure (keeps this view test-isolatable
/// and free of StoreKit dependency).
struct MoodCheckSheet: View {

    enum Mood: String, Sendable {
        case happy
        case neutral
        case sad
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.sonicMergeSemantic) private var semantic

    var onSelect: (Mood) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("How was that?")
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(Color(uiColor: semantic.textPrimary))
                .padding(.top, 32)

            VStack(spacing: 12) {
                moodButton(.happy, emoji: "😊", label: "Loved it")
                moodButton(.neutral, emoji: "😐", label: "It was okay")
                moodButton(.sad, emoji: "😞", label: "Could be better")
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color(uiColor: semantic.surfaceBase))
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private func moodButton(_ mood: Mood, emoji: String, label: String) -> some View {
        Button {
            onSelect(mood)
            dismiss()
        } label: {
            HStack(spacing: 16) {
                Text(emoji).font(.system(size: 36))
                Text(label)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color(uiColor: semantic.textPrimary))
                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: semantic.surfaceCard))
            )
            .accessibilityIdentifier("MoodCheckSheet.\(mood.rawValue)")
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// Presents the mood-check sheet when the binding is true. The caller's
    /// onSelect closure handles routing (e.g., 😊 → SKStoreReviewController).
    /// Use after a successful export when `ReviewPromptCoordinator.shouldPromptNow()`
    /// returned true.
    func moodCheckSheet(
        isPresented: Binding<Bool>,
        onSelect: @escaping (MoodCheckSheet.Mood) -> Void
    ) -> some View {
        sheet(isPresented: isPresented) {
            MoodCheckSheet(onSelect: onSelect)
        }
    }
}
