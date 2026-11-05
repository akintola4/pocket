//
//  PocketWidget.swift
//  PocketWidget
//
//  The default pair's rate and its age, read from the App Group cache (or the
//  bundled snapshot if the app has never downloaded). No network here: the
//  widget is meant to be right in airplane mode, and honest about how old the
//  numbers are. The system applies Liquid Glass to the container.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct RateEntry: TimelineEntry {
    let date: Date
    let from: String
    let to: String
    let rate: Decimal?
    let fetchedAt: Date?
    let origin: RatesOrigin
    let decimals: DecimalPreference

    var isStale: Bool {
        fetchedAt.map { ConversionLogic.isStale(fetchedAt: $0, now: date) } ?? true
    }

    /// "Rates from 5 Nov, 09:14 · out of date". The widget can't see the
    /// network, so it never says "offline"; it says "out of date" once a day
    /// has passed.
    var ageLabel: String {
        guard let fetchedAt else { return "No rates yet" }
        let status = ConversionLogic.status(fetchedAt: fetchedAt, isOnline: true, now: date)
        return ConversionLogic.ratesLabel(fetchedAt: fetchedAt, origin: origin, status: status, now: date)
    }

    func formatted(_ amount: Decimal, in code: String) -> String {
        ConversionLogic.format(amount, code: code, preference: decimals)
    }

    func converted(_ amount: Decimal) -> String {
        guard let rate else { return "—" }
        return formatted(amount * rate, in: to)
    }

    static let sample = RateEntry(
        date: .now, from: "USD", to: "NGN", rate: 1346.6, fetchedAt: .now,
        origin: .cached, decimals: .auto
    )
}

struct RateProvider: TimelineProvider {
    func placeholder(in context: Context) -> RateEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (RateEntry) -> Void) {
        completion(context.isPreview && RatesPersistence.loadCache() == nil ? .sample : makeEntry(at: Date()))
    }

    /// One entry now and, if the rates are still fresh, one at the moment they
    /// turn a day old, so "out of date" appears on time without the app.
    func getTimeline(in context: Context, completion: @escaping (Timeline<RateEntry>) -> Void) {
        let now = Date()
        var entries = [makeEntry(at: now)]
        if let fetchedAt = entries[0].fetchedAt {
            let staleAt = fetchedAt.addingTimeInterval(ConversionLogic.staleAfter + 1)
            if staleAt > now { entries.append(makeEntry(at: staleAt)) }
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(6 * 60 * 60))))
    }

    private func makeEntry(at date: Date) -> RateEntry {
        let pair = PocketSettings.defaultPair()
        let loaded = RatesPersistence.loadBest()
        return RateEntry(
            date: date,
            from: pair.from,
            to: pair.to,
            rate: loaded.flatMap { ConversionLogic.rate(from: pair.from, to: pair.to, in: $0.snapshot) },
            fetchedAt: loaded?.snapshot.fetchedAt,
            origin: loaded?.origin ?? .bundled,
            decimals: PocketSettings.decimalPreference()
        )
    }
}

// MARK: - Home Screen (small, medium)

struct RateWidget: Widget {
    let kind = "PocketRateWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RateProvider()) { entry in
            RateWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Exchange rate")
        .description("Your default pair, with how old the rate is. Works offline.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct RateWidgetView: View {
    let entry: RateEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium:
            HStack(alignment: .top, spacing: Tokens.Spacing.lg) {
                summary
                Divider()
                table
            }
        default:
            summary
        }
    }

    private var pairLabel: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            Text(CurrencyCatalog.info(for: entry.from).flag + CurrencyCatalog.info(for: entry.to).flag)
                .font(.caption)
            Text("\(entry.from) → \(entry.to)")
                .font(Theme.display(.caption).weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.from) to \(entry.to)")
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 0) {
            pairLabel
            Spacer(minLength: Tokens.Spacing.xs)
            Text(entry.converted(1))
                .font(Theme.display(.title).weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("per \(entry.formatted(1, in: entry.from))")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: Tokens.Spacing.xs)
            ageText
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var ageText: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.xs) {
            if entry.isStale {
                Image(systemName: "clock.badge.exclamationmark")
                    .accessibilityHidden(true)
            }
            Text(entry.ageLabel)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .font(.caption2)
        .foregroundStyle(entry.isStale ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
    }

    private var table: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            ForEach([Decimal(5), 10, 50, 100], id: \.self) { amount in
                HStack(alignment: .firstTextBaseline) {
                    Text(ConversionLogic.format(amount, code: entry.from, preference: .zero))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: Tokens.Spacing.sm)
                    Text(entry.converted(amount))
                        .fontWeight(.semibold)
                }
                .font(Theme.display(.caption))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Lock Screen (rectangular)

/// The system renders accessory widgets in a vibrant, monochrome mode, so this
/// leans on type weight rather than colour or flags.
struct LockRateWidget: Widget {
    let kind = "PocketLockRateWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RateProvider()) { entry in
            LockRateWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Exchange rate")
        .description("Your default pair on the Lock Screen.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct LockRateWidgetView: View {
    let entry: RateEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(entry.from) → \(entry.to)")
                .font(.caption.weight(.semibold))
                .widgetAccentable()
            Text(entry.converted(1))
                .font(Theme.display(.title3).weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(lockAge)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// The rectangular family has one short line for age: "5 Nov, 09:14",
    /// with "old" when it's past a day.
    private var lockAge: String {
        guard let fetchedAt = entry.fetchedAt else { return "No rates yet" }
        let stamp = ConversionLogic.timestamp(fetchedAt, now: entry.date)
        return entry.isStale ? "\(stamp) · old" : stamp
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    RateWidget()
} timeline: {
    RateEntry.sample
}

#Preview("Medium", as: .systemMedium) {
    RateWidget()
} timeline: {
    RateEntry.sample
}

#Preview("Lock", as: .accessoryRectangular) {
    LockRateWidget()
} timeline: {
    RateEntry.sample
}
