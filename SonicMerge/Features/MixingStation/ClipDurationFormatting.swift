// ClipDurationFormatting.swift
// SonicMerge

import Foundation

enum ClipDurationFormatting {
    static func mmss(from seconds: TimeInterval) -> String {
        let s = max(0, seconds)
        let mins = Int(s) / 60
        let secs = Int(s) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
