//
//  SettingsView.swift
//  Pocket
//
//  App target only. Native Form (picks up iOS 26 Liquid Glass chrome automatically).
//

import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let store: RatesStore
    let connectivity: ConnectivityMonitor

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                pairSection
                displaySection
                feelSection
                ratesSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: Default pair

    private var pairSection: some View {
        Section {
            currencyPicker("From", selection: $settings.defaultFrom)
            currencyPicker("To", selection: $settings.defaultTo)
        } header: {
            Text("Default pair")
        } footer: {
            Text("Pocket opens with this pair, and the widgets show it.")
        }
    }

    private func currencyPicker(_ label: String, selection: Binding<String>) -> some View {
        Picker(label, selection: selection) {
            ForEach(store.currencies) { info in
                Text("\(info.flag)  \(info.code) · \(info.localizedName)").tag(info.code)
            }
        }
        .pickerStyle(.navigationLink)
    }

    // MARK: Display

    private var displaySection: some View {
        Section {
            Picker("Decimal places", selection: $settings.decimals) {
                ForEach(DecimalPreference.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Decimal places")
        } header: {
            Text("Decimal places")
        } footer: {
            Text("Auto uses each currency's usual decimals: none for ¥ and CFA, three for BD.")
        }
    }

    // MARK: Feel

    private var feelSection: some View {
        Section("Feel") {
            Toggle("Haptics", isOn: $settings.haptics)
        }
    }

    // MARK: Rates

    private var ratesSection: some View {
        Section {
            LabeledContent("Rates") {
                let status = ConversionLogic.status(fetchedAt: store.snapshot.fetchedAt, isOnline: connectivity.isOnline)
                Text(ConversionLogic.statusParts(origin: store.rates.origin, status: status).joined(separator: ", ").capitalizedFirst(or: "Up to date"))
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Downloaded") {
                Text(ConversionLogic.timestamp(store.snapshot.fetchedAt)).foregroundStyle(.secondary)
            }
            LabeledContent("Currencies") {
                Text("\(store.currencies.count)").monospacedDigit().foregroundStyle(.secondary)
            }
            Button {
                Task { await store.refresh(force: true) }
            } label: {
                HStack {
                    Text("Refresh now")
                    if store.isRefreshing {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(!connectivity.isOnline || store.isRefreshing)
        } header: {
            Text("Rates")
        } footer: {
            Text("Rates are daily mid-market reference rates from [fawazahmed0/currency-api](https://github.com/fawazahmed0/exchange-api), released under CC0. They are cached on this phone and work offline. Banks and bureaux charge a spread on top.")
        }
    }

    // MARK: About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version") {
                Text(appVersion).foregroundStyle(.secondary)
            }
            LabeledContent("Made by") {
                Text("tope").foregroundStyle(.secondary)
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

private extension String {
    /// "built-in, offline" → "Built-in, offline"; empty → `fallback`.
    func capitalizedFirst(or fallback: String) -> String {
        guard let first else { return fallback }
        return first.uppercased() + dropFirst()
    }
}
