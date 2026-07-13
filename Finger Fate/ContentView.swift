import SwiftUI
import UIKit

private enum Phase: Equatable {
    case idle
    case tracking
    case choosing(winner: TouchID)
    case selected(winner: TouchID)
}

private let backgroundColor = Color(red: 13 / 255, green: 21 / 255, blue: 36 / 255)
private let slateColor = Color(red: 74 / 255, green: 85 / 255, blue: 104 / 255)
private let winnerColor = Color(red: 168 / 255, green: 85 / 255, blue: 247 / 255)
private let circleDiameter: CGFloat = 110
private let stabilityDelay: Duration = .milliseconds(1500)
private let countdownDuration: Duration = .milliseconds(1500)

struct ContentView: View {
    @State private var touches: [TouchID: CGPoint] = [:]
    @State private var phase: Phase = .idle
    @State private var pulse = false
    @State private var countdownProgress: CGFloat = 0
    @State private var stabilityTask: Task<Void, Never>?
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            ForEach(Array(touches.keys), id: \.self) { id in
                if let point = touches[id] {
                    FingerCircle(isWinner: isWinner(id), progress: countdownProgress, pulse: pulse)
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

    private func isWinner(_ id: TouchID) -> Bool {
        switch phase {
        case let .choosing(winner), let .selected(winner): return winner == id
        default: return false
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
        phase = .choosing(winner: winner)
        countdownProgress = 0
        withAnimation(.linear(duration: countdownDuration.seconds)) {
            countdownProgress = 0.85
        }
        try? await Task.sleep(for: countdownDuration)
        guard !Task.isCancelled, case .choosing = phase else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.easeOut(duration: 0.3)) {
            phase = .selected(winner: winner)
            countdownProgress = 1
        }
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
    let isWinner: Bool
    let progress: CGFloat
    let pulse: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    slateColor.opacity(isWinner ? 0.2 : 0.7),
                    style: StrokeStyle(lineWidth: 5, dash: [8, 8])
                )
            if isWinner {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(winnerColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: circleDiameter, height: circleDiameter)
        .scaleEffect(pulse && !isWinner ? 1.04 : 1)
    }
}

#Preview("Choosing") {
    ZStack {
        backgroundColor.ignoresSafeArea()
        FingerCircle(isWinner: false, progress: 0, pulse: false).position(x: 140, y: 180)
        FingerCircle(isWinner: false, progress: 0, pulse: false).position(x: 260, y: 130)
        FingerCircle(isWinner: false, progress: 0, pulse: false).position(x: 350, y: 300)
        FingerCircle(isWinner: false, progress: 0, pulse: false).position(x: 90, y: 480)
        FingerCircle(isWinner: true, progress: 0.85, pulse: false).position(x: 210, y: 600)
    }
}

private extension Duration {
    var seconds: Double {
        let (secs, atto) = components
        return Double(secs) + Double(atto) / 1e18
    }
}
