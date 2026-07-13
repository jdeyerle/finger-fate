import Foundation

struct RoundEngine<Generator: RandomNumberGenerator> {
    enum Phase: Equatable {
        case idle
        case tracking
        case choosing(highlighted: TouchID)
        case selected(winner: TouchID)
    }

    enum Effect: Equatable {
        case scheduleTimer(after: Duration, generation: Int)
        case hopHaptic
        case winnerHaptic
    }

    private(set) var phase: Phase = .idle
    private var generator: Generator
    private var generation = 0
    private var candidates: [TouchID] = []
    private var hops: [TouchID] = []
    private var hopIndex = 0

    init(generator: Generator) {
        self.generator = generator
    }

    mutating func touchesChanged(_ ids: [TouchID]) -> [Effect] {
        guard Set(ids) != Set(candidates) else { return [] }
        generation += 1
        guard !ids.isEmpty else {
            phase = .idle
            candidates = []
            hops = []
            hopIndex = 0
            return []
        }
        phase = .tracking
        candidates = candidates.filter(ids.contains) + ids.filter { !candidates.contains($0) }
        guard candidates.count >= 2 else { return [] }
        return [.scheduleTimer(after: .milliseconds(1500), generation: generation)]
    }

    mutating func timerFired(generation firedGeneration: Int) -> [Effect] {
        guard firedGeneration == generation else { return [] }
        switch phase {
        case .tracking:
            guard let winner = ChooserRound.selectWinner(from: candidates, using: &generator) else { return [] }
            hops = ChooserRound.hopSequence(through: candidates, endingAt: winner, cycles: 3)
            hopIndex = 0
            phase = .choosing(highlighted: hops[0])
            return [.hopHaptic, .scheduleTimer(after: hopDelay(0), generation: generation)]
        case .choosing:
            hopIndex += 1
            guard hopIndex < hops.count else {
                phase = .selected(winner: hops[hops.count - 1])
                return [.winnerHaptic]
            }
            phase = .choosing(highlighted: hops[hopIndex])
            return [.hopHaptic, .scheduleTimer(after: hopDelay(hopIndex), generation: generation)]
        case .idle, .selected:
            return []
        }
    }

    // decelerating roulette: hops start fast and stretch out toward the winner
    private func hopDelay(_ index: Int) -> Duration {
        let fraction = hops.count > 1 ? Double(index) / Double(hops.count - 1) : 1
        return .milliseconds(Int(70 + 330 * fraction * fraction))
    }
}
