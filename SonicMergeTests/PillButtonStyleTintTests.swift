// PillButtonStyleTintTests.swift
// SonicMergeTests
//
// Phase 8-01: Tests for Tint enum backward compatibility and color branching.
// Uses Swift Testing framework (import Testing) matching project convention.

import Testing
import SwiftUI
@testable import SonicMerge

struct PillButtonStyleTintTests {

    // MARK: - Backward compatibility (D-01)

    /// Default init (no arguments) must have tint == .accent
    @Test func defaultInit_hasTintAccent() {
        let style = PillButtonStyle()
        #expect(style.tint == .accent)
    }

    /// Explicit variant + size (no tint) must default tint to .accent
    @Test func explicitVariantAndSize_defaultsTintToAccent() {
        let style = PillButtonStyle(variant: .filled, size: .regular)
        #expect(style.tint == .accent)
    }

    /// Outline compact style (Phase 7 call site) must default tint to .accent
    @Test func outlineCompact_defaultsTintToAccent() {
        let style = PillButtonStyle(variant: .outline, size: .compact)
        #expect(style.tint == .accent)
    }

    // MARK: - AI tint (Phase 8)

    /// Explicit .ai tint must be stored on the style
    @Test func explicitAITint_isSaved() {
        let style = PillButtonStyle(variant: .filled, size: .compact, tint: .ai)
        #expect(style.tint == .ai)
    }

    /// Explicit .ai tint with regular size must be stored on the style
    @Test func aiTintRegularSize_isSaved() {
        let style = PillButtonStyle(variant: .filled, size: .regular, tint: .ai)
        #expect(style.tint == .ai)
    }

    /// Outline + .ai tint should store .ai
    @Test func outlineAITint_isSaved() {
        let style = PillButtonStyle(variant: .outline, size: .regular, tint: .ai)
        #expect(style.tint == .ai)
    }
}
