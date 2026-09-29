import Foundation

/// Nameless remnant clearing, agreed 2026-09-29 (DAILY_LOOP_AND_ECONOMY_20260929.md §7):
/// once a bounty case is closed, its area turns up one small case a day, rotating over
/// the closed cases. One investigation question and one street fight, about 6–8 minutes.
/// Pays copper through the shared repeatable-work taper (MPCDailyWorkLedger) plus two
/// units of the area's material; never a relic, merit or anything that becomes power.
public struct MPCRemnantCase: Equatable, Sendable, Identifiable {
    public struct Lead: Equatable, Sendable {
        public let evidence: String
        public let question: String
        public let choices: [MPCChurchBountyChoice]
        public let correctChoiceID: String
    }
    /// The closed bounty case this area belongs to.
    public let id: String
    public let area: String
    /// Two leads, alternating each time the case comes round.
    public let leads: [Lead]
    public let waves: [[MPCChurchTowerCatalog.Species]]
    /// Highest tower band the bodies may come from; a day's band is also capped by the
    /// floors the player has cleared (`MPCRemnantCatalog.band`).
    public let maxFloor: Int
    public let material: String
    public var title: String {
        "无名残余 · " + (MPCChurchBountyCatalog.all.first { $0.id == id }?.title ?? id)
    }
}

public enum MPCRemnantCatalog {
    public static let copper = 30
    public static let materialCount = 2
    public static let prefix = "church_maintenance_remnant_"
    typealias M = MPCTowerMaterials

    static func lead(_ evidence: String, _ question: String, _ choices: [(String, String)], correct: Int) -> MPCRemnantCase.Lead {
        let ids = ["a", "b", "c"]
        return .init(evidence: evidence, question: question,
                     choices: choices.enumerated().map { .init(id: ids[$0], text: $1.0, explanation: $1.1) },
                     correctChoiceID: ids[correct])
    }

    /// In the bounty catalog's order.
    public static let all: [MPCRemnantCase] = [
        .init(id: "b01", area: "废岗亭与封锁线", leads: [
            lead("命令匣已经封存，可废岗亭的旧机座还在渗油，桥下有东西顺着油迹往上爬。", "残余会从哪里冒出来？", [
                ("巡逻队换班走的桥面", "正常换班有登记，和油迹无关。"),
                ("顺着机座油迹通到桥下的排水口", "油迹一路没断，残余就在那条路上。"),
                ("诊所后门", "油迹没到那么远。")], correct: 1),
            lead("封锁线外夜里有盏灯一明一灭，间隔和当初的处决灯一样。", "那盏灯是怎么回事？", [
                ("旧机座上的残余信号灯，还在按旧节拍闪，把塔怪引了过来", "节拍对得上，灯下也有新爪印。"),
                ("守夜人点的灯", "守夜人的灯不闪，登记簿上有他的班次。"),
                ("有人在给走私船打信号", "节拍是处决灯的，不是航运信号。")], correct: 0)
        ], waves: [[.shieldJaw, .shieldJaw], [.saltSac]], maxFloor: 10, material: M.hide),
        .init(id: "b02", area: "废浴场与渡运台", leads: [
            lead("废浴场封了，可夜里池底有水声。救援站的人说，那里本该早就干了。", "水声从哪里来？", [
                ("有人偷偷回来洗东西", "入口封条完好，没有人的脚印。"),
                ("这几天下过雨", "这几天没下雨。"),
                ("塔怪在池底的旧管道里做了窝，把积水搅得直响", "管口有新刮痕，水面浮着鳞屑。")], correct: 2),
            lead("渡运台的船工说，最近总有空背架漂到岸边。", "背架从哪里来？", [
                ("市政救援站扔的", "救援架都有编号，登记齐全。"),
                ("废浴场的排水口，残余把堆在那里的旧背架拖进了水道", "背架上的锁扣和浴场旧物一样，还带着咬痕。"),
                ("上游货船掉下来的", "上游货船不用这种外锁背架。")], correct: 1)
        ], waves: [[.backSac, .shieldJaw], [.saltSac]], maxFloor: 50, material: M.membrane),
        .init(id: "b03", area: "钟沉船与码头", leads: [
            lead("退潮钟响后，钟沉船附近的水面又泛起白沫。", "白沫是什么？", [
                ("塔怪在舱口啃海盗留下的赃货箱", "白沫只在舱口一处，箱板上有新齿痕。"),
                ("亡魂又回来了", "灵体已经终结，逆钟口令没再出现。"),
                ("潮水冲的", "潮水冲不出只在一处的白沫。")], correct: 0),
            lead("老水手说码头夜里有人倒着敲钟，可钟台那晚没人上去。", "倒着响的钟声从哪来？", [
                ("钟台自己坏了", "钟表匠检查过，齿轮完好。"),
                ("值班的人撒谎", "那晚的值班记录有两个人作证。"),
                ("裂冠啸魔学会了旧暗号的节拍，在码头下面叫", "声音从水面下传来，不是从钟台上。")], correct: 2)
        ], waves: [[.crown, .saltSac], [.shieldJaw]], maxFloor: 90, material: M.silk),
        .init(id: "b04", area: "废印厂与公证柜台", leads: [
            lead("伪造母版已经销毁，可废印厂里夜夜有机器空转的声音。", "空转的是什么？", [
                ("印厂旧工偷偷开工", "旧工有值班证明，那晚在家。"),
                ("塔怪钻进旧机座，碰动了传动轴", "传动轴上有爪印，机座里有窝。"),
                ("三号旧机又被人装回去了", "母版已经销毁，三号机的底座是空的。")], correct: 1),
            lead("公证柜台收到一张没有印号的空白证书，边缘全是剪痕。", "剪痕是谁留的？", [
                ("剪肢螳魔在废纸堆里做窝，剪碎了旧证书", "剪痕是锯齿形的，和它的前肢一样。"),
                ("印章员", "印章员的裁纸刀是直刃。"),
                ("遗产领取者", "他只拿到了退还的合法证书。")], correct: 0)
        ], waves: [[.scissor, .copperback], [.shieldJaw]], maxFloor: 70, material: M.chitin),
        .init(id: "b05", area: "染坊后院与旧衣铺", leads: [
            lead("染坊后院封了，排水沟里的水还是红的。", "红水说明什么？", [
                ("染坊偷偷开工了", "染坊停业，账房没有新的进料。"),
                ("塔怪在翻泡着赤染料的旧桶", "桶被拖倒了，桶边有爪印。"),
                ("裁衣人还在作案", "裁衣人已被制止，现场一直封存。")], correct: 1),
            lead("旧衣铺后门挂着一截赤丝，打的是普通的结。", "这截赤丝是怎么来的？", [
                ("有人在模仿裁衣人", "裁衣人的记号是非法紧结，这只是普通结。"),
                ("衣铺老板自己挂的", "老板说他从不用赤丝。"),
                ("剪肢螳魔从染坊拖出来的废丝，钩在了门上", "丝头有剪断的锯口，门下有拖痕。")], correct: 2)
        ], waves: [[.scissor, .crown], [.shieldJaw]], maxFloor: 90, material: M.chitin),
        .init(id: "b06", area: "封舱台与报警钟楼", leads: [
            lead("封舱台清出来了，可压舱铅下面又有了新抓痕。", "抓痕是谁的？", [
                ("骨爪掠魔，爪距比人手宽得多", "爪距对得上，痕迹是新的。"),
                ("码头工搬货时留的", "码头工用撬棍，不留爪痕。"),
                ("海鸟", "海鸟抓不动压舱铅。")], correct: 0),
            lead("报警钟楼装了新钟舌，夜里却有东西在钟楼下撞门。", "该怎么处理？", [
                ("把钟舌拆下来，免得被偷", "钟要照常报警，不能拆。"),
                ("等港务员白天来处理", "撞门一夜比一夜重，拖不到白天。"),
                ("按撞痕的高度判断是塔怪，先清钟楼下的通道", "撞痕只到膝盖高，不是人。")], correct: 2)
        ], waves: [[.boneclaw], [.shieldJaw, .copperback]], maxFloor: 90, material: M.talon),
        .init(id: "b07", area: "木工街与第三间空屋", leads: [
            lead("夜班邮差说，昨夜又有门被敲了三声，这次声音细，像小孩。", "先去哪里蹲守？", [
                ("学堂门口，声音像小孩", "声音能被模仿，不能当作来源。"),
                ("门闩上有新黏液的木工街后巷", "黏液是新的，残余还在附近。"),
                ("第三间空屋", "空屋已经封存，封条完好。")], correct: 1),
            lead("修门工在排水口听到回声，同一句‘开门’响了七次，一次比一次尖。", "哪条痕迹说明是塔怪，不是有人恶作剧？", [
                ("排水泥里有缺趾的小爪印", "和结案时的缺趾爪痕一样，只是小一号。"),
                ("门上有粉笔记号", "那是孩子们玩的记号，和敲门无关。"),
                ("一共响了七次", "次数说明不了是谁。")], correct: 0)
        ], waves: [[.goldenThroat, .goldenThroat], [.shieldJaw]], maxFloor: 10, material: M.fiber),
        .init(id: "b08", area: "旧照相馆与相片铺", leads: [
            lead("旧照相馆封了，隔壁相片铺说暗房里还有东西在翻药瓶。", "怎么判断里面是塔怪，不是小偷？", [
                ("晚上有灯", "那是显影灯的定时器。"),
                ("门锁被撬过", "那是封存时教会开的，有记录。"),
                ("药瓶是被咬开的，地上有鳞屑", "人不会用牙开药瓶。")], correct: 2),
            lead("旧照相馆后巷的垃圾被翻得到处都是，底片散了一地。", "底片散落的方向说明什么？", [
                ("都朝着后巷的下水口，东西从那里进出", "底片被拖出了印子，一直拖到下水口。"),
                ("朝着相片铺，是店主扔的", "店主的废底片按规矩打包交给教会。"),
                ("被风吹散的", "后巷没有穿堂风。")], correct: 0)
        ], waves: [[.crimsonBrute, .moonfang], [.shieldJaw, .veilOracle]], maxFloor: 30, material: M.scale),
        .init(id: "b09", area: "废质押所与地下纸窖", leads: [
            lead("纸窖已经清空，民事柜台又收到两张被啃过的收据。", "是谁在啃？", [
                ("账房学徒", "他早已被证明清白，复写本也对得上。"),
                ("甲兽留下的幼体，齿印比原来小一号", "齿印一样歪，只是更小。"),
                ("老鼠", "鼠牙咬不出铜屑。")], correct: 1),
            lead("废质押所的破窗又被撞开，窗框上有新鲜的铜绿。", "先堵哪里？", [
                ("通往纸窖的排浆口", "铜绿一路滴到排浆口。"),
                ("质押所正门", "正门的教会封条没动过。"),
                ("隔壁仓库", "仓库地面干净，没有铜屑。")], correct: 0)
        ], waves: [[.copperback, .copperback], [.shieldJaw, .backSac]], maxFloor: 70, material: M.scale),
        .init(id: "b10", area: "封闭施济厅与守灯诊所", leads: [
            lead("转接链切断后，施济厅的空囊体还在收缩，发出低鸣。", "先处理什么？", [
                ("把囊体搬去诊所", "囊体没检验前不能离开封存区。"),
                ("被低鸣引来的塔怪在囊体旁筑了巢，先清巢", "巢是新的，低鸣一停它们就会散开找别的地方。"),
                ("烧掉旧账签", "账签是受害者的凭据，要归还。")], correct: 1),
            lead("守灯诊所说，最近有人拿着碎裂的账签来求治。", "账签从哪来？", [
                ("病人自己做的", "缺角和封存的原件一样，是真的。"),
                ("守灯诊所自己发的", "守灯诊所从不用账签。"),
                ("施济厅后院被翻开，塔怪把封存箱拖出来撕碎了", "后院有拖痕，箱角有齿印。")], correct: 2)
        ], waves: [[.veilOracle, .crown], [.boneclaw]], maxFloor: 90, material: M.silk)
    ]

    public static func remnant(_ caseID: String) -> MPCRemnantCase? { all.first { $0.id == caseID } }

    /// Today's case: one a day, rotating over the closed cases in catalog order;
    /// the lead alternates each time the rotation comes round.
    public static func today(day: Int, closedCaseIDs: Set<String>) -> (remnant: MPCRemnantCase, lead: Int)? {
        let closed = all.filter { closedCaseIDs.contains($0.id) }
        guard !closed.isEmpty, day >= 1 else { return nil }
        return (closed[day % closed.count], (day / closed.count) % 2)
    }

    /// The fight's band: the case's own cap, or the player's last cleared tenth if lower (at least F10).
    public static func band(_ remnant: MPCRemnantCase, highestTowerFloor: Int) -> Int {
        min(remnant.maxFloor, max(10, highestTowerFloor / 10 * 10))
    }

    public static func encounterID(caseID: String, band: Int, ticket: String) -> String {
        prefix + caseID + "-f\(band)_" + ticket
    }
    public static func encounter(id: String) -> MPCEncounterContent? {
        guard let parsed = MPCStreetEncounters.parse(id, prefix: prefix) else { return nil }
        let parts = parsed.key.components(separatedBy: "-f")
        guard parts.count == 2, let remnant = remnant(parts[0]), let band = Int(parts[1]),
              band.isMultiple(of: 10), (10...remnant.maxFloor).contains(band) else { return nil }
        return MPCStreetEncounters.content(id: id, name: remnant.title, tag: "remnant", waves: remnant.waves, floor: band)
    }
}

/// One save's remnant cases, one per day. A case accepted today may be finished on a
/// later day (within a week), but days not taken are gone: nothing banks up.
public struct MPCRemnantLedger: Codable, Equatable, Sendable {
    public enum Failure: Error, Equatable { case noCase, notAccepted, invalidChoice, unsolved, closed, pending, invalidBattle }
    public static let keptDays = 7

    public struct Job: Codable, Equatable, Sendable {
        public let day: Int
        public let caseID: String
        public let lead: Int
        public let band: Int
        public fileprivate(set) var excludedChoiceIDs: Set<String> = []
        public fileprivate(set) var solved = false
        public fileprivate(set) var activeTicket: String?
        public fileprivate(set) var settledTickets: Set<String> = []
        public fileprivate(set) var won = false
        public fileprivate(set) var claimed = false
        public var receiptID: String { "remnant-d\(day)" }
        public var remnant: MPCRemnantCase? { MPCRemnantCatalog.remnant(caseID) }
        public var encounterID: String? { activeTicket.map { MPCRemnantCatalog.encounterID(caseID: caseID, band: band, ticket: $0) } }
    }

    public private(set) var jobs: [String: Job] = [:]
    public init() {}

    static func key(_ day: Int) -> String { "d\(day)" }
    public func job(day: Int) -> Job? { jobs[Self.key(day)] }

    /// Takes today's case (or returns it if already taken). The band is fixed at acceptance.
    @discardableResult
    public mutating func accept(day: Int, closedCaseIDs: Set<String>, highestTowerFloor: Int) throws -> Job {
        if let job = job(day: day) { return job }
        guard let today = MPCRemnantCatalog.today(day: day, closedCaseIDs: closedCaseIDs) else { throw Failure.noCase }
        jobs = jobs.filter { $0.value.day >= day - Self.keptDays || $0.value.activeTicket != nil }
        let job = Job(day: day, caseID: today.remnant.id, lead: today.lead,
                      band: MPCRemnantCatalog.band(today.remnant, highestTowerFloor: highestTowerFloor))
        jobs[Self.key(day)] = job
        return job
    }

    /// A wrong answer is struck out at no cost, as in church maintenance.
    @discardableResult
    public mutating func answer(day: Int, choiceID: String) throws -> Bool {
        guard var job = job(day: day), let remnant = job.remnant else { throw Failure.notAccepted }
        guard !job.solved else { return true }
        let lead = remnant.leads[job.lead]
        guard lead.choices.contains(where: { $0.id == choiceID }), !job.excludedChoiceIDs.contains(choiceID) else { throw Failure.invalidChoice }
        let correct = choiceID == lead.correctChoiceID
        if correct { job.solved = true } else { job.excludedChoiceIDs.insert(choiceID) }
        jobs[Self.key(day)] = job
        return correct
    }

    public mutating func beginBattle(day: Int, ticket: String) throws -> String {
        guard var job = job(day: day) else { throw Failure.notAccepted }
        guard job.solved else { throw Failure.unsolved }
        guard !job.won else { throw Failure.closed }
        if let active = job.activeTicket {
            guard active == ticket else { throw Failure.pending }
            return job.encounterID!
        }
        guard MPCStreetEncounters.validTicket(ticket),
              !jobs.values.contains(where: { $0.activeTicket == ticket || $0.settledTickets.contains(ticket) }) else { throw Failure.invalidBattle }
        job.activeTicket = ticket
        jobs[Self.key(day)] = job
        return job.encounterID!
    }

    @discardableResult
    public mutating func settleBattle(day: Int, ticket: String, session: MPCChapterOneEncounterSession) throws -> Bool {
        guard var job = job(day: day) else { throw Failure.notAccepted }
        if job.settledTickets.contains(ticket) { return false }
        guard job.activeTicket == ticket, session.encounter.id == job.encounterID, session.outcome != .inProgress else {
            throw Failure.invalidBattle
        }
        job.activeTicket = nil
        job.settledTickets.insert(ticket)
        if session.outcome == .victory { job.won = true }
        jobs[Self.key(day)] = job
        return true
    }

    public mutating func abandonBattle(day: Int, ticket: String) {
        guard var job = job(day: day), job.activeTicket == ticket else { return }
        job.activeTicket = nil
        job.settledTickets.insert(ticket)
        jobs[Self.key(day)] = job
    }

    /// Pays once after the win: copper through today's taper, then the area's material.
    /// Returns nil when already claimed.
    public mutating func claim(day: Int, today: Int, work: inout MPCDailyWorkLedger,
                               coins: inout Int, inventory: inout [String: Int]) throws -> MPCDailyWorkLedger.Payout? {
        guard var job = job(day: day), let remnant = job.remnant else { throw Failure.notAccepted }
        if job.claimed { return nil }
        guard job.won else { throw Failure.unsolved }
        let payout = work.settle(receiptID: job.receiptID, day: today, copper: MPCRemnantCatalog.copper, merit: 0)
        coins += payout.copper
        inventory[remnant.material, default: 0] += MPCRemnantCatalog.materialCount
        job.claimed = true
        jobs[Self.key(day)] = job
        return payout
    }
}
