// SonicMerge/Features/SmartCut/Views/EditFillerListSheet.swift
import SwiftUI

struct EditFillerListSheet: View {
    @Binding var library: FillerLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var newWord = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Default words") {
                    ForEach(library.defaultOnWords + library.defaultOffWords, id: \.self) { word in
                        let isRemoved = library.removedDefaults.contains(word)
                        HStack {
                            Text(word)
                                .strikethrough(isRemoved)
                                .opacity(isRemoved ? 0.5 : 1)
                            Spacer()
                            Button(isRemoved ? "Restore" : "Remove") {
                                if isRemoved {
                                    library.addCustom(word)
                                } else {
                                    library.remove(word)
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Section("Your words") {
                    ForEach(library.customWords, id: \.self) { word in
                        Text(word)
                            .swipeActions {
                                Button(role: .destructive) {
                                    library.remove(word)
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                    HStack {
                        TextField("Add a word, e.g. anyway", text: $newWord)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                        Button("Add") {
                            library.addCustom(newWord)
                            newWord = ""
                        }
                        .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("Edit filler list")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
