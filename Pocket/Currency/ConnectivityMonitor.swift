//
//  ConnectivityMonitor.swift
//  Pocket
//
//  App target ONLY. Whether the device has a usable network path, from
//  NWPathMonitor. The monitor runs on the main queue so its updates land on the
//  main actor without hopping.
//

import Foundation
import Network

@Observable
final class ConnectivityMonitor {
    private(set) var isOnline: Bool

    @ObservationIgnored private let monitor = NWPathMonitor()

    init(forcedOffline: Bool = false) {
        isOnline = !forcedOffline
        guard !forcedOffline else { return }
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            MainActor.assumeIsolated {
                guard let self, self.isOnline != online else { return }
                self.isOnline = online
            }
        }
        monitor.start(queue: .main)
    }

    deinit {
        monitor.cancel()
    }
}
