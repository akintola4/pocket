//
//  ConverterView.swift
//  Pocket
//
//  The currency tool. Two glass cards — what you have, what it's worth — with a
//  swap between them, and the age of the rates always in view. App target only.
//

import SwiftUI

struct ConverterView: View {
    let store: RatesStore
    let settings: AppSettings
    let connectivity: ConnectivityMonitor

    @State private var from: String
    @State private var to: String
    @State private var amountText = "100"
    @State private var picking: Side?
    @State private var showSettings = false
    @State private var feedbackTick = 0
    @FocusState private var amountFocused: Bool

    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 44
    @ScaledMetric(relativeTo: .title) private var swapSize: CGFloat = 52

    enum Side: String, Identifiable {
        case from, to
        var id: String { rawValue }
    }

    init(store: RatesStore, settings: AppSettings, connectivity: ConnectivityMonitor) {
        self.store = store
        self.settings = settings
        self.connectivity = connectivity
        _from = State(initialValue: settings.defaultFrom)
        _to = State(initialValue: settings.defaultTo)
        _picking = State(initialValue: LaunchOptions.openPicker ? .to : nil)
    }

    // MARK: Derived values

    private var amount: Decimal { ConversionLogic.parseAmount(amountText) ?? 0 }
    private var rate: Decimal? { ConversionLogic.rate(from: from, to: to, in: store.snapshot) }
    private var result: Decimal { rate.map { amount * $0 } ?? 0 }
    private var resultText: String { ConversionLogic.format(result, code: to, preference: settings.decimals) }
    private var amountForSpeech: String { ConversionLogic.format(amount, code: from, preference: settings.decimals) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
                header
                RatesStatusBadge(store: store, connectivity: connectivity)

                VStack(spacing: Tokens.Spacing.sm) {
                    fromCard
                    swapButton
                    toCard
                }

                if let rate {
                    Text(ConversionLogic.rateLine(from: from, to: to, rate: rate))
                        .font(Tokens.Typography.text(.footnote))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                chips
                attribution
            }
            .padding(.horizontal, Tokens.Spacing.lg)
            .padding(.top, Tokens.Spacing.sm)
            .padding(.bottom, Tokens.Spacing.xxl)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await store.refresh(force: true) }
        .animation(Tokens.Motion.quick, value: result)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { amountFocused = false }
            }
        }
        .sensoryFeedback(trigger: feedbackTick) { _, _ in
            settings.haptics ? .impact(weight: .light) : nil
        }
        .onChange(of: amountText) { _, newValue in
            let clean = ConversionLogic.sanitizeAmount(newValue, maxFractionDigits: CurrencyCatalog.info(for: from).decimals)
            if clean != newValue { amountText = clean }
        }
        .onChange(of: settings.defaultFrom) { _, code in set(code, on: .from) }
        .onChange(of: settings.defaultTo) { _, code in set(code, on: .to) }
        .sheet(item: $picking) { side in
            CurrencyPickerSheet(
                store: store,
                title: side == .from ? "Convert from" : "Convert to",
                selected: side == .from ? from : to
            ) { code in
                set(code, on: side)
                store.noteUsed(code)
                feedbackTick += 1
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings, store: store, connectivity: connectivity)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("Currency")
                .font(Theme.display(.largeTitle).weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Tokens.Spacing.lg)
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .frame(minWidth: Tokens.Layout.minTapTarget, minHeight: Tokens.Layout.minTapTarget)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .tint(.primary)
            .accessibilityLabel("Settings")
        }
    }

    // MARK: Cards

    private var fromCard: some View {
        card {
            currencyRow(code: from, side: .from)
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.xs) {
                Text(CurrencyCatalog.info(for: from).symbol)
                    .font(Theme.amount(size: amountSize * 0.6))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("0", text: $amountText)
                    .font(Theme.amount(size: amountSize))
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .lineLimit(1)
                    .accessibilityLabel("Amount in \(CurrencyCatalog.info(for: from).localizedName)")
            }
        }
        .contentShape(.rect)
        .onTapGesture { amountFocused = true }
    }

    private var toCard: some View {
        card {
            currencyRow(code: to, side: .to)
            Text(resultText)
                .font(Theme.amount(size: amountSize))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText(value: (result as NSDecimalNumber).doubleValue))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .accessibilityLabel("\(amountForSpeech) is \(resultText)")
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
            content()
        }
        .padding(.horizontal, Tokens.Spacing.lg + Tokens.Spacing.xs)
        .padding(.vertical, Tokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    private func currencyRow(code: String, side: Side) -> some View {
        let info = CurrencyCatalog.info(for: code)
        return HStack(spacing: Tokens.Spacing.md) {
            Button {
                picking = side
            } label: {
                HStack(spacing: Tokens.Spacing.sm) {
                    Text(info.flag)
                        .font(.title2)
                    Text(info.code)
                        .font(Theme.display(.title3).weight(.semibold))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, Tokens.Spacing.md)
                .frame(minHeight: Tokens.Layout.minTapTarget)
                .background(.fill.tertiary, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(side == .from ? "From" : "To") \(info.localizedName)")
            .accessibilityHint("Opens the currency list")

            Text(info.localizedName)
                .font(Tokens.Typography.text(.subheadline))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityHidden(true)
        }
    }

    // MARK: Swap

    private var swapButton: some View {
        Button {
            withAnimation(Tokens.Motion.quick) {
                swap(&from, &to)
            }
            feedbackTick += 1
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.title3.weight(.semibold))
                .frame(width: swapSize, height: swapSize)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .tint(.primary)
        .accessibilityLabel("Swap currencies")
        .accessibilityHint("Converts from \(to) to \(from) instead")
    }

    // MARK: Chips

    @ViewBuilder private var chips: some View {
        let codes = store.chipCodes
        if !codes.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
                Text("CONVERT TO")
                    .font(.caption2)
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                ScrollView(.horizontal) {
                    GlassEffectContainer(spacing: Tokens.Spacing.sm) {
                        HStack(spacing: Tokens.Spacing.sm) {
                            ForEach(codes, id: \.self) { code in
                                chip(code)
                            }
                        }
                        .padding(.vertical, Tokens.Spacing.xs)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
        }
    }

    @ViewBuilder private func chip(_ code: String) -> some View {
        let info = CurrencyCatalog.info(for: code)
        let selected = code == to
        let label = HStack(spacing: Tokens.Spacing.xs + Tokens.Spacing.xxs) {
            Text(info.flag)
            Text(info.code)
                .font(Theme.display(.subheadline).weight(.semibold))
        }
        .frame(minHeight: Tokens.Layout.minTapTarget - Tokens.Spacing.md)

        let action = {
            guard !selected else { return }
            set(code, on: .to)
            store.noteUsed(code)
            feedbackTick += 1
        }

        Group {
            if selected {
                Button(action: action) { label }
                    .buttonStyle(.glassProminent)
            } else {
                Button(action: action) { label }
                    .buttonStyle(.glass)
                    .tint(.primary)
            }
        }
        .frame(minHeight: Tokens.Layout.minTapTarget)
        .accessibilityLabel("Convert to \(info.localizedName)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Attribution

    private var attribution: some View {
        Link(destination: URL(string: "https://github.com/fawazahmed0/exchange-api")!) {
            Text("Rates: fawazahmed0/currency-api, CC0. Daily mid-market rates for reference, not for trading.")
                .font(Tokens.Typography.text(.caption))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .tint(.secondary)
        .accessibilityHint("Opens the rates source on GitHub")
        .padding(.top, Tokens.Spacing.sm)
    }

    // MARK: Actions

    private func set(_ code: String, on side: Side) {
        switch side {
        case .from:
            if code == to { to = from }
            from = code
        case .to:
            if code == from { from = to }
            to = code
        }
    }
}

// MARK: - Rates status

/// "Rates from 5 Nov, 09:14 · offline". Re-evaluates every minute so "out of
/// date" appears on time even if nothing else changes.
struct RatesStatusBadge: View {
    let store: RatesStore
    let connectivity: ConnectivityMonitor

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let snapshot = store.snapshot
            let status = ConversionLogic.status(fetchedAt: snapshot.fetchedAt, isOnline: connectivity.isOnline, now: context.date)
            let text = ConversionLogic.ratesLabel(fetchedAt: snapshot.fetchedAt, origin: store.rates.origin, status: status, now: context.date)
            Badge(text: text, tone: tone(status), systemImage: icon(status))
                .accessibilityLabel(text.replacingOccurrences(of: " · ", with: ", "))
        }
    }

    private func tone(_ status: RatesStatus) -> Badge.Tone {
        switch status {
        case .upToDate: store.rates.origin == .bundled ? .neutral : .success
        case .outOfDate, .offline: .warning
        }
    }

    private func icon(_ status: RatesStatus) -> String {
        switch status {
        case .upToDate: store.rates.origin == .bundled ? "shippingbox" : "checkmark.circle"
        case .outOfDate: "clock.badge.exclamationmark"
        case .offline: "wifi.slash"
        }
    }
}

#Preview {
    ConverterView(store: RatesStore(), settings: AppSettings(), connectivity: ConnectivityMonitor())
}
