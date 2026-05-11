//
//  LiveTranscriptPane.swift
//  SonicMerge
//
//  Expandable disclosure showing the streaming SpeechAnalyzer transcript
//  during Smart Cut analysis. iOS 26+ only — gated by callers, not by
//  this file (so the type compiles on the iOS 17 floor).
//

import SwiftUI

struct LiveTranscriptPane: View {

    let text: String

    @State private var isExpanded: Bool = false
    @Environment(\.sonicMergeSemantic) private var semantic

    var body: some View {
        if text.isEmpty {
            EmptyView()
        } else {
            DisclosureGroup(isExpanded: $isExpanded) {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(text)
                            .font(.callout)
                            .foregroundStyle(Color(uiColor: semantic.textPrimary))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .id("liveTranscriptTail")
                    }
                    .frame(maxHeight: 160)
                    .onChange(of: text) { _, _ in
                        // Auto-scroll to the end as new words arrive.
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("liveTranscriptTail", anchor: .bottom)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .foregroundStyle(Color(uiColor: semantic.accentAI))
                    Text("Live transcript")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(uiColor: semantic.accentAI))
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
