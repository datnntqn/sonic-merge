// SonicMerge/Features/SmartCut/Views/Studio/LocalePicker.swift
//
// Sheet listing all locales SFSpeechRecognizer supports. Sorted by user's
// preferred-languages first ("Suggested" header), then alphabetical. Names
// pinned to English (see LanguagePill rationale).
//

import SwiftUI
import Speech

struct LocalePicker: View {

    let currentIdentifier: String
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.sonicMergeSemantic) private var semantic

    @State private var searchText = ""

    private var allLocales: [Locale] {
        Array(SFSpeechRecognizer.supportedLocales())
    }

    private var suggested: [Locale] {
        // Locales whose language code matches the user's preferredLanguages.
        let preferredCodes = Locale.preferredLanguages
            .compactMap { Locale(identifier: $0).language.languageCode?.identifier }
        let preferredSet = Set(preferredCodes)
        return allLocales
            .filter { preferredSet.contains($0.language.languageCode?.identifier ?? "") }
            .sorted { displayName($0) < displayName($1) }
    }

    private var others: [Locale] {
        let suggestedSet = Set(suggested.map(\.identifier))
        return allLocales
            .filter { !suggestedSet.contains($0.identifier) }
            .sorted { displayName($0) < displayName($1) }
    }

    private var filteredSuggested: [Locale] {
        guard !searchText.isEmpty else { return suggested }
        return suggested.filter { matches(searchText, in: $0) }
    }

    private var filteredOthers: [Locale] {
        guard !searchText.isEmpty else { return others }
        return others.filter { matches(searchText, in: $0) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !filteredSuggested.isEmpty {
                    Section("Suggested") {
                        ForEach(filteredSuggested, id: \.identifier) { locale in
                            row(locale)
                        }
                    }
                }
                if !filteredOthers.isEmpty {
                    Section(filteredSuggested.isEmpty ? "" : "All languages") {
                        ForEach(filteredOthers, id: \.identifier) { locale in
                            row(locale)
                        }
                    }
                }
            }
            .navigationTitle("Language")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search languages")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color(uiColor: semantic.accentAction))
                }
            }
        }
    }

    private func row(_ locale: Locale) -> some View {
        Button {
            onPick(locale.identifier)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName(locale))
                        .foregroundStyle(Color(uiColor: semantic.textPrimary))
                    Text(locale.identifier)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color(uiColor: semantic.textSecondary))
                }
                Spacer()
                if locale.identifier == currentIdentifier {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color(uiColor: semantic.accentAction))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func displayName(_ locale: Locale) -> String {
        Locale(identifier: "en")
            .localizedString(forIdentifier: locale.identifier)
            ?? locale.identifier
    }

    private func matches(_ query: String, in locale: Locale) -> Bool {
        let q = query.lowercased()
        return displayName(locale).lowercased().contains(q)
            || locale.identifier.lowercased().contains(q)
    }
}
