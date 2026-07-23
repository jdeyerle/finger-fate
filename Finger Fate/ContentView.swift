import SwiftUI
import UIKit

private let fingerPalette: [Color] = [
    Color(red: 0.96, green: 0.36, blue: 0.31),
    Color(red: 0.97, green: 0.77, blue: 0.27),
    Color(red: 0.20, green: 0.83, blue: 0.51),
    Color(red: 0.43, green: 0.51, blue: 0.96),
    Color(red: 0.97, green: 0.60, blue: 0.23),
    Color(red: 0.31, green: 0.89, blue: 0.76),
    Color(red: 0.71, green: 0.44, blue: 0.96),
    Color(red: 0.39, green: 0.72, blue: 0.95),
]
private let hintBackground = Color(red: 0.16, green: 0.16, blue: 0.17)
private let circleDiameter: CGFloat = 110

private typealias LiveRoundEngine = RoundEngine<SystemRandomNumberGenerator>

struct ContentView: View {
    @State private var touches: [TouchID: CGPoint] = [:]
    @State private var colorIndices: [TouchID: Int] = [:]
    @State private var engine = LiveRoundEngine(generator: SystemRandomNumberGenerator())
    @State private var phase: LiveRoundEngine.Phase = .idle
    @State private var pulse = false
    @State private var timerTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black

            ForEach(Array(touches.keys), id: \.self) { id in
                if let point = touches[id] {
                    FingerBlob(state: blobState(id), color: fingerColor(id), pulse: pulse)
                        .position(point)
                        .animation(.spring(duration: 0.35), value: phase)
                }
            }

            if touches.count < 2 {
                hintPill
            }

            if case let .selected(winner) = phase {
                winnerBanner(color: fingerColor(winner))
            }

            MultiTouchView(onChange: handleTouches)
        }
        // blobs must share the full-screen space TrackingView reports touches in
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var hintPill: some View {
        VStack {
            Spacer()
            Text(touches.isEmpty ? "Place your fingers on the screen" : "Add at least one more finger")
                .font(.system(.body, design: .serif))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(hintBackground, in: Capsule())
                .padding(.bottom, 48)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: touches.isEmpty)
    }

    private func winnerBanner(color: Color) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 2) {
                Text("Fate has")
                    .foregroundStyle(.white)
                Text("chosen")
                    .foregroundStyle(color)
            }
            .font(.system(size: 44, weight: .bold, design: .serif))
            .italic()
            .padding(.bottom, 80)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func fingerColor(_ id: TouchID) -> Color {
        fingerPalette[colorIndices[id, default: 0] % fingerPalette.count]
    }

    private func blobState(_ id: TouchID) -> FingerBlob.State {
        switch phase {
        case let .choosing(highlighted) where highlighted == id: return .highlighted
        case let .selected(winner) where winner == id: return .winner
        case .selected: return .loser
        default: return .waiting
        }
    }

    private func handleTouches(_ points: [TouchID: CGPoint]) {
        let newIDs = Set(points.keys).subtracting(touches.keys)
        touches = points
        if points.isEmpty {
            colorIndices = [:]
        } else {
            assignColors(to: newIDs)
        }
        perform(engine.touchesChanged(Array(points.keys)))
    }

    private func assignColors(to newIDs: Set<TouchID>) {
        // sequential: each new touch takes the next unused palette slot
        for id in newIDs.sorted(by: { "\($0)" < "\($1)" }) {
            let used = Set(colorIndices.values)
            let free = (0..<fingerPalette.count).first { !used.contains($0) }
            colorIndices[id] = free ?? colorIndices.count % fingerPalette.count
        }
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
            case let .hopHaptic(intensity):
                UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: intensity)
            case .winnerHaptic:
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        }
        syncPhase()
    }

    private func syncPhase() {
        if case .selected = engine.phase {
            withAnimation(.spring(duration: 0.5, bounce: 0.5)) { phase = engine.phase }
        } else {
            phase = engine.phase
        }
    }
}

private struct FingerBlob: View {
    enum State {
        case waiting
        case highlighted
        case winner
        case loser
    }

    let state: State
    let color: Color
    let pulse: Bool

    var body: some View {
        ZStack {
            shape
                .fill(color.gradient)
            if state == .winner {
                FlowerShape()
                    .stroke(.white.opacity(0.9), lineWidth: 3)
            }
        }
        .frame(width: circleDiameter, height: circleDiameter)
        .scaleEffect(scale)
        .opacity(state == .loser ? 0.12 : 1)
        .shadow(color: color.opacity(shadowOpacity), radius: state == .winner ? 40 : 24)
    }

    private var shape: AnyShape {
        state == .winner ? AnyShape(FlowerShape()) : AnyShape(Circle())
    }

    private var scale: CGFloat {
        switch state {
        case .waiting: return pulse ? 1.05 : 1
        case .highlighted: return 1.18
        case .winner: return 1.5
        case .loser: return 0.7
        }
    }

    private var shadowOpacity: Double {
        switch state {
        case .waiting, .loser: return 0
        case .highlighted: return 0.6
        case .winner: return 0.9
        }
    }
}

private struct FlowerShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let base = min(rect.width, rect.height) / 2
        let petals = 8.0
        let steps = 240
        // polar rose: r = base * (0.88 + 0.12·cos(petals·θ)) traces the scalloped petal edge
        let points = (0...steps).map { step -> CGPoint in
            let angle = Double(step) / Double(steps) * 2 * .pi
            let radius = base * (0.88 + 0.12 * cos(petals * angle))
            return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        }
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}

#Preview("Choosing") {
    ZStack {
        Color.black.ignoresSafeArea()
        FingerBlob(state: .waiting, color: fingerPalette[0], pulse: false).position(x: 140, y: 180)
        FingerBlob(state: .waiting, color: fingerPalette[1], pulse: false).position(x: 260, y: 130)
        FingerBlob(state: .loser, color: fingerPalette[2], pulse: false).position(x: 350, y: 300)
        FingerBlob(state: .waiting, color: fingerPalette[3], pulse: false).position(x: 90, y: 480)
        FingerBlob(state: .winner, color: fingerPalette[5], pulse: false).position(x: 210, y: 600)
    }
}
