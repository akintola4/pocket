//
//  PocketApp.swift
//  Pocket
//
//  Created by tope akintola on 05/11/2026.
//
//  Pocket is a set of small tools that work with no signal. Each tool is a tab;
//  today there is one. Add a case to `PocketTool` and a view for it in
//  `RootView.content(for:)`, and the tab bar appears on its own.
//

import SwiftUI

@main
struct PocketApp: App {
    @State private var settings = AppSettings()
    @State private var store = RatesStore(client: RatesClient(isOffline: LaunchOptions.forceOffline))
    @State private var connectivity = ConnectivityMonitor(forcedOffline: LaunchOptions.forceOffline)
    /// Once per cold launch. Coming back from the background skips it.
    @State private var showSplash = !LaunchOptions.skipSplash
    @State private var splashStart: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let splashTimeline = SplashLogic.Timeline().slowed(by: LaunchOptions.splashSlowdown)

    var body: some Scene {
        WindowGroup {
            ZStack {
                TimelineView(.animation(paused: !showSplash)) { context in
                    RootView(store: store, settings: settings, connectivity: connectivity)
                        .scaleEffect(appScale(at: context.date))
                }
                if showSplash {
                    SplashOverlay(
                        symbols: SplashLogic.coinCodes(home: settings.defaultTo).map { CurrencyCatalog.info(for: $0).symbol },
                        haptics: settings.haptics,
                        timeline: splashTimeline,
                        onStart: { splashStart = $0 },
                        onFinish: { showSplash = false }
                    )
                }
            }
        }
    }

    private func appScale(at date: Date) -> CGFloat {
        guard showSplash, !reduceMotion else { return 1 }
        let t = splashStart.map { date.timeIntervalSince($0) } ?? 0
        return SplashLogic.appScale(at: t, in: splashTimeline)
    }
}

// MARK: - Tools

enum PocketTool: String, CaseIterable, Identifiable {
    case currency
    // Planned, in this order: qrScanner, flashlight (with Morse code).
    // Units became its own app, Tape (github.com/akintola4/tape).

    var id: String { rawValue }

    var title: String {
        switch self {
        case .currency: "Currency"
        }
    }

    var systemImage: String {
        switch self {
        case .currency: "dollarsign.arrow.circlepath"
        }
    }
}

struct RootView: View {
    let store: RatesStore
    let settings: AppSettings
    let connectivity: ConnectivityMonitor

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabShell(items: PocketTool.allCases.map { tool in
            TabShellItem(id: tool.id, title: tool.title, systemImage: tool.systemImage) {
                content(for: tool)
                    // One tool doesn't need a tab bar. The second one brings it back.
                    .toolbarVisibility(PocketTool.allCases.count > 1 ? .visible : .hidden, for: .tabBar)
            }
        })
        .task { await store.refresh() }
        .onChange(of: connectivity.isOnline) { _, online in
            if online { Task { await store.refresh() } }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, connectivity.isOnline { Task { await store.refresh() } }
        }
    }

    @ViewBuilder
    private func content(for tool: PocketTool) -> some View {
        switch tool {
        case .currency:
            ConverterView(store: store, settings: settings, connectivity: connectivity)
        }
    }
}

// MARK: - Launch arguments

/// Debug-only switches for screenshots and offline testing, set in the scheme
/// or passed to `simctl launch`.
enum LaunchOptions {
    /// `-PocketOffline`: never touch the network and report the device as
    /// offline, so the cached or bundled path is what you see.
    static var forceOffline: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-PocketOffline")
        #else
        false
        #endif
    }

    /// `-PocketNoSplash`: open straight on the converter, for screenshots.
    static var skipSplash: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-PocketNoSplash")
        #else
        false
        #endif
    }

    /// `-PocketSplashSlow`: play the opening animation 4× slower, for tuning it.
    static var splashSlowdown: Double {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-PocketSplashSlow") ? 4 : 1
        #else
        1
        #endif
    }

    /// `-PocketOpenPicker`: open the currency list on launch.
    static var openPicker: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-PocketOpenPicker")
        #else
        false
        #endif
    }
}
