//
//  AppSettings.swift
//  Pocket
//
//  App target ONLY. Reactive wrapper over the shared App Group store for user
//  settings. The widget reads the ones it needs (pair, decimals) via PocketSettings.
//

import SwiftUI
import WidgetKit

@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var defaultFrom: String { didSet { defaults.set(defaultFrom, forKey: SettingsKeys.defaultFrom); reloadWidgets() } }
    var defaultTo: String { didSet { defaults.set(defaultTo, forKey: SettingsKeys.defaultTo); reloadWidgets() } }
    var decimals: DecimalPreference { didSet { defaults.set(decimals.rawValue, forKey: SettingsKeys.decimals); reloadWidgets() } }
    var haptics: Bool { didSet { defaults.set(haptics, forKey: SettingsKeys.haptics) } }

    init(defaults: UserDefaults = PocketShared.defaults) {
        self.defaults = defaults
        let pair = PocketSettings.defaultPair(from: defaults)
        defaultFrom = pair.from
        defaultTo = pair.to
        decimals = PocketSettings.decimalPreference(from: defaults)
        haptics = defaults.object(forKey: SettingsKeys.haptics) as? Bool ?? true
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
