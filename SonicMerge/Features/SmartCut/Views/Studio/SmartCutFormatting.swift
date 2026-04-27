// SmartCutFormatting.swift
// SonicMerge
//
// Phase 12 (Smart Cut Studio Refactor): formatting helpers shared by the
// new Studio views. Lifted verbatim from FillerListPanel's private helpers
// (lines 136-144 of the now-retired file) so they don't get orphaned when
// FillerListPanel is deleted in Chunk 8.

import Foundation

enum SmartCutFormatting {

    /// "0:20" / "12:34" minute:second timestamp.
    static func formatTimestamp(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    /// "1.5s" threshold readout.
    static func formatThreshold(_ seconds: TimeInterval) -> String {
        String(format: "%.1fs", seconds)
    }
}
