//
//  PocketWidgetViews.swift
//  Pocket
//
//  Shared between the app AND the widget extension.
//
//  The widget's entry and views. They live here, not in PocketWidget/, so the
//  test target can draw them for the README (PocketTests/WidgetScreenshots.swift);
//  the widget extension is the only place they appear on a phone.
//

import SwiftUI
import WidgetKit

// MARK: - Entry

nonisolated struct RateEntry: TimelineEntry {
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

// MARK: - Home Screen (small, medium)

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
