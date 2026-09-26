import Foundation

/// 雾港桌规：三人、两副完整扑克牌。经典三人斗地主只有一副牌；
/// this variant borrows the two-deck bombs and four-joker rocket while keeping
/// the three-player landlord-versus-two-farmers alliance.
public struct MPCDouCard: Codable, Hashable, Identifiable, Sendable {
    public let rank: Int // 3...15 (2), 16 small joker, 17 big joker
    public let suit: String
    public let copy: Int
    public var id: String { "\(copy)-\(rank)-\(suit)" }
    public var label: String {
        if rank == 16 { return "小王" }
        if rank == 17 { return "大王" }
        let face = [11: "J", 12: "Q", 13: "K", 14: "A", 15: "2"][rank] ?? String(rank)
        return face + suit
    }
    public var isRed: Bool { suit == "♥" || suit == "♦" || rank == 17 }
}

public enum MPCDouError: Error, Equatable {
    case invalidDeck, invalidStake, wrongPhase, wrongTurn, invalidBid, invalidMove,
         cannotPass, gameFinished, unknownCard
}

public struct MPCDouCombo: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case single, pair, triple, tripleSingle, triplePair, straight, pairRun,
             tripleRun, planeSingles, planePairs, fourSingles, fourPairs, bomb, heaven
    }
    public let kind: Kind
    public let count: Int
    public let primary: Int
    public var isBomb: Bool { kind == .bomb || kind == .heaven }
    public var label: String {
        switch kind {
        case .single: "单张"; case .pair: "对子"; case .triple: "三张"
        case .tripleSingle: "三带一"; case .triplePair: "三带二"
        case .straight: "顺子"; case .pairRun: "连对"; case .tripleRun: "飞机"
        case .planeSingles: "飞机带单"; case .planePairs: "飞机带对"
        case .fourSingles: "四带二单"; case .fourPairs: "四带两对"
        case .bomb: "\(count)张炸弹"; case .heaven: "天王炸"
        }
    }
    public func beats(_ other: MPCDouCombo) -> Bool {
        if kind == .heaven { return other.kind != .heaven }
        if other.kind == .heaven { return false }
        if kind == .bomb {
            if other.kind != .bomb { return true }
            return count != other.count ? count > other.count : primary > other.primary
        }
        if other.kind == .bomb { return false }
        return kind == other.kind && count == other.count && primary > other.primary
    }
}

public enum MPCDouPhase: String, Codable, Sendable { case bidding, playing, redeal, finished }

public struct MPCDouSettlement: Codable, Equatable, Sendable {
    public let gameID: String
    public let caseID: String
    public let wager: Int
    public let playerWon: Bool
    public let multiplier: Int
    public var payout: Int { playerWon ? wager * (1 + multiplier) : 0 }
    public var netCopper: Int { payout - wager }
}

public enum MPCDouRules {
    public static let wagers = [10, 20, 40]
    public static var standardDeck: [MPCDouCard] {
        (0..<2).flatMap { copy in
            ["♠", "♥", "♣", "♦"].flatMap { suit in
                (3...15).map { MPCDouCard(rank: $0, suit: suit, copy: copy) }
            } + [MPCDouCard(rank: 16, suit: "", copy: copy),
                 MPCDouCard(rank: 17, suit: "", copy: copy)]
        }
    }

    public static func deal(caseID: String, wager: Int, gameID: String,
                            shuffledDeck: [MPCDouCard], startingPlayer: Int) throws -> MPCDouGame {
        guard wagers.contains(wager) else { throw MPCDouError.invalidStake }
        guard (0..<3).contains(startingPlayer), shuffledDeck.count == 108,
              Set(shuffledDeck) == Set(standardDeck) else { throw MPCDouError.invalidDeck }
        return MPCDouGame(gameID: gameID, caseID: caseID, wager: wager,
                          hands: [Array(shuffledDeck[0..<34]), Array(shuffledDeck[34..<68]),
                                  Array(shuffledDeck[68..<102])],
                          bottom: Array(shuffledDeck[102..<108]), currentPlayer: startingPlayer)
    }

    public static func classify(_ cards: [MPCDouCard]) -> MPCDouCombo? {
        guard !cards.isEmpty, Set(cards).count == cards.count else { return nil }
        let n = cards.count
        let counts = Dictionary(grouping: cards, by: \.rank).mapValues(\.count)
        let ranks = counts.keys.sorted()
        func combo(_ kind: MPCDouCombo.Kind, _ primary: Int) -> MPCDouCombo {
            .init(kind: kind, count: n, primary: primary)
        }
        if n == 4, counts[16] == 2, counts[17] == 2 { return combo(.heaven, 17) }
        if ranks.count == 1, let rank = ranks.first {
            switch n {
            case 1: return combo(.single, rank)
            case 2: return combo(.pair, rank)
            case 3 where rank <= 15: return combo(.triple, rank)
            case 4...8 where rank <= 15: return combo(.bomb, rank)
            default: return nil
            }
        }
        if n == 4, let core = counts.first(where: { $0.value == 3 && $0.key <= 15 })?.key {
            return combo(.tripleSingle, core)
        }
        if n == 5, counts.count == 2,
           let core = counts.first(where: { $0.value == 3 && $0.key <= 15 })?.key,
           counts.values.contains(2) { return combo(.triplePair, core) }
        if n == 6, let core = counts.first(where: { $0.value == 4 && $0.key <= 15 })?.key {
            return combo(.fourSingles, core)
        }
        if n == 8, let core = counts.first(where: { $0.value == 4 && $0.key <= 15 })?.key,
           counts.count == 3, counts.filter({ $0.key != core }).values.allSatisfy({ $0 == 2 }) {
            return combo(.fourPairs, core)
        }
        func run(_ unit: Int, minimum: Int) -> Bool {
            ranks.count >= minimum && ranks.last! <= 14 && ranks.first! >= 3 &&
            ranks.last! - ranks.first! + 1 == ranks.count && counts.values.allSatisfy { $0 == unit }
        }
        if n >= 5, n == ranks.count, run(1, minimum: 5) { return combo(.straight, ranks.last!) }
        if n >= 6, n == ranks.count * 2, run(2, minimum: 3) { return combo(.pairRun, ranks.last!) }
        if n >= 6, n == ranks.count * 3, run(3, minimum: 2) { return combo(.tripleRun, ranks.last!) }
        // A two-deck hand may contain four or more of a core rank. Wings may
        // never reuse a rank from the airplane's triple sequence.
        for unit in [5, 4] where n >= unit * 2 && n % unit == 0 {
            let length = n / unit
            for first in 3...(14 - length + 1) {
                let core = Array(first..<(first + length))
                guard core.allSatisfy({ counts[$0, default: 0] == 3 }) else { continue }
                let wings = counts.filter { !core.contains($0.key) }
                if unit == 5, wings.count == length, wings.values.allSatisfy({ $0 == 2 }) {
                    return combo(.planePairs, core.last!)
                }
                if unit == 4, wings.values.reduce(0, +) == length {
                    return combo(.planeSingles, core.last!)
                }
            }
        }
        return nil
    }

    /// Candidate generator for NPCs. It never peeks at hidden hands or future
    /// cards; every candidate is run through the same human move validator.
    public static func legalMoves(_ hand: [MPCDouCard], beating target: MPCDouCombo?) -> [[MPCDouCard]] {
        let groups = Dictionary(grouping: hand, by: \.rank)
        let ranks = groups.keys.sorted()
        var moves: [[MPCDouCard]] = []
        func append(_ cards: [MPCDouCard]) {
            guard let shape = classify(cards), target == nil || shape.beats(target!) else { return }
            moves.append(cards)
        }
        for rank in ranks {
            let cards = groups[rank]!
            append(Array(cards.prefix(1)))
            if cards.count >= 2 { append(Array(cards.prefix(2))) }
            if rank <= 15, cards.count >= 3 {
                let triple = Array(cards.prefix(3))
                append(triple)
                for other in ranks where other != rank {
                    append(triple + Array(groups[other]!.prefix(1)))
                    if groups[other]!.count >= 2 { append(triple + Array(groups[other]!.prefix(2))) }
                }
            }
            if rank <= 15, cards.count >= 4 {
                for size in 4...cards.count { append(Array(cards.prefix(size))) }
                let rest = ranks.filter { $0 != rank }
                let loose = rest.flatMap { groups[$0]! }
                if loose.count >= 2 {
                    append(Array(cards.prefix(4)) + Array(loose.prefix(2)))
                    let pairRanks = rest.filter { groups[$0]!.count >= 2 }
                    if pairRanks.count >= 2 {
                        append(Array(cards.prefix(4)) + Array(groups[pairRanks[0]]!.prefix(2))
                               + Array(groups[pairRanks[1]]!.prefix(2)))
                    }
                }
            }
        }
        if groups[16]?.count == 2, groups[17]?.count == 2 {
            append(groups[16]! + groups[17]!)
        }
        for unit in 1...3 {
            let minimum = unit == 1 ? 5 : unit == 2 ? 3 : 2
            for start in 3...14 {
                var run: [MPCDouCard] = []
                for rank in start...14 {
                    guard let group = groups[rank], group.count >= unit else { break }
                    run += group.prefix(unit)
                    let length = rank - start + 1
                    if length >= minimum { append(run) }
                    if unit == 3, length >= 2 {
                        let outs = ranks.filter { $0 < start || $0 > rank }
                        let loose = outs.flatMap { groups[$0]! }
                        if loose.count >= length {
                            append(run + Array(loose.prefix(length)))
                            let pairs = outs.filter { groups[$0]!.count >= 2 }
                            if pairs.count >= length {
                                append(run + pairs.prefix(length).flatMap { groups[$0]!.prefix(2) })
                            }
                        }
                    }
                }
            }
        }
        return moves
    }
}

public struct MPCDouGame: Codable, Equatable, Sendable {
    public let gameID: String
    public let caseID: String
    public let wager: Int
    public private(set) var hands: [[MPCDouCard]]
    public let bottom: [MPCDouCard]
    public private(set) var phase: MPCDouPhase = .bidding
    public private(set) var currentPlayer: Int
    public private(set) var bids: [Int?] = [nil, nil, nil]
    public private(set) var highestBid = 0
    public private(set) var landlord: Int? = nil
    public private(set) var lastPlay: [MPCDouCard] = []
    public private(set) var lastPlayer: Int? = nil
    public private(set) var passCount = 0
    public private(set) var bombsPlayed = 0
    public private(set) var movesMade = [0, 0, 0]
    public private(set) var winner: Int? = nil
    public private(set) var recentAction = "等待叫分"

    public init(gameID: String, caseID: String, wager: Int, hands: [[MPCDouCard]],
                bottom: [MPCDouCard], currentPlayer: Int) {
        self.gameID = gameID; self.caseID = caseID; self.wager = wager
        self.hands = hands; self.bottom = bottom; self.currentPlayer = currentPlayer
    }

    public var playerWon: Bool? {
        guard let winner, let landlord else { return nil }
        return (winner == landlord) == (landlord == 0)
    }
    public var multiplier: Int {
        let base = max(1, highestBid)
        let bombFactor = 1 << min(2, bombsPlayed)
        let spring: Int
        if let winner, let landlord {
            spring = winner == landlord && (0..<3).filter({ $0 != landlord }).allSatisfy({ movesMade[$0] == 0 }) ? 2
                : winner != landlord && movesMade[landlord] <= 1 ? 2 : 1
        } else { spring = 1 }
        return min(8, base * bombFactor * spring)
    }
    public var settlement: MPCDouSettlement? {
        guard let playerWon else { return nil }
        return .init(gameID: gameID, caseID: caseID, wager: wager,
                     playerWon: playerWon, multiplier: multiplier)
    }

    public mutating func bid(_ value: Int) throws {
        guard phase == .bidding else { throw MPCDouError.wrongPhase }
        guard bids[currentPlayer] == nil, value == 0 || ((1...3).contains(value) && value > highestBid) else {
            throw MPCDouError.invalidBid
        }
        let bidder = currentPlayer
        bids[bidder] = value
        if value > highestBid { highestBid = value; landlord = bidder }
        recentAction = "\(bidder == 0 ? "你" : "牌手\(bidder)")\(value == 0 ? "不叫" : "叫\(value)分")"
        if value == 3 || bids.allSatisfy({ $0 != nil }) {
            if let landlord {
                hands[landlord] += bottom
                phase = .playing
                currentPlayer = landlord
                recentAction += " · \(landlord == 0 ? "你" : "牌手\(landlord)")成为地主"
            } else {
                phase = .redeal
                recentAction = "三家不叫 · 重新洗牌"
            }
        } else { currentPlayer = (currentPlayer + 1) % 3 }
    }

    public mutating func play(cardIDs: Set<String>) throws {
        guard phase == .playing else { throw MPCDouError.wrongPhase }
        let hand = hands[currentPlayer]
        let cards = hand.filter { cardIDs.contains($0.id) }
        guard !cardIDs.isEmpty, cards.count == cardIDs.count else { throw MPCDouError.unknownCard }
        guard let combo = MPCDouRules.classify(cards) else { throw MPCDouError.invalidMove }
        if let target = MPCDouRules.classify(lastPlay), !combo.beats(target) {
            throw MPCDouError.invalidMove
        }
        let actor = currentPlayer
        hands[actor].removeAll { cardIDs.contains($0.id) }
        movesMade[actor] += 1
        if combo.isBomb { bombsPlayed += 1 }
        lastPlay = cards
        lastPlayer = actor
        passCount = 0
        recentAction = "\(actor == 0 ? "你" : "牌手\(actor)")出了\(combo.label)"
        if hands[actor].isEmpty {
            winner = actor
            phase = .finished
            recentAction += " · \(playerWon == true ? "你方" : "对方")获胜"
        } else { currentPlayer = (actor + 1) % 3 }
    }

    public mutating func pass() throws {
        guard phase == .playing else { throw MPCDouError.wrongPhase }
        guard !lastPlay.isEmpty, lastPlayer != currentPlayer else { throw MPCDouError.cannotPass }
        let actor = currentPlayer
        passCount += 1
        recentAction = "\(actor == 0 ? "你" : "牌手\(actor)")不出"
        if passCount == 2 {
            currentPlayer = lastPlayer!
            lastPlay = []
            lastPlayer = nil
            passCount = 0
            recentAction += " · 新一轮由牌权方先出"
        } else { currentPlayer = (actor + 1) % 3 }
    }

    public mutating func runComputerTurns() throws {
        var steps = 0
        while currentPlayer != 0 && phase != .finished && phase != .redeal {
            steps += 1
            guard steps < 150 else { throw MPCDouError.invalidMove }
            if phase == .bidding {
                let hand = hands[currentPlayer]
                let counts = Dictionary(grouping: hand, by: \.rank).mapValues(\.count)
                let strength = hand.filter { $0.rank >= 14 }.count +
                    counts.values.filter { $0 >= 4 }.count * 4
                let offer = strength >= 12 ? min(3, highestBid + 1) : 0
                try bid(offer <= highestBid ? 0 : offer)
                continue
            }
            let target = MPCDouRules.classify(lastPlay)
            if let landlord, landlord != currentPlayer, landlord != lastPlayer,
               lastPlayer != nil {
                try pass() // preserve partner's winning lead
                continue
            }
            let moves = MPCDouRules.legalMoves(hands[currentPlayer], beating: target)
            guard !moves.isEmpty else { try pass(); continue }
            let sorted = moves.sorted { left, right in
                let a = MPCDouRules.classify(left)!, b = MPCDouRules.classify(right)!
                if a.isBomb != b.isBomb { return !a.isBomb }
                if target == nil, left.count != right.count { return left.count > right.count }
                if a.count != b.count { return a.count < b.count }
                return a.primary < b.primary
            }
            try play(cardIDs: Set(sorted[0].map(\.id)))
        }
    }
}
