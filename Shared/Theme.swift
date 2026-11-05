//
//  Theme.swift
//  Pocket
//
//  Shared between the app AND the widget extension.
//
//  Spacing, radii and type scales come from `Tokens` (swiftui-registry). This
//  file holds the two things that are Pocket's own: the accent and the display
//  face for big numbers.
//

import SwiftUI

nonisolated enum Theme {
    /// Green, after the Nigerian flag. Lives in each target's asset catalog as
    /// AccentColor (a lighter tone in dark mode); this reads it.
    static let accent = Color.accentColor

    /// SF Rounded — the face for headlines and every amount on screen.
    static func display(_ style: Font.TextStyle) -> Font { .system(style, design: .rounded) }

    /// SF Rounded at a fixed size, for the converter's big numbers. Callers pass
    /// a `@ScaledMetric` so it still follows Dynamic Type.
    static func amount(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
    }
}
