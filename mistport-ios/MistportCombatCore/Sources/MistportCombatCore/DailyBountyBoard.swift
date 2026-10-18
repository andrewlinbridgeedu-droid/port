import Foundation

/// Public intelligence is deliberately less precise than the investigation:
/// the player can judge the danger without being handed the suspect's location.
public struct MPCBountyNotice: Sendable, Equatable {
    public let crime: String
    public let combat: String
    public let warning: String
}

public enum MPCBountyNoticeCatalog {
    public static func notice(for id: String) -> MPCBountyNotice? {
        switch id {
        case "b01": return .init(crime: "照一张早已撤销的处决令，在封锁线外杀了两个人。", combat: "缺齿剑伏击：蓄势后打出约 2.5 倍重斩。", warning: "它不动的时候最危险。举剑那一下，别把防御全交出去。")
        case "b02": return .init(crime: "把还活着的人反扣在背架上，当成尸体运走。", combat: "金纹束缚：命中后再追加两次持续伤害。", warning: "挡下了第一下，未必挡得住后面那两下。")
        case "b03": return .init(crime: "倒敲船钟作暗号，劫了三艘退潮出港的船。", combat: "两道护航残影在场时，船长不受直接伤害；另有蓄力重击。", warning: "先清护航残影，别对着船长白费力气。")
        case "b04": return .init(crime: "偷用真章倒签两份遗嘱，让一家人为一张纸反目。", combat: "倒序覆写：若连续施放相同技能，反击升至约 2.5 倍。", warning: "交替出招。同一招连用两次，它就记住了。")
        case "b05": return .init(crime: "借量衣把人带走，趁人还醒着，用赤丝勒紧。", combat: "赤丝缠缚：直接伤害后再追加三次持续伤害。", warning: "拖得越久，丝勒得越紧。")
        case "b06": return .init(crime: "熄灯押运活人，砸了报警钟，穿着失窃军甲不许人下船。", combat: "重甲防御与蓄力重击交替出现，重击约为普通攻击两倍。", warning: "它举甲防御时先缓一缓，把手段留给重击。")
        case "b07": return .init(crime: "学人求救，骗住户开门，已有三人受伤。", combat: "喉铃突袭约 1.75 倍伤害；毒涎随后持续三次。", warning: "个头不大，毒却能把没准备的人慢慢拖垮。")
        case "b08": return .init(crime: "借别人的脸和签名取钱，把本人锁进暗房。", combat: "借脸伪影掩护真身，短刺约为普通攻击 1.5 倍。", warning: "认准真身，别把招式花在影子上。")
        case "b09": return .init(crime: "专吃已还清的债据，咬伤取证的人；背后是谁在使唤它，还没查清。", combat: "铜背甲不断叠盾，裂甲重爪约为普通攻击两倍。", warning: "先破甲，再对付它的重爪。")
        case "b10": return .init(crime: "篡改免费疗契，让不相干的人替病人折寿。", combat: "绯帷重击约 1.8 倍；囊体最多三次为她转息疗伤。", warning: "先截断囊体，不然她会一直回血，越拖越长。")
        default: return nil
        }
    }
}

public struct MPCDailyBountyIssue: Codable, Equatable, Sendable {
    public let dayOrdinal: Int
    public let offerIDs: [String]
    public init(dayOrdinal: Int, offerIDs: [String]) {
        self.dayOrdinal = dayOrdinal
        self.offerIDs = offerIDs
    }
    /// Adds a case the day must carry (MPCProgressionWalls.guaranteedCase); the day is not rerolled.
    public func guaranteeing(_ caseID: String?) -> MPCDailyBountyIssue {
        guard let caseID, !offerIDs.contains(caseID) else { return self }
        return .init(dayOrdinal: dayOrdinal, offerIDs: offerIDs + [caseID])
    }
}

/// A local, deterministic issue: reopening the board cannot reroll the day.
/// Accepted cases stay in the ledger when the next issue is printed.
public enum MPCDailyBountyRotation {
    public static func dayOrdinal(for date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return (parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
    }

    public static func issue(dayOrdinal: Int, eligibleIDs: [String]) -> MPCDailyBountyIssue {
        var ids = Array(Set(eligibleIDs)).sorted()
        var seed = UInt64(max(0, dayOrdinal)) &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        func next() -> UInt64 {
            seed = seed &* 2_862_933_555_777_941_757 &+ 3_037_000_493
            return seed
        }
        let count = min(ids.count, 3 + Int(next() % 4))
        if ids.count > 1 {
            for index in stride(from: ids.count - 1, through: 1, by: -1) {
                ids.swapAt(index, Int(next() % UInt64(index + 1)))
            }
        }
        let tiers: [Set<String>] = [
            ["b01", "b07", "b08"],
            ["b02", "b03", "b04", "b09"],
            ["b05", "b06", "b10"]
        ]
        var selected: [String] = []
        for tier in tiers {
            if let candidate = ids.first(where: { tier.contains($0) }) {
                selected.append(candidate)
            }
        }
        for id in ids where selected.count < count && !selected.contains(id) {
            selected.append(id)
        }
        return .init(dayOrdinal: dayOrdinal, offerIDs: Array(selected.prefix(count)))
    }
}

public struct MPCBountyDefeatLoss: Codable, Equatable, Sendable {
    public let battleID: String
    public let copper: Int
    public let relicID: String?
    public init(battleID: String, copper: Int, relicID: String?) {
        self.battleID = battleID
        self.copper = copper
        self.relicID = relicID
    }
}

/// Stable rolls let a restarted settlement reproduce the same loss. From
/// 2026-09-29 a defeat only costs copper: carried relics are never lost, so
/// `relicID` is always nil (the field stays so older saved receipts decode).
public enum MPCBountyDefeatRisk {
    public static let copperChance = 35
    public static func loss(battleID: String, availableCopper: Int, carriedOrdinaryRelicIDs: [String]) -> MPCBountyDefeatLoss {
        let coinRoll = hash("copper:" + battleID) % 100
        let copper = coinRoll < copperChance ? min(max(0, availableCopper), min(60, (max(0, availableCopper) * 15 + 99) / 100)) : 0
        return .init(battleID: battleID, copper: copper, relicID: nil)
    }
    private static func hash(_ text: String) -> UInt64 {
        text.utf8.reduce(14_695_981_039_346_656_037) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }
}
