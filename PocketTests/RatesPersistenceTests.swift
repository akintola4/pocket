//
//  RatesPersistenceTests.swift
//  PocketTests
//
//  Parsing (API payload and Pocket's snapshot format), the on-disk cache, and
//  choosing between the bundled and cached rates. Each test writes to its own
//  temporary folder, never the App Group.
//

import Testing
import Foundation
@testable import Pocket

private func tempCacheURL() -> URL {
    FileManager.default.temporaryDirectory
        .appending(path: "PocketTests-\(UUID().uuidString)")
        .appending(path: RatesPersistence.cacheFileName)
}

private func snapshot(date: String, fetchedAt: TimeInterval, ngn: Double = 1500) -> RatesSnapshot {
    RatesSnapshot(
        base: "USD", date: date, fetchedAt: Date(timeIntervalSince1970: fetchedAt),
        source: "test", rates: ["USD": 1, "NGN": ngn]
    )
}

@Suite("Parsing the API payload")
struct APIParsingTests {
    private let payload = """
    {
      "date": "2026-11-05",
      "usd": {
        "usd": 1,
        "ngn": 1346.60127178,
        "ghs": 11.65113931,
        "kes": 129.93883277,
        "btc": 0.0000098,
        "xau": 0.00025,
        "zzz": -4,
        "bad": "1.0"
      }
    }
    """

    private let now = Date(timeIntervalSince1970: 1_793_866_440)

    @Test func readsDateBaseAndRates() throws {
        let parsed = try RatesParser.parseAPI(Data(payload.utf8), fetchedAt: now)
        #expect(parsed.base == "USD")
        #expect(parsed.date == "2026-11-05")
        #expect(parsed.fetchedAt == now)
        #expect(parsed.source == "fawazahmed0/currency-api")
        #expect(parsed.rates["NGN"] == 1346.60127178)
        #expect(parsed.rates["GHS"] == 11.65113931)
    }

    @Test func dropsCryptoMetalsAndJunk() throws {
        let parsed = try RatesParser.parseAPI(Data(payload.utf8), fetchedAt: now)
        #expect(Set(parsed.rates.keys) == ["USD", "NGN", "GHS", "KES"])
    }

    @Test func keepsEverythingValidWithoutAFilter() throws {
        let parsed = try RatesParser.parseAPI(Data(payload.utf8), fetchedAt: now, keeping: nil)
        #expect(parsed.rates["BTC"] == 0.0000098)
        #expect(parsed.rates["ZZZ"] == nil)
        #expect(parsed.rates["BAD"] == nil)
    }

    @Test func worksForAnyBase() throws {
        let eur = #"{"date":"2026-11-05","eur":{"ngn":1600,"usd":1.1}}"#
        let parsed = try RatesParser.parseAPI(Data(eur.utf8), fetchedAt: now)
        #expect(parsed.base == "EUR")
        #expect(parsed.rate(for: "EUR") == 1)
        #expect(ConversionLogic.rate(from: "USD", to: "NGN", in: parsed).map { ConversionLogic.rounded($0, places: 2) } == Decimal(string: "1454.55"))
    }

    @Test func rejectsMalformedPayloads() {
        #expect(throws: RatesError.invalidPayload) { try RatesParser.parseAPI(Data("not json".utf8), fetchedAt: now) }
        #expect(throws: RatesError.invalidPayload) { try RatesParser.parseAPI(Data(#"{"usd":{"ngn":1}}"#.utf8), fetchedAt: now) }
        #expect(throws: RatesError.invalidPayload) { try RatesParser.parseAPI(Data(#"{"date":"yesterday","usd":{"ngn":1}}"#.utf8), fetchedAt: now) }
        #expect(throws: RatesError.noRates) { try RatesParser.parseAPI(Data(#"{"date":"2026-11-05","usd":{}}"#.utf8), fetchedAt: now) }
    }
}

@Suite("Snapshot format and the bundled file")
struct SnapshotParsingTests {
    @Test func roundTripsThroughJSON() throws {
        let original = snapshot(date: "2026-11-05", fetchedAt: 1_793_866_440)
        let decoded = try RatesParser.parseSnapshot(RatesParser.encode(original))
        #expect(decoded == original)
    }

    @Test func rejectsEmptyOrBrokenSnapshots() {
        let empty = #"{"base":"USD","date":"2026-11-05","fetchedAt":"2026-11-05T08:14:00Z","source":"x","rates":{}}"#
        #expect(throws: RatesError.noRates) { try RatesParser.parseSnapshot(Data(empty.utf8)) }
        #expect(throws: RatesError.invalidPayload) { try RatesParser.parseSnapshot(Data("{}".utf8)) }
    }

    @Test func bundledSnapshotLoadsAndCoversAfrica() throws {
        let bundled = try #require(RatesPersistence.loadBundled())
        #expect(bundled.base == "USD")
        #expect(bundled.source == "fawazahmed0/currency-api")
        for code in ["NGN", "GHS", "KES", "ZAR", "EGP", "XOF", "XAF", "EUR", "GBP", "JPY", "BHD"] {
            #expect(bundled.rate(for: code) != nil, "missing \(code)")
        }
    }

    @Test func everyBundledRateHasCatalogMetadata() throws {
        let bundled = try #require(RatesPersistence.loadBundled())
        let unknown = bundled.rates.keys.filter { CurrencyCatalog.byCode[$0] == nil }
        #expect(unknown.isEmpty, "no catalog entry for \(unknown.sorted())")
    }
}

@Suite("Cache on disk")
struct CacheTests {
    @Test func missingCacheIsNil() {
        #expect(RatesPersistence.loadCache(at: tempCacheURL()) == nil)
    }

    @Test func writeThenRead() throws {
        let url = tempCacheURL()
        let original = snapshot(date: "2026-11-05", fetchedAt: 1_793_866_440)
        try RatesPersistence.saveCache(original, at: url)
        #expect(RatesPersistence.loadCache(at: url) == original)
    }

    @Test func overwriteReplaces() throws {
        let url = tempCacheURL()
        try RatesPersistence.saveCache(snapshot(date: "2026-11-04", fetchedAt: 1_793_780_000), at: url)
        let newer = snapshot(date: "2026-11-05", fetchedAt: 1_793_866_440, ngn: 1400)
        try RatesPersistence.saveCache(newer, at: url)
        #expect(RatesPersistence.loadCache(at: url) == newer)
    }

    @Test func corruptCacheIsIgnored() throws {
        let url = tempCacheURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ half a file".utf8).write(to: url)
        #expect(RatesPersistence.loadCache(at: url) == nil)
    }
}

@Suite("Bundled or cached")
struct ChoosingTests {
    private let older = snapshot(date: "2026-11-01", fetchedAt: 1_793_520_000)
    private let newer = snapshot(date: "2026-11-05", fetchedAt: 1_793_866_440)

    @Test func newerCacheWins() {
        #expect(RatesPersistence.choose(cached: newer, bundled: older) == LoadedRates(snapshot: newer, origin: .cached))
    }

    @Test func newerBundleWinsOverAnOldCache() {
        #expect(RatesPersistence.choose(cached: older, bundled: newer) == LoadedRates(snapshot: newer, origin: .bundled))
    }

    @Test func sameDayGoesToTheLaterDownload() {
        let morning = snapshot(date: "2026-11-05", fetchedAt: 1_793_840_000)
        #expect(RatesPersistence.choose(cached: morning, bundled: newer)?.origin == .bundled)
        #expect(RatesPersistence.choose(cached: newer, bundled: morning)?.origin == .cached)
    }

    @Test func tieGoesToTheCache() {
        #expect(RatesPersistence.choose(cached: newer, bundled: newer)?.origin == .cached)
    }

    @Test func eitherAloneIsUsed() {
        #expect(RatesPersistence.choose(cached: nil, bundled: older)?.origin == .bundled)
        #expect(RatesPersistence.choose(cached: older, bundled: nil)?.origin == .cached)
        #expect(RatesPersistence.choose(cached: nil, bundled: nil) == nil)
    }

    @Test func firstLaunchWithNoCacheUsesTheBundle() throws {
        let loaded = try #require(RatesPersistence.loadBest(cacheURL: tempCacheURL()))
        #expect(loaded.origin == .bundled)
    }

    @Test func aFreshDownloadOnDiskBeatsTheBundle() throws {
        let url = tempCacheURL()
        let bundled = try #require(RatesPersistence.loadBundled())
        let downloaded = RatesSnapshot(
            base: "USD", date: bundled.date, fetchedAt: bundled.fetchedAt.addingTimeInterval(60),
            source: bundled.source, rates: bundled.rates
        )
        try RatesPersistence.saveCache(downloaded, at: url)
        #expect(RatesPersistence.loadBest(cacheURL: url) == LoadedRates(snapshot: downloaded, origin: .cached))
    }
}
