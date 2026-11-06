//
//  SplashOverlay.swift
//  Pocket
//
//  The opening animation, played once per cold launch on top of the app. It
//  starts on the launch screen's exact picture (green, pocket centred), so iOS
//  hands over without a flash. The app underneath is already live, so the
//  dive at the end lands on the real converter. A tap skips straight to it.
//
//  Every position comes from SplashLogic as a function of elapsed time; this
//  view only reads the clock and draws.
//

import SwiftUI

struct SplashOverlay: View {
    /// Coin faces in drop order, home currency last (₦, $, KSh…).
    let symbols: [String]
    let haptics: Bool
    var timeline = SplashLogic.Timeline()
    /// When the clock starts, so the app underneath can move in step.
    var onStart: (Date) -> Void = { _ in }
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date?
    @State private var landed = 0
    @State private var skipped = false

    var body: some View {
        ZStack {
            if reduceMotion {
                still.ignoresSafeArea()
                credit
            } else {
                TimelineView(.animation(paused: start == nil)) { context in
                    let t = start.map { context.date.timeIntervalSince($0) } ?? 0
                    ZStack {
                        // Full screen, so the pocket sits where the launch image did.
                        frame(at: t).ignoresSafeArea()
                        credit.opacity(SplashLogic.creditOpacity(at: t, in: timeline))
                    }
                }
            }
        }
        .opacity(skipped ? 0 : 1)
        .contentShape(.rect)
        .onTapGesture(perform: skip)
        .sensoryFeedback(trigger: landed) { _, count in
            guard haptics, count > 0 else { return nil }
            return count == timeline.coins ? .impact(flexibility: .soft, intensity: 0.8) : .impact(weight: .light, intensity: 0.4)
        }
        .task { await run() }
        .accessibilityHidden(true)
    }

    // MARK: - Drawing

    /// The coins drop and the pocket squashes on green. Then the camera dives
    /// through: the pocket rushes past and blurs while the green clears and
    /// the app settles in underneath (PocketApp scales it with
    /// SplashLogic.appScale). Only the pocket and coins blur; blurring flat
    /// green would cost a full-screen pass for nothing.
    private func frame(at t: Double) -> some View {
        let p = SplashLogic.diveProgress(at: t, in: timeline)
        let squash = SplashLogic.squash(at: t, in: timeline)

        return ZStack {
            PocketMark.green.opacity(1 - p)
            ZStack {
                ForEach(symbols.indices, id: \.self) { index in
                    coin(symbols[index])
                        .rotationEffect(.degrees(SplashLogic.coinTilt[index]))
                        .offset(x: SplashLogic.coinX[index], y: SplashLogic.coinY(index, at: t, in: timeline))
                        .opacity(SplashLogic.coinOpacity(index, at: t, in: timeline))
                }
                PocketMarkView()
                    .scaleEffect(x: squash.x, y: squash.y, anchor: .bottom)
            }
            .scaleEffect(SplashLogic.diveScale(at: t, in: timeline))
            .blur(radius: 8 * p)
            .opacity(1 - p)
        }
    }

    /// Reduce Motion: no coins, no squash, no dive. The pocket holds, then the
    /// green fades away.
    private var still: some View {
        ZStack {
            PocketMark.green
            PocketMarkView()
        }
    }

    /// "Made by" and the DEVAKINTOLA wordmark, above the home indicator. The
    /// launch screen can only hold one centred image, so this fades in with
    /// the first coin rather than popping on.
    private var credit: some View {
        VStack {
            Spacer()
            HStack(alignment: .center, spacing: 8) {
                Text("Made by")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Image("DevAkintola")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 24)
                    .accessibilityLabel("DevAkintola")
            }
            .foregroundStyle(.white)
            .padding(.bottom, 12)
        }
    }

    private func coin(_ symbol: String) -> some View {
        Text(symbol)
            .font(.system(size: 22, weight: .heavy, design: .rounded))
            .foregroundStyle(PocketMark.green)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .padding(6)
            .frame(width: SplashLogic.coinDiameter, height: SplashLogic.coinDiameter)
            .background(.white, in: .circle)
    }

    // MARK: - Timing

    private func run() async {
        if reduceMotion {
            try? await Task.sleep(for: .seconds(0.15))
            withAnimation(.easeOut(duration: 0.2)) { skipped = true }
            try? await Task.sleep(for: .seconds(0.2))
            onFinish()
            return
        }
        let began = Date.now
        start = began
        onStart(began)
        // One haptic per coin as it lands.
        for index in 0..<timeline.coins {
            let wait = timeline.landing(ofCoin: index) - Date.now.timeIntervalSince(began)
            try? await Task.sleep(for: .seconds(max(wait, 0)))
            landed = index + 1
        }
        try? await Task.sleep(for: .seconds(max(timeline.total - Date.now.timeIntervalSince(began), 0)))
        onFinish()
    }

    private func skip() {
        withAnimation(.easeOut(duration: 0.15)) { skipped = true }
        Task {
            try? await Task.sleep(for: .seconds(0.15))
            onFinish()
        }
    }
}
