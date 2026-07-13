import SwiftUI
import UIKit

private enum Phase: Equatable {
    case idle
    case tracking
    case choosing(highlighted: TouchID)
    case selected(winner: TouchID)
}

private let backgroundColor = Color(red: 13 / 255, green: 21 / 255, blue: 36 / 255)
private let slateColor = Color(red: 74 / 255, green: 85 / 255, blue: 104 / 255)
private let winnerColor = Color(red: 168 / 255, green: 85 / 255, blue: 247 / 255)
private let circleDiameter: CGFloat = 110
private let stabilityDelay: Duration = .milliseconds(1500)
private let hopCycles = 3

struct ContentView: View {
    @State private var touches: [TouchID: CGPoint] = [:]
    @State private var phase: Phase = .idle
    @State private var pulse = false
    @State private var stabilityTask: Task<Void, Never>?
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            ForEach(Array(touches.keys), id: \.self) { id in
                if let point = touches[id] {
                    FingerCircle(state: circleState(id), pulse: pulse)
                        .position(point)
                }
            }

            MultiTouchView(onChange: handleTouches)
                .ignoresSafeArea()
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private func circleState(_ id: TouchID) -> FingerCircle.State {
        switch phase {
        case let .choosing(highlighted) where highlighted == id: return .highlighted
        case let .selected(winner) where winner == id: return .winner
        case .selected: return .loser
        default: return .waiting
        }
    }

    private func handleTouches(_ points: [TouchID: CGPoint]) {
        let previousIDs = Set(touches.keys)
        touches = points
        let currentIDs = Set(points.keys)

        if currentIDs.isEmpty {
            scheduleReset()
            return
        }
        resetTask?.cancel()

        if currentIDs != previousIDs {
            restartStabilityTimer()
        }
    }

    private func restartStabilityTimer() {
        stabilityTask?.cancel()
        if case .selected = phase { phase = .tracking }
        if case .choosing = phase { phase = .tracking }
        if phase == .idle { phase = .tracking }

        let candidates = Array(touches.keys)
        guard candidates.count >= 2 else {
            phase = .tracking
            return
        }

        stabilityTask = Task {
            try? await Task.sleep(for: stabilityDelay)
            guard !Task.isCancelled else { return }
            await beginChoosing()
        }
    }

    @MainActor
    private func beginChoosing() async {
        var generator = SystemRandomNumberGenerator()
        guard let winner = ChooserRound.selectWinner(from: Array(touches.keys), using: &generator) else {
            return
        }
        let hops = ChooserRound.hopSequence(through: Array(touches.keys), endingAt: winner, cycles: hopCycles)
        let hopHaptic = UIImpactFeedbackGenerator(style: .light)
        for (index, id) in hops.enumerated() {  // sequential: each hop is a timed animation step
            guard !Task.isCancelled, phase != .idle, phase != .tracking else { return }
            phase = .choosing(highlighted: id)
            hopHaptic.impactOccurred(intensity: 0.6)
            try? await Task.sleep(for: hopDelay(index, of: hops.count))
        }
        guard !Task.isCancelled, case .choosing = phase else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.easeOut(duration: 0.3)) {
            phase = .selected(winner: winner)
        }
    }

    // decelerating roulette: hops start fast and stretch out toward the winner
    private func hopDelay(_ index: Int, of total: Int) -> Duration {
        let fraction = total > 1 ? Double(index) / Double(total - 1) : 1
        return .milliseconds(Int(70 + 330 * fraction * fraction))
    }

    private func scheduleReset() {
        stabilityTask?.cancel()
        resetTask?.cancel()
        resetTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, touches.isEmpty else { return }
            phase = .idle
        }
    }
}

private struct FingerCircle: View {
    enum State {
        case waiting
        case highlighted
        case winner
        case loser
    }

    let state: State
    let pulse: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    slateColor.opacity(state == .loser ? 0.25 : 0.7),
                    style: StrokeStyle(lineWidth: 5, dash: [8, 8])
                )
            if state == .highlighted || state == .winner {
                Circle()
                    .trim(from: 0, to: state == .winner ? 1 : 0.85)
                    .stroke(winnerColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: circleDiameter, height: circleDiameter)
        .scaleEffect(pulse && state == .waiting ? 1.04 : 1)
    }
}

#Preview("Choosing") {
    ZStack {
        backgroundColor.ignoresSafeArea()
        FingerCircle(state: .waiting, pulse: false).position(x: 140, y: 180)
        FingerCircle(state: .waiting, pulse: false).position(x: 260, y: 130)
        FingerCircle(state: .waiting, pulse: false).position(x: 350, y: 300)
        FingerCircle(state: .waiting, pulse: false).position(x: 90, y: 480)
        FingerCircle(state: .highlighted, pulse: false).position(x: 210, y: 600)
    }
}
