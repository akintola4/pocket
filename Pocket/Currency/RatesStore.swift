//
//  RatesStore.swift
//  Pocket
//
//  App target ONLY. The reactive source of truth for the currency tool. Wraps
//  the shared, observation-free persistence/logic layer and adds the side
//  effects: download, write the cache, reload widgets, remember favourites.
//

import SwiftUI
import WidgetKit

@Observable
final class RatesStore {
    private(set) var rates: LoadedRates
    private(set) var isRefreshing = false
    private(set) var favourites: [String]
    private(set) var recents: [String]

    @ObservationIgnored private let client: RatesClient
    @ObservationIgnored private let cacheURL: URL
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var lastAttempt: Date?

    init(
        client: RatesClient = RatesClient(),
        cacheURL: URL = RatesPersistence.cacheURL(),
        defaults: UserDefaults = PocketShared.defaults,
        bundle: Bundle = .main
    ) {
        guard let loaded = RatesPersistence.loadBest(cacheURL: cacheURL, bundle: bundle) else {
            fatalError("rates-snapshot.json is missing from the app bundle")
        }
        self.rates = loaded
        self.client = client
        self.cacheURL = cacheURL
        self.defaults = defaults
        self.favourites = PocketSettings.codes(forKey: SettingsKeys.favourites, from: defaults) ?? PocketSettings.defaultFavourites
        self.recents = PocketSettings.codes(forKey: SettingsKeys.recents, from: defaults) ?? []
    }

    var snapshot: RatesSnapshot { rates.snapshot }

    /// Currencies the current snapshot can actually convert.
    var currencies: [CurrencyInfo] {
        CurrencyCatalog.all.filter { snapshot.rate(for: $0.code) != nil }
    }

    // MARK: Refresh

    /// Downloads fresh rates. Fails quietly: on any error the rates on screen
    /// stay as they are, and their age label says how old they are.
    /// `force` skips the one-minute guard (pull-to-refresh).
    func refresh(force: Bool = false) async {
        guard !isRefreshing else { return }
        if !force, let lastAttempt, Date().timeIntervalSince(lastAttempt) < 60 { return }
        lastAttempt = Date()
        isRefreshing = true
        defer { isRefreshing = false }

        guard let fresh = try? await client.fetchLatest() else { return }
        try? RatesPersistence.saveCache(fresh, at: cacheURL)
        rates = LoadedRates(snapshot: fresh, origin: .cached)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Favourites and recents

    func isFavourite(_ code: String) -> Bool { favourites.contains(code) }

    func toggleFavourite(_ code: String) {
        if let index = favourites.firstIndex(of: code) {
            favourites.remove(at: index)
        } else {
            favourites.append(code)
        }
        defaults.set(favourites, forKey: SettingsKeys.favourites)
    }

    func noteUsed(_ code: String) {
        recents = ConversionLogic.pushRecent(code, into: recents)
        defaults.set(recents, forKey: SettingsKeys.recents)
    }

    var chipCodes: [String] {
        ConversionLogic.chips(favourites: favourites, recents: recents)
            .filter { snapshot.rate(for: $0) != nil }
    }
}
