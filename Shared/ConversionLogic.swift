//
//  ConversionLogic.swift
//  Pocket
//
//  Shared between the app AND the widget extension.
//
//  The pure part of the currency tool: cross rates, rounding, formatting,
//  parsing what was typed, and how old the rates are. No state, no I/O — every
//  input (locale, time zone, "now") is a parameter so the tests can pin it.
//

import Foundation

/// How many decimals to show in a result.
nonisolated enum DecimalPreference: String, CaseIterable, Identifiable, Sendable {
    /// Each currency's usual decimals: ¥ has none, BD has three.
    case auto
    case zero
    case two

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: "Auto"
        case .zero: "0"
        case .two: "2"
        }
    }
}

/// What the rates' age means right now. Rates are never described as current
/// unless the device is online and they were downloaded within `staleAfter`.
nonisolated enum RatesStatus: Equatable, Sendable {
    case upToDate
    case outOfDate
    case offline
}

nonisolated enum ConversionLogic {
    /// The source publishes once a day, so anything older than a day is behind.
    static let staleAfter: TimeInterval = 24 * 60 * 60

    // MARK: Converting

    /// Units of `to` that one unit of `from` buys, crossed through the
    /// snapshot's base: (base→to) / (base→from).
    static func rate(from: String, to: String, in snapshot: RatesSnapshot) -> Decimal? {
        if from == to { return 1 }
        guard let fromRate = snapshot.rate(for: from), let toRate = snapshot.rate(for: to), fromRate > 0 else {
            return nil
        }
        return decimal(toRate) / decimal(fromRate)
    }

    static func convert(_ amount: Decimal, from: String, to: String, in snapshot: RatesSnapshot) -> Decimal? {
        rate(from: from, to: to, in: snapshot).map { amount * $0 }
    }

    /// Goes through the shortest string form so 1346.6 stays 1346.6 instead of
    /// picking up binary noise like 1346.5999999999999.
    static func decimal(_ value: Double) -> Decimal {
        Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX")) ?? Decimal(value)
    }

    // MARK: Rounding

    static func decimals(for code: String, preference: DecimalPreference) -> Int {
        switch preference {
        case .auto: CurrencyCatalog.info(for: code).decimals
        case .zero: 0
        case .two: 2
        }
    }

    /// Half-up, the way a till rounds.
    static func rounded(_ value: Decimal, places: Int) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, places, .plain)
        return result
    }

    static func rounded(_ value: Decimal, code: String, preference: DecimalPreference = .auto) -> Decimal {
        rounded(value, places: decimals(for: code, preference: preference))
    }

    // MARK: Formatting

    /// "₦134,660.13", "¥1,235", "BD 1.235" — the currency's own symbol and
    /// decimals, with grouping, decimal mark and symbol position from `locale`.
    static func format(
        _ value: Decimal,
        code: String,
        preference: DecimalPreference = .auto,
        locale: Locale = .current
    ) -> String {
        let places = decimals(for: code, preference: preference)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = code
        formatter.currencySymbol = CurrencyCatalog.info(for: code).symbol
        formatter.minimumFractionDigits = places
        formatter.maximumFractionDigits = places
        formatter.roundingMode = .halfUp
        let value = rounded(value, places: places) as NSDecimalNumber
        return formatter.string(from: value) ?? "\(code) \(value)"
    }

    /// A rate to six significant figures, so tiny rates keep their digits:
    /// "1,346.60", "0.000742611".
    static func formatRate(_ rate: Decimal, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.usesSignificantDigits = true
        formatter.maximumSignificantDigits = 6
        formatter.minimumSignificantDigits = 1
        return formatter.string(from: rate as NSDecimalNumber) ?? "\(rate)"
    }

    /// "1 USD = 1,346.6 NGN"
    static func rateLine(from: String, to: String, rate: Decimal, locale: Locale = .current) -> String {
        "1 \(from) = \(formatRate(rate, locale: locale)) \(to)"
    }

    // MARK: Parsing input

    /// What the user typed, as a number. Accepts the locale's decimal mark and
    /// ignores its grouping mark. Returns nil for empty or malformed input.
    static func parseAmount(_ text: String, locale: Locale = .current) -> Decimal? {
        let decimalMark = locale.decimalSeparator ?? "."
        let groupMark = locale.groupingSeparator ?? ","
        var cleaned = text.trimmingCharacters(in: .whitespaces)
        if groupMark != decimalMark {
            cleaned = cleaned.replacingOccurrences(of: groupMark, with: "")
        }
        cleaned = cleaned.replacingOccurrences(of: decimalMark, with: ".")
        guard !cleaned.isEmpty,
              cleaned.allSatisfy({ ($0.isASCII && $0.isNumber) || $0 == "." }),
              cleaned.filter({ $0 == "." }).count <= 1,
              cleaned.contains(where: \.isNumber)
        else { return nil }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// What the amount field keeps as you type: digits and one decimal mark,
    /// at most `maxIntegerDigits` whole digits and `maxFractionDigits` after the
    /// mark (none at all for ¥). Leading zeros go; ".5" becomes "0.5".
    static func sanitizeAmount(
        _ text: String,
        maxFractionDigits: Int,
        maxIntegerDigits: Int = 12,
        locale: Locale = .current
    ) -> String {
        let mark = Character(locale.decimalSeparator ?? ".")
        var whole = ""
        var fraction = ""
        var seenMark = false
        for character in text {
            if character.isASCII, character.isNumber {
                if seenMark {
                    if fraction.count < maxFractionDigits { fraction.append(character) }
                } else if whole.count < maxIntegerDigits {
                    whole.append(character)
                }
            } else if character == mark, !seenMark, maxFractionDigits > 0 {
                seenMark = true
            }
        }
        while whole.count > 1, whole.first == "0" { whole.removeFirst() }
        if seenMark, whole.isEmpty { whole = "0" }
        return seenMark ? whole + String(mark) + fraction : whole
    }

    // MARK: Age

    static func isStale(fetchedAt: Date, now: Date = Date()) -> Bool {
        now.timeIntervalSince(fetchedAt) > staleAfter
    }

    static func status(fetchedAt: Date, isOnline: Bool, now: Date = Date()) -> RatesStatus {
        if !isOnline { return .offline }
        return isStale(fetchedAt: fetchedAt, now: now) ? .outOfDate : .upToDate
    }

    /// "5 Nov, 09:14" (en_GB) or "Nov 5, 9:14 AM" (en_US). The year appears only
    /// when it isn't the current one.
    static func timestamp(
        _ date: Date,
        now: Date = Date(),
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)

        let day = DateFormatter()
        day.locale = locale
        day.timeZone = timeZone
        day.setLocalizedDateFormatFromTemplate(sameYear ? "dMMM" : "dMMMy")

        let time = DateFormatter()
        time.locale = locale
        time.timeZone = timeZone
        time.setLocalizedDateFormatFromTemplate("jmm")

        return "\(day.string(from: date)), \(time.string(from: date))"
    }

    /// The words after the timestamp, in order: where the rates came from, then
    /// whether they can be trusted as current.
    static func statusParts(origin: RatesOrigin, status: RatesStatus) -> [String] {
        var parts: [String] = []
        if origin == .bundled { parts.append("built-in") }
        switch status {
        case .offline: parts.append("offline")
        case .outOfDate: parts.append("out of date")
        case .upToDate: break
        }
        return parts
    }

    /// "Rates from 3 Nov, 09:14 · offline"
    static func ratesLabel(
        fetchedAt: Date,
        origin: RatesOrigin,
        status: RatesStatus,
        now: Date = Date(),
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        let stamp = "Rates from \(timestamp(fetchedAt, now: now, locale: locale, timeZone: timeZone))"
        return ([stamp] + statusParts(origin: origin, status: status)).joined(separator: " · ")
    }

    // MARK: Quick chips

    /// Favourites first, then recents, without repeats, capped at `limit`.
    static func chips(favourites: [String], recents: [String], limit: Int = 10) -> [String] {
        var seen = Set<String>()
        return (favourites + recents).filter { seen.insert($0).inserted }.prefix(limit).map { $0 }
    }

    /// Moves `code` to the front of the recents, keeping at most `limit`.
    static func pushRecent(_ code: String, into recents: [String], limit: Int = 6) -> [String] {
        Array(([code] + recents.filter { $0 != code }).prefix(limit))
    }
}
