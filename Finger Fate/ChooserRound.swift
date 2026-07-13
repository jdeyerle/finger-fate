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
}
