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
        case hopHaptic(intensity: Double)
        case winnerHaptic
    }

    static var stabilityDelay: Duration { .milliseconds(1500) }
    static var suspenseHold: Duration { .milliseconds(420) }
    private static var minimumCycles: Int { 3 }
    private static var minimumHops: Int { 12 }
    private static var firstHopMilliseconds: Double { 55 }

    private(set) var phase: Phase = .idle
    private var generator: Generator
    private var generation = 0
    private var candidates: [TouchID] = []
    private var hops: [TouchID] = []
    private var hopIndex = 0
    private var finalHopMilliseconds: Double = 480

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
        return [.scheduleTimer(after: Self.stabilityDelay, generation: generation)]
    }

    mutating func timerFired(generation firedGeneration: Int) -> [Effect] {
        guard firedGeneration == generation else { return [] }
        switch phase {
        case .tracking:
            guard let winner = ChooserRound.selectWinner(from: candidates, using: &generator) else { return [] }
            // hopSequence truncates at the winner, so guarantee minimumHops even in the worst case
            let cycles = max(Self.minimumCycles, Int((Double(Self.minimumHops - 1) / Double(candidates.count)).rounded(.up)) + 1)
            hops = ChooserRound.hopSequence(through: candidates, endingAt: winner, cycles: cycles)
            hopIndex = 0
            finalHopMilliseconds = Double.random(in: 480...620, using: &generator)
            phase = .choosing(highlighted: hops[0])
            return [.hopHaptic(intensity: hopIntensity(0)), .scheduleTimer(after: hopDelay(0), generation: generation)]
        case .choosing:
            hopIndex += 1
            if hopIndex < hops.count {
                phase = .choosing(highlighted: hops[hopIndex])
                return [.hopHaptic(intensity: hopIntensity(hopIndex)), .scheduleTimer(after: hopDelay(hopIndex), generation: generation)]
            }
            if hopIndex == hops.count {
                // suspense hold: the winner stays merely highlighted for a beat before lock-in
                return [.scheduleTimer(after: Self.suspenseHold, generation: generation)]
            }
            phase = .selected(winner: hops[hops.count - 1])
            return [.winnerHaptic]
        case .idle, .selected:
            return []
        }
    }

    // exponential friction decay, randomized per round: hops stretch geometrically toward the final hop
    private func hopDelay(_ index: Int) -> Duration {
        .milliseconds(Int(Self.firstHopMilliseconds * pow(finalHopMilliseconds / Self.firstHopMilliseconds, hopFraction(index))))
    }

    private func hopIntensity(_ index: Int) -> Double {
        0.4 + 0.5 * hopFraction(index)
    }

    private func hopFraction(_ index: Int) -> Double {
        hops.count > 1 ? Double(index) / Double(hops.count - 1) : 1
    }
}
