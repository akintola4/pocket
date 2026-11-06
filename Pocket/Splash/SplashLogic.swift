//
//  SplashLogic.swift
//  Pocket
//
//  Sizes, timings and motion curves for the opening animation, as plain
//  functions of time so they can be tuned in one place and tested.
//
//  The story: coins from around the world drop into the pocket one after
//  another, each giving it a small bump. Your home currency lands last with a
//  big squash, then the camera dives through the pocket into the app.
//

import SwiftUI

nonisolated enum SplashLogic {
    /// The pocket's size on screen. Must match LaunchPocket.svg (120 × 120.923)
    /// or the hand-off from the launch screen jumps.
    static let markSize = CGSize(width: 120, height: 120 * 524.0 / 520)

    static let coinDiameter: CGFloat = 40

    /// Coin heights, measured from the pocket's centre. Each starts well above
    /// the flap and finishes hidden inside the pocket.
    static let coinStartY: CGFloat = -260
    static let coinRestY: CGFloat = 10

    /// Where each coin falls from and how it's tilted, so they don't drop in a
    /// single file. The last coin, your home currency, falls straight and flat.
    static let coinX: [CGFloat] = [-18, 16, -9, 20, 0]
    static let coinTilt: [Double] = [-14, 10, -6, 12, 0]

    /// The coins to drop: four well-known currencies, then the home one last.
    static func coinCodes(home: String) -> [String] {
        let pool = ["USD", "EUR", "GBP", "JPY", "GHS", "ZAR"]
        return Array(pool.filter { $0 != home }.prefix(coinX.count - 1)) + [home]
    }

    /// Phase lengths in seconds, at normal speed.
    struct Timeline: Equatable {
        var coins = 5
        /// Gap between one coin starting to fall and the next.
        var interval = 0.2
        var fall = 0.32
        /// How long each squash takes to reach its deepest point.
        var squash = 0.06
        /// The spring back after a squash.
        var settle = 0.3
        /// The dive into the app.
        var dive = 0.45

        /// The same timeline stretched by `factor`, for watching it in slow motion.
        func slowed(by factor: Double) -> Timeline {
            Timeline(coins: coins, interval: interval * factor, fall: fall * factor, squash: squash * factor,
                     settle: settle * factor, dive: dive * factor)
        }

        func start(ofCoin index: Int) -> Double { Double(index) * interval }
        /// When coin `index` hits the pocket (and its haptic fires).
        func landing(ofCoin index: Int) -> Double { start(ofCoin: index) + fall }
        var lastLanding: Double { landing(ofCoin: coins - 1) }
        /// When the pocket has settled and the dive begins.
        var diveStarts: Double { lastLanding + squash + settle }
        var total: Double { diveStarts + dive }
    }

    // MARK: - Motion at time t

    /// A falling coin's height: ease-in, because a falling thing speeds up.
    static func coinY(_ index: Int, at t: Double, in timeline: Timeline) -> CGFloat {
        let p = progress(t - timeline.start(ofCoin: index), over: timeline.fall)
        return coinStartY + (coinRestY - coinStartY) * CGFloat(p * p)
    }

    /// Fades in over the first quarter of the fall; gone once it's inside.
    static func coinOpacity(_ index: Int, at t: Double, in timeline: Timeline) -> Double {
        let local = t - timeline.start(ofCoin: index)
        guard local >= 0, local < timeline.fall else { return 0 }
        return progress(local, over: timeline.fall * 0.25)
    }

    /// How hard each landing squashes the pocket. The early coins give it a
    /// small bump; the home coin squashes it properly.
    static func squashAmount(forCoin index: Int, of count: Int) -> Double {
        index == count - 1 ? 0.12 : 0.045
    }

    /// The pocket's scale at `t`, anchored at its bottom edge: wider and
    /// shorter on each landing, then a damped spring back to 1.
    static func squash(at t: Double, in timeline: Timeline) -> (x: CGFloat, y: CGFloat) {
        var amount = 0.0
        for index in 0..<timeline.coins {
            let local = t - timeline.landing(ofCoin: index)
            guard local >= 0 else { continue }
            let peak = squashAmount(forCoin: index, of: timeline.coins)
            if local < timeline.squash {
                let p = local / timeline.squash
                amount += peak * (1 - (1 - p) * (1 - p))          // ease-out into the squash
            } else if local < timeline.squash + timeline.settle {
                let u = (local - timeline.squash) / timeline.settle
                amount += peak * exp(-5 * u) * cos(.pi * 3 * u)   // one small overshoot, then rest
            }
        }
        return (CGFloat(1 + amount), CGFloat(1 - amount * 1.17))
    }

    /// 0 → 1 across the dive, on a fast-start curve: it moves straight away,
    /// then eases in to rest. Drives the green clearing, the blur and the app.
    static func diveProgress(at t: Double, in timeline: Timeline) -> Double {
        diveCurve.value(at: progress(t - timeline.diveStarts, over: timeline.dive))
    }

    /// The pocket during the dive: a small dip first (the Twitter launch does
    /// the same, so the push reads as a push), then it grows past you.
    static func diveScale(at t: Double, in timeline: Timeline) -> CGFloat {
        let local = progress(t - timeline.diveStarts, over: timeline.dive)
        let dip = 0.15
        if local < dip {
            return 1 - 0.06 * CGFloat(sin(local / dip * .pi / 2))
        }
        let p = diveCurve.value(at: (local - dip) / (1 - dip))
        return 0.94 + (6 - 0.94) * CGFloat(p)
    }

    /// The app behind the splash starts a touch small and settles to full size
    /// as the green clears, on the same clock, so the two read as one move.
    static func appScale(at t: Double, in timeline: Timeline) -> CGFloat {
        0.94 + 0.06 * CGFloat(diveProgress(at: t, in: timeline))
    }

    /// The "Made by" credit: fades in with the first coin, out with the dive.
    static func creditOpacity(at t: Double, in timeline: Timeline) -> Double {
        min(progress(t, over: timeline.fall * 0.75), 1 - diveProgress(at: t, in: timeline))
    }

    static let diveCurve = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.32, y: 0.72),
                                            endControlPoint: UnitPoint(x: 0, y: 1))

    private static func progress(_ elapsed: Double, over duration: Double) -> Double {
        min(max(elapsed / duration, 0), 1)
    }
}
