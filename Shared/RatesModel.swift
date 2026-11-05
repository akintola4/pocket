//
//  RatesModel.swift
//  Pocket
//
//  Shared between the app AND the widget extension.
//
//  The data Pocket converts with, and the two ways it arrives: the API's payload
//  (fawazahmed0/currency-api) and Pocket's own snapshot format, which is what the
//  bundled starter file and the on-disk cache both use. Everything here is
//  observation-free and side-effect-free so the widget can use it directly.
//

import Foundation

// MARK: - Currency

nonisolated struct CurrencyInfo: Identifiable, Hashable, Sendable {
    let code: String
    let name: String
    let symbol: String
    let decimals: Int
    let flag: String

    var id: String { code }

    /// The name in the reader's language when the system has one, else English.
    var localizedName: String {
        Locale.current.localizedString(forCurrencyCode: code) ?? name
    }
}

// MARK: - Snapshot

/// One day's table of rates. `rates[code]` is how many units of `code` one unit
/// of `base` buys. The base itself may be missing from `rates`; it is always 1.
nonisolated struct RatesSnapshot: Codable, Equatable, Sendable {
    let base: String
    /// The day the source published these rates, `yyyy-MM-dd`.
    let date: String
    /// When these rates were downloaded. This is the time Pocket shows as the
    /// rates' age, because it is the last moment they were known to be current.
    let fetchedAt: Date
    let source: String
    let rates: [String: Double]

    func rate(for code: String) -> Double? {
        code == base ? 1 : rates[code]
    }

    /// True if `self` should win over `other`: newer publish day first, then the
    /// later download.
    func isNewer(than other: RatesSnapshot) -> Bool {
        if date != other.date { return date > other.date }
        return fetchedAt > other.fetchedAt
    }
}

/// Where the rates on screen came from.
nonisolated enum RatesOrigin: String, Codable, Sendable {
    /// The starter file shipped inside the app.
    case bundled
    /// Downloaded on this device and kept in the App Group container.
    case cached
}

nonisolated struct LoadedRates: Equatable, Sendable {
    let snapshot: RatesSnapshot
    let origin: RatesOrigin
}

nonisolated enum RatesError: Error, Equatable {
    case invalidPayload
    case noRates
    case badStatus(Int)
    case offline
}

// MARK: - Parsing

nonisolated enum RatesParser {
    static let sourceName = "fawazahmed0/currency-api"

    /// Parses the API's `currencies/{base}.json` payload:
    /// `{ "date": "2026-11-05", "usd": { "ngn": 1346.6, ... } }`.
    ///
    /// Codes are upper-cased and filtered to `keeping` (the catalog by default),
    /// which drops the crypto and metals the API also lists. Non-finite or
    /// non-positive rates are dropped rather than trusted.
    static func parseAPI(
        _ data: Data,
        fetchedAt: Date,
        keeping codes: Set<String>? = Set(CurrencyCatalog.byCode.keys)
    ) throws -> RatesSnapshot {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let date = object["date"] as? String,
              date.wholeMatch(of: /\d{4}-\d{2}-\d{2}/) != nil,
              let (baseKey, table) = object.first(where: { $0.key != "date" && $0.value is [String: Any] }),
              let rawRates = table as? [String: Any]
        else { throw RatesError.invalidPayload }

        let base = baseKey.uppercased()
        var rates: [String: Double] = [:]
        for (key, value) in rawRates {
            let code = key.uppercased()
            guard let number = value as? NSNumber else { continue }
            let rate = number.doubleValue
            guard rate.isFinite, rate > 0 else { continue }
            if let codes, !codes.contains(code) { continue }
            rates[code] = rate
        }
        rates[base] = 1
        guard rates.count > 1 else { throw RatesError.noRates }

        return RatesSnapshot(base: base, date: date, fetchedAt: fetchedAt, source: sourceName, rates: rates)
    }

    /// Parses Pocket's own snapshot format (bundled starter file and cache).
    static func parseSnapshot(_ data: Data) throws -> RatesSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(RatesSnapshot.self, from: data) else {
            throw RatesError.invalidPayload
        }
        guard !snapshot.rates.isEmpty, snapshot.rates.values.allSatisfy({ $0.isFinite && $0 > 0 }) else {
            throw RatesError.noRates
        }
        return snapshot
    }

    static func encode(_ snapshot: RatesSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }
}
