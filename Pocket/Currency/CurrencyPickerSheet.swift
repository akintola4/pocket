//
//  CurrencyPickerSheet.swift
//  Pocket
//
//  Every currency the rates cover, searchable by code or name, with favourites
//  pinned on top. The star is its own button so VoiceOver can reach it apart
//  from the row. App target only.
//

import SwiftUI

struct CurrencyPickerSheet: View {
    let store: RatesStore
    let title: String
    let selected: String
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var matches: [CurrencyInfo] {
        let all = store.currencies.sorted {
            $0.localizedName.localizedStandardCompare($1.localizedName) == .orderedAscending
        }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return all }
        return all.filter {
            $0.code.localizedCaseInsensitiveContains(trimmed)
                || $0.localizedName.localizedStandardContains(trimmed)
                || $0.name.localizedStandardContains(trimmed)
                || $0.symbol == trimmed
        }
    }

    var body: some View {
        let matches = matches
        let favourites = store.favourites.compactMap { code in matches.first { $0.code == code } }
        let others = matches.filter { !store.isFavourite($0.code) }

        NavigationStack {
            List {
                if !favourites.isEmpty {
                    Section("Favourites") {
                        ForEach(favourites) { row($0) }
                    }
                }
                if !others.isEmpty {
                    Section(query.isEmpty ? "All currencies" : "Results") {
                        ForEach(others) { row($0) }
                    }
                }
            }
            .overlay {
                if matches.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Code or name")
            .autocorrectionDisabled()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }

    private func row(_ info: CurrencyInfo) -> some View {
        let isSelected = info.code == selected
        let isFavourite = store.isFavourite(info.code)

        return HStack(spacing: Tokens.Spacing.sm) {
            Button {
                onPick(info.code)
                dismiss()
            } label: {
                ListRow(title: info.localizedName, subtitle: info.symbol == info.code ? info.code : "\(info.code) · \(info.symbol)") {
                    Text(info.flag)
                        .font(.title2)
                        .frame(minWidth: 32)
                } trailing: {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(info.localizedName), \(info.code), symbol \(info.symbol)")
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            Button {
                withAnimation(Tokens.Motion.quick) { store.toggleFavourite(info.code) }
            } label: {
                Image(systemName: isFavourite ? "star.fill" : "star")
                    .font(.body)
                    .foregroundStyle(isFavourite ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .frame(minWidth: Tokens.Layout.minTapTarget, minHeight: Tokens.Layout.minTapTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavourite ? "Remove \(info.code) from favourites" : "Add \(info.code) to favourites")
        }
        .listRowInsets(EdgeInsets(top: 0, leading: Tokens.Spacing.lg, bottom: 0, trailing: Tokens.Spacing.xs))
    }
}
