import Foundation

/// Multi-step street tasks (HOME_MAP_STREET_TASKS_20260929.md §4.1, §6.2), written
/// 2026-09-30 for the three kinds city contribution opens:
/// - urgent errands (tier 2): one a day on the plaza board, 3 steps, 15 copper;
/// - joint errands (tier 3): on every third day, two or three neighbours' requests in
///   one chain of 4–5 steps, 30 copper, each of them +1 affinity;
/// - city commissions (tier 4): one a week from the harbour office or city hall,
///   5–6 steps, 60 copper; finishing one adds a permanent scene to the home painting.
/// Every step is "find the right person or place and do one thing". The rules decide who
/// is lit and whether a step is done; the home map only draws and walks.
public struct MPCStreetStep: Equatable, Sendable {
    public enum Action: String, Codable, Sendable {
        /// Talk to the target.
        case talk
        /// Hand the target workshop goods.
        case handOver
        /// A three-way question at the target; a wrong answer is struck out at no cost.
        case answer
        /// A small street fight at the target.
        case battle
    }
    /// A neighbour ID (harbor-pedestrians.json) or a home-map place (`MPCStreetTaskCatalog.places`).
    public let target: String
    public let action: Action
    /// The task bar's line: what to do now.
    public let goal: String
    /// What is said when the step is done.
    public let line: String
    public var items: [String: Int] = [:]
    public var question: String?
    public var choices: [MPCChurchBountyChoice] = []
    public var correctChoiceID: String?
    public var pests: [MPCChurchTowerCatalog.Species] = []

    public var isPerson: Bool { MPCNeighborCatalog.neighbor(target) != nil }

    static func talk(_ target: String, _ goal: String, _ line: String) -> Self {
        .init(target: target, action: .talk, goal: goal, line: line)
    }
    static func give(_ target: String, _ goal: String, _ item: String, _ count: Int, _ line: String) -> Self {
        .init(target: target, action: .handOver, goal: goal, line: line, items: [item: count])
    }
    static func ask(_ target: String, _ goal: String, _ question: String, _ choices: [(String, String)], correct: Int, _ line: String) -> Self {
        let ids = ["a", "b", "c"]
        return .init(target: target, action: .answer, goal: goal, line: line, question: question,
                     choices: choices.enumerated().map { .init(id: ids[$0], text: $1.0, explanation: $1.1) }, correctChoiceID: ids[correct])
    }
    static func fight(_ target: String, _ goal: String, _ pests: [MPCChurchTowerCatalog.Species], _ line: String) -> Self {
        .init(target: target, action: .battle, goal: goal, line: line, pests: pests)
    }
}

public struct MPCStreetTask: Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable, CaseIterable { case urgent, joint, commission }
    public let id: String
    public let kind: Kind
    public let title: String
    /// Who posts it: a neighbour, or `harbor` / `cityhall` for a commission.
    public let giverID: String
    /// The notice on the board or the office counter.
    public let request: String
    public let steps: [MPCStreetStep]
    public let thanks: String
    /// Neighbours whose affinity rises by one when it is done.
    public let neighbors: [String]
    /// Commissions only: the `commissionDecals` site shown on the home painting once done.
    public let sceneID: String?

    public var copper: Int {
        switch kind {
        case .urgent: 15
        case .joint: 30
        case .commission: 60
        }
    }
    /// Urgent and joint tasks count as errands for city contribution; commissions do not.
    public var contributionSource: MPCCityContribution.Source? { kind == .commission ? nil : .errand }
    public var feature: MPCCityContribution.Feature {
        switch kind {
        case .urgent: .urgentErrand
        case .joint: .jointErrand
        case .commission: .cityCommission
        }
    }
}

extension MPCStreetTaskCatalog {
    /// Buildings and street spots of the home map (home-map-layout.json). `housing` (赁屋行)
    /// and `highland-board` (高地告示处) came with the housing work on main; no street task
    /// uses them yet.
    public static let places: Set<String> = [
        "palace", "church", "bank", "science", "newspaper", "cityhall", "police", "industry", "tavern",
        "post", "clinic", "harbor", "oldstreet", "board", "cafe", "drain", "blockade-notice",
        "housing", "highland-board",
    ]
    public static let streetPrefix = "church_maintenance_street_"

    static var strap: String { MPCCraftingCatalog.strapID }
    static var salve: String { MPCCraftingCatalog.salveID }
    static var cloth: String { MPCCraftingCatalog.clothID }
    static var patch: String { MPCCraftingCatalog.patchID }

    static func urgent(_ giver: String, _ title: String, _ request: String, _ steps: [MPCStreetStep], thanks: String) -> MPCStreetTask {
        .init(id: "urgent-" + MPCNeighborCatalog.slug(giver), kind: .urgent, title: title, giverID: giver, request: request,
              steps: steps, thanks: thanks, neighbors: [giver], sceneID: nil)
    }

    /// One urgent errand per neighbour; the day's poster is the neighbour opposite today's askers.
    public static let urgentErrands: [MPCStreetTask] = [
        urgent("postman", "急件送诊所", "邮包里混进一封急件，收件人写的是诊所，下午就要用。我还有半条街没送完。", [
            .talk("postman", "找邮差取急件", "就这封，火漆是红的，别压着。"),
            .talk("clinic", "把急件送到诊所", "是药方的回执！正等着它配药。"),
            .talk("postman", "回邮差那里销单", "销了。今天这一包总算一封都没晚。")
        ], thanks: "急件没误，诊所那边会记着邮局的好。"),
        urgent("west-lane", "今晚的新门牌", "新搬来的一户今晚就要住进去，可门上还钉着旧号。", [
            .talk("west-lane", "到登记员那里拿新门牌", "十七号改成四十二号。钉歪了，他们会敲错门。"),
            .give("oldstreet", "到旧街把门牌垫平钉牢", patch, 1, "垫上铁片，门牌不晃了。"),
            .talk("west-lane", "回登记员那里改簿子", "簿子也改好了。")
        ], thanks: "今晚这一户不会敲错门了。"),
        urgent("baker", "早市前的烟道", "炉子的烟道堵了，面包出不了炉，得赶在早市前通开。", [
            .talk("baker", "问面包师烟道是怎么堵的", "烟从后墙倒灌。昨夜屋顶那截烟道里一直有吱吱声，还有爪子挠的声音。"),
            .ask("upper-road", "问上坡守灯人昨夜在屋顶看见了什么", "屋顶那截烟道为什么堵？", [
                ("鸟在烟道口做了窝", "这个季节鸟不在雾港筑巢，也不会挠。"),
                ("一只小塔怪钻进去取暖", "吱吱声和爪子声都对得上，烟道口还有烤焦的毛。"),
                ("风把瓦片吹进了烟道", "瓦片都在原处，也不会叫。")], correct: 1,
                 "是只小塔怪，天一冷就往烟道里钻。拿长钩一掏就出来。"),
            .talk("baker", "回去告诉面包师", "塔怪？我这就让伙计拿长钩去掏。早市赶得上。")
        ], thanks: "炉子通了。早市第一炉面包，给你留了一个。"),
        urgent("cafe-lane", "送奶船", "今晚有船回港，店里的奶不够了，得去码头找送奶船。", [
            .talk("cafe-lane", "问跑堂要多少奶", "两桶。店主说船一靠岸，喝咖啡的人就排到街口。"),
            .talk("dockworker", "请码头工人帮忙找送奶船", "送奶船在二号栈桥。我帮你扛一桶上来。"),
            .talk("cafe-lane", "把奶送回咖啡馆", "赶上了！今晚每杯都能加奶。")
        ], thanks: "店主让我谢谢你，还说你下回来，第一杯不收钱。"),
        urgent("east-houses", "雾夜的灯油", "今晚起雾，我的灯油不够点到码头。", [
            .talk("east-houses", "问提灯人还差多少油", "差一壶。上坡守灯人手里还有存货，只是他不爱出门。"),
            .talk("upper-road", "向上坡守灯人借一壶灯油", "拿去。下个月他还我就是。"),
            .talk("east-houses", "把灯油交给东岸提灯人", "够了，今晚四十一盏都能亮。")
        ], thanks: "雾再大，码头这条路也看得见。"),
        urgent("courier", "涨潮前的急件", "港务处的急件要在涨潮前送上船，我腿都跑软了。", [
            .talk("courier", "找信使取急件", "急件还没盖放行印，港务处不盖，船上不收。"),
            .talk("harbor", "到港务处盖放行印", "印盖好了。快，潮水要涨了。"),
            .talk("sailor-walk", "把急件交给离港水手", "正是船长等的。你再晚一刻，我们就得带着空信袋出海了。")
        ], thanks: "赶上了？好。下回换我替你跑一趟。"),
        urgent("clockmaker", "正午的报时锤", "钟台的报时锤卡住了，正午前修不好，整条街都会误点。", [
            .talk("clockmaker", "听钟表匠说哪儿卡住了", "锤轴里卡着东西，还会动。我够不着，你个子高。"),
            .fight("church", "爬上钟台赶走卡在锤轴里的塔怪", [.goldenThroat], "塔怪一跑，锤子当地一声落下来。"),
            .talk("clockmaker", "回钟表匠那里对时", "差两分，我拨回来——好了。")
        ], thanks: "正午的钟会准时响。"),
        urgent("market-lane", "婚礼的花篮", "有人订了一篮花，午后要送到市政厅的婚礼上，花商走不开。", [
            .talk("market-lane", "问帮工花篮在哪", "花商在摊子后面包。你去取，我守摊。"),
            .talk("florist", "找花商取包好的花篮", "包好了。别倒着拿，花会折。"),
            .talk("cityhall", "把花篮送到市政厅", "正好，新人刚到。替我们谢谢花摊。")
        ], thanks: "送到了？花商今天会多给我一块饼。"),
        urgent("florist", "码头上的花苗", "一船花苗到了码头，得赶在晒蔫前搬进阴凉处。", [
            .talk("florist", "问花商花苗在哪条船", "蓝帆那条。四十盆，别叠着放。"),
            .talk("dockworker", "请码头工人帮忙搬花苗", "搬到仓库阴面了，放心。"),
            .give("florist", "给花商两块过滤布遮阳", cloth, 2, "盖上了，一棵都没蔫。")
        ], thanks: "这一批能活，明年春天广场全是它们。"),
        urgent("clock-square", "老船长的生日", "老船长今天生日，我想在他下船前把礼物送到。别让他知道是我。", [
            .talk("clock-square", "问水手礼物在哪", "在商人那儿订了只烟斗，钱付过了。"),
            .talk("merchant", "到商人那里取烟斗", "包好了，别让海水溅着。"),
            .talk("harbor", "赶在老船长下船前送到码头", "他收下了，没说话，拍了拍我的肩。")
        ], thanks: "他拍你肩膀了？那就是高兴了。他从来不说出口。"),
        urgent("dockworker", "查货前的封签", "一只货箱的封签松了，港务的人待会儿要来查。", [
            .talk("dockworker", "问码头工人是哪只货箱", "最里面那只。封签得去港务处领新的。"),
            .talk("harbor", "到港务处领一张新封签", "新封签，编号要和单子对上。"),
            .give("dockworker", "给码头工人两条维修绑带扎紧货箱", strap, 2, "扎紧了，封签贴正了。")
        ], thanks: "查的人来了，一眼就过。今天少挨一顿骂。"),
        urgent("south-quay", "风里的船期表", "今天的船期表要在开市前贴出去，可墨还没干，风又大。", [
            .talk("south-quay", "从抄账员那里拿船期表", "小心，墨还湿。要是能借块铅条压着就好了。"),
            .talk("newspaper", "向报馆借一块压纸的铅条", "拿去，记得还。"),
            .talk("board", "把船期表贴到委托板旁", "贴好了，压牢了，风吹不走。")
        ], thanks: "开市的人都看得见了。铅条我下午去还。"),
        urgent("musician", "送别会的琴弦", "今晚码头有送别会，我的琴弦断了一根。", [
            .talk("musician", "看看乐师缺哪根弦", "最细的那根。商人那儿什么都有，也许有。"),
            .talk("merchant", "问商人有没有琴弦", "有一卷羊肠弦，本来是修帆用的，拿去试试。"),
            .talk("musician", "把琴弦交给乐师", "音准了。")
        ], thanks: "今晚这首《回港》，第一遍拉给你听。"),
        urgent("upper-road", "冻住的坡道", "上坡那段路冻了，天黑前得撒上砂，不然车会往下滑。", [
            .talk("upper-road", "问守灯人要撒多少砂", "一袋就够。工坊区炉渣筛出来的粗砂最好。"),
            .talk("industry", "到工坊区要一袋粗砂", "拿去，炉渣筛的，不值钱。"),
            .talk("upper-road", "把砂交给守灯人", "撒上了。")
        ], thanks: "今晚的车能停得住了。"),
        urgent("cathedral-road", "转院的担架", "诊所的伤者要转到教会，担架还缺人抬另一头。", [
            .talk("cathedral-road", "找教会跑腿搭把手", "你抬后头，我在前面看路。"),
            .talk("clinic", "到诊所接伤者", "轻点抬，他腿上的夹板刚绑好。"),
            .talk("church", "把伤者送到教会", "床铺好了。一路没颠着他。")
        ], thanks: "他睡着了。谢谢你，走得那么稳。"),
        urgent("flower-seller-walk", "雨前的紫藤", "野坡上的紫藤开了。今天不剪，明天一场雨就全落了。", [
            .talk("flower-seller-walk", "问花贩紫藤在哪片坡", "旧街后坡，可那儿蹲着一只塔怪。"),
            .fight("oldstreet", "到旧街后坡赶走守着紫藤的塔怪", [.moonfang, .moonfang], "塔怪跑了，紫藤还在。"),
            .talk("flower-seller-walk", "帮花贩把紫藤背回来", "满满一筐。")
        ], thanks: "这一筐够卖到周末。你挑一枝，别客气。"),
        urgent("sailor-walk", "提前开的船", "船提前开了！我的铺盖还在酒馆楼上。", [
            .talk("sailor-walk", "问水手铺盖放在哪", "酒馆楼上第二间，床底下。"),
            .talk("tavern", "到酒馆楼上取水手的铺盖", "他的东西都在这儿，一件没少。"),
            .talk("harbor", "赶在开船前送到码头", "接住了！")
        ], thanks: "下回回港，我请你喝一杯。"),
        urgent("archive-apprentice-walk", "虫蛀的封皮", "一卷旧名册要在下午交给市政厅，可封皮被虫蛀了，一碰就掉渣。", [
            .talk("archive-apprentice-walk", "看看学徒手里的名册", "就是这卷。得先包起来，不然送到一半就散了。"),
            .give("archive-apprentice-walk", "给学徒一块过滤布包封皮", cloth, 1, "包好了，不会再掉渣。"),
            .talk("cityhall", "把名册送到市政厅", "准时。书记官说，这卷他们找了三年。")
        ], thanks: "书记官夸我了。其实是你跑的腿。"),
        urgent("cafe_keeper", "走错门的记者", "报馆的记者约了今天在店里采访，可到现在都没来。", [
            .talk("cafe_keeper", "问店主约了几点", "约的是十点。他说店招是蓝的……可我的店招前天被人挪了。"),
            .talk("newspaper", "去报馆找记者", "我在对街那家等了半天！原来招牌被挪了。"),
            .talk("cafe", "带记者回咖啡馆", "来了就好。")
        ], thanks: "第一杯我请。采访登出来，你也有一份功劳。"),
        urgent("street_warden", "被撕的公告", "巷口的封锁公告被人撕了，天黑前得重新贴上。", [
            .talk("street_warden", "问巡街人公告要去哪领", "警署有备份，盖了章的才作数。"),
            .talk("police", "到警署领一张新公告", "盖了章的，别折。"),
            .talk("blockade-notice", "把公告贴回巷口", "贴好了，这回用的双层浆糊。")
        ], thanks: "今晚这条巷子不会有人误闯了。"),
        urgent("scholar", "到期前的一页", "借来的书明天到期，我还差一页没抄完，墨却用光了。", [
            .talk("scholar", "问学者要什么墨", "黑的就行，稀一点也不怕。"),
            .talk("newspaper", "向报馆讨一瓶墨", "印报的油墨太稠，兑点水再用。"),
            .talk("scholar", "把墨交给学者", "够抄完了。")
        ], thanks: "书能准时还了。借书的人守时，下回才借得出来。"),
        urgent("merchant", "写错的货单", "一批布今天到港，可货单上的数目写错了，得在卸货前改。", [
            .talk("merchant", "拿商人的货单去核对", "单子上写一百匹。可那条船小，货舱顶多装十来匹。"),
            .ask("south-quay", "请港务抄账员核对货单", "货单上哪一处写错了？", [
                ("匹数多写了一个零", "那条船的货舱装不下一百匹，十匹才对。"),
                ("船名写错了", "船名和登记簿一致。"),
                ("到港日期写错了", "日期是今天，对的。")], correct: 0, "改成十匹，我盖个章。"),
            .talk("merchant", "回商人那里签字", "改好了。")
        ], thanks: "差点多交九十匹的税。这份人情我记下了。"),
        urgent("visitor", "丢了寄存牌", "我今晚就坐车离开，可行李寄存的牌子丢了。", [
            .talk("visitor", "问旅人行李什么样", "一只旧皮箱。我在旅店门口折了一枝紫藤，别在箱把上。"),
            .ask("post", "到邮局寄存处认领行李", "寄存员问：你的箱子是哪一只？", [
                ("绿色的帆布箱", "绿箱子是另一位客人的。"),
                ("箱把上别着一枝紫藤的旧皮箱", "旅人说过，他折了一枝紫藤别在箱把上。"),
                ("没有锁的木箱", "旅人的箱子带锁。")], correct: 1, "是这只。签个字就能拿走。"),
            .talk("visitor", "把行李交给旅人", "就是它！")
        ], thanks: "雾港的人都这么热心吗？我会想念这里的。"),
    ]

    /// Joint errands, in the order they are posted.
    public static let jointErrands: [MPCStreetTask] = [
        .init(id: "joint-wedding", kind: .joint, title: "婚礼前夜", giverID: "florist",
              request: "市政厅明天办婚礼，花拱、喜饼、乐曲都还没着落。花商、面包师、乐师各管一样，得有人把三头串起来。",
              steps: [
                .talk("florist", "向花商订花拱", "花拱要紫藤和白花，我今晚扎。就差两块过滤布裹花根。"),
                .give("florist", "给花商两块过滤布", cloth, 2, "够了。你去问面包师，喜饼能不能赶出来。"),
                .talk("baker", "问面包师喜饼能不能赶出来", "三层，傍晚出炉。婚礼上的曲子定了吗？"),
                .talk("musician", "请乐师明天在市政厅拉琴", "新人第一支舞……就拉《雾散》。"),
                .talk("cityhall", "回市政厅报备", "花、饼、琴都定了。明天见。")
              ], thanks: "花拱、喜饼、曲子，一样不差。新人说要请你们三位喝喜酒。",
              neighbors: ["florist", "baker", "musician"], sceneID: nil),
        .init(id: "joint-night-shift", kind: .joint, title: "码头的夜班", giverID: "south-quay",
              request: "今夜有船进港。账要记、货要卸、栈桥要点灯，三头都得对上。",
              steps: [
                .talk("south-quay", "问抄账员今晚哪条船进港", "‘灰鸥’号，半夜到，装的是盐和布。"),
                .talk("dockworker", "通知码头工人留人卸货", "我留三个人。可栈桥那段黑，得有灯。"),
                .talk("east-houses", "请提灯人今晚多点两盏栈桥灯", "我点。可那段栈桥底下常有东西爬。"),
                .fight("harbor", "清掉栈桥底下的塔怪", [.copperback, .moonfang], "栈桥干净了。"),
                .talk("south-quay", "回抄账员那里登记", "灯、人、船都记上了。")
              ], thanks: "今晚不会乱。‘灰鸥’号的船长会知道，雾港的夜班靠得住。",
              neighbors: ["south-quay", "dockworker", "east-houses"], sceneID: nil),
        .init(id: "joint-missing-page", kind: .joint, title: "丢了的第十七页", giverID: "archive-apprentice-walk",
              request: "旧名册少了第十七页，那一页记着旧街的住户。学者抄过几份，登记员有门牌簿，得三个人对一对。",
              steps: [
                .talk("archive-apprentice-walk", "听学徒说少了哪一页", "第十七页，旧街的住户，门牌重编以前的。"),
                .ask("scholar", "问学者手里哪份抄本是真的第十七页", "学者摊开三份抄本，哪份才是原来的第十七页？", [
                    ("纸色发黄、写着旧门牌号的那份", "门牌重编以前抄的，号码和名册对得上。"),
                    ("字迹最工整的那份", "工整的是誊清本，门牌已经是新号了。"),
                    ("盖着市政厅印的那份", "印是后来补盖的，日期比名册晚了十年。")], correct: 0, "就是它。我当年抄得急，墨都洇了。"),
                .talk("west-lane", "请登记员对照门牌簿", "对得上：十七号那户姓苏，后来搬走了。"),
                .talk("archive-apprentice-walk", "把抄页交还学徒", "补上了。")
              ], thanks: "名册总算完整了。三个人凑出来的一页，比原来那页还清楚。",
              neighbors: ["archive-apprentice-walk", "scholar", "west-lane"], sceneID: nil),
        .init(id: "joint-soup-day", kind: .joint, title: "教会的施粥日", giverID: "cathedral-road",
              request: "明天教会施粥，碗不够，锅也不够。商人有碗，咖啡馆有大锅。",
              steps: [
                .talk("cathedral-road", "问跑腿施粥还缺什么", "缺碗，也缺一口大锅。"),
                .talk("merchant", "找商人借一箱碗", "借，不要钱。碗底有我的记号，用完送回来。"),
                .talk("cafe_keeper", "请咖啡馆店主借一口大锅", "锅借你，再送一壶热咖啡给排队的人。"),
                .talk("church", "把碗和锅送到教会", "齐了。")
              ], thanks: "今天来的人都喝上了热的。有人问是谁张罗的，我说了你们三个的名字。",
              neighbors: ["cathedral-road", "merchant", "cafe_keeper"], sceneID: nil),
        .init(id: "joint-lamp-oil", kind: .joint, title: "掺了水的灯油", giverID: "upper-road",
              request: "上坡的灯一盏盏灭了。灯油是从商人那儿进的，得查清楚是怎么回事。",
              steps: [
                .talk("upper-road", "问守灯人灯为什么灭", "上个月那批油点不亮，一烧就噼啪响。"),
                .ask("merchant", "到商人那里查这批油", "这批灯油是怎么掺进水的？", [
                    ("运油船漏进了海水，沉在桶底", "桶底有一层咸水，桶箍锈穿了一圈。"),
                    ("有人故意兑了水", "桶封没被撬开过。"),
                    ("雨水从桶盖渗了进去", "桶盖是蜡封的，是干的。")], correct: 0, "是桶漏了。我给他换一桶好的。"),
                .talk("east-houses", "请提灯人先分一壶好油", "拿去。换桶的事我跟商人说。"),
                .talk("upper-road", "把好油交给守灯人", "点上了。")
              ], thanks: "今晚上坡不会黑。商人答应以后每桶都先开盖看一眼。",
              neighbors: ["upper-road", "merchant", "east-houses"], sceneID: nil),
        .init(id: "joint-home-letter", kind: .joint, title: "赶邮船的家书", giverID: "visitor",
              request: "旅人想给北港的家里寄信，今天的邮船就要走了。邮差封了包，信使也许还追得上。",
              steps: [
                .talk("visitor", "从旅人那里接过家书", "家在北港，信要赶今天的邮船。"),
                .talk("postman", "把信交给邮差", "北港的邮包已经封了。你去问信使，还追不追得上。"),
                .talk("courier", "请信使追邮船", "我跑一趟。可码头那边有只塔怪蹲在邮筒上。"),
                .fight("harbor", "赶走蹲在邮筒上的塔怪", [.goldenThroat, .moonfang], "邮筒口空出来了。"),
                .talk("visitor", "告诉旅人信寄出了", "寄出了？")
              ], thanks: "谢谢你们。雾港的邮差，比我家乡的还快。",
              neighbors: ["visitor", "postman", "courier"], sceneID: nil),
        .init(id: "joint-bench", kind: .joint, title: "广场的长椅", giverID: "street_warden",
              request: "广场那张长椅被人挪来挪去，水手和乐师吵了一早上。巡街人想请人去说和。",
              steps: [
                .talk("street_warden", "问巡街人出了什么事", "两个人都要那张长椅，谁也不让。"),
                .talk("clock-square", "问水手为什么要那张长椅", "我在那儿坐了二十年，能看见港口。"),
                .talk("musician", "问乐师为什么要那张长椅", "那儿回声最好，琴声能传到码头。"),
                .talk("street_warden", "请巡街人把长椅挪到钟楼正下方", "挪好了：水手看得见港口，琴声也传得到码头。")
              ], thanks: "两个人都不吵了。水手还点了一首歌——头一回。",
              neighbors: ["street_warden", "clock-square", "musician"], sceneID: nil),
        .init(id: "joint-awning", kind: .joint, title: "花摊的遮棚", giverID: "market-lane",
              request: "花摊的遮棚被风掀了，花都晒着。帮工一个人搭不起来。",
              steps: [
                .talk("market-lane", "问帮工棚子怎么了", "棚架的绳子断了，得重新绑。"),
                .give("market-lane", "给帮工三条维修绑带绑棚架", strap, 3, "绑上了。还得有人扶着。"),
                .talk("flower-seller-walk", "请流动花贩帮忙扶棚", "我扶。可别告诉花商是我帮的。"),
                .talk("florist", "告诉花商棚子搭好了", "……是那个流动花贩帮的吧？绑带上打的是她的结。")
              ], thanks: "替我谢谢她。明天剪下的紫藤，分她一半。",
              neighbors: ["market-lane", "flower-seller-walk", "florist"], sceneID: nil),
    ]

    /// City commissions, one a week in this order; each changes the home painting once.
    public static let cityCommissions: [MPCStreetTask] = [
        .init(id: "commission-fountain", kind: .commission, title: "喷泉广场的花与旗", giverID: "cityhall",
              request: "市政厅：广场喷泉修好一年了，还是光秃秃的。市里拨了款，请你把花坛和彩旗张罗起来。",
              steps: [
                .talk("cityhall", "到市政厅领工单", "工单：矮石花坛一圈，彩旗三串。石料找工坊区，花找花商，彩旗找咖啡馆店主——她那儿有旧帆布。"),
                .talk("industry", "到工坊区订花坛石料", "矮石有现成的，下午送到广场。"),
                .talk("florist", "请花商挑当季的花", "白的、黄的、粉的、紫的，挑耐盐雾的，明早种下去。"),
                .give("cafe_keeper", "给咖啡馆店主两块过滤布缝彩旗", cloth, 2, "旧帆布配过滤布，三串彩旗，傍晚缝好。"),
                .fight("board", "清掉喷泉池底筑窝的塔怪", [.goldenThroat, .goldenThroat], "池底干净了，花坛可以砌了。"),
                .talk("cityhall", "回市政厅交工", "我去看过了，花坛和彩旗都好了。")
              ], thanks: "广场从今天起，是雾港最好看的地方。市政厅会记住这一笔。",
              neighbors: [], sceneID: "fountain"),
        .init(id: "commission-yard", kind: .commission, title: "货场的新帆布", giverID: "harbor",
              request: "港务处：工坊货场的吊臂空着，货箱也没有封签。港务处要挂上新帆布，把封签货箱堆整齐。",
              steps: [
                .talk("harbor", "到港务处领工单", "帆布要深蓝配浅金，绣港务锚记；货箱要贴封签。封签找抄账员，帆布找商人，挂帆布的绳子你来做。"),
                .talk("merchant", "向商人订深蓝帆布", "深蓝配浅金，锚记请裁缝绣上。明天到货。"),
                .give("dockworker", "给码头工人三条维修绑带挂帆布", strap, 3, "绳子够结实，吊臂上挂稳了。"),
                .talk("south-quay", "到抄账员那里领封签", "八张封签，编号连着，一张都别弄丢。"),
                .fight("industry", "赶走占了货堆的铜背甲兽", [.copperback, .copperback], "货堆腾出来了，箱子可以码了。"),
                .talk("harbor", "回港务处交工", "帆布挂起来了，货箱也封好了。")
              ], thanks: "远远看过去，那片货场总算像个港口的样子了。",
              neighbors: [], sceneID: "yard"),
    ]

    public static var streetTasks: [MPCStreetTask] { urgentErrands + jointErrands + cityCommissions }
    public static func streetTask(_ id: String) -> MPCStreetTask? { streetTasks.first { $0.id == id } }

    /// The neighbour who posts the day's urgent errand: opposite today's askers in the rotation.
    public static func urgentErrand(day: Int) -> MPCStreetTask {
        let neighbor = MPCNeighborCatalog.all[(MPCNeighborCatalog.rotationStart(day: day) + 11) % MPCNeighborCatalog.all.count]
        return urgentErrands.first { $0.giverID == neighbor.id }!
    }
    /// Joint errands are posted on every third day.
    public static func jointErrand(day: Int) -> MPCStreetTask? {
        day.isMultiple(of: 3) ? jointErrands[(day / 3) % jointErrands.count] : nil
    }
    /// A commission stays up for seven days; the next is posted seven days after the last.
    public static let commissionDays = 7

    /// Street fights are small: early bodies, a chore rather than a tower floor.
    public static func streetFloor(_ kind: MPCStreetTask.Kind) -> Int {
        switch kind {
        case .urgent: 10
        case .joint: 15
        case .commission: 20
        }
    }
    public static func streetEncounterID(taskID: String, step: Int, ticket: String) -> String {
        streetPrefix + taskID + "-s\(step)_" + ticket
    }
    public static func streetEncounter(id: String) -> MPCEncounterContent? {
        guard let parsed = MPCStreetEncounters.parse(id, prefix: streetPrefix),
              let cut = parsed.key.range(of: "-s", options: .backwards), let step = Int(parsed.key[cut.upperBound...]),
              let task = streetTask(String(parsed.key[..<cut.lowerBound])), task.steps.indices.contains(step),
              task.steps[step].action == .battle else { return nil }
        return MPCStreetEncounters.content(id: id, name: task.title, tag: "street",
                                           waves: [task.steps[step].pests], floor: streetFloor(task.kind))
    }

    /// Home-map targets for street tasks: the poster before a task is taken, then the
    /// current step's person or place.
    public static func streetTargets(_ ledger: MPCStreetTaskLedger) -> [MPCStreetTaskTarget] {
        ledger.offers.compactMap { offer -> MPCStreetTaskTarget? in
            guard let task = offer.task, !offer.done else { return nil }
            let kind: MPCStreetTaskTarget.Kind = task.kind == .commission ? .commission : task.kind == .joint ? .jointErrand : .urgentErrand
            guard offer.accepted else {
                let place = task.kind == .commission ? task.giverID : "board"
                return .init(id: offer.id + ":post", taskID: offer.id, kind: kind, placeID: place, title: task.title)
            }
            guard let step = offer.step else { return nil }
            return .init(id: offer.id + ":\(offer.stepIndex)", taskID: offer.id, kind: kind,
                         personID: step.isPerson ? step.target : nil, placeID: step.isPerson ? nil : step.target,
                         title: task.title + " · " + step.goal)
        }
    }
}

/// One save's street tasks. Offers appear by city-contribution tier and lapse at the end
/// of their window (urgent: the day; joint: the day after; commission: seven days) unless
/// a street fight is under way. A finished task pays once.
public struct MPCStreetTaskLedger: Codable, Equatable, Sendable {
    public enum Failure: Error, Equatable { case notOffered, notAccepted, done, wrongTarget, wrongAction, stock, invalidChoice, pending, invalidBattle }

    public struct Offer: Codable, Equatable, Sendable, Identifiable {
        public let id: String
        public let taskID: String
        public let postedDay: Int
        public let lastDay: Int
        public fileprivate(set) var accepted = false
        public fileprivate(set) var stepIndex = 0
        public fileprivate(set) var excludedChoiceIDs: Set<String> = []
        public fileprivate(set) var activeTicket: String?
        public fileprivate(set) var settledTickets: Set<String> = []
        public fileprivate(set) var done = false
        public var task: MPCStreetTask? { MPCStreetTaskCatalog.streetTask(taskID) }
        public var step: MPCStreetStep? {
            guard let task, !done, task.steps.indices.contains(stepIndex) else { return nil }
            return task.steps[stepIndex]
        }
    }
    public struct Reward: Codable, Equatable, Sendable {
        public let offerID: String
        public let taskID: String
        public let copper: Int
        public let thanks: String
        /// Raise each of these neighbours' affinity by one (`MPCNeighborLedger.raiseAffinity`).
        public let neighbors: [String]
        /// A commission's scene for the home painting.
        public let sceneID: String?
        /// Record with `MPCCityContributionLedger` as `.errand`; nil for commissions.
        public let contributionReceipt: String?
    }
    /// What a finished step says; `reward` is set when it was the last step.
    public struct Progress: Codable, Equatable, Sendable {
        public let line: String
        public let reward: Reward?
    }

    public private(set) var day = 0
    public private(set) var offers: [Offer] = []
    public private(set) var completed: [String] = []
    /// Home-painting scenes earned, in the order they were earned.
    public private(set) var scenes: [String] = []
    /// Days a commission was posted.
    public private(set) var commissionDays: [Int] = []
    public init() {}

    /// Opens a pacing day: drops lapsed offers (a fight under way stays) and posts what the
    /// contribution tier allows. Street goods come from the workshop, open after Q5.
    @discardableResult
    public mutating func open(day: Int, contributionPoints: Int) -> [Offer] {
        guard day > self.day else { return offers }
        self.day = day
        offers.removeAll { ($0.lastDay < day || $0.done) && $0.activeTicket == nil }
        func post(_ task: MPCStreetTask, id: String, lastDay: Int) {
            guard !offers.contains(where: { $0.id == id }) else { return }
            offers.append(.init(id: id, taskID: task.id, postedDay: day, lastDay: lastDay))
        }
        if MPCCityContribution.isOpen(.urgentErrand, points: contributionPoints), day >= MPCNeighborCatalog.firstDay {
            post(MPCStreetTaskCatalog.urgentErrand(day: day), id: "urgent-d\(day)", lastDay: day)
        }
        if MPCCityContribution.isOpen(.jointErrand, points: contributionPoints), let joint = MPCStreetTaskCatalog.jointErrand(day: day) {
            post(joint, id: "joint-d\(day)", lastDay: day + 1)
        }
        let window = MPCStreetTaskCatalog.commissionDays
        if MPCCityContribution.isOpen(.cityCommission, points: contributionPoints),
           commissionDays.last.map({ day >= $0 + window }) ?? true,
           let next = MPCStreetTaskCatalog.cityCommissions.first(where: { !completed.contains($0.id) }) {
            commissionDays.append(day)
            post(next, id: "commission-d\(day)", lastDay: day + window - 1)
        }
        return offers
    }

    public mutating func accept(offerID: String) throws {
        guard let i = offers.firstIndex(where: { $0.id == offerID }) else { throw Failure.notOffered }
        guard !offers[i].done else { throw Failure.done }
        offers[i].accepted = true
    }

    private func current(_ offerID: String, _ action: MPCStreetStep.Action, at target: String?) throws -> (Int, MPCStreetStep) {
        guard let i = offers.firstIndex(where: { $0.id == offerID }), offers[i].task != nil else { throw Failure.notOffered }
        guard !offers[i].done else { throw Failure.done }
        guard offers[i].accepted else { throw Failure.notAccepted }
        guard let step = offers[i].step else { throw Failure.done }
        if let target, target != step.target { throw Failure.wrongTarget }
        guard step.action == action else { throw Failure.wrongAction }
        return (i, step)
    }

    private mutating func advance(_ i: Int, _ step: MPCStreetStep, coins: inout Int) -> Progress {
        offers[i].stepIndex += 1
        offers[i].excludedChoiceIDs = []
        guard let task = offers[i].task, offers[i].stepIndex >= task.steps.count else { return .init(line: step.line, reward: nil) }
        offers[i].done = true
        completed.append(task.id)
        if let scene = task.sceneID, !scenes.contains(scene) { scenes.append(scene) }
        coins += task.copper
        let reward = Reward(offerID: offers[i].id, taskID: task.id, copper: task.copper, thanks: task.thanks, neighbors: task.neighbors,
                            sceneID: task.sceneID, contributionReceipt: task.contributionSource == nil ? nil : "street-" + offers[i].id)
        return .init(line: step.line, reward: reward)
    }

    /// Talking to someone who is lit but not this step's target is not an error for the
    /// player (they say "not me"); the App shows that and does not call this.
    public mutating func talk(offerID: String, at target: String, coins: inout Int) throws -> Progress {
        let (i, step) = try current(offerID, .talk, at: target)
        return advance(i, step, coins: &coins)
    }

    public mutating func handOver(offerID: String, at target: String, coins: inout Int, inventory: inout [String: Int]) throws -> Progress {
        let (i, step) = try current(offerID, .handOver, at: target)
        guard step.items.allSatisfy({ inventory[$0.key, default: 0] >= $0.value }) else { throw Failure.stock }
        for (item, count) in step.items { inventory[item, default: 0] -= count }
        return advance(i, step, coins: &coins)
    }

    /// A wrong answer is struck out at no cost. Returns nil until the right one.
    public mutating func answer(offerID: String, at target: String, choiceID: String, coins: inout Int) throws -> Progress? {
        let (i, step) = try current(offerID, .answer, at: target)
        guard step.choices.contains(where: { $0.id == choiceID }), !offers[i].excludedChoiceIDs.contains(choiceID) else { throw Failure.invalidChoice }
        guard choiceID == step.correctChoiceID else { offers[i].excludedChoiceIDs.insert(choiceID); return nil }
        return advance(i, step, coins: &coins)
    }

    public mutating func beginBattle(offerID: String, ticket: String) throws -> String {
        let (i, _) = try current(offerID, .battle, at: nil)
        let id = MPCStreetTaskCatalog.streetEncounterID(taskID: offers[i].taskID, step: offers[i].stepIndex, ticket: ticket)
        if let active = offers[i].activeTicket {
            guard active == ticket else { throw Failure.pending }
            return id
        }
        guard MPCStreetEncounters.validTicket(ticket),
              !offers.contains(where: { $0.activeTicket == ticket || $0.settledTickets.contains(ticket) }) else { throw Failure.invalidBattle }
        offers[i].activeTicket = ticket
        return id
    }

    /// Settles a street fight once; a loss leaves the step open for another try.
    public mutating func settleBattle(offerID: String, ticket: String, session: MPCChapterOneEncounterSession, coins: inout Int) throws -> Progress? {
        guard let i = offers.firstIndex(where: { $0.id == offerID }) else { throw Failure.notOffered }
        if offers[i].settledTickets.contains(ticket) { return nil }
        guard offers[i].activeTicket == ticket, let step = offers[i].step,
              session.encounter.id == MPCStreetTaskCatalog.streetEncounterID(taskID: offers[i].taskID, step: offers[i].stepIndex, ticket: ticket),
              session.outcome != .inProgress else { throw Failure.invalidBattle }
        offers[i].activeTicket = nil
        offers[i].settledTickets.insert(ticket)
        guard session.outcome == .victory else { return nil }
        return advance(i, step, coins: &coins)
    }

    /// Closes an abandoned fight once; the step stays open.
    public mutating func abandonBattle(offerID: String, ticket: String) {
        guard let i = offers.firstIndex(where: { $0.id == offerID }), offers[i].activeTicket == ticket else { return }
        offers[i].activeTicket = nil
        offers[i].settledTickets.insert(ticket)
    }
}
