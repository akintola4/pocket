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

    var body: some Scene {
        WindowGroup {
            RootView(store: store, settings: settings, connectivity: connectivity)
        }
    }
}

// MARK: - Tools

enum PocketTool: String, CaseIterable, Identifiable {
    case currency
    // Planned, in this order: units, qrScanner, flashlight (with Morse code).

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

    /// `-PocketOpenPicker`: open the currency list on launch.
    static var openPicker: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-PocketOpenPicker")
        #else
        false
        #endif
    }
}
