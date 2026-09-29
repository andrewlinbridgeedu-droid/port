import Foundation

/// A playable vertical slice, isolated from all real saves and unique rewards.
/// Seeded other-player construction is explicitly fixture data, never multiplayer proof.
public struct MPCWorkshopPlaytest: Sendable {
    public enum Side: String, CaseIterable, Codable, Sendable {
        case pumps, shipping
        public var name: String { self == .pumps ? "泵站联合会" : "灰帆联营" }
    }
    public enum Purpose: String, Codable, Sendable { case tower, ordinary, hard }
    public enum Failure: Error, Equatable { case busy, locked, funds, stock, conflict, unfinished, closed }
    public struct Entry: Identifiable, Codable, Equatable, Sendable {
        public let id: Int
        public let kind: String
        public let text: String
        public let player: Int
        public let project: Int
        public let external: Int
    }
    public struct BattleReceipt: Identifiable, Codable, Equatable, Sendable {
        public let id: String
        public let purpose: Purpose
        public let encounter: String
        public let seconds: Double
        public let won: Bool
        public let medicineUsed: Int
        public let initialEnemyIDs: [String]
        public let events: [MPCCampaignBattleEvent]
    }
    public struct Snapshot: Codable, Equatable, Sendable {
        public let version: String
        public let fixtureNotice: String
        public let side: Side?
        public let copper, projectCash, supplierCash, external, hide, straps, medicines, proficiency, installed, publicPoints: Int
        public let closed: Bool
        public let winner: Side?
        public let entries: [Entry]
        public let battles: [BattleReceipt]
    }
    public private(set) var side: Side?
    public private(set) var copper = 48
    public private(set) var projectCash = 498
    public private(set) var supplierCash = 702
    public private(set) var external = 0
    public private(set) var hide = 0
    public private(set) var straps = 0
    public private(set) var medicines = 0
    public private(set) var proficiency = 0
    public private(set) var installed = 11
    public private(set) var projectStraps = 0
    public private(set) var sold = 0
    public private(set) var crafted = 0
    public private(set) var paidInputs = 0
    public private(set) var medicineSpend = 0
    public private(set) var publicPoints = 0
    public private(set) var publicAttempted = false
    public private(set) var closed = false
    public private(set) var winner: Side?
    public private(set) var entries: [Entry] = []
    public private(set) var battles: [BattleReceipt] = []
    public private(set) var battle: MPCCampaignBattleDriver?
    public private(set) var purpose: Purpose?
    public private(set) var pendingHide = false
    private var initialMedicine = 0
    private var initialEnemyIDs: [String] = []
    private var nextTicket = 1
    private var battleID = ""
    private var applied: [String: String] = [:]
    public static let fixtureNotice = "第二章资格与30层装备为隔离快照；本方此前3名玩家5点、对方4名玩家4点及11套工程为预置。非联网，非正式存档。"
    public var moneyConserved: Bool { copper + projectCash + supplierCash + external == 1248 }
    public var remainingDemand: Int { max(0, 2 - sold) }
    public var canMakeAdvanced: Bool { false } // needs sequence 8 + proficiency 20 + learned recipe; recipe not learned in fixture
    public var canSettleBattle: Bool { battle?.isComplete == true }
    public var snapshots: Snapshot {
        .init(version: "workshop-playtest-v1", fixtureNotice: Self.fixtureNotice, side: side,
              copper: copper, projectCash: projectCash, supplierCash: supplierCash, external: external,
              hide: hide, straps: straps, medicines: medicines, proficiency: proficiency, installed: installed,
              publicPoints: publicPoints, closed: closed, winner: winner, entries: entries, battles: battles)
    }
    public init() {
        record("fixture", "已有11套组具安装；最后一套的布与锡罐已付款入库，只缺2条绑带。有预算18铜。")
    }
    private mutating func record(_ kind: String, _ text: String) {
        entries.append(.init(id: entries.count, kind: kind, text: text, player: copper, project: projectCash, external: external))
    }
    private func replay(_ id: String, _ command: String) throws -> Bool {
        guard !id.isEmpty else { throw Failure.conflict }
        if let prior = applied[id] {
            guard prior == command else { throw Failure.conflict }
            return true
        }
        return false
    }
    private func idle() throws {
        guard battle == nil else { throw Failure.busy }
        guard !closed else { throw Failure.closed }
    }
    public mutating func choose(_ side: Side) throws {
        try idle()
        guard self.side == nil || self.side == side else { throw Failure.locked }
        if self.side == nil { self.side = side; record("side", "关注\(side.name)的供能计划；不收报名费，也不发工资。") }
    }
    @discardableResult public mutating func craft(id: String, advanced: Bool = false) throws -> Bool {
        let command = advanced ? "advanced" : "craft"
        if try replay(id, command) { return false }
        try idle()
        guard !advanced, side != nil else { throw Failure.locked }
        guard hide >= 1 else { throw Failure.stock }
        guard copper >= 13 else { throw Failure.funds }
        hide -= 1; copper -= 13; external += 13; straps += 3
        crafted += 1; paidInputs += 13; proficiency = min(20, proficiency + 1)
        applied[id] = command
        record("craft", "消耗1份韧皮、12铜底料和1铜工坊耗材，制成3条维修绑带；皮革熟练度+1。")
        return true
    }
    @discardableResult public mutating func sell(id: String, quantity: Int) throws -> Bool {
        let command = "sell:\(quantity)"
        if try replay(id, command) { return false }
        try idle()
        guard quantity > 0, quantity <= remainingDemand else { throw Failure.closed }
        guard straps >= quantity else { throw Failure.stock }
        let payment = quantity * 9
        guard projectCash >= payment else { throw Failure.funds }
        straps -= quantity; projectStraps += quantity; sold += quantity
        projectCash -= payment; copper += payment; applied[id] = command
        record("sale", "项目买入\(quantity)条绑带，支付\(payment)铜；这是已有预算转移，尚未安装。")
        return true
    }
    @discardableResult public mutating func install(id: String) throws -> Bool {
        if try replay(id, "install") { return false }
        try idle()
        guard installed == 11, projectStraps == 2 else { throw Failure.stock }
        projectStraps -= 2; installed = 12; applied[id] = "install"
        record("install", "2条绑带与已入库的2过滤布、2锡罐组成最后一套组具，安装在12号滤筒位；工程12/12验收。")
        return true
    }
    @discardableResult public mutating func buyMedicine(id: String) throws -> Bool {
        if try replay(id, "medicine") { return false }
        try idle()
        guard medicines < 3 else { throw Failure.stock }
        guard copper >= 9 else { throw Failure.funds }
        copper -= 9; supplierCash += 9; medicines += 1; medicineSpend += 9
        applied[id] = "medicine"
        record("medicine_purchase", "花9铜购买1瓶止痛膏。未使用不消耗；商人收到的钱仍在系统内，不当销毁。")
        return true
    }
    public mutating func begin(_ purpose: Purpose, passive: String? = nil, medal: Bool = false) throws {
        try idle()
        guard side != nil, !pendingHide else { throw Failure.locked }
        if purpose != .tower {
            guard installed == 12, !publicAttempted else { throw Failure.locked }
        }
        let next: MPCCampaignBattleDriver
        if purpose == .tower { next = try .init(towerFloor: 1, gearFloor: 30, medicines: medicines) }
        else {
            guard passive == nil || ["relic_return_gift_clasp", "relic_salt_sealed_breathing_bag"].contains(passive!) else { throw Failure.locked }
            let scenario: MPCCampaignScenario = side == .pumps ? (purpose == .hard ? .relayHard : .relayOrdinary) : (purpose == .hard ? .guardHard : .guardOrdinary)
            next = try .init(scenario: scenario, gearFloor: 30, passive: passive, medicines: medicines, medal: medal)
        }
        self.purpose = purpose; battle = next; initialMedicine = medicines
        initialEnemyIDs = next.session.enemies.map(\.contentID)
        battleID = "trial-battle-\(nextTicket)"; nextTicket += 1
        if purpose != .tower { publicAttempted = true }
        record("battle_start", purpose == .tower ? "开始教会塔F1重玩。只测试新增材料，不结算旧首通铜币、功勋或装备。" : "已冻结本次公共行动；正常失败或撤退同样占用唯一尝试。")
    }
    public mutating func advance(to time: Double) throws { try battle?.advance(to: time) }
    public mutating func target(_ id: String) { battle?.select(id) }
    @discardableResult public mutating func cast(_ skill: FoolSkillID?) -> Bool { battle?.cast(skill) ?? false }
    @discardableResult public mutating func useMedicine() -> Bool { battle?.medicine() ?? false }
    @discardableResult public mutating func useMedal() -> Bool { battle?.medal() ?? false }
    public mutating func settleBattle(retreat: Bool = false) throws {
        guard let b = battle, let purpose else { throw Failure.locked }
        guard b.isComplete || retreat else { throw Failure.unfinished }
        let won = b.session.outcome == .victory
        medicines = b.session.consumables["consumable_pain_salve", default: 0]
        let receipt = BattleReceipt(id: battleID, purpose: purpose, encounter: b.session.encounter.id,
            seconds: b.time, won: won, medicineUsed: initialMedicine - medicines,
            initialEnemyIDs: initialEnemyIDs, events: b.session.campaignPrototype?.events ?? [])
        battles.append(receipt)
        if purpose == .tower { pendingHide = won }
        else { publicPoints = won ? (purpose == .hard ? 2 : 1) : 0 }
        record("battle_end", "\(won ? "胜利" : "未完成")，用时\(Int(b.time))秒，实际用药\(receipt.medicineUsed)瓶。\(purpose == .tower ? "材料需凭这一次胜利领取。" : "本次贡献\(publicPoints)点。")")
        battle = nil; self.purpose = nil
    }
    @discardableResult public mutating func claimHide(id: String) throws -> Bool {
        if try replay(id, "loot") { return false }
        try idle()
        guard pendingHide else { throw Failure.locked }
        hide += 1; pendingHide = false; applied[id] = "loot"
        record("loot", "从本次盾颚魔残骸取得1份韧皮。候选材料掉落；不重复发放旧塔权益。")
        return true
    }
    public mutating func close() throws {
        try idle()
        guard let side, !pendingHide else { throw Failure.locked }
        // Explicit other-account fixture: our 3 distinct successes/5 points;
        // opponent 4 distinct successes/4 points with complete engineering.
        let eligible = installed == 12 && publicPoints > 0
        winner = eligible ? side : (side == .pumps ? .shipping : .pumps)
        closed = true
        record("world_close", "本试玩没有核心人物战，双方NPC存活。\(winner!.name)依工程及公共成果取得合同；你的施工和交货记录永久保留在本次试玩导出中。")
    }
}
