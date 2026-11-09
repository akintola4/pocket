//
//  WidgetScreenshots.swift
//  PocketTests
//
//  Draws the real Lock Screen widget view (Shared/PocketWidgetViews.swift)
//  onto a stand-in Lock Screen for docs/screenshots/widget-lock.png. The
//  Simulator's own Lock Screen comes with a system notification and a stock
//  widget, and it can't be edited without tapping through the wallpaper
//  gallery, so this is how the README gets a clean one. Skipped unless
//  POCKET_WIDGET_SHOTS is set; scripts/screenshots.sh sets it.
//

import Testing
import SwiftUI
import WidgetKit
@testable import Pocket

@MainActor
@Suite("Widget screenshots", .enabled(if: ProcessInfo.processInfo.environment["POCKET_WIDGET_SHOTS"] != nil))
struct WidgetScreenshots {
    /// iPhone 17 Pro, in points.
    private static let screen = CGSize(width: 402, height: 874)
    private static let rectangular = CGSize(width: 172, height: 76)

    private static let output = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "docs/screenshots")

    /// 09:41 today, the same moment the status bar override and
    /// `-PocketDemoRates` use.
    private static let nineFortyOne = Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: .now)!

    /// The bundled snapshot's rate, so the numbers match the app screenshots.
    private static let entry = RateEntry(
        date: nineFortyOne, from: "USD", to: "NGN", rate: Decimal(string: "1346.60127178"),
        fetchedAt: nineFortyOne, origin: .cached, decimals: .auto
    )

    @Test func lockScreen() throws {
        let screen = VStack(spacing: 0) {
            Text(Self.nineFortyOne, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .font(.system(size: 22, weight: .semibold))
                .padding(.top, 70)
            Text("9:41")
                .font(.system(size: 104, weight: .semibold, design: .rounded))
                .monospacedDigit()
            LockRateWidgetView(entry: Self.entry)
                .frame(width: Self.rectangular.width, height: Self.rectangular.height)
                .padding(.top, 8)
            Spacer()
        }
        .foregroundStyle(.white)
        .frame(width: Self.screen.width, height: Self.screen.height)
        .background(Wallpaper())
        .environment(\.colorScheme, .dark)
        try save(screen, as: "widget-lock.png")
    }

    private func save(_ view: some View, as name: String) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        let image = try #require(renderer.uiImage)
        let data = try #require(image.pngData())
        try FileManager.default.createDirectory(at: Self.output, withIntermediateDirectories: true)
        try data.write(to: Self.output.appending(path: name))
    }
}

/// A plain gradient in Pocket's greens, standing in for a wallpaper.
private struct Wallpaper: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.02, green: 0.16, blue: 0.11), Color(red: 0.0, green: 0.42, blue: 0.27)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
