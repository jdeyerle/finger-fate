import Foundation
import Testing
@testable import Finger_Fate

private final class SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

private func makeIDs(_ count: Int) -> [TouchID] {
    let objects = (0..<count).map { _ in NSObject() }
    return objects.map(ObjectIdentifier.init)
}

struct ChooserRoundTests {
    @Test func selectsWinnerAmongCandidates() {
        let ids = makeIDs(4)
        var gen = SeededGenerator(seed: 42)
        let winner = ChooserRound.selectWinner(from: ids, using: &gen)
        #expect(winner != nil)
        #expect(ids.contains(winner!))
    }

    @Test func returnsNilForEmpty() {
        var gen = SeededGenerator(seed: 1)
        #expect(ChooserRound.selectWinner(from: [], using: &gen) == nil)
    }

    @Test func returnsNilForSingleTouch() {
        let ids = makeIDs(1)
        var gen = SeededGenerator(seed: 1)
        #expect(ChooserRound.selectWinner(from: ids, using: &gen) == nil)
    }

    @Test func seededGeneratorIsDeterministic() {
        let ids = makeIDs(5)
        var genA = SeededGenerator(seed: 99)
        var genB = SeededGenerator(seed: 99)
        let a = ChooserRound.selectWinner(from: ids, using: &genA)
        let b = ChooserRound.selectWinner(from: ids, using: &genB)
        #expect(a == b)
    }

    @Test func selectsExactlyOneWinner() {
        let ids = makeIDs(3)
        var gen = SeededGenerator(seed: 7)
        let winner = ChooserRound.selectWinner(from: ids, using: &gen)
        #expect(ids.filter { $0 == winner }.count == 1)
    }
}
