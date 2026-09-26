import Testing
@testable import MistportCombatCore

@Suite("Bounty five-card draw and real wagers")
struct BountyPokerTests {
    private func hand(_ cards: [(Int, String)]) -> [MPCPokerCard] {
        cards.map { MPCPokerCard(rank: $0.0, suit: $0.1) }
    }

    @Test func standardHandOrderAndKickers() {
        let straightFlush = hand([(10,"♠"),(11,"♠"),(12,"♠"),(13,"♠"),(14,"♠")])
        let four = hand([(9,"♠"),(9,"♥"),(9,"♦"),(9,"♣"),(2,"♠")])
        let fullHouse = hand([(8,"♠"),(8,"♥"),(8,"♣"),(2,"♠"),(2,"♥")])
        let flush = hand([(2,"♠"),(4,"♠"),(7,"♠"),(9,"♠"),(13,"♠")])
        let straight = hand([(5,"♠"),(6,"♥"),(7,"♣"),(8,"♦"),(9,"♠")])
        let three = hand([(7,"♠"),(7,"♥"),(7,"♣"),(2,"♠"),(14,"♥")])
        let twoPair = hand([(8,"♠"),(8,"♥"),(5,"♣"),(5,"♦"),(14,"♠")])
        let pair = hand([(14,"♠"),(14,"♥"),(2,"♣"),(5,"♦"),(9,"♠")])
        let high = hand([(14,"♠"),(12,"♥"),(9,"♣"),(5,"♦"),(2,"♠")])
        let ordered = [high,pair,twoPair,three,straight,flush,fullHouse,four,straightFlush]
            .map(MPCPokerRules.rank)
        #expect(ordered.map(\.category) == Array(0...8))
        #expect(zip(ordered, ordered.dropFirst()).allSatisfy { $0 < $1 })
        let lowStraight = hand([(14,"♠"),(2,"♥"),(3,"♣"),(4,"♦"),(5,"♠")])
        #expect(MPCPokerRules.rank(lowStraight).kickers == [5])
        #expect(MPCPokerRules.rank(lowStraight) < MPCPokerRules.rank(straight))
        let strongerPair = hand([(14,"♣"),(14,"♦"),(13,"♠"),(5,"♠"),(2,"♥")])
        #expect(MPCPokerRules.rank(strongerPair) > MPCPokerRules.rank(pair))
    }

    @Test func fullDeckExchangeAndPayoutAreConsistent() throws {
        let round = try MPCPokerRules.deal(caseID: "b03", wager: 20, roundID: "round-1",
                                            shuffledDeck: MPCPokerRules.standardDeck.reversed())
        #expect(Set(round.player + round.dealer + round.drawPile).count == 52)
        let shown = try MPCPokerRules.showdown(round, discarding: [0,2,4])
        #expect(Set(shown.player + shown.dealer).count == 10)
        #expect(shown.outcome == (shown.playerRank > shown.dealerRank ? .win : shown.playerRank == shown.dealerRank ? .tie : .loss))
        #expect(shown.payout == (shown.outcome == .win ? 40 : shown.outcome == .tie ? 20 : 0))
        #expect(throws: MPCPokerError.invalidDiscard) {
            try MPCPokerRules.showdown(round, discarding: [0,1,2,3])
        }
        #expect(throws: MPCPokerError.invalidWager) {
            try MPCPokerRules.deal(caseID: "b03", wager: 0, roundID: "bad", shuffledDeck: MPCPokerRules.standardDeck)
        }
    }

    @Test func winLossAndExactTieHaveDifferentWalletEffects() throws {
        let royalSpades = hand([(10,"♠"),(11,"♠"),(12,"♠"),(13,"♠"),(14,"♠")])
        let royalHearts = hand([(10,"♥"),(11,"♥"),(12,"♥"),(13,"♥"),(14,"♥")])
        let weak = hand([(2,"♠"),(3,"♥"),(5,"♣"),(7,"♦"),(9,"♥")])
        func deal(_ player: [MPCPokerCard], _ opponent: [MPCPokerCard]) throws -> MPCPokerRound {
            let used = Set(player + opponent)
            let deck = player + opponent + MPCPokerRules.standardDeck.filter { !used.contains($0) }
            return try MPCPokerRules.deal(caseID: "b08", wager: 20,
                                           roundID: "fixed-\(player.first!.suit)", shuffledDeck: deck)
        }
        let win = try MPCPokerRules.showdown(deal(royalSpades, weak), discarding: [])
        #expect(win.outcome == .win && win.payout == 40 && win.netCopper == 20)
        let loss = try MPCPokerRules.showdown(deal(weak, royalSpades), discarding: [])
        #expect(loss.outcome == .loss && loss.payout == 0 && loss.netCopper == -20)
        let tie = try MPCPokerRules.showdown(deal(royalSpades, royalHearts), discarding: [])
        #expect(tie.outcome == .tie && tie.payout == 20 && tie.netCopper == 0)
    }

    @Test func disclosedFifthHandWinsUnderEveryAllowedDiscard() throws {
        let deck = try MPCPokerRules.guaranteedFifthDeck(shuffledDeck: MPCPokerRules.standardDeck.reversed())
        let round = try MPCPokerRules.deal(caseID: "b03", wager: 10, roundID: "fifth", shuffledDeck: deck)
        for mask in 0..<32 where mask.nonzeroBitCount <= 3 {
            let discarded = Set((0..<5).filter { mask & (1 << $0) != 0 })
            let shown = try MPCPokerRules.showdown(round, discarding: discarded)
            #expect(shown.outcome == .win)
        }
    }
}
