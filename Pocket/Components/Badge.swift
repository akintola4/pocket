//
//  Badge.swift
//  Pocket
//
//  Copied from swiftui-registry and owned here. App target only.
//

import SwiftUI

/// A small status or count marker.
///
/// Tone is a tinted *fill*, never a saturated one with white text on top. White
/// on systemGreen measures 2.2:1 and white on systemOrange 2.2:1, against the
/// 4.5:1 that 11pt semibold text requires — and neither reaches even the 3:1
/// allowed for bold. Label colour on a light wash of the same hue keeps the
/// hue as the signal and lets the system guarantee the contrast, in both
/// appearances and under Increase Contrast.
struct Badge: View {

    enum Tone {
        case neutral, accent, success, warning, danger, outline
    }

    let text: String
    var tone: Tone = .neutral
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            if let systemImage {
                // No font of its own: it inherits the one below, so the glyph
                // scales with Dynamic Type instead of staying pinned at 10pt.
                Image(systemName: systemImage)
                    .imageScale(.small)
            }
            Text(text)
        }
        .font(Tokens.Typography.display(.caption2).weight(.semibold))
        .padding(.horizontal, Tokens.Spacing.sm)
        .padding(.vertical, Tokens.Spacing.xxs)
        .foregroundStyle(foreground)
        .background(background, in: Capsule())
        .overlay {
            if tone == .outline {
                Capsule().strokeBorder(Color(.separator), lineWidth: 1)
            }
        }
        .accessibilityLabel(text)
    }

    private var foreground: AnyShapeStyle {
        switch tone {
        case .neutral: AnyShapeStyle(.secondary)
        default: AnyShapeStyle(.primary)
        }
    }

    /// `.tint` rather than `Color.accentColor`: the former resolves whatever a
    /// host set on this subtree, the latter only ever reads the app-wide asset.
    private var background: AnyShapeStyle {
        switch tone {
        case .neutral: AnyShapeStyle(Color(.secondarySystemFill))
        case .outline: AnyShapeStyle(Color.clear)
        case .accent: AnyShapeStyle(.tint.opacity(0.18))
        case .success: AnyShapeStyle(Color.green.opacity(0.18))
        case .warning: AnyShapeStyle(Color.orange.opacity(0.18))
        case .danger: AnyShapeStyle(Color.red.opacity(0.18))
        }
    }
}

#Preview("Tones") {
    HStack(spacing: Tokens.Spacing.sm) {
        Badge(text: "New")
        Badge(text: "Pro", tone: .accent)
        Badge(text: "Live", tone: .success, systemImage: "dot.radiowaves.left.and.right")
        Badge(text: "3 left", tone: .warning)
        Badge(text: "Failed", tone: .danger)
        Badge(text: "Draft", tone: .outline)
    }
    .padding()
}

#Preview("Accessibility size") {
    VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
        Badge(text: "Live", tone: .success, systemImage: "dot.radiowaves.left.and.right")
        Badge(text: "Failed", tone: .danger, systemImage: "exclamationmark.triangle.fill")
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .padding()
}
