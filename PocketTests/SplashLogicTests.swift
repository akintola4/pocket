//
//  SplashLogicTests.swift
//  PocketTests
//
//  The opening animation's timeline: coins in the right order, the pocket
//  back at rest before the dive, and the app at full size when it's over.
//

import Testing
import SwiftUI
@testable import Pocket

struct SplashLogicTests {
    @Test func `the mark matches the launch screen image`() {
        // LaunchPocket.svg is 120 × 120.923 pt.
        #expect(SplashLogic.markSize.width == 120)
        #expect(abs(SplashLogic.markSize.height - 120.923) < 0.001)
    }

    @Test func `slow motion stretches every phase`() {
        let slow = SplashLogic.Timeline().slowed(by: 4)
        #expect(abs(slow.total - SplashLogic.Timeline().total * 4) < 1e-9)
    }

    @Test func `five coins, home currency last, no repeats`() {
        for home in ["NGN", "USD", "EUR", "KES"] {
            let codes = SplashLogic.coinCodes(home: home)
            #expect(codes.count == 5)
            #expect(codes.last == home)
            #expect(Set(codes).count == codes.count)
        }
        #expect(SplashLogic.coinX.count == SplashLogic.Timeline().coins)
        #expect(SplashLogic.coinTilt.count == SplashLogic.Timeline().coins)
    }

    @Test func `the animation is about two seconds, under iFood's three`() {
        let t = SplashLogic.Timeline()
        #expect(t.lastLanding < t.diveStarts)
        #expect(t.total > 1.5 && t.total < 3)
    }

    @Test func `coins land in order and are gone once inside`() {
        let t = SplashLogic.Timeline()
        for index in 0..<t.coins {
            #expect(abs(SplashLogic.coinY(index, at: t.landing(ofCoin: index), in: t) - SplashLogic.coinRestY) < 0.001)
            #expect(SplashLogic.coinOpacity(index, at: t.landing(ofCoin: index) + 0.01, in: t) == 0)
            #expect(SplashLogic.coinOpacity(index, at: t.start(ofCoin: index) - 0.01, in: t) == 0)
        }
    }

    @Test func `the pocket is back at rest when the dive starts`() {
        let t = SplashLogic.Timeline()
        let rest = SplashLogic.squash(at: t.diveStarts, in: t)
        #expect(rest.x == 1 && rest.y == 1)
        // The home coin squashes hardest.
        let home = SplashLogic.squash(at: t.lastLanding + t.squash, in: t)
        let first = SplashLogic.squash(at: t.landing(ofCoin: 0) + t.squash, in: t)
        #expect(home.y < first.y)
    }

    @Test func `dive dips first, then pushes past and lands the app at full size`() {
        let t = SplashLogic.Timeline()
        #expect(SplashLogic.diveScale(at: t.diveStarts + t.dive * 0.1, in: t) < 1)
        #expect(abs(SplashLogic.diveScale(at: t.total, in: t) - 6) < 0.001)
        #expect(SplashLogic.diveProgress(at: t.diveStarts, in: t) == 0)
        #expect(SplashLogic.appScale(at: t.diveStarts, in: t) < 1)
        #expect(abs(SplashLogic.appScale(at: t.total, in: t) - 1) < 0.001)
    }

    @Test func `the credit fades in with the coins and out with the dive`() {
        let t = SplashLogic.Timeline()
        #expect(SplashLogic.creditOpacity(at: 0, in: t) == 0)
        #expect(SplashLogic.creditOpacity(at: t.lastLanding, in: t) == 1)
        #expect(abs(SplashLogic.creditOpacity(at: t.total, in: t)) < 0.001)
    }
}
