//
//  TabShell.swift
//  Pocket
//
//  Copied from swiftui-registry and owned here. App target only.
//

import SwiftUI

/// One tab in a `TabShell`.
struct TabShellItem: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let content: AnyView

    init(id: String? = nil, title: String, systemImage: String, @ViewBuilder content: () -> some View) {
        self.id = id ?? title
        self.title = title
        self.systemImage = systemImage
        self.content = AnyView(content())
    }
}

/// The root tab container, with an optional dedicated search tab.
///
/// `AnyView` is a deliberate trade: it makes the tab list plain data you can
/// build from a config or a feature flag, which is worth more here than the
/// handful of nanoseconds generics would save.
struct TabShell: View {

    let items: [TabShellItem]
    var searchTitle: String = "Search"
    var searchContent: AnyView? = nil

    @State private var selection: String = ""

    var body: some View {
        TabView(selection: $selection) {
            ForEach(items) { item in
                Tab(item.title, systemImage: item.systemImage, value: item.id) {
                    item.content
                }
            }

            if let searchContent {
                Tab(searchTitle, systemImage: "magnifyingglass", value: "__search", role: .search) {
                    searchContent
                }
            }
        }
        .onAppear {
            if selection.isEmpty { selection = items.first?.id ?? "" }
        }
    }
}

#Preview("Tabs") {
    TabShell(
        items: [
            TabShellItem(title: "Today", systemImage: "checkmark.circle") {
                Text("Today").font(Tokens.Typography.display(.largeTitle))
            },
            TabShellItem(title: "History", systemImage: "calendar") {
                Text("History").font(Tokens.Typography.display(.largeTitle))
            },
            TabShellItem(title: "Settings", systemImage: "gearshape") {
                Text("Settings").font(Tokens.Typography.display(.largeTitle))
            }
        ],
        searchContent: AnyView(Text("Search").font(Tokens.Typography.display(.largeTitle)))
    )
}
