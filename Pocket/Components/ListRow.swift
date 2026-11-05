//
//  ListRow.swift
//  Pocket
//
//  Copied from swiftui-registry and owned here. App target only.
//

import SwiftUI

/// A list row: something on the left, text in the middle, something on the right.
///
/// Named `ListRow` rather than `Item` because a type called `Item` dropped into
/// someone's app is asking for a collision — most SwiftUI projects already have
/// one.
struct ListRow<Leading: View, Trailing: View>: View {

    let title: String
    var subtitle: String? = nil
    var showsChevron: Bool = false
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Tokens.Spacing.md) {
            leading

            VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
                Text(title)
                    .font(Tokens.Typography.text(.body))
                    .foregroundStyle(.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(Tokens.Typography.text(.footnote))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
                .foregroundStyle(.secondary)
                .font(Tokens.Typography.text(.subheadline))

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, Tokens.Spacing.sm)
        .frame(minHeight: Tokens.Layout.minTapTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

extension ListRow where Leading == EmptyView, Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, showsChevron: Bool = false) {
        self.init(title: title, subtitle: subtitle, showsChevron: showsChevron) {
            EmptyView()
        } trailing: {
            EmptyView()
        }
    }
}

extension ListRow where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        showsChevron: Bool = false,
        @ViewBuilder leading: () -> Leading
    ) {
        self.init(title: title, subtitle: subtitle, showsChevron: showsChevron, leading: leading) {
            EmptyView()
        }
    }
}

#Preview("Rows") {
    List {
        ListRow(title: "Notifications", subtitle: "Daily at 9:00", showsChevron: true) {
            Image(systemName: "bell.badge")
                .foregroundStyle(.tint)
                .frame(width: 28)
        }
        ListRow(title: "Nigerian Naira", subtitle: "NGN · ₦") {
            Text("🇳🇬").font(.title2)
        } trailing: {
            Badge(text: "Favourite", tone: .accent)
        }
        ListRow(title: "Version", subtitle: nil) {
            EmptyView()
        } trailing: {
            Text("1.4.0")
        }
    }
}
