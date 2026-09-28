import Foundation

/// First real loop of 《谁让雾港重新亮灯》 on a single save, at the transfer
/// station: choose a side → deliver straps to its funded order → install the
/// last kit → one ordinary public attempt → local contract result.
/// Other accounts and the first eleven kits are labelled fixtures, not players.
/// The 18-copper order budget is a one-time, per-save launch budget; it must be
/// counted as issuance in any shared economy, never as a closed loop.
public struct MPCLightsLocalEvent: Codable, Equatable, Sendable {
    public typealias Faction = MPCWorldCampaignPrototype.Faction
    public typealias P = MPCLightsEventPreview

    public static let ruleVersion = "lights-local-v1"
    public static let fixtureNotice = "其他账号成绩与前11套工程为预置夹具：本方此前3个账号5点，对方4个账号4点且工程完工。非联网，不是真实玩家。"
    public static let strapID = MPCLocalWorkshopLedger.strapID
    public static let strapsPerKit = 2
    public static let strapPrice = 9
    public static let orderBudget = strapsPerKit * strapPrice
    /// Fixture: accounts and points already recorded before the player arrives.
    public static let fixtureOwn = (accounts: 3, points: 5)
    public static let fixtureOpponent = (accounts: 4, points: 4)

    public enum Failure: Error, Equatable { case locked, side, stock, funds, order, pending, attempted, invalidBattle, conflict }

    public struct Entry: Codable, Equatable, Sendable {
        public let id: String
        public let kind: String
        public let text: String
        public let playerCopperDelta: Int
        public let projectCopperDelta: Int
    }

    public private(set) var side: Faction?
    public private(set) var projectCash = orderBudget
    public private(set) var projectStraps = 0
    public private(set) var installedKits = 11
    public private(set) var activeTicket: String?
    public private(set) var publicAttempted = false
    public private(set) var publicWon = false
    public private(set) var entries: [Entry] = []
    private var applied: [String: String] = [:]

    public init() {}

    public var orderOpen: Bool { projectStraps < Self.strapsPerKit && installedKits < P.kitSlots }
    public var worksComplete: Bool { installedKits == P.kitSlots }
    public var closed: Bool { publicAttempted && activeTicket == nil }

    private func replay(_ id: String, _ command: String) throws -> Bool {
        guard !id.isEmpty else { throw Failure.conflict }
        guard let prior = applied[id] else { return false }
        guard prior == command else { throw Failure.conflict }
        return true
    }
    private mutating func log(_ id: String, _ kind: String, _ text: String, player: Int = 0, project: Int = 0) {
        entries.append(.init(id: id, kind: kind, text: text, playerCopperDelta: player, projectCopperDelta: project))
        applied[id] = kind
    }

    /// Free support; locks the stance for this event. Neutral selling is not offered here.
    @discardableResult
    public mutating func choose(_ faction: Faction, id: String, eligible: Bool) throws -> Bool {
        if try replay(id, "side") { return false }
        guard eligible else { throw Failure.locked }
        guard side == nil else { throw Failure.side }
        side = faction
        log(id, "side", "支持\(P.sideName(faction))。不收报名费，不发工资；本次事件立场锁定。")
        return true
    }

    /// Delivers exactly the two straps the funded order still accepts.
    @discardableResult
    public mutating func deliver(id: String, eligible: Bool, coins: inout Int, inventory: inout [String: Int]) throws -> Bool {
        if try replay(id, "deliver") { return false }
        guard eligible, let side else { throw Failure.locked }
        guard orderOpen else { throw Failure.order }
        let quantity = Self.strapsPerKit - projectStraps
        let payment = quantity * Self.strapPrice
        guard inventory[Self.strapID, default: 0] >= quantity else { throw Failure.stock }
        guard projectCash >= payment, coins <= Int.max - payment else { throw Failure.funds }
        inventory[Self.strapID, default: 0] -= quantity
        coins += payment; projectCash -= payment; projectStraps += quantity
        log(id, "deliver", "\(P.projectName(side))验收\(quantity)条维修绑带，付\(payment)铜。钱来自本存档一次性的项目预算。",
            player: payment, project: -payment)
        return true
    }

    /// The straps join the stocked cloth and tins and are consumed by the 12th slot.
    @discardableResult
    public mutating func install(id: String, eligible: Bool) throws -> Bool {
        if try replay(id, "install") { return false }
        guard eligible, let side else { throw Failure.locked }
        guard projectStraps == Self.strapsPerKit, installedKits == P.kitSlots - 1 else { throw Failure.stock }
        projectStraps = 0; installedKits = P.kitSlots
        log(id, "install", "2条绑带与已入库的2块过滤布、2个锡罐组成最后一套检修组具，装进\(P.projectName(side))第12号滤筒位。工程12/12验收。")
        return true
    }

    /// One valid world attempt per save. The ticket is written before combat;
    /// defeat, retreat or abandonment all use it up.
    public mutating func beginPublic(id: String, eligible: Bool) throws -> String {
        guard eligible, let side else { throw Failure.locked }
        guard worksComplete else { throw Failure.order }
        guard activeTicket == nil else { throw Failure.pending }
        guard !publicAttempted else { throw Failure.attempted }
        guard MPCLightsPublicTarget.validTicket(id) else { throw Failure.conflict }
        activeTicket = id; publicAttempted = true
        log(id, "public_begin", "开始普通公共行动：\(MPCLightsPublicTarget.title(side))。本存档唯一的有效尝试。")
        return MPCLightsPublicTarget.encounterID(side: side, ticket: id)
    }

    @discardableResult
    public mutating func settlePublic(id: String, session: MPCChapterOneEncounterSession) throws -> Bool {
        guard let side, activeTicket == id else {
            if applied["settle:" + id] != nil { return false }
            throw Failure.invalidBattle
        }
        guard session.encounter.id == MPCLightsPublicTarget.encounterID(side: side, ticket: id),
              session.outcome != .inProgress else { throw Failure.invalidBattle }
        publicWon = session.outcome == .victory
        activeTicket = nil
        log("settle:" + id, "public_end", publicWon ? "普通公共行动胜利：解除一处阻碍，记1点公共贡献。" : "普通公共行动未完成；本次尝试已用掉，不记贡献。")
        return true
    }

    /// Retreat or abandonment closes the ticket without contribution.
    public mutating func abandonPublic(id: String, defeated: Bool = false) {
        guard activeTicket == id else { return }
        activeTicket = nil
        log("settle:" + id, "public_end", (defeated ? "普通公共行动失败" : "撤出普通公共行动") + "；本次尝试已用掉，不记贡献。")
    }

    public func ledger(_ faction: Faction) -> P.Ledger {
        let own = faction == side
        let base = own ? Self.fixtureOwn : Self.fixtureOpponent
        let mine = own && publicWon ? 1 : 0
        return P.Ledger(raised: P.fundingCap, investors: 10, installedKits: own ? installedKits : P.kitSlots,
                        orderedKits: 0, publicScore: base.points + mine, successfulAccounts: base.accounts + mine)
    }

    /// Local result once the attempt is closed; both leaders survive (no core battle yet).
    public var contract: P.Contract? {
        guard side != nil, closed else { return nil }
        return try? P.contract(pumps: ledger(.pumps), shipping: ledger(.shipping), aidaDead: false, rowanDead: false)
    }
}

/// The ordinary public target: authored tower bodies under maintenance-style
/// IDs, so Unity presentation, music and identity reuse the shipped path.
public enum MPCLightsPublicTarget {
    public typealias Faction = MPCWorldCampaignPrototype.Faction
    public static let prefix = "church_maintenance_lights_"

    public static func title(_ side: Faction) -> String { side == .pumps ? "解除泵路误锁" : "清理货场通道" }
    static func validTicket(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 80 && id.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || $0 == "-" }
    }
    public static func encounterID(side: Faction, ticket: String) -> String { prefix + side.rawValue + "_" + ticket }

    public static func encounter(id: String) -> MPCEncounterContent? {
        guard id.hasPrefix(prefix) else { return nil }
        let rest = id.dropFirst(prefix.count).split(separator: "_", maxSplits: 1).map(String.init)
        guard rest.count == 2, let side = Faction(rawValue: rest[0]), validTicket(rest[1]) else { return nil }
        let early = MPCChurchTowerCatalog.floors.prefix(10).flatMap { $0.encounter.waves.flatMap(\.enemyIDs) }
        func body(_ species: MPCChurchTowerCatalog.Species) -> String {
            early.first { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0)?.species == species }!
        }
        // Pumps: a jammed pump line guarded by a jaw and a copperback, then a salt sac.
        // Shipping: the cargo lane, same weight with the order reversed.
        let waves: [[String]] = side == .pumps
            ? [[body(.shieldJaw), body(.copperback)], [body(.saltSac)]]
            : [[body(.saltSac), body(.copperback)], [body(.shieldJaw)]]
        return .init(id: id, name: title(side), investigationID: "lights_public",
                     waves: waves.enumerated().map { w, ids in
                         MPCEncounterWave(enemyIDs: ids.enumerated().map { $1 + "~maintenance-lights-w\(w)-p\($0)" })
                     },
                     companionSlots: 0, fixedRewardItemIDs: [], firstClearRelicID: nil, recommendedTags: ["church_maintenance", "lights_public"])
    }
}
