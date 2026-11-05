//
//  Tokens.swift
//  Pocket
//
//  Copied from swiftui-registry and owned here. Shared between the app AND the widget extension.
//

import SwiftUI

/// The single source of dimension and type values for every item in the registry.
///
/// There are no colors here on purpose. Color comes from the system
/// (`Color(.systemBackground)`, `.secondary`, `Color(.separator)`) and from the
/// host app's accent via `.tint`, so a component dropped into your app inherits
/// your palette instead of importing a second one.
enum Tokens {

    /// A 4pt-based spacing scale. Every gap, padding and inset in the registry
    /// comes from here — no loose numbers in component bodies.
    enum Spacing {
        /// 2 — hairline insets, badge padding.
        static let xxs: CGFloat = 2
        /// 4 — between a control and its caption or error text.
        static let xs: CGFloat = 4
        /// 8 — between a label and the control it names.
        static let sm: CGFloat = 8
        /// 12 — between sibling controls in the same group.
        static let md: CGFloat = 12
        /// 16 — a card's internal padding.
        static let lg: CGFloat = 16
        /// 24 — a screen's horizontal margin, and the gap between groups.
        static let xl: CGFloat = 24
        /// 32 — above a screen's headline, below its last control.
        static let xxl: CGFloat = 32
    }

    /// Corner radii. Four steps, because a fifth never earns itself.
    enum Radius {
        /// 6 — chips, badges, key caps.
        static let xs: CGFloat = 6
        /// 8 — inputs and other inline controls.
        static let sm: CGFloat = 8
        /// 12 — buttons.
        static let md: CGFloat = 12
        /// 20 — cards and sheets.
        static let lg: CGFloat = 20
    }

    enum Layout {
        /// Forms stop growing here. Past ~420pt a single text column reads badly,
        /// and on iPad an edge-to-edge login form looks broken.
        static let contentMaxWidth: CGFloat = 420
        /// The HIG minimum hit target. Used as a `minHeight`, never a fixed
        /// `height`, so controls still grow with Dynamic Type.
        static let minTapTarget: CGFloat = 44
        /// One device pixel on a 3x screen — for borders that shouldn't bloom.
        static let hairline: CGFloat = 1 / 3
    }

    /// Type.
    ///
    /// Apple's typefaces ship with the OS, and their license explicitly forbids
    /// embedding them in an app ("You may not embed the Apple Font in any
    /// software programs"). So nothing here loads a font file — each helper
    /// reaches the family through `Font.Design`, which is both legal and the
    /// only way to keep Dynamic Type, optical sizing and localisation working:
    ///
    ///   .default    SF Pro        the system face
    ///   .rounded    SF Pro Rounded
    ///   .serif      New York
    ///   .monospaced SF Mono
    ///
    /// Every helper takes a `Font.TextStyle` rather than a point size, so text
    /// still scales with the reader's settings.
    enum Typography {
        /// Rounded, for headlines and numerals — the registry's one stylistic
        /// choice.
        static func display(_ style: Font.TextStyle) -> Font {
            .system(style, design: .rounded)
        }

        /// SF Pro, for anything the user reads rather than scans.
        static func text(_ style: Font.TextStyle) -> Font {
            .system(style)
        }

        /// New York. For long-form reading, quotes, and editorial surfaces.
        static func serif(_ style: Font.TextStyle) -> Font {
            .system(style, design: .serif)
        }

        /// SF Mono. Code, key caps, and anything that must align in columns.
        static func mono(_ style: Font.TextStyle) -> Font {
            .system(style, design: .monospaced)
        }

        /// Digits that keep their column when the value changes — timers,
        /// counters, prices. Without this, proportional digits jitter.
        static func tabular(_ style: Font.TextStyle) -> Font {
            .system(style, design: .rounded).monospacedDigit()
        }
    }

    /// One duration and one curve, so motion across the registry feels like one
    /// system rather than each component's author guessing.
    enum Motion {
        /// State changes the user caused: expanding, selecting, toggling.
        static let quick: Animation = .snappy(duration: 0.22)
        /// Things arriving or leaving on their own: toasts, banners.
        static let enter: Animation = .smooth(duration: 0.3)
    }
}
