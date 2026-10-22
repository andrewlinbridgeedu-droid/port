import Foundation

// 上线的理由 (2026-10-22, user: 1 2 3 4 都做). What will be waiting later that is not here now, shared by
// the paper's 明日预告 and the daily reminder, and one line for each mission that opens on a later day.
// Pull only: nothing here is lost by staying away (MPCDailyPacing lets every missed day be caught up).

public enum MPCComingUp {
    /// What is known now about a later moment. Days are pacing days (MPCDailyPacing).
    public struct Facts: Sendable {
        public var nowDay: Int
        public var thenDay: Int
        /// The first story mission not yet cleared.
        public var nextMission: (number: Int, title: String)?
        /// Whether the church (and its well) is open.
        public var wellOpen: Bool
        public var clearedFloors: Int
        /// Copper from deposits and projects that falls due between now and then.
        public var payoutCopper: Int
        /// Teammates back from an errand by then, not back now.
        public var teammatesBack: [String]
        /// The merchant is in port then and not now.
        public var merchantArrives: Bool
        /// Stamina is below the maximum now and full by then.
        public var staminaFull: Bool
        public init(nowDay: Int, thenDay: Int, nextMission: (number: Int, title: String)? = nil, wellOpen: Bool = false,
                    clearedFloors: Int = 0, payoutCopper: Int = 0, teammatesBack: [String] = [],
                    merchantArrives: Bool = false, staminaFull: Bool = false) {
            self.nowDay = nowDay; self.thenDay = thenDay; self.nextMission = nextMission; self.wellOpen = wellOpen
            self.clearedFloors = clearedFloors; self.payoutCopper = payoutCopper; self.teammatesBack = teammatesBack
            self.merchantArrives = merchantArrives; self.staminaFull = staminaFull
        }
    }

    public enum Kind: String, Sendable { case story, well, payout, teammate, merchant, stamina }
    public struct Line: Equatable, Sendable {
        public let kind: Kind
        public let text: String
    }

    /// Most important first: the story, the well, money, teammates, the merchant, stamina.
    public static func lines(_ f: Facts) -> [Line] {
        var lines: [Line] = []
        if let m = f.nextMission, MPCDailyPacing.isMissionOpen(m.number, day: f.thenDay),
           !MPCDailyPacing.isMissionOpen(m.number, day: f.nowDay) {
            lines.append(.init(kind: .story, text: "第 \(m.number) 关《\(m.title)》开放"))
        }
        // The well only once today's floors are used up: floors still open today are not news.
        let allowedNow = MPCDailyPacing.towerFirstClearsAllowed(day: f.nowDay)
        if f.wellOpen, f.clearedFloors >= allowedNow {
            let left = MPCChurchTowerCatalog.releasedFloorCount - f.clearedFloors
            let more = MPCDailyPacing.towerFirstClearsAllowed(day: f.thenDay) - f.clearedFloors
            if left > 0, more > 0 { lines.append(.init(kind: .well, text: "深井新开 \(min(more, left)) 层")) }
        }
        if f.payoutCopper > 0 { lines.append(.init(kind: .payout, text: "到账 \(f.payoutCopper) 铜")) }
        if !f.teammatesBack.isEmpty { lines.append(.init(kind: .teammate, text: f.teammatesBack.joined(separator: "、") + "回来了")) }
        if f.merchantArrives { lines.append(.init(kind: .merchant, text: "货郎\(MPCWanderingMerchant.name)靠岸")) }
        if f.staminaFull { lines.append(.init(kind: .stamina, text: "体力满了")) }
        return lines
    }

    /// The reminder: at most three things, nil when nothing new is waiting (no reminder that day).
    public static func reminder(_ f: Facts) -> (title: String, body: String)? {
        let all = lines(f)
        guard !all.isEmpty else { return nil }
        let title = all.first?.kind == .story ? "雾港 · 新的一关" : "雾港"
        return (title, all.prefix(3).map(\.text).joined(separator: " · "))
    }

    /// A hook for the mission that opens on a later day (Q8–Q30): what the player is left wondering
    /// after the day's last fight. Written to the 2026-10-18 rewrite's rules: things, not concepts.
    public static func teaser(mission: Int) -> String? { teasers[mission] }

    static let teasers: [Int: String] = [
        8: "台下那只记忆蛭还在念另一个名字。下一次，它要拿你的东西来编。",
        9: "记忆丝那头连着一份寻人证词。有人正用很好看的字改它。",
        10: "证词底下压着一份名单。翻到后面，有一个你认得的名字。",
        11: "名单上，你的名字后面填着一个地址。那户人家今晚多摆了一副碗筷。",
        12: "玛拉说，明天有件事要告诉你。她说这话的时候，没有看你。",
        13: "录音里的男人说：别怕，安置好就能走。排渠里，有人每天都这么说。",
        14: "洛克说，名字都在名牌箱里。伊恩的那一块，背后牵着一根红线。",
        15: "顺着红线走到头，是一扇亮着灯的窗户，和一双勒破了的手。",
        16: "远处再也不会响起哨声了。那条老猎犬，会第三次挡在路口。",
        17: "签发处有一台笔臂从不停手。你抽走一张纸，它就补上一张。",
        18: "笔臂底下的图通向五处主锚。守在门口的，是一张三年前的许可。",
        19: "盐栈宿舍的床头钉着木牌。有的名字擦掉了，有的还没来得及。",
        20: "下一批押运已经出发了。车上的木匣里，有人在轻轻地敲。",
        21: "洛克胸前那根线勒得更紧了。他想说的那句话，还没说完。",
        22: "复核接口的补位栏空着一格。维娅已经想好要填谁了。",
        23: "一块旧钟铜，一捧盐，一页白纸。只要验得过，就不必再用人去填。",
        24: "地下泊位还有人在等船。有个声音在问那只缺角的杯子。",
        25: "维娅托人带话：这一次，她自己来。",
        26: "还是那具锤卫，还是那条车链。这是最后一趟车了。",
        27: "原始档案库的门开了。最早写下你名字的那一页，就在里面。",
        28: "回流的中央站着一个白头发的老人，手里合着一本档案书。",
        29: "瑟维安的钟环上还亮着五格。他要拿最后的积蓄，替自己签一条退路。",
        30: "钟环全暗了。下一次，只剩他自己。",
    ]
}
