import Foundation

typealias TouchID = ObjectIdentifier

enum ChooserRound {
    static func selectWinner<G: RandomNumberGenerator>(
        from candidates: [TouchID],
        using generator: inout G
    ) -> TouchID? {
        guard candidates.count >= 2 else { return nil }
        return candidates.randomElement(using: &generator)
    }

    static func hopSequence(through candidates: [TouchID], endingAt winner: TouchID, cycles: Int) -> [TouchID] {
        guard cycles > 0, candidates.contains(winner) else { return [] }
        let repeated = Array(repeating: candidates, count: cycles).flatMap { $0 }
        guard let finalWinnerIndex = repeated.lastIndex(of: winner) else { return [] }
        return Array(repeated.prefix(through: finalWinnerIndex))
    }
}
