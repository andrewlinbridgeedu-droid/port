import Foundation

public struct MPCPokerCard: Codable, Hashable, Sendable {
    public let rank: Int
    public let suit: String

    public init(rank: Int, suit: String) {
        self.rank = rank
        self.suit = suit
    }

    public var rankLabel: String {
        [11: "J", 12: "Q", 13: "K", 14: "A"][rank] ?? String(rank)
    }
    public var label: String { rankLabel + suit }
    public var isRed: Bool { suit == "♥" || suit == "♦" }
}

public enum MPCPokerOutcome: String, Codable, Sendable {
    case win, tie, loss
}

public enum MPCPokerError: Error, Equatable {
    case invalidDeck, invalidWager, insufficientCopper, invalidDiscard, noActiveRound
}

public struct MPCPokerHandRank: Codable, Equatable, Comparable, Sendable {
    public let category: Int
    public let kickers: [Int]

    public var label: String {
        ["高牌", "一对", "两对", "三条", "顺子", "同花", "葫芦", "四条", "同花顺"][category]
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.category != rhs.category { return lhs.category < rhs.category }
        for (left, right) in zip(lhs.kickers, rhs.kickers) where left != right { return left < right }
        return false
    }
}

public struct MPCPokerRound: Codable, Equatable, Sendable {
    public let roundID: String
    public let caseID: String
    public let wager: Int
    public let player: [MPCPokerCard]
    public let dealer: [MPCPokerCard]
    public let drawPile: [MPCPokerCard]
}

public struct MPCPokerShowdown: Codable, Equatable, Sendable {
    public let roundID: String
    public let caseID: String
    public let wager: Int
    public let player: [MPCPokerCard]
    public let dealer: [MPCPokerCard]
    public let playerRank: MPCPokerHandRank
    public let dealerRank: MPCPokerHandRank
    public let outcome: MPCPokerOutcome

    /// The ante was deducted when the cards were dealt. A win returns the
    /// ante and an equal-sized opponent stake; a tie returns the ante only.
    public var payout: Int {
        switch outcome { case .win: return wager * 2; case .tie: return wager; case .loss: return 0 }
    }
    public var netCopper: Int { payout - wager }
}

public enum MPCPokerRules {
    public static let wagers = [10, 20, 40]
    public static let suits = ["♠", "♥", "♣", "♦"]
    public static var standardDeck: [MPCPokerCard] {
        suits.flatMap { suit in (2...14).map { MPCPokerCard(rank: $0, suit: suit) } }
    }

    /// The story-friendly table discloses a fifth-hand safety net. Every
    /// legal 0...3-card draw still beats the dealer; no result is overwritten.
    public static func guaranteedFifthDeck(shuffledDeck: [MPCPokerCard]) throws -> [MPCPokerCard] {
        guard shuffledDeck.count == 52, Set(shuffledDeck) == Set(standardDeck) else {
            throw MPCPokerError.invalidDeck
        }
        let player = (10...14).map { MPCPokerCard(rank: $0, suit: "♠") }
        let dealer = [MPCPokerCard(rank: 2, suit: "♠"), MPCPokerCard(rank: 4, suit: "♥"),
                      MPCPokerCard(rank: 6, suit: "♣"), MPCPokerCard(rank: 8, suit: "♦"),
                      MPCPokerCard(rank: 10, suit: "♣")]
        let draws = [MPCPokerCard(rank: 3, suit: "♥"), MPCPokerCard(rank: 5, suit: "♦"),
                     MPCPokerCard(rank: 7, suit: "♣"), MPCPokerCard(rank: 2, suit: "♥"),
                     MPCPokerCard(rank: 4, suit: "♣"), MPCPokerCard(rank: 6, suit: "♦")]
        let front = player + dealer + draws
        let reserved = Set(front)
        return front + shuffledDeck.filter { !reserved.contains($0) }
    }

    public static func deal(caseID: String, wager: Int, roundID: String, shuffledDeck: [MPCPokerCard],
                            priorStakesCoverFifth: Bool = false) throws -> MPCPokerRound {
        guard wagers.contains(wager) || (priorStakesCoverFifth && wager == 0) else {
            throw MPCPokerError.invalidWager
        }
        guard shuffledDeck.count == 52, Set(shuffledDeck) == Set(standardDeck) else { throw MPCPokerError.invalidDeck }
        return .init(roundID: roundID, caseID: caseID, wager: wager,
                     player: Array(shuffledDeck[0..<5]), dealer: Array(shuffledDeck[5..<10]),
                     drawPile: Array(shuffledDeck[10...]))
    }

    public static func rank(_ hand: [MPCPokerCard]) -> MPCPokerHandRank {
        precondition(hand.count == 5 && Set(hand).count == 5)
        let ranks = hand.map(\.rank).sorted(by: >)
        let counts = Dictionary(grouping: ranks, by: { $0 }).mapValues(\.count)
        let groups = counts.keys.sorted {
            if counts[$0] != counts[$1] { return counts[$0, default: 0] > counts[$1, default: 0] }
            return $0 > $1
        }
        let flush = Set(hand.map(\.suit)).count == 1
        let distinct = Set(ranks).sorted()
        let straightHigh: Int? = distinct == [2, 3, 4, 5, 14] ? 5
            : (distinct.count == 5 && distinct[4] - distinct[0] == 4 ? distinct[4] : nil)
        if let high = straightHigh, flush { return .init(category: 8, kickers: [high]) }
        if counts[groups[0]] == 4 { return .init(category: 7, kickers: groups) }
        if counts[groups[0]] == 3 && counts[groups[1]] == 2 { return .init(category: 6, kickers: groups) }
        if flush { return .init(category: 5, kickers: ranks) }
        if let high = straightHigh { return .init(category: 4, kickers: [high]) }
        if counts[groups[0]] == 3 { return .init(category: 3, kickers: groups) }
        if counts[groups[0]] == 2 && counts[groups[1]] == 2 { return .init(category: 2, kickers: groups) }
        if counts[groups[0]] == 2 { return .init(category: 1, kickers: groups) }
        return .init(category: 0, kickers: ranks)
    }

    public static func showdown(_ round: MPCPokerRound, discarding indices: Set<Int>) throws -> MPCPokerShowdown {
        guard indices.count <= 3, indices.allSatisfy({ (0..<5).contains($0) }) else { throw MPCPokerError.invalidDiscard }
        guard round.player.count == 5, round.dealer.count == 5, round.drawPile.count == 42,
              Set(round.player + round.dealer + round.drawPile) == Set(standardDeck) else {
            throw MPCPokerError.invalidDeck
        }
        var player = round.player
        var dealer = round.dealer
        var next = 0
        for index in indices.sorted() {
            player[index] = round.drawPile[next]
            next += 1
        }
        for index in dealerDiscards(round.dealer) {
            dealer[index] = round.drawPile[next]
            next += 1
        }
        let playerRank = rank(player)
        let dealerRank = rank(dealer)
        let outcome: MPCPokerOutcome = playerRank > dealerRank ? .win : playerRank == dealerRank ? .tie : .loss
        return .init(roundID: round.roundID, caseID: round.caseID, wager: round.wager,
                     player: player, dealer: dealer, playerRank: playerRank,
                     dealerRank: dealerRank, outcome: outcome)
    }

    /// The informant keeps made hands and draws to pairs or near-flushes.
    /// No player card or hidden future card is consulted when choosing.
    private static func dealerDiscards(_ hand: [MPCPokerCard]) -> [Int] {
        let value = rank(hand)
        if value.category >= 4 { return [] }
        let counts = Dictionary(grouping: hand, by: \.rank).mapValues(\.count)
        if value.category >= 1 {
            let heldRanks = Set(counts.filter { $0.value >= 2 }.map(\.key))
            return hand.indices.filter { !heldRanks.contains(hand[$0].rank) }.prefix(3).map { $0 }
        }
        let suitCounts = Dictionary(grouping: hand, by: \.suit).mapValues(\.count)
        if let nearFlush = suitCounts.first(where: { $0.value == 4 })?.key {
            return hand.indices.filter { hand[$0].suit != nearFlush }
        }
        let held = Set(hand.indices.sorted { hand[$0].rank > hand[$1].rank }.prefix(2))
        return hand.indices.filter { !held.contains($0) }
    }
}
