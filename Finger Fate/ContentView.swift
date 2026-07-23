import SwiftUI
import UIKit

private enum Phase: Equatable {
    case idle
    case tracking
    case choosing(highlighted: TouchID)
    case selected(winner: TouchID)
}

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
private let stabilityDelay: Duration = .milliseconds(1500)
private let hopCycles = 3

struct ContentView: View {
    @State private var touches: [TouchID: CGPoint] = [:]
    @State private var colorIndices: [TouchID: Int] = [:]
    @State private var phase: Phase = .idle
    @State private var pulse = false
    @State private var stabilityTask: Task<Void, Never>?
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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

    private func fingerColor(_ id: TouchID) -> Color {
        fingerPalette[colorIndices[id, default: 0] % fingerPalette.count]
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

    private func blobState(_ id: TouchID) -> FingerBlob.State {
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
        assignColors(to: Set(points.keys).subtracting(previousIDs))
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

    private func assignColors(to newIDs: Set<TouchID>) {
        // sequential: each new touch takes the next unused palette slot
        for id in newIDs.sorted(by: { "\($0)" < "\($1)" }) {
            let used = Set(colorIndices.values)
            let free = (0..<fingerPalette.count).first { !used.contains($0) }
            colorIndices[id] = free ?? colorIndices.count % fingerPalette.count
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
            guard !Task.isCancelled else { return }
            phase = .choosing(highlighted: id)
            hopHaptic.impactOccurred(intensity: 0.6)
            try? await Task.sleep(for: hopDelay(index, of: hops.count))
        }
        guard !Task.isCancelled, case .choosing = phase else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.spring(duration: 0.45, bounce: 0.4)) {
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
            colorIndices = [:]
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
