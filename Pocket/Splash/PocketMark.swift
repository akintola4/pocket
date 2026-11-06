//
//  PocketMark.swift
//  Pocket
//
//  The pocket from the app icon, drawn in the icon's own 520 × 524 grid. The
//  launch screen image (Assets/LaunchPocket.svg) uses the same paths, so the
//  splash starts on exactly the picture iOS was already showing.
//

import SwiftUI

nonisolated enum PocketMark {
    static let gridSize = CGSize(width: 520, height: 524)

    /// The green behind the pocket: the icon's, in light and dark mode alike.
    static let green = Color(red: 0, green: 0x87 / 255, blue: 0x51 / 255)

    /// Maps the 520 × 524 grid onto `rect`.
    static func transform(into rect: CGRect) -> CGAffineTransform {
        CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: rect.width / gridSize.width, y: rect.height / gridSize.height)
    }

    nonisolated struct Flap: Shape {
        func path(in rect: CGRect) -> Path {
            Path(CGRect(x: 0, y: 0, width: 520, height: 113))
                .applying(PocketMark.transform(into: rect))
        }
    }

    nonisolated struct Body: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 127))
                p.addLine(to: CGPoint(x: 520, y: 127))
                p.addLine(to: CGPoint(x: 520, y: 331))
                p.addCurve(to: CGPoint(x: 260, y: 524), control1: CGPoint(x: 520, y: 436), control2: CGPoint(x: 403, y: 524))
                p.addCurve(to: CGPoint(x: 0, y: 331), control1: CGPoint(x: 117, y: 524), control2: CGPoint(x: 0, y: 436))
                p.closeSubpath()
            }
            .applying(PocketMark.transform(into: rect))
        }
    }

    /// Flap and body as one piece, without the gap between them.
    nonisolated struct Silhouette: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in
                p.move(to: .zero)
                p.addLine(to: CGPoint(x: 520, y: 0))
                p.addLine(to: CGPoint(x: 520, y: 331))
                p.addCurve(to: CGPoint(x: 260, y: 524), control1: CGPoint(x: 520, y: 436), control2: CGPoint(x: 403, y: 524))
                p.addCurve(to: CGPoint(x: 0, y: 331), control1: CGPoint(x: 117, y: 524), control2: CGPoint(x: 0, y: 436))
                p.closeSubpath()
            }
            .applying(PocketMark.transform(into: rect))
        }
    }

    /// The stitch line. Stroke it with `stitchStyle(width:)` to get the dots.
    nonisolated struct Stitch: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in
                p.move(to: CGPoint(x: 34, y: 34))
                p.addLine(to: CGPoint(x: 468, y: 34))
                p.addQuadCurve(to: CGPoint(x: 486, y: 52), control: CGPoint(x: 486, y: 34))
                p.addLine(to: CGPoint(x: 486, y: 336))
                p.addCurve(to: CGPoint(x: 260, y: 490), control1: CGPoint(x: 486, y: 426), control2: CGPoint(x: 388, y: 490))
                p.addCurve(to: CGPoint(x: 34, y: 336), control1: CGPoint(x: 132, y: 490), control2: CGPoint(x: 34, y: 426))
                p.closeSubpath()
            }
            .applying(PocketMark.transform(into: rect))
        }
    }

    /// Zero-length dashes with round caps: the icon's dotted stitch, scaled
    /// to a mark `width` points wide.
    static func stitchStyle(width: CGFloat) -> StrokeStyle {
        let unit = width / gridSize.width
        return StrokeStyle(lineWidth: 16 * unit, lineCap: .round, dash: [0, 36 * unit])
    }
}

/// The white pocket with its green stitches, as on the icon.
struct PocketMarkView: View {
    var body: some View {
        ZStack {
            // Green behind the gap between flap and body, so whatever goes
            // into the pocket (the coin) doesn't show through it.
            PocketMark.Silhouette().fill(PocketMark.green)
            PocketMark.Flap().fill(.white)
            PocketMark.Body().fill(.white)
            PocketMark.Stitch().stroke(PocketMark.green, style: PocketMark.stitchStyle(width: SplashLogic.markSize.width))
        }
        .frame(width: SplashLogic.markSize.width, height: SplashLogic.markSize.height)
    }
}
