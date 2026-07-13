import SwiftUI
import UIKit

private let backgroundColor = Color(red: 13 / 255, green: 21 / 255, blue: 36 / 255)
private let slateColor = Color(red: 74 / 255, green: 85 / 255, blue: 104 / 255)
private let winnerColor = Color(red: 168 / 255, green: 85 / 255, blue: 247 / 255)
private let circleDiameter: CGFloat = 110

private typealias LiveRoundEngine = RoundEngine<SystemRandomNumberGenerator>

struct ContentView: View {
    @State private var touches: [TouchID: CGPoint] = [:]
    @State private var engine = LiveRoundEngine(generator: SystemRandomNumberGenerator())
    @State private var phase: LiveRoundEngine.Phase = .idle
    @State private var pulse = false
    @State private var timerTask: Task<Void, Never>?

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
        touches = points
        perform(engine.touchesChanged(Array(points.keys)))
    }

    private func perform(_ effects: [LiveRoundEngine.Effect]) {
        for effect in effects {
            switch effect {
            case let .scheduleTimer(after, generation):
                timerTask?.cancel()
                timerTask = Task {
                    try? await Task.sleep(for: after)
                    guard !Task.isCancelled else { return }
                    perform(engine.timerFired(generation: generation))
                }
            case .hopHaptic:
                UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
            case .winnerHaptic:
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        }
        syncPhase()
    }

    private func syncPhase() {
        if case .selected = engine.phase {
            withAnimation(.easeOut(duration: 0.3)) { phase = engine.phase }
        } else {
            phase = engine.phase
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
