//
//  PocketPersistence.swift
//  Pocket
//
//  Shared between the app AND the widget extension.
//
//  The single code path to the App Group: the rates cache on disk and the few
//  settings the widget also reads. The app's stores and the widget's timeline
//  provider both go through here, so they always see the same data.
//

import Foundation

nonisolated enum PocketShared {
    /// Comes from `POCKET_APP_GROUP` in Config/Pocket.xcconfig via each target's
    /// Info.plist, so changing the bundle prefix there is the only edit needed.
    static let appGroupID: String =
        (Bundle.main.object(forInfoDictionaryKey: "PocketAppGroup") as? String) ?? "group.foster.pocket"

    /// The App Group suite. On the Simulator this resolves without portal
    /// provisioning. Falls back to `.standard` only if the suite can't be opened.
    static let defaults: UserDefaults = UserDefaults(suiteName: appGroupID) ?? .standard

    /// The App Group container, or the app's own Application Support folder if
    /// the group isn't provisioned (the widget then can't see the cache, but the
    /// app still works).
    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? URL.applicationSupportDirectory
    }
}

/// UserDefaults keys (shared so the widget can read the ones it needs).
nonisolated enum SettingsKeys {
    static let defaultFrom = "defaultFrom"
    static let defaultTo = "defaultTo"
    static let decimals = "decimals"
    static let haptics = "haptics"
    static let favourites = "favourites"
    static let recents = "recents"
}

nonisolated enum PocketSettings {
    static let defaultFrom = "USD"
    static let defaultTo = "NGN"
    static let defaultFavourites = ["USD", "NGN", "GHS", "KES", "ZAR", "EUR", "GBP"]

    static func defaultPair(from defaults: UserDefaults = PocketShared.defaults) -> (from: String, to: String) {
        (defaults.string(forKey: SettingsKeys.defaultFrom) ?? defaultFrom,
         defaults.string(forKey: SettingsKeys.defaultTo) ?? defaultTo)
    }

    static func decimalPreference(from defaults: UserDefaults = PocketShared.defaults) -> DecimalPreference {
        DecimalPreference(rawValue: defaults.string(forKey: SettingsKeys.decimals) ?? "") ?? .auto
    }

    static func codes(forKey key: String, from defaults: UserDefaults = PocketShared.defaults) -> [String]? {
        defaults.stringArray(forKey: key)
    }
}

nonisolated enum RatesPersistence {
    static let cacheFileName = "rates-cache.json"
    static let bundledResource = "rates-snapshot"

    static func cacheURL(in directory: URL = PocketShared.containerURL) -> URL {
        directory.appending(path: cacheFileName)
    }

    static func loadCache(at url: URL = cacheURL()) -> RatesSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? RatesParser.parseSnapshot(data)
    }

    /// Atomic, so the widget never reads a half-written file.
    static func saveCache(_ snapshot: RatesSnapshot, at url: URL = cacheURL()) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try RatesParser.encode(snapshot).write(to: url, options: .atomic)
    }

    /// The starter snapshot shipped in the bundle, so the very first launch
    /// works in airplane mode.
    static func loadBundled(from bundle: Bundle = .main) -> RatesSnapshot? {
        guard let url = bundle.url(forResource: bundledResource, withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? RatesParser.parseSnapshot(data)
    }

    /// The newer of the two. A cache from last month loses to the snapshot in a
    /// freshly built app; ties go to the cache, which this device downloaded.
    static func choose(cached: RatesSnapshot?, bundled: RatesSnapshot?) -> LoadedRates? {
        switch (cached, bundled) {
        case let (cached?, bundled?):
            bundled.isNewer(than: cached)
                ? LoadedRates(snapshot: bundled, origin: .bundled)
                : LoadedRates(snapshot: cached, origin: .cached)
        case let (cached?, nil):
            LoadedRates(snapshot: cached, origin: .cached)
        case let (nil, bundled?):
            LoadedRates(snapshot: bundled, origin: .bundled)
        case (nil, nil):
            nil
        }
    }

    static func loadBest(cacheURL: URL = cacheURL(), bundle: Bundle = .main) -> LoadedRates? {
        choose(cached: loadCache(at: cacheURL), bundled: loadBundled(from: bundle))
    }
}
