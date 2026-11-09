//
//  PocketWidget.swift
//  PocketWidget
//
//  The default pair's rate and its age, read from the App Group cache (or the
//  bundled snapshot if the app has never downloaded). No network here: the
//  widget is meant to be right in airplane mode, and honest about how old the
//  numbers are. The system applies Liquid Glass to the container.
//
//  The entry and views are in Shared/PocketWidgetViews.swift.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

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
