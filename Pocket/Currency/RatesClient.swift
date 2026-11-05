//
//  RatesClient.swift
//  Pocket
//
//  App target ONLY. Downloads today's rates. Free, keyless, CC0:
//  https://github.com/fawazahmed0/exchange-api
//
//  jsDelivr first, then the project's Cloudflare mirror. Short timeouts and no
//  waiting for connectivity: if the network isn't there, fail fast and let the
//  store keep what it has.
//

import Foundation

struct RatesClient {
    static let endpoints = [
        URL(string: "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.min.json")!,
        URL(string: "https://latest.currency-api.pages.dev/v1/currencies/usd.min.json")!,
    ]

    /// Set by the `-PocketOffline` launch argument: behave exactly as if the
    /// device had no network.
    var isOffline = false

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    func fetchLatest() async throws -> RatesSnapshot {
        if isOffline { throw RatesError.offline }

        var lastError: Error = RatesError.invalidPayload
        for url in Self.endpoints {
            do {
                let (data, response) = try await Self.session.data(from: url)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard status == 200 else { throw RatesError.badStatus(status) }
                return try RatesParser.parseAPI(data, fetchedAt: Date())
            } catch {
                lastError = error
            }
        }
        throw lastError
    }
}
