import Testing
@testable import MistportCombatCore

@Suite("Three-player two-deck harbor landlord")
struct BountyDouDizhuTests {
    private let deck = MPCDouRules.standardDeck
    private func cards(_ ranks: [Int]) -> [MPCDouCard] {
        var seen: [Int:Int] = [:]
        return ranks.map { rank in
            let index = seen[rank, default: 0]
            seen[rank] = index + 1
            return MPCDouCard(rank: rank, suit: ["♠", "♥", "♣", "♦"][index % 4], copy: index / 4)
        }
    }
    @Test func all108CardsAndSixBottomAreUnique() throws {
        #expect(deck.count == 108)
        #expect(Set(deck).count == 108)
        let game = try MPCDouRules.deal(caseID: "b03", wager: 20, gameID: "test",
                                        shuffledDeck: deck.reversed(), startingPlayer: 0)
        #expect(game.hands.map(\.count) == [34, 34, 34])
        #expect(game.bottom.count == 6)
        #expect(Set(game.hands.flatMap { $0 } + game.bottom).count == 108)
        #expect(throws: MPCDouError.invalidDeck) {
            try MPCDouRules.deal(caseID: "b03", wager: 20, gameID: "bad",
                                 shuffledDeck: deck + [deck[0]], startingPlayer: 0)
        }
    }
    @Test func fullPatternsAndTwoDeckBombHierarchy() {
        func shape(_ values: [Int]) -> MPCDouCombo? { MPCDouRules.classify(cards(values)) }
        #expect(shape([3,3,3,3])?.kind == .bomb)
        #expect(shape([3,3,3,3,3,3,3,3])?.count == 8)
        #expect(shape([16,16,17,17])?.kind == .heaven)
        #expect(shape([3,3,3,4,4,4])?.kind == .tripleRun)
        #expect(shape([3,3,3,4,4,4,8,9])?.kind == .planeSingles)
        #expect(shape([3,3,3,4,4,4,8,8,9,9])?.kind == .planePairs)
        #expect(shape([3,4,5,6,7])?.kind == .straight)
        #expect(shape([3,3,4,4,5,5])?.kind == .pairRun)
        #expect(shape([3,3,3,3,4,4,5,5])?.kind == .fourPairs)
        #expect(shape([3,4,5,6,15]) == nil)
        #expect(shape([3,3,3,4,4,5]) == nil)
        #expect(shape([16,16,17,17])!.beats(shape([3,3,3,3,3,3,3,3])!))
        #expect(shape([3,3,3,3,3])!.beats(shape([14,14,14,14])!))
        #expect(!shape([3,3,3,3])!.beats(shape([4,4,4,4,4])!))
    }
    @Test func bidsTricksPassesAndTeamWin() throws {
        var game = try MPCDouRules.deal(caseID: "b08", wager: 10, gameID: "turn",
                                         shuffledDeck: deck, startingPlayer: 0)
        try game.bid(1)
        try game.bid(0)
        try game.bid(0)
        #expect(game.phase == .playing && game.landlord == 0 && game.hands[0].count == 40)
        #expect(throws: MPCDouError.cannotPass) { try game.pass() }
        let first = game.hands[0].min { $0.rank < $1.rank }!
        try game.play(cardIDs: [first.id])
        #expect(throws: MPCDouError.invalidMove) {
            try game.play(cardIDs: [game.hands[1].first(where: { $0.rank <= first.rank })!.id])
        }
        try game.pass()
        try game.pass()
        #expect(game.currentPlayer == 0 && game.lastPlay.isEmpty)
    }
    @Test func computersCanPlayACompleteRandomDealWithoutFabricatedResults() throws {
        for sequence in 0..<5 {
            var shuffled = deck
            shuffled.shuffle()
            var game = try MPCDouRules.deal(caseID: "b03", wager: 10, gameID: "sim-\(sequence)",
                                             shuffledDeck: shuffled, startingPlayer: 0)
            try game.bid(1)
            try game.runComputerTurns()
            var turns = 0
            while game.phase != .finished && turns < 300 {
                turns += 1
                if game.phase == .redeal { break }
                if game.phase == .bidding { try game.bid(3); try game.runComputerTurns(); continue }
                #expect(game.currentPlayer == 0)
                let target = MPCDouRules.classify(game.lastPlay)
                let moves = MPCDouRules.legalMoves(game.hands[0], beating: target)
                if let chosen = moves.first { try game.play(cardIDs: Set(chosen.map(\.id))) }
                else { try game.pass() }
                try game.runComputerTurns()
            }
            #expect(game.phase == .finished)
            #expect(game.settlement != nil)
            #expect(game.hands[game.winner!].isEmpty)
            #expect(game.settlement!.payout == (game.playerWon! ? 10 * (1 + game.multiplier) : 0))
        }
    }
}
