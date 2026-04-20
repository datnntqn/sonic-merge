// AIOrbView.swift
// SonicMerge
//
// Phase 8 — CL-01: AI Orb nebula sphere visualizer.
//
// Renders a 240pt pulsating nebula sphere via TimelineView + Canvas, with
// 4 layered radial gradient blobs modulated by sine-wave phase offsets.
// Includes a progress ring, state-dependent labels, and a cancel button.
//
// Animation pauses when reduceMotion is true or viewModel.isProcessing is false.
// All colors resolve through @Environment(\.sonicMergeSemantic) — zero hardcoded values.

import SwiftUI

// MARK: - AIOrbView

/// Pulsating nebula sphere visualizer for the Cleaning Lab denoising workflow.
///
/// Renders three states:
/// - Idle (isProcessing=false, hasDenoisedResult=false): static nebula, "Ready to denoise" label
/// - Processing (isProcessing=true): animated nebula + progress ring + "Denoising…" label + cancel
/// - Success (isProcessing=false, hasDenoisedResult=true): static nebula + full ring + "Denoised" label
struct AIOrbView: View {

    let viewModel: CleaningLabViewModel

    @Environment(\.sonicMergeSemantic) private var semantic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Blob Configuration

    /// Configuration for a single animated radial gradient blob.
    private struct BlobConfig {
        let baseRadius: CGFloat
        let phaseOffset: Double
        let frequency: Double
        let gradientColors: [Color]
        let blendMode: GraphicsContext.BlendMode
        let baseCenter: CGPoint
    }

    // MARK: - Pause Logic (per D-03)

    /// Animation pauses for both idle state and reduceMotion — both render the static t=0 composition.
    private var shouldPause: Bool {
        reduceMotion || !viewModel.isProcessing
    }

    // MARK: - Blob Factory

    /// Builds the 4 radial blob configs with semantic token colors.
    private func makeBlobs() -> [BlobConfig] {
        [
            // Core: Deep Indigo, blendMode .normal
            BlobConfig(
                baseRadius: 40,
                phaseOffset: 0.0,
                frequency: 0.35,
                gradientColors: [
                    Color(uiColor: semantic.accentAction).opacity(0.95),
                    Color(uiColor: semantic.accentAction).opacity(0)
                ],
                blendMode: .normal,
                baseCenter: CGPoint(x: 120, y: 120)
            ),
            // Mid 1: System Purple, blendMode .screen
            BlobConfig(
                baseRadius: 70,
                phaseOffset: 1.57,
                frequency: 0.50,
                gradientColors: [
                    Color(uiColor: semantic.accentGradientEnd).opacity(0.75),
                    Color(uiColor: semantic.accentGradientEnd).opacity(0)
                ],
                blendMode: .screen,
                baseCenter: CGPoint(x: 120, y: 120)
            ),
            // Mid 2: System Purple, blendMode .screen
            BlobConfig(
                baseRadius: 95,
                phaseOffset: 3.14,
                frequency: 0.65,
                gradientColors: [
                    Color(uiColor: semantic.accentGradientEnd).opacity(0.50),
                    Color(uiColor: semantic.accentGradientEnd).opacity(0)
                ],
                blendMode: .screen,
                baseCenter: CGPoint(x: 120, y: 120)
            ),
            // Rim: Lime Green, blendMode .screen (outer donut ring)
            BlobConfig(
                baseRadius: 115,
                phaseOffset: 4.71,
                frequency: 0.80,
                gradientColors: [
                    Color(uiColor: semantic.accentAI).opacity(0),
                    Color(uiColor: semantic.accentAI).opacity(0.35)
                ],
                blendMode: .screen,
                baseCenter: CGPoint(x: 120, y: 120)
            )
        ]
    }

    // MARK: - Computed Label

    private var orbLabel: String {
        if viewModel.isProcessing {
            return "Denoising\u{2026}"  // single-char ellipsis per UI-SPEC
        } else if viewModel.hasDenoisedResult {
            return "Denoised"
        } else {
            return "Ready to denoise"
        }
    }

    private var orbLabelColor: Color {
        if viewModel.isProcessing || viewModel.hasDenoisedResult {
            return colorScheme == .dark
                ? Color(uiColor: semantic.accentAI)
                : Color(uiColor: semantic.accentAction)
        } else {
            return Color(uiColor: semantic.textSecondary)
        }
    }

    // MARK: - Accessibility Label

    private var accessibilityLabel: String {
        if viewModel.isProcessing {
            return "AI denoising in progress, \(Int(viewModel.progress * 100)) percent complete"
        } else if viewModel.hasDenoisedResult {
            return "Denoised"
        } else {
            return "Ready to denoise"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: SonicMergeTheme.Spacing.sm) {

            ZStack {
                // 1. Outer bloom — separate Circle layer, NOT inside Canvas (per D-02)
                Circle()
                    .fill(RadialGradient(
                        colors: [
                            Color(uiColor: semantic.accentAI).opacity(0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 144
                    ))
                    .frame(width: 288, height: 288)
                    .blur(radius: reduceTransparency ? 8 : 24)
                    .blendMode(.screen)

                // 2. Canvas orb — TimelineView + Canvas with 4 animated blobs
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: shouldPause)) { timeline in
                    Canvas { ctx, size in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        for blob in makeBlobs() {
                            let r = blob.baseRadius * (1 + 0.08 * sin(t * blob.frequency * 2 * .pi + blob.phaseOffset))
                            let cx = blob.baseCenter.x + cos(t * blob.frequency * 2 * .pi + blob.phaseOffset) * 12
                            let cy = blob.baseCenter.y + sin(t * blob.frequency * 1.3 * 2 * .pi + blob.phaseOffset) * 12
                            let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                            let shading = GraphicsContext.Shading.radialGradient(
                                Gradient(colors: blob.gradientColors),
                                center: CGPoint(x: cx, y: cy),
                                startRadius: 0,
                                endRadius: r
                            )
                            ctx.blendMode = blob.blendMode
                            ctx.fill(Ellipse().path(in: rect), with: shading)
                        }
                    }
                }
                .frame(width: 240, height: 240)
                .saturation(1.15)

                // 3. Progress ring — visible when isProcessing
                if viewModel.isProcessing {
                    Circle()
                        .trim(from: 0, to: CGFloat(viewModel.progress))
                        .stroke(
                            Color(uiColor: semantic.accentAI),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 256, height: 256)
                        .animation(.easeOut(duration: 0.25), value: viewModel.progress)
                        .accessibilityHidden(true)
                }

                // Full ring when success state
                if !viewModel.isProcessing && viewModel.hasDenoisedResult {
                    Circle()
                        .trim(from: 0, to: 1.0)
                        .stroke(
                            Color(uiColor: semantic.accentAI),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 256, height: 256)
                        .accessibilityHidden(true)
                }
            }

            // 4. State-dependent label
            Text(orbLabel)
                .font(.title3)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .foregroundStyle(orbLabelColor)

            // 5. Percent readout — only when processing
            if viewModel.isProcessing {
                Text("\(Int(viewModel.progress * 100))%")
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: semantic.textSecondary))
                    .monospacedDigit()
            }

            // 6. Cancel button — only when processing
            if viewModel.isProcessing {
                Button("Cancel denoising") {
                    viewModel.cancelDenoising()
                }
                .buttonStyle(PillButtonStyle(variant: .outline, size: .compact, tint: .accent))
                .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.isProcessing)
            }
        }
        // 7. Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(viewModel.isProcessing ? .updatesFrequently : [])
    }
}
