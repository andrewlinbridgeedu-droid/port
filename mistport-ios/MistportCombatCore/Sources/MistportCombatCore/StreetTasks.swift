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
        urgent("postman", "红火漆的急件", "邮包里混进一封诊所的急件，下午就要用。我还有半条街没送完，可这封不敢让它等。", [
            .talk("postman", "找邮差取急件", "红火漆的这封。别揣怀里，手汗会把字洇了。"),
            .talk("clinic", "把急件送到诊所", "是药方回执。门口那孩子烧了一夜，就等它配药。"),
            .talk("postman", "回邮差那里销单", "他在单子上划掉这一栏，划得很慢，像怕划错。")
        ], thanks: "没晚就好。有的信晚到一天，就再也用不上了。"),
        urgent("west-lane", "今晚的新门牌", "有户人家今晚搬进旧街。东仓那场火以后，他们三年搬了四回。门上还钉着旧号。", [
            .talk("west-lane", "到登记员那里拿新门牌", "四十二号。钉正些，这是他们家三年来头一块自己的门牌。"),
            .give("oldstreet", "到旧街把门牌垫平钉牢", patch, 1, "垫上铁片，门牌不晃了。屋里的小孩扒着窗，看你钉完最后一颗钉子。"),
            .talk("west-lane", "回登记员那里改簿子", "簿子改好了。往后寄给这家的信，不会再被退回去了。")
        ], thanks: "今晚他们家的灯，是在自己屋里点的。"),
        urgent("baker", "早市前的烟道", "烟道堵了，面包出不了炉。天亮前要出海的人，还等着来拿硬面包。", [
            .talk("baker", "问面包师烟道是怎么堵的", "烟从后墙倒灌。昨夜屋顶那截烟道里一直吱吱叫，还有爪子挠铁皮的声音。"),
            .ask("upper-road", "问上坡守灯人昨夜在屋顶看见了什么", "屋顶那截烟道为什么堵？", [
                ("鸟在烟道口做了窝", "这个季节鸟不在雾港筑巢，也不会挠铁皮。"),
                ("一只小塔怪钻进去取暖", "吱吱声和爪子声都对得上，烟道口还粘着烤焦的毛。"),
                ("风把瓦片吹进了烟道", "瓦片都在原处，瓦片也不会叫。")], correct: 1,
                 "是只小塔怪。天一冷，它们就往暖和的地方钻，跟人一样。"),
            .talk("baker", "回去告诉面包师", "塔怪？也是冻坏了。我让伙计拿长钩去掏，轻一点，别伤着它。")
        ], thanks: "炉子通了。头一炉硬面包先装给出海的人，第二炉的头一个是你的。"),
        urgent("cafe-lane", "送奶船", "今晚有船回港，等船的人都会来店里坐着。奶不够了，得去码头找送奶船。", [
            .talk("cafe-lane", "问跑堂要多少奶", "两桶。等船的人一坐就是半夜，热奶比咖啡好入口。"),
            .talk("dockworker", "请码头工人帮忙找送奶船", "送奶船在二号栈桥。我帮你扛一桶，反正每条船靠岸，我都要去看一眼。"),
            .talk("cafe-lane", "把奶送回咖啡馆", "赶上了。窗边那位老太太，今晚能先喝上一杯热的。")
        ], thanks: "船靠岸了，店里一下子全是人。店主说你下回来，第一杯不收钱。"),
        urgent("east-houses", "雾夜的灯油", "今晚起雾，我的灯油不够点到最后一盏。那一盏不能不亮。", [
            .talk("east-houses", "问提灯人还差多少油", "差一壶。上坡守灯人那儿有存货。你去敲门，别说是我要的。"),
            .talk("upper-road", "向上坡守灯人借一壶灯油", "又是他？拿去。跟他说，怕黑就早点出门，别等雾起来。"),
            .talk("east-houses", "把灯油交给东岸提灯人", "他这么说的？……嗯。够了，今晚四十一盏都能亮。")
        ], thanks: "最后那盏在老钟表铺门口。雾再大，回来的人也找得到那扇门。"),
        urgent("courier", "涨潮前的急件", "有封信得在涨潮前送上船。收信的是船上的厨子，他女儿昨夜出生了，他还不知道。", [
            .talk("courier", "找信使取急件", "信还没盖放行印。港务处不盖，船上不收。"),
            .talk("harbor", "到港务处盖放行印", "盖好了。听说是报喜的，港务员盖得格外正。快，潮要涨了。"),
            .talk("sailor-walk", "把急件交给离港水手", "我这就给厨子送去。他要是哭了，我可不替他瞒着。")
        ], thanks: "赶上了？好。这一趟要在海上待半年，总算让他出海前知道了。"),
        urgent("clockmaker", "正午的报时锤", "钟台的报时锤卡住了。正午那一声，码头靠它放饭，诊所靠它发药。", [
            .talk("clockmaker", "听钟表匠说哪儿卡住了", "锤轴里卡着东西，还会动。我够不着，你个子高。"),
            .fight("church", "爬上钟台赶走卡在锤轴里的塔怪", [.goldenThroat], "塔怪一跑，锤子当的一声落下来，整座钟台都在嗡嗡响。"),
            .talk("clockmaker", "回钟表匠那里对时", "差两分，我拨回来。老师傅在的时候，这钟一分都没差过。")
        ], thanks: "正午的钟响了，街上没人抬头。没人抬头，就说明它响得对。"),
        urgent("market-lane", "婚礼的花篮", "有人订了一篮花，午后送去市政厅。是一对老人，说年轻时没钱办婚礼，现在补上。", [
            .talk("market-lane", "问帮工花篮在哪", "花商在摊子后面包，包了一上午，拆了三回。你去取，我守摊。"),
            .talk("florist", "找花商取包好的花篮", "包好了，别倒着拿。老太太要白花，她说年轻时戴不起。"),
            .talk("cityhall", "把花篮送到市政厅", "正好。老先生的领结歪了，老太太正踮着脚替他扶正。")
        ], thanks: "送到了？花商嘴上不说，包花的时候一直在哼歌。今天她准会多给我一块饼。"),
        urgent("florist", "码头上的花苗", "一船花苗到了码头，是城里的孩子一个铜一个铜攒钱订的。得赶在晒蔫前搬进阴凉处。", [
            .talk("florist", "问花商花苗在哪条船", "蓝帆那条。四十盆，每盆插着孩子的名字签，别弄混了。"),
            .talk("dockworker", "请码头工人帮忙搬花苗", "搬到仓库阴面了。有一盆的签子字歪歪扭扭，写着“给妈妈”。"),
            .give("florist", "给花商两块过滤布遮阳", cloth, 2, "盖上了，一棵都没蔫。")
        ], thanks: "这一批能活。明年春天，孩子们会自己来认自己那一盆。"),
        urgent("clock-square", "老船长的生日", "老船长今天生日。往年是我们船长给他送烟斗，今年船长不在了，我替他送。别说是我。", [
            .talk("clock-square", "问水手礼物在哪", "在商人那儿订的，钱付过了。烟斗上刻着我们那条船的名字。"),
            .talk("merchant", "到商人那里取烟斗", "包好了，别让海水溅着。他付钱的时候，铜币数了三遍。"),
            .talk("harbor", "赶在老船长下船前送到码头", "老船长摸着烟斗上的刻字，半天没说话，最后拍了拍你的肩。")
        ], thanks: "拍你肩膀了？那就是收下了。我们船长也这样，高兴从来不说出口。"),
        urgent("dockworker", "查货前的封签", "一只货箱的封签松了，港务的人待会儿就来查。查出毛病，扣的是全班人的工钱。", [
            .talk("dockworker", "问码头工人是哪只货箱", "最里面那只。不是我们弄松的，可查的人不管这些。新封签得去港务处领。"),
            .talk("harbor", "到港务处领一张新封签", "新封签，编号要和单子对上。下回松了早点来。"),
            .give("dockworker", "给码头工人两条维修绑带扎紧货箱", strap, 2, "扎紧了。他用一把磨得发亮的旧钩子收了绳头，又在衣角上擦了擦。")
        ], thanks: "查的人来了，一眼就过。今晚全班都领整钱，老吴家的房租有着落了。"),
        urgent("south-quay", "风里的船期表", "船期表要在开市前贴出去，墨还没干，风又大。好些人一早就来看，等家里人的船。", [
            .talk("south-quay", "从抄账员那里拿船期表", "小心，墨还湿。要是能借块铅条压着就好了。"),
            .talk("newspaper", "向报馆借一块压纸的铅条", "拿去，记得还。上回借出去那块，到今天也没回来。"),
            .talk("board", "把船期表贴到委托板旁", "贴好了，压牢了。还没贴稳，就有个女人凑过来，用手指一行一行往下找。")
        ], thanks: "开市的人都看得见了。有人找着了船名，有人没找着，明天还会来。铅条我下午去还。"),
        urgent("musician", "送别会的琴弦", "今晚码头送一个老渔夫，他要搬去内陆的女儿家，多半不回来了。我的琴弦偏偏断了一根。", [
            .talk("musician", "看看乐师缺哪根弦", "最细的那根。商人那儿什么都有，也许有。"),
            .talk("merchant", "问商人有没有琴弦", "有一卷羊肠弦，本来是修帆用的。拿去，不要钱，替我也送送他。"),
            .talk("musician", "把琴弦交给乐师", "音准了。他点的是《回港》。我问为什么，他说想再听一遍。")
        ], thanks: "今晚的《回港》我拉慢一点。他上车以前，应该能听完。"),
        urgent("upper-road", "冻住的坡道", "上坡那段路冻了。东头那家媳妇这两天要生，接生婆夜里得坐车上来。天黑前得撒上砂。", [
            .talk("upper-road", "问守灯人要撒多少砂", "一袋就够。工坊区炉渣筛出来的粗砂最好。"),
            .talk("industry", "到工坊区要一袋粗砂", "拿去，炉渣筛的，不值钱。谁家要生了？那就挑最粗的。"),
            .talk("upper-road", "把砂交给守灯人", "撒上了。今晚我把那几盏灯挑亮些，车上来看得清路。")
        ], thanks: "今晚的车能停住了。等孩子落了地，我头一个去敲你的门报喜。"),
        urgent("cathedral-road", "转院的担架", "诊所的床不够了，一个伤者要转到教会。担架还缺人抬另一头。", [
            .talk("cathedral-road", "找教会跑腿搭把手", "你抬后头，我在前面看路。下坡那段石板滑，慢点。"),
            .talk("clinic", "到诊所接伤者", "轻点抬，他腿上的夹板刚绑好。他娘跟在后头，手里拎着他的一双鞋。"),
            .talk("church", "把伤者送到教会", "床铺好了。他娘把鞋摆在床底下，鞋尖朝外，说等他自己穿着走回去。")
        ], thanks: "他睡着了，他娘还坐着。谢谢你，一路走得那么稳。"),
        urgent("flower-seller-walk", "雨前的紫藤", "野坡上的紫藤开了。今天不剪，明天一场雨就全落了。", [
            .talk("flower-seller-walk", "问花贩紫藤在哪片坡", "旧街后坡。可那儿蹲着一只塔怪，我背着筐跑不过它。"),
            .fight("oldstreet", "到旧街后坡赶走守着紫藤的塔怪", [.moonfang, .moonfang], "塔怪跑了。紫藤还在，只被它压扁了几串。"),
            .talk("flower-seller-walk", "帮花贩把紫藤背回来", "满满一筐。最好的那串我先收着，有位老先生每周来买一枝，给他太太。")
        ], thanks: "这一筐够卖到周末。你也挑一枝，花开着，就该有人看。"),
        urgent("sailor-walk", "提前开的船", "船提前开了！我的铺盖还在酒馆楼上，里面卷着我娘缝的护膝。", [
            .talk("sailor-walk", "问水手铺盖放在哪", "酒馆楼上第二间，床底下。蓝布卷的那个，绳子是我娘打的结。"),
            .talk("tavern", "到酒馆楼上取水手的铺盖", "他的东西都在这儿，一件没少。老板娘又往铺盖里塞了两块硬面包。"),
            .talk("harbor", "赶在开船前送到码头", "接住了！船已经离岸一臂远，他是探着身子抢过去的。")
        ], thanks: "下回回港，我请你喝一杯。到时候你站在码头上，我一眼就认得出。"),
        urgent("archive-apprentice-walk", "虫蛀的封皮", "一卷旧街出生簿下午要交给市政厅，可封皮被虫蛀了，一碰就掉渣。有人在等它。", [
            .talk("archive-apprentice-walk", "看看学徒手里的出生簿", "就是这卷，五十年里旧街生的孩子都在上面。得先包起来，不然送到一半就散了。"),
            .give("archive-apprentice-walk", "给学徒一块过滤布包封皮", cloth, 1, "包好了。我在布角上写了个“轻”字，书记官会懂。"),
            .talk("cityhall", "把出生簿送到市政厅", "书记官翻到一页，朝门外喊：“老太太，找到了，您是在雾港出生的。”")
        ], thanks: "书记官夸我了，其实是你跑的腿。今天这件事，我要记进自己的本子里。"),
        urgent("cafe_keeper", "走错门的记者", "报馆的记者约了今天来店里，要写我母亲定下的那条规矩。到现在都没来。", [
            .talk("cafe_keeper", "问店主约了几点", "约的是十点。他说店招是蓝的……可我的店招前天被人挪了。"),
            .talk("newspaper", "去报馆找记者", "我在对街那家等了半天！还以为店主改了主意，不想说了。"),
            .talk("cafe", "带记者回咖啡馆", "来了就好。坐吧，从我母亲开店那年说起。")
        ], thanks: "第一杯我请。登出来以后，我要剪下来，挂在吧台后面那枚船徽旁边。"),
        urgent("street_warden", "被撕的公告", "巷口的封锁公告被人撕了。天黑前得重新贴上，不然夜里有人误闯。", [
            .talk("street_warden", "问巡街人公告要去哪领", "警署有备份，盖了章的才作数。撕下的那半张在水沟里，被人折成了纸船。"),
            .talk("police", "到警署领一张新公告", "盖了章的，别折。"),
            .talk("blockade-notice", "把公告贴回巷口", "贴好了，这回用的双层浆糊。门后有个孩子，一直盯着你看。")
        ], thanks: "今晚这条巷子不会有人误闯了。那只纸船？我没扔，搁在窗台上了。"),
        urgent("scholar", "到期前的一页", "借来的书明天到期，下一个借的学生排了一个月。我还差一页没抄完，墨却用光了。", [
            .talk("scholar", "问学者要什么墨", "黑的就行，稀一点也不怕。我字小，一瓶能用很久。"),
            .talk("newspaper", "向报馆讨一瓶墨", "印报的油墨太稠，兑点水再用。那位学者啊，常来我们这儿翻旧报。"),
            .talk("scholar", "把墨交给学者", "够抄完了。他抄到最后一行，又对着原书比了一遍。")
        ], thanks: "书能准时还了。那个学生翻开扉页，会看见我夹的一张书签。"),
        urgent("merchant", "写错的货单", "一批布今天到港，货单上的数目写错了，得在卸货前改。这批布是给教会做冬衣的。", [
            .talk("merchant", "拿商人的货单去核对", "单子上写一百匹。可那条船小，货舱顶多装十来匹。"),
            .ask("south-quay", "请港务抄账员核对货单", "货单上哪一处写错了？", [
                ("匹数多写了一个零", "那条船的货舱装不下一百匹，十匹才对。"),
                ("船名写错了", "船名和登记簿一致。"),
                ("到港日期写错了", "日期是今天，对的。")], correct: 0, "改成十匹，我盖个章。抄错了能改，别抄假就行。"),
            .talk("merchant", "回商人那里签字", "改好了。卸货的人已经在栈桥上等着了。")
        ], thanks: "差点多交九十匹的税，冬衣就得少做二十件。这份人情我记下了。"),
        urgent("visitor", "丢了寄存牌", "今晚的车就要开了，我的寄存牌却不见了。箱子里是祖父的旧照片。", [
            .talk("visitor", "问旅人行李什么样", "一只旧皮箱。早上我在旧街一面老墙下折了枝紫藤，别在箱把上。"),
            .ask("post", "到邮局寄存处认领行李", "寄存员问：你的箱子是哪一只？", [
                ("绿色的帆布箱", "绿箱子是另一位客人的。"),
                ("箱把上别着一枝紫藤的旧皮箱", "旅人说过，紫藤就别在箱把上。"),
                ("没有锁的木箱", "旅人的是皮箱，还带着锁。")], correct: 1, "是这只，紫藤还没蔫。签个字就能拿走。"),
            .talk("visitor", "把行李交给旅人", "就是它！旅人先打开箱子摸了摸那叠照片，才扣上锁。")
        ], thanks: "祖父说雾港的钟声和别处不一样。我来了才知道，他没骗我。我会想念这里的。"),
    ]

    /// Joint errands, in the order they are posted.
    public static let jointErrands: [MPCStreetTask] = [
        .init(id: "joint-wedding", kind: .joint, title: "婚礼前夜", giverID: "florist",
              request: "市政厅明天办婚礼，新人两家都不宽裕。花拱、喜饼、曲子，花商、面包师、乐师各管一样，得有人把三头串起来。",
              steps: [
                .talk("florist", "向花商订花拱", "花拱要紫藤和白花，我今晚扎。就差两块过滤布裹花根。"),
                .give("florist", "给花商两块过滤布", cloth, 2, "够了。你去问面包师喜饼赶不赶得出。我出花，她出饼，都不收钱，说好的。"),
                .talk("baker", "问面包师喜饼能不能赶出来", "三层，傍晚出炉。新娘子小时候天天来我这儿讨面包边。曲子定了吗？"),
                .talk("musician", "请乐师明天在市政厅拉琴", "第一支舞就拉《雾散》。他俩头一回在广场上碰见，我拉的就是这首。"),
                .talk("cityhall", "回市政厅报备", "花、饼、琴都定了。明天上午，别迟到。")
              ], thanks: "花拱、喜饼、曲子，一样不差。新人说要请你们三位喝喜酒，坐头一桌。",
              neighbors: ["florist", "baker", "musician"], sceneID: nil),
        .init(id: "joint-night-shift", kind: .joint, title: "码头的夜班", giverID: "south-quay",
              request: "今夜有船进港，要停东仓那头的栈桥。账要记、货要卸、灯要点，三头都得对上。",
              steps: [
                .talk("south-quay", "问抄账员今晚哪条船进港", "‘灰鸥’号，半夜到，装的是盐和布。停三号栈桥，东仓那头。"),
                .talk("dockworker", "通知码头工人留人卸货", "我留三个人。可东仓烧了以后，那段栈桥就再没点过灯。"),
                .talk("east-houses", "请提灯人今晚多点两盏栈桥灯", "我点。那两根灯柱还是焦的。栈桥底下常有东西爬，你先去看看。"),
                .fight("harbor", "清掉栈桥底下的塔怪", [.copperback, .moonfang], "栈桥干净了。灯亮起来，三年了，东仓那一头第一次有光。"),
                .talk("south-quay", "回抄账员那里登记", "灯、人、船都记上了。")
              ], thanks: "‘灰鸥’号靠稳了。提灯人一直守到最后一箱卸完，才回去吹灯。",
              neighbors: ["south-quay", "dockworker", "east-houses"], sceneID: nil),
        .init(id: "joint-missing-page", kind: .joint, title: "丢了的第十七页", giverID: "archive-apprentice-walk",
              request: "旧名册丢了第十七页，记的是旧街的老住户。学者抄过几份，登记员有门牌簿，得三个人对一对。",
              steps: [
                .talk("archive-apprentice-walk", "听学徒说少了哪一页", "第十七页，门牌重编以前的老住户。少了这一页，那条街就像少了几户人。"),
                .ask("scholar", "问学者手里哪份抄本是真的第十七页", "学者摊开三份抄本，哪份才是原来的第十七页？", [
                    ("纸色发黄、写着旧门牌号的那份", "门牌重编以前抄的，号码和名册对得上。"),
                    ("字迹最工整的那份", "工整的是誊清本，门牌已经是新号了。"),
                    ("盖着市政厅印的那份", "印是后来补盖的，日期比名册晚了十年。")], correct: 0, "就是它。我当年抄得急，墨都洇了。没想到还有人要。"),
                .talk("west-lane", "请登记员对照门牌簿", "对得上。十七号那户姓苏，是一对姐妹，后来一个往东，一个往西。"),
                .talk("archive-apprentice-walk", "把抄页交还学徒", "补上了。苏家姐妹的名字墨太淡，我又描了一遍。")
              ], thanks: "名册总算完整了。三个人凑出来的一页，比原来那页还清楚。",
              neighbors: ["archive-apprentice-walk", "scholar", "west-lane"], sceneID: nil),
        .init(id: "joint-soup-day", kind: .joint, title: "教会的施粥日", giverID: "cathedral-road",
              request: "明天教会施粥，碗不够，锅也不够。排队的人里，好些是东仓那场火以后一直没安顿下来的。",
              steps: [
                .talk("cathedral-road", "问跑腿施粥还缺什么", "缺碗，也缺一口大锅。去年来了四十个人，今年怕要多一倍。"),
                .talk("merchant", "找商人借一箱碗", "借，不要钱。碗底有我的记号，用完送回来。少一两只别来告诉我，我不数。"),
                .talk("cafe_keeper", "请咖啡馆店主借一口大锅", "锅借你，再送一壶热咖啡给排队的人。等着的时候手冷，捧着也好。"),
                .talk("church", "把碗和锅送到教会", "齐了。")
              ], thanks: "来的人都喝上了热的。有个老人把碗洗干净了才还。有人问是谁张罗的，我说了你们三个。",
              neighbors: ["cathedral-road", "merchant", "cafe_keeper"], sceneID: nil),
        .init(id: "joint-lamp-oil", kind: .joint, title: "掺了水的灯油", giverID: "upper-road",
              request: "上坡的灯一盏接一盏灭了，下坡回家的人只能摸黑。灯油是从商人那儿进的，得问清楚。",
              steps: [
                .talk("upper-road", "问守灯人灯为什么灭", "上个月那批油点不亮，一烧就噼啪响。昨晚有个老太太在坡上摔了一跤。"),
                .ask("merchant", "到商人那里查这批油", "这批灯油是怎么掺进水的？", [
                    ("运油船漏进了海水，沉在桶底", "桶底有一层咸水，桶箍锈穿了一圈。"),
                    ("有人故意兑了水", "桶封没被撬开过。"),
                    ("雨水从桶盖渗了进去", "桶盖是蜡封的，是干的。")], correct: 0, "是桶漏了。我做了三十年买卖，没卖过一滴假油。给他换一桶好的。"),
                .talk("east-houses", "请提灯人先分一壶好油", "拿去。换桶的事我跟商人说。别说是我给的，他会不好意思。"),
                .talk("upper-road", "把好油交给守灯人", "点上了。……是东岸那个给的吧？他的油壶嘴上总缠着一圈布。")
              ], thanks: "今晚上坡不会黑了。商人答应，以后每桶都先开盖看一眼。",
              neighbors: ["upper-road", "merchant", "east-houses"], sceneID: nil),
        .init(id: "joint-home-letter", kind: .joint, title: "赶邮船的家书", giverID: "visitor",
              request: "旅人想给北港的家里寄信，今天的邮船就要走了。邮差封了包，信使也许还追得上。",
              steps: [
                .talk("visitor", "从旅人那里接过家书", "信要赶今天的邮船。我母亲每天去码头等信，我答应过她。"),
                .talk("postman", "把信交给邮差", "北港的邮包已经封了。你去问信使，还追不追得上。这种信，不能等下一班。"),
                .talk("courier", "请信使追邮船", "我跑一趟。可码头那边有只塔怪蹲在邮筒上。"),
                .fight("harbor", "赶走蹲在邮筒上的塔怪", [.goldenThroat, .moonfang], "邮筒口空出来了。信使接过信，一路跑上了跳板。"),
                .talk("visitor", "告诉旅人信寄出了", "寄出了？那她下个礼拜就能收到了。")
              ], thanks: "谢谢你们。信里我写了：雾港的钟声，跟祖父说的一模一样。",
              neighbors: ["visitor", "postman", "courier"], sceneID: nil),
        .init(id: "joint-bench", kind: .joint, title: "广场的长椅", giverID: "street_warden",
              request: "广场那张长椅被人挪来挪去，水手和乐师吵了一早上。巡街人想请人去说和。",
              steps: [
                .talk("street_warden", "问巡街人出了什么事", "两个人都要那张长椅，谁也不让。一个说要看港口，一个说要听回声。"),
                .talk("clock-square", "问水手为什么要那张长椅", "我在那儿坐了二十年。从那儿看得见港口，有条船回来，我得第一个看见。"),
                .talk("musician", "问乐师为什么要那张长椅", "那儿回声最好，琴声能传到码头。我想让船上的人也听得见。"),
                .talk("street_warden", "请巡街人把长椅挪到钟楼正下方", "挪好了。水手看得见港口，琴声也传得到码头。")
              ], thanks: "两个人都不吵了。傍晚水手点了一首歌，头一回。乐师拉的时候，他一直望着港口。",
              neighbors: ["street_warden", "clock-square", "musician"], sceneID: nil),
        .init(id: "joint-awning", kind: .joint, title: "花摊的遮棚", giverID: "market-lane",
              request: "花摊的遮棚被风掀了，花都晒着。帮工一个人搭不起来。",
              steps: [
                .talk("market-lane", "问帮工棚子怎么了", "棚架的绳子断了，得重新绑。花商进货去了，回来看见要心疼的。"),
                .give("market-lane", "给帮工三条维修绑带绑棚架", strap, 3, "绑上了。还得有人扶着。"),
                .talk("flower-seller-walk", "请流动花贩帮忙扶棚", "我扶。可别告诉花商是我帮的。"),
                .talk("florist", "告诉花商棚子搭好了", "……是那个流动花贩帮的吧？绑带上打的是她的结。她以前在我这儿帮过工。")
              ], thanks: "替我谢谢她。……算了，明天剪的紫藤分她一半，她会明白的。",
              neighbors: ["market-lane", "flower-seller-walk", "florist"], sceneID: nil),
    ]

    /// City commissions, one a week in this order; each changes the home painting once.
    public static let cityCommissions: [MPCStreetTask] = [
        .init(id: "commission-fountain", kind: .commission, title: "喷泉广场的花与旗", giverID: "cityhall",
              request: "市政厅：喷泉修好一年了，广场还是光秃秃的。老人们说，从前一到春天这里就挂满彩旗。市里拨了款，请你张罗。",
              steps: [
                .talk("cityhall", "到市政厅领工单", "工单：矮石花坛一圈，彩旗三串。石料找工坊区，花找花商，彩旗找咖啡馆店主——她那儿有旧帆布。"),
                .talk("industry", "到工坊区订花坛石料", "矮石有现成的，下午送到广场。我家小子就是在那喷泉边学会走路的。"),
                .talk("florist", "请花商挑当季的花", "白的、黄的、粉的、紫的，挑耐盐雾的，明早种下去。"),
                .give("cafe_keeper", "给咖啡馆店主两块过滤布缝彩旗", cloth, 2, "这帆布是我母亲那年换下的旧店招。配上过滤布，三串彩旗傍晚缝好。"),
                .fight("board", "清掉喷泉池底筑窝的塔怪", [.goldenThroat, .goldenThroat], "池底干净了，花坛可以砌了。泥里还捡出几枚许愿的铜币，生了绿锈。"),
                .talk("cityhall", "回市政厅交工", "我去看过了，花坛和彩旗都好了。")
              ], thanks: "广场从今天起，是雾港最好看的地方。下午就有老人坐在花坛边晒太阳了。",
              neighbors: [], sceneID: "fountain"),
        .init(id: "commission-yard", kind: .commission, title: "货场的新帆布", giverID: "harbor",
              request: "港务处：工坊货场的吊臂空了一冬，货箱没贴封签，乱堆着。请挂上新帆布，把货箱封好码齐。",
              steps: [
                .talk("harbor", "到港务处领工单", "帆布要深蓝配浅金，绣港务锚记；货箱要贴封签。封签找抄账员，帆布找商人，挂帆布的绳子你来做。"),
                .talk("merchant", "向商人订深蓝帆布", "深蓝配浅金，明天到货。锚记请裁缝绣，她爹在港务处干了一辈子，她闭着眼都绣得出。"),
                .give("dockworker", "给码头工人三条维修绑带挂帆布", strap, 3, "绳子够结实，吊臂上挂稳了。风一吹，帆布鼓起来，像要出海。"),
                .talk("south-quay", "到抄账员那里领封签", "八张封签，编号连着，一张都别弄丢。"),
                .fight("industry", "赶走占了货堆的铜背甲兽", [.copperback, .copperback], "货堆腾出来了，箱子可以码了。"),
                .talk("harbor", "回港务处交工", "帆布挂起来了，货箱也封好了。")
              ], thanks: "远远看过去，那片货场总算像个港口的样子了。收工的人走出老远，还回头看了一眼。",
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
    /// current step's person or place. With `today`, an offer past its last day is not lit
    /// even before the ledger opens the new day (a fight under way still is).
    public static func streetTargets(_ ledger: MPCStreetTaskLedger, today: Int? = nil) -> [MPCStreetTaskTarget] {
        ledger.offers.compactMap { offer -> MPCStreetTaskTarget? in
            guard let task = offer.task, !offer.done,
                  today.map({ offer.lastDay >= $0 || offer.activeTicket != nil }) ?? true else { return nil }
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
        /// How the player carries it out (MPCStreetTaskCatalog.ways); absent in older saves.
        public fileprivate(set) var way: MPCCityFaction?
        public var task: MPCStreetTask? { MPCStreetTaskCatalog.streetTask(taskID) }
        public var chosenWay: MPCErrandWay? { way.flatMap { side in MPCStreetTaskCatalog.ways(taskID).first { $0.side == side } } }
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
        /// The way it was carried out, for the city trend.
        public var way: MPCErrandWay? = nil
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

    /// `way`: how the player will carry it out (both pay the same; nil only where a task has no ways).
    public mutating func accept(offerID: String, way: MPCCityFaction? = nil) throws {
        guard let i = offers.firstIndex(where: { $0.id == offerID }) else { throw Failure.notOffered }
        guard !offers[i].done else { throw Failure.done }
        if let way {
            guard MPCStreetTaskCatalog.ways(offers[i].taskID).contains(where: { $0.side == way }) else { throw Failure.invalidChoice }
            offers[i].way = way
        }
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
                            sceneID: task.sceneID, contributionReceipt: task.contributionSource == nil ? nil : "street-" + offers[i].id,
                            way: offers[i].chosenWay)
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
