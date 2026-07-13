import Foundation
import Testing
@testable import Finger_Fate

private final class Holder {}

private func makeIDs(_ count: Int) -> [TouchID] {
    let objects = (0..<count).map { _ in Holder() }
    return objects.map(ObjectIdentifier.init)
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

private func makeEngine(seed: UInt64 = 1) -> RoundEngine<SeededGenerator> {
    RoundEngine(generator: SeededGenerator(seed: seed))
}

struct RoundEngineTests {
    @Test func twoFingersDownStartTrackingAndScheduleStabilityCountdown() {
        var engine = makeEngine()
        let ids = makeIDs(2)
        let effects = engine.touchesChanged(ids)
        #expect(engine.phase == .tracking)
        #expect(effects == [.scheduleTimer(after: .milliseconds(1500), generation: 1)])
    }

    @Test func stabilityCountdownFiringHighlightsFirstFingerAndSchedulesNextHop() {
        var engine = makeEngine()
        let ids = makeIDs(3)
        _ = engine.touchesChanged(ids)
        let effects = engine.timerFired(generation: 1)
        #expect(engine.phase == .choosing(highlighted: ids[0]))
        #expect(effects.first == .hopHaptic)
        #expect(effects.count == 2)
        if case let .scheduleTimer(after, generation) = effects[1] {
            #expect(after == .milliseconds(70))
            #expect(generation == 1)
        } else {
            Issue.record("expected a scheduled hop, got \(effects)")
        }
    }

    @Test func rouletteCyclesEveryFingerDeceleratesAndLocksWinnerWithHaptic() {
        var engine = makeEngine(seed: 42)
        let ids = makeIDs(3)
        _ = engine.touchesChanged(ids)
        var effects = engine.timerFired(generation: 1)
        var highlights: [TouchID] = []
        var delays: [Duration] = []
        // sequential: each iteration replays the timer the previous one scheduled
        while case let .choosing(highlighted) = engine.phase {
            highlights.append(highlighted)
            guard case let .scheduleTimer(after, generation) = effects.last else {
                Issue.record("choosing phase must schedule the next hop, got \(effects)")
                return
            }
            delays.append(after)
            effects = engine.timerFired(generation: generation)
        }
        #expect(Set(highlights) == Set(ids))
        #expect(delays == delays.sorted())
        #expect(delays.first! < delays.last!)
        #expect(effects.contains(.winnerHaptic))
        guard case let .selected(winner) = engine.phase else {
            Issue.record("expected a selected winner, ended in \(engine.phase)")
            return
        }
        #expect(winner == highlights.last)
        #expect(ids.contains(winner))
    }

    @Test func unchangedTouchSetDoesNotInterruptRoulette() {
        var engine = makeEngine()
        let ids = makeIDs(3)
        _ = engine.touchesChanged(ids)
        _ = engine.timerFired(generation: 1)
        let phaseMidRoulette = engine.phase
        let effects = engine.touchesChanged(ids.reversed())
        #expect(engine.phase == phaseMidRoulette)
        #expect(effects.isEmpty)
    }

    @Test func liftingAllFingersResetsToIdleAndAllowsNewRound() {
        var engine = makeEngine(seed: 7)
        _ = engine.touchesChanged(makeIDs(3))
        _ = engine.timerFired(generation: 1)
        _ = engine.touchesChanged([])
        #expect(engine.phase == .idle)
        let effects = engine.touchesChanged(makeIDs(2))
        #expect(engine.phase == .tracking)
        #expect(effects == [.scheduleTimer(after: .milliseconds(1500), generation: 3)])
    }

    @Test func staleTimerFromEarlierTouchSetIsIgnored() {
        var engine = makeEngine()
        _ = engine.touchesChanged(makeIDs(2))
        _ = engine.touchesChanged(makeIDs(3))
        let effects = engine.timerFired(generation: 1)
        #expect(effects.isEmpty)
        #expect(engine.phase == .tracking)
    }

    @Test func staleTimerAfterResetStaysIdle() {
        var engine = makeEngine()
        _ = engine.touchesChanged(makeIDs(2))
        _ = engine.touchesChanged([])
        let effects = engine.timerFired(generation: 1)
        #expect(effects.isEmpty)
        #expect(engine.phase == .idle)
    }

    @Test func singleFingerTracksWithoutSchedulingCountdown() {
        var engine = makeEngine()
        let effects = engine.touchesChanged(makeIDs(1))
        #expect(engine.phase == .tracking)
        #expect(effects.isEmpty)
    }
}
