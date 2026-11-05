//
//  ConversionLogicTests.swift
//  PocketTests
//
//  The pure conversion logic in Shared/ConversionLogic.swift: cross rates,
//  rounding per currency, formatting, typed input, and how the rates' age is
//  labelled. Locale, time zone and "now" are pinned so these pass anywhere.
//

import Testing
import Foundation
@testable import Pocket

private let gb = Locale(identifier: "en_GB")
private let lagos = TimeZone(identifier: "Africa/Lagos")!

/// 5 Nov 2026, 09:14 in Lagos (08:14 UTC).
private let fetched = Date(timeIntervalSince1970: 1_793_866_440)

private func snapshot(_ rates: [String: Double], base: String = "USD") -> RatesSnapshot {
    RatesSnapshot(base: base, date: "2026-11-05", fetchedAt: fetched, source: "test", rates: rates)
}

private let table = snapshot(["NGN": 1500, "GHS": 12, "EUR": 0.8, "JPY": 150, "BHD": 0.376])

@Suite("Conversion through the base")
struct ConversionTests {
    @Test func baseToCurrencyUsesTheRateDirectly() {
        #expect(ConversionLogic.convert(100, from: "USD", to: "NGN", in: table) == 150_000)
    }

    @Test func currencyToBaseDivides() throws {
        // 1/1500 repeats, so the raw product is 0.999…; rounding to USD's
        // decimals is what the screen shows.
        let dollars = try #require(ConversionLogic.convert(1500, from: "NGN", to: "USD", in: table))
        #expect(ConversionLogic.rounded(dollars, code: "USD") == 1)
        #expect(ConversionLogic.convert(3000, from: "NGN", to: "USD", in: table).map { ConversionLogic.rounded($0, code: "USD") } == 2)
    }

    @Test func crossRateGoesThroughTheBase() {
        // 1 GHS = 1500 / 12 = 125 NGN
        #expect(ConversionLogic.rate(from: "GHS", to: "NGN", in: table) == 125)
        #expect(ConversionLogic.convert(2, from: "GHS", to: "NGN", in: table) == 250)
    }

    @Test func crossRateBetweenTwoNonBaseCurrencies() {
        // 1 EUR = 150 / 0.8 = 187.5 JPY
        #expect(ConversionLogic.rate(from: "EUR", to: "JPY", in: table) == Decimal(string: "187.5"))
    }

    @Test func sameCurrencyIsOne() {
        #expect(ConversionLogic.rate(from: "NGN", to: "NGN", in: table) == 1)
    }

    @Test func unknownCurrencyHasNoRate() {
        #expect(ConversionLogic.rate(from: "USD", to: "XYZ", in: table) == nil)
        #expect(ConversionLogic.convert(1, from: "XYZ", to: "NGN", in: table) == nil)
    }

    @Test func doubleNoiseDoesNotLeakIntoDecimals() {
        #expect(ConversionLogic.decimal(1346.6) == Decimal(string: "1346.6"))
    }

    @Test func roundTripComesBack() throws {
        let there = try #require(ConversionLogic.convert(100, from: "USD", to: "GHS", in: table))
        let back = try #require(ConversionLogic.convert(there, from: "GHS", to: "USD", in: table))
        #expect(ConversionLogic.rounded(back, places: 2) == 100)
    }
}

@Suite("Rounding per currency")
struct RoundingTests {
    @Test func autoUsesEachCurrencysDecimals() {
        #expect(ConversionLogic.decimals(for: "NGN", preference: .auto) == 2)
        #expect(ConversionLogic.decimals(for: "JPY", preference: .auto) == 0)
        #expect(ConversionLogic.decimals(for: "BHD", preference: .auto) == 3)
        #expect(ConversionLogic.decimals(for: "XOF", preference: .auto) == 0)
    }

    @Test func preferenceOverridesTheCurrency() {
        #expect(ConversionLogic.decimals(for: "BHD", preference: .zero) == 0)
        #expect(ConversionLogic.decimals(for: "JPY", preference: .two) == 2)
    }

    @Test func roundsHalfUp() {
        #expect(ConversionLogic.rounded(Decimal(string: "2.5")!, code: "JPY") == 3)
        #expect(ConversionLogic.rounded(Decimal(string: "1.005")!, code: "NGN") == Decimal(string: "1.01"))
        #expect(ConversionLogic.rounded(Decimal(string: "1.2345")!, code: "BHD") == Decimal(string: "1.235"))
        #expect(ConversionLogic.rounded(Decimal(string: "1.2344")!, code: "BHD") == Decimal(string: "1.234"))
    }
}

@Suite("Formatting")
struct FormattingTests {
    private let nbsp = "\u{00A0}"

    @Test func naira() {
        #expect(ConversionLogic.format(Decimal(string: "134660.125")!, code: "NGN", locale: gb) == "₦134,660.13")
    }

    @Test func cedi() {
        #expect(ConversionLogic.format(Decimal(string: "1234.5")!, code: "GHS", locale: gb) == "GH₵1,234.50")
    }

    @Test func yenHasNoDecimals() {
        #expect(ConversionLogic.format(Decimal(string: "1234.5")!, code: "JPY", locale: gb) == "¥1,235")
    }

    @Test func bahrainiDinarHasThree() {
        #expect(ConversionLogic.format(Decimal(string: "1234.5")!, code: "BHD", locale: gb) == "BD\(nbsp)1,234.500")
    }

    @Test func letterSymbolsGetASpace() {
        #expect(ConversionLogic.format(1000, code: "KES", locale: gb) == "KSh\(nbsp)1,000.00")
        #expect(ConversionLogic.format(1000, code: "ZAR", locale: gb) == "R\(nbsp)1,000.00")
    }

    @Test func zeroPreferenceDropsDecimals() {
        #expect(ConversionLogic.format(Decimal(string: "1234.5")!, code: "NGN", preference: .zero, locale: gb) == "₦1,235")
    }

    @Test func localeDecidesSeparatorsAndPosition() {
        let french = ConversionLogic.format(Decimal(string: "1234.5")!, code: "NGN", locale: Locale(identifier: "fr_FR"))
        #expect(french == "1\u{202F}234,50\(nbsp)₦")
    }

    @Test func rateLineKeepsSmallRatesReadable() {
        #expect(ConversionLogic.rateLine(from: "USD", to: "NGN", rate: Decimal(string: "1346.60127")!, locale: gb) == "1 USD = 1,346.6 NGN")
        #expect(ConversionLogic.formatRate(Decimal(string: "0.000742611")!, locale: gb) == "0.000742611")
    }
}

@Suite("Typed amounts")
struct AmountInputTests {
    @Test func parsesPlainAndDecimal() {
        #expect(ConversionLogic.parseAmount("100", locale: gb) == 100)
        #expect(ConversionLogic.parseAmount("12.5", locale: gb) == Decimal(string: "12.5"))
        #expect(ConversionLogic.parseAmount("1,250.75", locale: gb) == Decimal(string: "1250.75"))
    }

    @Test func usesTheLocalesDecimalMark() {
        #expect(ConversionLogic.parseAmount("12,5", locale: Locale(identifier: "fr_FR")) == Decimal(string: "12.5"))
    }

    @Test func rejectsEmptyAndJunk() {
        #expect(ConversionLogic.parseAmount("", locale: gb) == nil)
        #expect(ConversionLogic.parseAmount(".", locale: gb) == nil)
        #expect(ConversionLogic.parseAmount("1.2.3", locale: gb) == nil)
        #expect(ConversionLogic.parseAmount("abc", locale: gb) == nil)
    }

    @Test func sanitizeKeepsOneMarkAndCapsDecimals() {
        #expect(ConversionLogic.sanitizeAmount("12.345", maxFractionDigits: 2, locale: gb) == "12.34")
        #expect(ConversionLogic.sanitizeAmount("1.2.3", maxFractionDigits: 2, locale: gb) == "1.23")
        #expect(ConversionLogic.sanitizeAmount(".5", maxFractionDigits: 2, locale: gb) == "0.5")
        #expect(ConversionLogic.sanitizeAmount("007", maxFractionDigits: 2, locale: gb) == "7")
    }

    @Test func sanitizeDropsTheMarkForZeroDecimalCurrencies() {
        #expect(ConversionLogic.sanitizeAmount("100.5", maxFractionDigits: 0, locale: gb) == "1005")
    }

    @Test func sanitizeCapsWholeDigits() {
        #expect(ConversionLogic.sanitizeAmount("12345678901234", maxFractionDigits: 2, locale: gb) == "123456789012")
    }
}

@Suite("Age and staleness")
struct AgeTests {
    private let hour: TimeInterval = 60 * 60

    @Test func freshWhenOnlineAndUnderADay() {
        #expect(ConversionLogic.status(fetchedAt: fetched, isOnline: true, now: fetched + 23 * hour) == .upToDate)
    }

    @Test func outOfDateAfterADayEvenOnline() {
        #expect(ConversionLogic.status(fetchedAt: fetched, isOnline: true, now: fetched + 25 * hour) == .outOfDate)
        #expect(ConversionLogic.isStale(fetchedAt: fetched, now: fetched + 25 * hour))
    }

    @Test func offlineIsNeverUpToDate() {
        #expect(ConversionLogic.status(fetchedAt: fetched, isOnline: false, now: fetched + hour) == .offline)
    }

    @Test func labelMatchesTheDesign() {
        let label = ConversionLogic.ratesLabel(
            fetchedAt: fetched, origin: .cached, status: .offline,
            now: fetched + hour, locale: gb, timeZone: lagos
        )
        #expect(label == "Rates from 5 Nov, 09:14 · offline")
    }

    @Test func freshCachedRatesCarryNoWarning() {
        let label = ConversionLogic.ratesLabel(
            fetchedAt: fetched, origin: .cached, status: .upToDate,
            now: fetched + hour, locale: gb, timeZone: lagos
        )
        #expect(label == "Rates from 5 Nov, 09:14")
    }

    @Test func bundledRatesSayTheyAreBuiltIn() {
        let label = ConversionLogic.ratesLabel(
            fetchedAt: fetched, origin: .bundled, status: .offline,
            now: fetched + hour, locale: gb, timeZone: lagos
        )
        #expect(label == "Rates from 5 Nov, 09:14 · built-in · offline")
    }

    @Test func staleRatesSayOutOfDate() {
        let label = ConversionLogic.ratesLabel(
            fetchedAt: fetched, origin: .cached, status: .outOfDate,
            now: fetched + 48 * hour, locale: gb, timeZone: lagos
        )
        #expect(label == "Rates from 5 Nov, 09:14 · out of date")
    }

    @Test func showsTheYearOnlyWhenItDiffers() {
        let nextYear = fetched + 365 * 24 * hour
        #expect(ConversionLogic.timestamp(fetched, now: nextYear, locale: gb, timeZone: lagos) == "5 Nov 2026, 09:14")
    }
}

@Suite("Quick chips")
struct ChipTests {
    @Test func favouritesThenRecentsWithoutRepeats() {
        let chips = ConversionLogic.chips(favourites: ["NGN", "GHS"], recents: ["KES", "NGN", "ZAR"])
        #expect(chips == ["NGN", "GHS", "KES", "ZAR"])
    }

    @Test func chipsAreCapped() {
        let chips = ConversionLogic.chips(favourites: ["A", "B", "C"], recents: ["D", "E"], limit: 4)
        #expect(chips == ["A", "B", "C", "D"])
    }

    @Test func recentsMoveToFrontAndCap() {
        let recents = ConversionLogic.pushRecent("GHS", into: ["NGN", "GHS", "KES"], limit: 3)
        #expect(recents == ["GHS", "NGN", "KES"])
        #expect(ConversionLogic.pushRecent("ZAR", into: recents, limit: 3) == ["ZAR", "GHS", "NGN"])
    }
}

@Suite("Currency catalog")
struct CatalogTests {
    @Test func africanCurrenciesHaveTheirOwnSymbols() {
        #expect(CurrencyCatalog.info(for: "NGN").symbol == "₦")
        #expect(CurrencyCatalog.info(for: "GHS").symbol == "GH₵")
        #expect(CurrencyCatalog.info(for: "KES").symbol == "KSh")
        #expect(CurrencyCatalog.info(for: "ZAR").symbol == "R")
        #expect(CurrencyCatalog.info(for: "EGP").symbol == "E£")
    }

    @Test func codesAreUnique() {
        #expect(CurrencyCatalog.byCode.count == CurrencyCatalog.all.count)
    }

    @Test func noTwoDollarsLookAlike() {
        let dollars = CurrencyCatalog.all.filter { $0.symbol == "$" }
        #expect(dollars.map(\.code) == ["USD"])
    }
}
