import Foundation

public struct MPCChurchBountyNode: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let speaker: String
    public let location: String
    public let dialogue: String
    public let evidence: String
    public let requires: Set<String>
    public init(id: String, speaker: String, location: String, dialogue: String, evidence: String, requires: Set<String> = []) {
        self.id=id; self.speaker=speaker; self.location=location; self.dialogue=dialogue; self.evidence=evidence; self.requires=requires
    }
}
public struct MPCChurchBounty: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    /// Historical placement for old saves and pacing reports; daily issues no longer gate on it.
    public let unlockMission: Int
    public let enemyID: String
    public let modelID: String
    public let visualIdentity: String
    public let nodes: [MPCChurchBountyNode]
    public let copper: Int
    public let merit: Int
    public let closure: String
    public var encounterID: String { "church_bounty_" + id }
}
public struct MPCChurchBountyChoice: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let text: String
    public let explanation: String
}
public struct MPCChurchBountyChallenge: Codable, Equatable, Sendable {
    public let question: String
    public let choices: [MPCChurchBountyChoice]
    public let correctChoiceID: String
}
public enum MPCChurchBountyCatalog {
    public static let all: [MPCChurchBounty] = [
        .init(id:"b01",title:"第七号空壳",unlockMission:7,enemyID:"bounty_b01_execution_body",modelID:"bounty-b01",visualIdentity:"灰铁甲、左肩七号铭牌、缺齿长剑。",nodes:[
            .init(id:"witness",speaker:"诺恩",location:"封锁公告处",dialogue:"两个人都死在封锁线外。第一声钟响时，巡逻队还没换班。",evidence:"两起凶案发生于同一封锁时段。"),
            .init(id:"wound",speaker:"奥黛尔",location:"诊所",dialogue:"剑从左上斜下，同一道缺口留下两枚短齿痕。这不是跌伤。",evidence:"独立验伤：左斜剑创与双短齿。"),
            .init(id:"exclude",speaker:"值勤登记员",location:"巡逻值房",dialogue:"有人说所有守卫都去过。登记和两名夜班人证明，正常巡逻队当时在桥另一侧。",evidence:"排除误导：正常巡逻队有独立不在场证明。",requires:["witness","wound"]),
            .init(id:"compare",speaker:"维拉",location:"铁匠铺",dialogue:"把木门割痕与剑齿拓片叠起来。两枚短齿一模一样，油垢只来自废岗亭旧机座。",evidence:"实物比对指向废岗亭。",requires:["exclude"]),
            .init(id:"identity",speaker:"废岗亭观察",location:"废岗亭",dialogue:"左肩七号残标、缺齿剑和双案时间指令均吻合。它亮起处决灯，转向门外的幸存者。",evidence:"目标独立编号与作案工具核验完成。",requires:["compare"])
        ],copper:60,merit:12,closure:"非法执行体已销毁，命令匣封存。维修工的责任另案取证，不因职业推定有罪。"),
        .init(id:"b02",title:"背架收尸人",unlockMission:14,enemyID:"bounty_b02_abductor",modelID:"bounty-b02",visualIdentity:"旧褐工装，沾血的反扣束带与外锁背架。",nodes:[
            .init(id:"witness",speaker:"奥黛尔",location:"诊所",dialogue:"他运走的所谓死者，昨天还亲自签收了药。治疗记录与死亡证明相互冲突。",evidence:"被掳者近期仍活着。"),
            .init(id:"wound",speaker:"逃出的工人",location:"避难屋",dialogue:"我看见同伴还在挣扎。束带扣朝外，他说死人不需要自己解开。",evidence:"独立目击：活人被反扣束带拘禁。"),
            .init(id:"exclude",speaker:"救援登记员",location:"市政救援站",dialogue:"洛克的编号和救援录音对得上。他没有这副外锁架，不能拿他的旧事替此案定罪。",evidence:"洛克的救援录音与交接编号相符。",requires:["witness","wound"]),
            .init(id:"compare",speaker:"维拉",location:"渡运台",dialogue:"锁扣油迹与这张废浴场渡运收据相符。市政救援架从不从外面锁死人。",evidence:"油迹与收据交叉定位废浴场。",requires:["exclude"]),
            .init(id:"identity",speaker:"浴场观察",location:"废浴场",dialogue:"反扣束带、赃运收据和仍被拘束的人同时在场。确认是独立绑架犯，他开始收紧背架。",evidence:"活人获救入口与作案者身份核验。",requires:["compare"])
        ],copper:80,merit:16,closure:"收尸人被制止，幸存者获释。束带和运单已由教会封存。"),
        .init(id:"b03",title:"溺钟海盗",unlockMission:23,enemyID:"bounty_b03_drowned_captain",modelID:"bounty-b03",visualIdentity:"海蓝亡魂，胸前船锚章与旧海盗印。",nodes:[
            .init(id:"witness",speaker:"港务员",location:"港务登记处",dialogue:"被劫的三艘船都在退潮钟响后出港。船期没有被改过。",evidence:"独立船期锁定袭船时间。"),
            .init(id:"wound",speaker:"伊莱",location:"钟台",dialogue:"那不是换班口令。倒着敲的三短一长，是旧海盗队的回船暗号。",evidence:"逆钟节拍属于海盗队。"),
            .init(id:"exclude",speaker:"老水手",location:"码头",dialogue:"活人港工被疑是船长，可袭击后的湿甲板上，只有我们的脚印。那船长早已溺亡。",evidence:"排除活人港工；亡魂线索与旧船证一致。",requires:["witness","wound"]),
            .init(id:"compare",speaker:"港务员",location:"沉船档案柜",dialogue:"溺亡船证、潮线残盐、袭击钟点三者重合。潮退时钟沉船露出舱口。",evidence:"三项物证定位钟沉船。",requires:["exclude"]),
            .init(id:"identity",speaker:"沉船观察",location:"钟沉船",dialogue:"灵体持有相同海盗印，重复逆钟口令并驱赶袭船残影。确认目标，不能把普通溺亡者当罪犯。",evidence:"海盗印、暗号与攻击行为核验。",requires:["compare"])
        ],copper:100,merit:20,closure:"袭船灵体终结，海盗印和赃货账入档。受害船主将依据这份账册取回货物。"),
        .init(id:"b04",title:"铜笔伪造者",unlockMission:19,enemyID:"bounty_b04_forgery_engine",modelID:"enemy_codex_executor",visualIdentity:"铜绿笔端、倒序印号，机械臂留有断齿。",nodes:[
            .init(id:"witness",speaker:"遗产领取者",location:"公证柜台",dialogue:"两份遗嘱都写唯一继承人。我没要求谁死，只想知道哪一张被改过。",evidence:"两份互斥遗嘱原件。"),
            .init(id:"wound",speaker:"印章员",location:"验印台",dialogue:"章是真的，序号却倒着走。有人用真章做了假的先后顺序。",evidence:"独立验印确认倒序号。"),
            .init(id:"exclude",speaker:"维拉",location:"铁匠铺",dialogue:"重复笔压不是每个书记员都有。普通抄写笔会回弹，这道断笔间距来自损坏的齿轮。",evidence:"排除普通书记员，锁定特定机器缺陷。",requires:["witness","wound"]),
            .init(id:"compare",speaker:"印厂旧工",location:"废印厂外",dialogue:"把两张纸的间距叠起来，只能由三号旧机产生。它被偷运回废印厂。",evidence:"断笔间距与机器档案唯一匹配。",requires:["exclude"]),
            .init(id:"identity",speaker:"印厂观察",location:"废印厂",dialogue:"倒序模具与待覆盖遗嘱在同一台机器上。机身序号与失窃登记一致，确认伪造母版的写入源。",evidence:"机器序号、工具与伪造原件核验。",requires:["compare"])
        ],copper:120,merit:24,closure:"伪造母版销毁，合法证书退还，遗嘱的真实先后顺序得以恢复。"),
        .init(id:"b05",title:"赤丝裁衣人",unlockMission:27,enemyID:"bounty_b05_silk_murderer",modelID:"bounty-b05",visualIdentity:"灰白衣、赤丝与小银剪胸针。",nodes:[
            .init(id:"witness",speaker:"衣铺老板",location:"旧衣铺",dialogue:"失踪的人都留下同一种量衣单，衣服却从未回来。",evidence:"失踪名单与量衣单对应。"),
            .init(id:"wound",speaker:"奥黛尔",location:"诊所",dialogue:"针孔周围有生前出血。他们不是死后被缝住，是活着时遭到勒紧。",evidence:"独立验伤证实生前侵害。"),
            .init(id:"exclude",speaker:"维娅的封存证言",location:"联络处",dialogue:"这不是我的收束结。外侧多了一道非法收紧结，故意让人无法呼救。",evidence:"现场绳结与维娅封存的结法不同，另有操作者。",requires:["witness","wound"]),
            .init(id:"compare",speaker:"染坊学徒",location:"染坊账房",dialogue:"赤染料批号与收款条一致。那些量衣单都进了后院染坊。",evidence:"染料与收款条定位染坊后院。",requires:["exclude"]),
            .init(id:"identity",speaker:"染坊观察",location:"染坊后院",dialogue:"剪刀胸针、非法紧结和失踪者衣料全在。操作者开始勒紧被缚者，身份与罪证已核验。",evidence:"独立凶手与现场罪证匹配。",requires:["compare"])
        ],copper:140,merit:28,closure:"裁衣人被制止，被缚者获救。维娅提供证言，不抹掉她原有责任。"),
        .init(id:"b06",title:"无灯押船人",unlockMission:26,enemyID:"bounty_b06_dark_hold_captain",modelID:"enemy_archive_adjudicator",visualIdentity:"漆黑赃甲、划除的军号与船锚腰牌。",nodes:[
            .init(id:"witness",speaker:"港务员",location:"港务登记处",dialogue:"三艘货船进暗航线前都熄了灯。不是灯油不足，补给单上刚加满。",evidence:"熄灯航线与补给记录冲突。"),
            .init(id:"wound",speaker:"铁匠",location:"军甲修理棚",dialogue:"这块甲片序号在失窃清单上。我只认编号，不凭一个人穿重甲就定罪。",evidence:"赃甲序号独立确认。"),
            .init(id:"exclude",speaker:"码头工",location:"报警钟楼",dialogue:"正常重卫交接时钟还完好。那个船锚腰牌的人，用锤砸掉了钟舌。",evidence:"排除正常值勤重卫；具体毁钟者有独立标识。",requires:["witness","wound"]),
            .init(id:"compare",speaker:"港务员",location:"封舱台外",dialogue:"赃甲编号、锤痕和压舱铅痕都指向同一艘船。封舱台就在前面。",evidence:"三项物证定位封舱台。",requires:["exclude"]),
            .init(id:"identity",speaker:"封舱观察",location:"封舱台",dialogue:"划除军号和船锚腰牌吻合。押船头目持锤阻止人质离船；确认独立身份，准备破围。",evidence:"赃甲、腰牌、现场强迫行为核验。",requires:["compare"])
        ],copper:160,merit:32,closure:"押船头目被击败，人质离船。失窃军甲与赃物已查扣归档。"),
        .init(id:"b07",title:"三声敲门客",unlockMission:5,enemyID:"bounty_b07_knocker",modelID:"bounty-b07",visualIdentity:"青蓝低伏的铃蛙，金色喉铃和不同门牌的封签。",nodes:[
            .init(id:"witness",speaker:"夜班邮差",location:"旧邮局",dialogue:"同一句‘替我开门’在两条街同时响起。原说话者那时正躺在诊所。",evidence:"求救声在同一时刻出现在两个街区。"),
            .init(id:"wound",speaker:"奥黛尔",location:"诊所",dialogue:"三名伤者的门闩上都是同样的黏液和右前爪缺趾木屑。",evidence:"独立验伤与缺趾爪痕吻合。"),
            .init(id:"exclude",speaker:"修门工",location:"木工街",dialogue:"我的工单、五指工具痕和邮务时间都能核实；不能因我听力不好就说我偷声。",evidence:"排除被传闻误指的修门工。",requires:["witness","wound"]),
            .init(id:"compare",speaker:"档案员",location:"旧排水口",dialogue:"木漆、排水泥和重复声纹都指向第三间空屋。",evidence:"三种独立痕迹定位第三间空屋。",requires:["exclude"]),
            .init(id:"identity",speaker:"空屋观察",location:"第三间空屋",dialogue:"喉铃复制求救声，缺趾爪碰上同样的门闩；它正诱骗另一名住户。",evidence:"现场行为、喉铃与爪痕共同核实目标。",requires:["compare"])
        ],copper:60,merit:20,closure:"诱骗已停止，借声喉膜拓样封存，失去声音者的记录归还家属。"),
        .init(id:"b08",title:"借脸人·弥伦",unlockMission:11,enemyID:"bounty_b08_miren",modelID:"bounty-b08",visualIdentity:"半张蜡面具、深蓝礼服、红领饰和短刺；真身右手有旧伤。",nodes:[
            .init(id:"witness",speaker:"被冒名者的雇主",location:"雇工会",dialogue:"他在同一天的两座城签了收据，不可能都是本人。",evidence:"同日异地的两张签收原件。"),
            .init(id:"wound",speaker:"奥黛尔",location:"诊所",dialogue:"真正的家人右手有旧伤。盗款人的伪签留下了另一种手压。",evidence:"病历旧伤与伪签手压不符。"),
            .init(id:"exclude",speaker:"港务员",location:"港务登记处",dialogue:"被疑的孪生兄弟出港底片和船员证言都在；他没有回来。",evidence:"独立时间线排除孪生兄弟。",requires:["witness","wound"]),
            .init(id:"compare",speaker:"照相师",location:"相片铺",dialogue:"蜡面反光与赃收据乳剂粉末来自同一间旧照相馆。",evidence:"蜡面与相片乳剂定位旧照相馆。",requires:["exclude"]),
            .init(id:"identity",speaker:"照相馆观察",location:"旧照相馆",dialogue:"他拿着失窃原件，换脸时仍露出真实右手伤痕，正把被替代者锁进暗房。",evidence:"赃物、旧伤与现场拘禁行为共同核实弥伦。",requires:["compare"])
        ],copper:80,merit:20,closure:"弥伦已被拘捕，伪装撤除，被替代者获释，借面签收底片封存。"),
        .init(id:"b09",title:"铜背吞契兽",unlockMission:17,enemyID:"bounty_b09_contract_eater",modelID:"bounty-b09",visualIdentity:"青绿鳞皮、赤铜不对称背甲和夹在甲缝里的旧封签。",nodes:[
            .init(id:"witness",speaker:"两名债户",location:"民事柜台",dialogue:"我们都留着已清偿原收据，账房底联却被咬掉一个‘清’字。",evidence:"两份独立清偿收据与残缺底联。"),
            .init(id:"wound",speaker:"档案员",location:"卷宗室",dialogue:"纸断面有唾液和同一枚歪铜齿印，不是虫蛀。",evidence:"唾液与歪铜齿缺口一致。"),
            .init(id:"exclude",speaker:"账房学徒",location:"质押所外",dialogue:"公开复写本和异地登记都证明我按时销账；有人把坏账栽到我头上。",evidence:"排除无辜账房学徒。",requires:["witness","wound"]),
            .init(id:"compare",speaker:"档案员",location:"废质押所",dialogue:"纸窖排浆含相同票纸和铜屑，破窗齿痕也吻合。",evidence:"票纸、铜屑与破窗齿印定位地下纸窖。",requires:["exclude"]),
            .init(id:"identity",speaker:"纸窖观察",location:"地下纸窖",dialogue:"甲兽护着被吞的凭据，并袭击取证者。先收容它，再查是谁驱使它索债。",evidence:"甲兽被确认是危险现场目标；催债责任仍待查。",requires:["compare"])
        ],copper:110,merit:20,closure:"甲兽已安全收容，清偿凭据复原并归还债户；幕后催债者另案调查。"),
        .init(id:"b10",title:"换寿先知·绯欠",unlockMission:26,enemyID:"bounty_b10_life_oracle",modelID:"bounty-b10",visualIdentity:"白发、绯月冠架和红白长帷，掌中拿着碎裂账签。",nodes:[
            .init(id:"witness",speaker:"获治病患",location:"施济登记处",dialogue:"收据正面写免费，背面却在我签名后添上另一人的寿数。",evidence:"三张疗契背面出现事后增补条款。"),
            .init(id:"wound",speaker:"奥黛尔",location:"诊所",dialogue:"与病患从未接触的人，在同一收据号对应的日子开始衰弱。",evidence:"独立病历显示转嫁伤害的时间对应。"),
            .init(id:"exclude",speaker:"守灯值班员",location:"守灯诊所",dialogue:"公开药剂批次、原始值班稿和病人行踪都不在那条转接链里。",evidence:"排除正规诊所，保留其原始记录。",requires:["witness","wound"]),
            .init(id:"compare",speaker:"档案员",location:"施济厅外",dialogue:"封条纤维、账签缺角和转接印只出自封闭施济厅。",evidence:"三项物证定位封闭施济厅。",requires:["exclude"]),
            .init(id:"identity",speaker:"施济厅观察",location:"封闭施济厅",dialogue:"绯欠命令囊体把别人的疗效转接给自己；原底稿与伪造版本同在。",evidence:"现场转接行为、原稿和伪契核实目标。",requires:["compare"])
        ],copper:150,merit:30,closure:"转接链已切断，受害者的疗契记录归还，换寿双联账封存。")
    ]
    public static func challenge(caseID: String, nodeID: String) -> MPCChurchBountyChallenge? {
        guard ["compare","identity"].contains(nodeID) else { return nil }
        let matches: [String: (String, String, String)] = [
            "b01": ("剑齿缺口与木门双痕重合", "七号残标、缺齿剑与命令时间均吻合的非法执行体", "所有空壳守卫都长得一样"),
            "b02": ("外锁油迹与渡运收据吻合", "外锁背架、污血束带与现场人质均吻合的绑架者", "洛克也使用救援背架"),
            "b03": ("船期、溺亡船证与潮线重合", "持海盗印并发逆钟口令的袭船灵体", "港工衣服上有海水"),
            "b04": ("倒序章与断笔间距唯一匹配", "倒序模具和伪造原件同在的非法机器", "普通书记员也用铜笔"),
            "b05": ("染料批号与收款条指向同一染坊", "持剪刀胸针并使用非法紧结的现场操作者", "维娅以前会操纵红丝"),
            "b06": ("失窃甲号、锤痕与压舱铅痕相符", "持船锚腰牌、穿编号赃甲并阻止人质离开的头目", "正常重卫也穿重甲"),
            "b07": ("木漆、排水泥和重复声纹指向第三间空屋", "喉铃复声、缺趾爪和诱骗行为同时吻合的铃蛙", "修门工也常去空屋"),
            "b08": ("蜡面反光与赃收据乳剂指向旧照相馆", "拿着赃物且旧伤与病历吻合的弥伦", "孪生兄弟与他长得相同"),
            "b09": ("票纸、铜屑与歪齿印指向地下纸窖", "护着吞毁凭据并攻击取证者的甲兽", "账房学徒也经手收据"),
            "b10": ("封条纤维、账签缺角和转接印指向施济厅", "持伪契并指挥囊体转接疗效的绯欠", "所有医者都会替人治疗")
        ]
        guard let match = matches[caseID] else { return nil }
        let correct = nodeID == "compare" ? match.0 : match.1
        let misleading = match.2
        let id = caseID + "_" + nodeID + "_match"
        return .init(question: nodeID == "compare" ? "哪组证据能够排除相似对象并确定地点？" : "谁符合已验证的作案身份？", choices:[
            .init(id:id,text:correct,explanation:"独立证据相互印证，记录比对结果。"),
            .init(id:caseID+"_"+nodeID+"_look",text:misleading,explanation:"外观或职业相同不构成罪证，已从本案嫌疑依据中排除。"),
            .init(id:caseID+"_"+nodeID+"_rumor",text:"依照街头传闻，先抓最可疑的人",explanation:"传闻没有与时间、工具、现场相互印证，不能开启攻击。")
        ],correctChoiceID:id)
    }
    public static func bounty(id: String) -> MPCChurchBounty? { all.first {$0.id == id} }
    public static func encounter(id: String) -> MPCEncounterContent? {
        guard let b = all.first(where: {$0.encounterID == id}) else { return nil }
        let enemyIDs: [String] = b.id == "b03" ? [b.enemyID,"bounty_b03_escort_left","bounty_b03_escort_right"]
            : b.id == "b08" ? [b.enemyID,"bounty_b08_mirror_left","bounty_b08_mirror_right"]
            : b.id == "b10" ? [b.enemyID,"bounty_b10_life_vessel"] : [b.enemyID]
        return .init(id:id,name:b.title,investigationID:b.id,waves:[.init(enemyIDs:enemyIDs)],companionSlots:0,fixedRewardItemIDs:[],firstClearRelicID:nil,recommendedTags:["church_bounty"])
    }
    public static func enemyDefinition(id: String) -> MPCEnemyContent? {
        if ["bounty_b03_escort_left","bounty_b03_escort_right"].contains(id) {
            return .init(id:id,name:"溺钟护航残影",rank:.normal,maxHP:500,attack:45,defense:5,intentPattern:["strike","recover"],teachingPurpose:"先清护航残影解除船长防护",skills:[.init(id:id+"_strike",intent:"strike"),.init(id:id+"_recover",intent:"recover",damageBasisPoints:0)])
        }
        if id.hasPrefix("bounty_b08_mirror_") {
            return .init(id:id,name:"借脸伪影",rank:.normal,maxHP:380,attack:45,defense:3,intentPattern:["strike","recover"],teachingPurpose:"伪影可击散，但只有真身的短刺结算主案伤害",skills:[.init(id:id+"_strike",intent:"strike"),.init(id:id+"_recover",intent:"recover",damageBasisPoints:0)])
        }
        if id == "bounty_b10_life_vessel" {
            return .init(id:id,name:"收寿囊体",rank:.normal,maxHP:600,attack:30,defense:4,intentPattern:["recover","bounty_transfer","recover"],teachingPurpose:"先击破囊体可截断外来治疗",skills:[.init(id:id+"_transfer",intent:"bounty_transfer",target:.lowestHealthAlly,damageBasisPoints:0,healingBasisPoints:800)])
        }
        guard let bounty = all.first(where: {$0.enemyID == id}) else { return nil }
        let settings: [String: (Int, Int, [String])] = [
            "b01": (1400,100,["recover","charge","bounty_ambush"]),
            "b02": (2200,140,["bounty_bind_charge","bounty_bind","recover"]),
            "b03": (2200,130,["strike","charge","heavy_strike","recover"]),
            "b04": (2500,160,["bounty_copy_charge","bounty_overwrite","recover"]),
            "b05": (3200,110,["strike","strike","charge","bounty_silk_bind","recover"]),
            "b06": (3200,190,["guard","charge","heavy_strike","recover"]),
            "b07": (1300,92,["bounty_knock_charge","bounty_knock","bounty_spittle","recover"]),
            "b08": (1900,125,["bounty_mirror","charge","bounty_true_stab","recover"]),
            "b09": (2700,150,["bounty_armor","charge","bounty_rend","recover"]),
            "b10": (3000,165,["bounty_veil_charge","bounty_veil","recover"])
        ]
        guard let (hp, attack, pattern) = settings[bounty.id] else { return nil }
        let noDamage: Set<String> = ["guard","charge","recover","bounty_bind_charge","bounty_copy_charge","bounty_knock_charge","bounty_mirror","bounty_armor","bounty_veil_charge"]
        return .init(id:id,name:bounty.title,rank:.elite,maxHP:hp,attack:attack,defense:10,intentPattern:pattern,teachingPurpose:bounty.closure,skills:pattern.enumerated().map { index, intent in
            .init(id: id + "_skill_" + String(index), intent: intent, damageBasisPoints: noDamage.contains(intent) ? 0 : ["heavy_strike","bounty_rend"].contains(intent) ? 2000 : 1000)
        })
    }
}
public enum MPCChurchBountyError: Error, Equatable {
    case unavailable, locked, missingEvidence, notAccepted, unverifiedIdentity
    case wrongLocation, missingLead, invalidWarrant, warrantRequired, pokerUnavailable
    case battlePending, invalidBattle, alreadyClosed
}
public enum MPCChurchBountyObservationKind: String, Codable, Equatable, Sendable {
    case testimony, object, scene
}
/// What the player actually saw or heard. A conclusion in `evidenceIDs` is
/// separate from its source, so a disproved guess never deletes the testimony.
public struct MPCChurchBountyObservation: Codable, Equatable, Sendable {
    public let nodeID: String
    public let source: String
    public let location: String
    public let kind: MPCChurchBountyObservationKind
}
public struct MPCChurchBountyProgress: Codable, Equatable, Sendable {
    public var accepted = false
    /// Stable five-node conclusion IDs retained for pre-city saves.
    public var evidenceIDs: Set<String> = []
    public var excludedChoiceIDs: Set<String> = []
    public var visitedLocations: Set<String> = []
    public var currentLocation: String?
    public var observations: [String:MPCChurchBountyObservation] = [:]
    public var siteFeatureIDs: Set<String> = []
    public var pokerWins: Set<String> = []
    public var pokerLosses = 0
    public var alternativeLeadIDs: Set<String> = []
    public var warrantPresented = false
    public var warrantEvidenceIDs: Set<String> = []
    public var namedSuspectID: String?
    public var activeBattleID: String?
    public var victoriousBattleID: String?
    public var settledBattleIDs: Set<String> = []
    public var claimed = false
    public var pendingTurnIn: Bool { victoriousBattleID != nil && !claimed }
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case accepted, evidenceIDs, excludedChoiceIDs, visitedLocations, currentLocation
        case observations, siteFeatureIDs, pokerWins, pokerLosses, alternativeLeadIDs
        case warrantPresented, warrantEvidenceIDs, namedSuspectID
        case activeBattleID, victoriousBattleID, settledBattleIDs, claimed
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy:CodingKeys.self)
        accepted = try c.decodeIfPresent(Bool.self,forKey:.accepted) ?? false
        evidenceIDs = try c.decodeIfPresent(Set<String>.self,forKey:.evidenceIDs) ?? []
        excludedChoiceIDs = try c.decodeIfPresent(Set<String>.self,forKey:.excludedChoiceIDs) ?? []
        visitedLocations = try c.decodeIfPresent(Set<String>.self,forKey:.visitedLocations) ?? []
        currentLocation = try c.decodeIfPresent(String.self,forKey:.currentLocation)
        observations = try c.decodeIfPresent([String:MPCChurchBountyObservation].self,forKey:.observations) ?? [:]
        siteFeatureIDs = try c.decodeIfPresent(Set<String>.self,forKey:.siteFeatureIDs) ?? []
        pokerWins = try c.decodeIfPresent(Set<String>.self,forKey:.pokerWins) ?? []
        pokerLosses = try c.decodeIfPresent(Int.self,forKey:.pokerLosses) ?? 0
        alternativeLeadIDs = try c.decodeIfPresent(Set<String>.self,forKey:.alternativeLeadIDs) ?? []
        activeBattleID = try c.decodeIfPresent(String.self,forKey:.activeBattleID)
        victoriousBattleID = try c.decodeIfPresent(String.self,forKey:.victoriousBattleID)
        settledBattleIDs = try c.decodeIfPresent(Set<String>.self,forKey:.settledBattleIDs) ?? []
        claimed = try c.decodeIfPresent(Bool.self,forKey:.claimed) ?? false
        // A battle already running in an older save must remain resumable.
        warrantPresented = try c.decodeIfPresent(Bool.self,forKey:.warrantPresented)
            ?? (activeBattleID != nil || victoriousBattleID != nil || claimed)
        warrantEvidenceIDs = try c.decodeIfPresent(Set<String>.self,forKey:.warrantEvidenceIDs) ?? []
        namedSuspectID = try c.decodeIfPresent(String.self,forKey:.namedSuspectID)
    }
}
public struct MPCChurchBountyReward: Codable, Equatable, Sendable {
    public let receiptID: String
    public let caseID: String
    public let copper: Int
    public let merit: Int
}
public struct MPCChurchBountyLedger: Codable, Equatable, Sendable {
    public static let churchLocation = "教会"
    public static let tavernLocation = "酒馆"
    public static let identityFeatureIDs: Set<String> = ["appearance","conduct"]
    public private(set) var cases: [String:MPCChurchBountyProgress] = [:]
    public init() {}
    private static func pokerLocation(for id: String) -> String? {
        switch id { case "b03": return "码头"; case "b08": return tavernLocation; default: return nil }
    }
    private static func alternativeLeadLocation(for id: String) -> String? {
        switch id { case "b03": return "沉船档案柜"; case "b08": return "港务登记处"; default: return nil }
    }
    private static func hasOptionalLead(_ id: String, _ p: MPCChurchBountyProgress) -> Bool {
        pokerLocation(for:id) == nil || p.pokerWins.contains(id) || p.alternativeLeadIDs.contains(id)
    }
    /// The map/door interaction calls this only after the avatar reaches its
    /// street entrance. Dossier actions cannot change the current location.
    @discardableResult public mutating func visit(_ id: String, location: String, completedMissions: Set<Int>) throws -> Bool {
        guard let b = MPCChurchBountyCatalog.bounty(id:id) else { throw MPCChurchBountyError.unavailable }
        let allowed = Set(b.nodes.map(\.location))
            .union([Self.churchLocation,Self.tavernLocation])
            .union(Self.pokerLocation(for:id).map {[$0]} ?? [])
            .union(Self.alternativeLeadLocation(for:id).map {[$0]} ?? [])
        guard allowed.contains(location) else { throw MPCChurchBountyError.unavailable }
        var p = cases[id] ?? .init()
        let firstVisit = p.visitedLocations.insert(location).inserted
        p.currentLocation = location
        cases[id] = p
        return firstVisit
    }
    @discardableResult public mutating func accept(_ id: String, completedMissions: Set<Int>) throws -> Bool {
        guard MPCChurchBountyCatalog.bounty(id:id) != nil else { throw MPCChurchBountyError.unavailable }
        var p = cases[id] ?? .init()
        guard !p.claimed else { throw MPCChurchBountyError.alreadyClosed }
        guard [Self.churchLocation,Self.tavernLocation].contains(p.currentLocation) else { throw MPCChurchBountyError.wrongLocation }
        if p.accepted { return false }; p.accepted = true; cases[id] = p; return true
    }
    /// Sources may precede acceptance or be found out of order. Only talking
    /// to the person or examining the object at its actual location records it.
    @discardableResult public mutating func investigate(_ id: String, nodeID: String, completedMissions: Set<Int>) throws -> MPCChurchBountyNode {
        guard let b = MPCChurchBountyCatalog.bounty(id:id), let node = b.nodes.first(where: {$0.id == nodeID}) else { throw MPCChurchBountyError.unavailable }
        var p = cases[id] ?? .init()
        guard p.currentLocation == node.location, p.visitedLocations.contains(node.location) else { throw MPCChurchBountyError.wrongLocation }
        let kind: MPCChurchBountyObservationKind = ["witness","wound","exclude"].contains(nodeID) ? .testimony
            : nodeID == "identity" ? .scene : .object
        p.observations[nodeID] = .init(nodeID:nodeID,source:node.speaker,location:node.location,kind:kind)
        if ["witness","wound"].contains(nodeID) { p.evidenceIDs.insert(nodeID) }
        if p.observations["exclude"] != nil && p.evidenceIDs.isSuperset(of:["witness","wound"]) {
            p.evidenceIDs.insert("exclude")
        }
        cases[id] = p; return node
    }
    /// Two distinct site checks are required before a resemblance can be
    /// treated as an identification. They remain recorded after defeat.
    @discardableResult public mutating func inspectSiteFeature(_ id: String, featureID: String, completedMissions: Set<Int>) throws -> Bool {
        guard let b = MPCChurchBountyCatalog.bounty(id:id), let site = b.nodes.first(where:{$0.id == "identity"}) else { throw MPCChurchBountyError.unavailable }
        guard Self.identityFeatureIDs.contains(featureID) else { throw MPCChurchBountyError.unavailable }
        var p = cases[id] ?? .init()
        guard p.currentLocation == site.location else { throw MPCChurchBountyError.wrongLocation }
        let result = p.siteFeatureIDs.insert(featureID).inserted
        cases[id] = p; return result
    }
    /// An informant's agreed clue is won only at that informant's table.
    /// Wagers are settled by the campaign wallet, outside this evidence ledger.
    @discardableResult public mutating func playPoker(_ id: String, won: Bool, completedMissions: Set<Int>) throws -> Bool {
        guard MPCChurchBountyCatalog.bounty(id:id) != nil else { throw MPCChurchBountyError.unavailable }
        guard let table = Self.pokerLocation(for:id) else { throw MPCChurchBountyError.pokerUnavailable }
        var p = cases[id] ?? .init()
        guard p.currentLocation == table else { throw MPCChurchBountyError.wrongLocation }
        if won { p.pokerWins.insert(id) } else if !p.pokerWins.contains(id) { p.pokerLosses += 1 }
        cases[id] = p; return p.pokerWins.contains(id)
    }
    @discardableResult public mutating func inspectAlternativeLead(_ id: String, completedMissions: Set<Int>) throws -> Bool {
        guard MPCChurchBountyCatalog.bounty(id:id) != nil else { throw MPCChurchBountyError.unavailable }
        guard let place = Self.alternativeLeadLocation(for:id) else { throw MPCChurchBountyError.unavailable }
        var p = cases[id] ?? .init()
        guard p.currentLocation == place else { throw MPCChurchBountyError.wrongLocation }
        let result = p.alternativeLeadIDs.insert(id).inserted
        cases[id] = p; return result
    }
    @discardableResult public mutating func answer(_ id: String, nodeID: String, choiceID: String, completedMissions: Set<Int>) throws -> Bool {
        guard let challenge = MPCChurchBountyCatalog.challenge(caseID:id,nodeID:nodeID), challenge.choices.contains(where: {$0.id == choiceID}) else { throw MPCChurchBountyError.unavailable }
        _ = try investigate(id,nodeID:nodeID,completedMissions:completedMissions)
        var p = cases[id] ?? .init()
        let correct = choiceID == challenge.correctChoiceID
        if correct {
            guard p.evidenceIDs.isSuperset(of:["witness","wound"]) else { throw MPCChurchBountyError.missingEvidence }
            if nodeID == "compare" {
                guard Self.hasOptionalLead(id,p) else { throw MPCChurchBountyError.missingLead }
            } else {
                guard p.evidenceIDs.contains("compare"), p.siteFeatureIDs.isSuperset(of:Self.identityFeatureIDs) else {
                    throw MPCChurchBountyError.missingEvidence
                }
            }
            p.evidenceIDs.insert(nodeID)
        } else { p.excludedChoiceIDs.insert(choiceID) }
        cases[id] = p; return correct
    }
    /// The player names the target and chooses two independent primary sources.
    @discardableResult public mutating func presentWarrant(_ id: String, suspectID: String, supportingEvidenceIDs: Set<String>) throws -> Bool {
        guard let b = MPCChurchBountyCatalog.bounty(id:id), let site = b.nodes.first(where:{$0.id == "identity"}), var p = cases[id] else {
            throw MPCChurchBountyError.unavailable
        }
        guard p.accepted else { throw MPCChurchBountyError.notAccepted }
        guard p.currentLocation == site.location else { throw MPCChurchBountyError.wrongLocation }
        guard p.evidenceIDs.contains("identity"), p.siteFeatureIDs.isSuperset(of:Self.identityFeatureIDs) else {
            throw MPCChurchBountyError.unverifiedIdentity
        }
        let independentSources: Bool
        if let witness = p.observations["witness"], let wound = p.observations["wound"] {
            independentSources = witness.source != wound.source || witness.location != wound.location
        } else {
            // Both validated conclusions can come from a pre-city save.
            independentSources = p.observations["witness"] == nil && p.observations["wound"] == nil
        }
        guard suspectID == b.enemyID, supportingEvidenceIDs == ["witness","wound"],
              supportingEvidenceIDs.isSubset(of:p.evidenceIDs), independentSources else {
            throw MPCChurchBountyError.invalidWarrant
        }
        if p.warrantPresented { return false }
        p.warrantPresented = true
        p.warrantEvidenceIDs = supportingEvidenceIDs
        p.namedSuspectID = suspectID
        cases[id] = p; return true
    }
    @discardableResult public mutating func beginBattle(_ id: String, battleID: String) throws -> String {
        guard let b = MPCChurchBountyCatalog.bounty(id:id), let site = b.nodes.first(where:{$0.id == "identity"}) else {
            throw MPCChurchBountyError.unavailable
        }
        var p = cases[id] ?? .init()
        guard p.accepted else { throw MPCChurchBountyError.notAccepted }
        guard !p.claimed, p.victoriousBattleID == nil else { throw MPCChurchBountyError.alreadyClosed }
        guard p.evidenceIDs.contains("identity") else { throw MPCChurchBountyError.unverifiedIdentity }
        guard p.warrantPresented || p.activeBattleID == battleID else { throw MPCChurchBountyError.warrantRequired }
        guard p.currentLocation == site.location || p.activeBattleID == battleID else { throw MPCChurchBountyError.wrongLocation }
        guard !battleID.isEmpty, !cases.values.contains(where: {$0.settledBattleIDs.contains(battleID)}) else { throw MPCChurchBountyError.invalidBattle }
        if let active = p.activeBattleID { guard active == battleID else { throw MPCChurchBountyError.battlePending }; return b.encounterID }
        guard !cases.values.contains(where: {$0.activeBattleID == battleID}) else { throw MPCChurchBountyError.invalidBattle }
        p.activeBattleID = battleID; cases[id] = p; return b.encounterID
    }
    @discardableResult public mutating func settleBattle(_ id: String, battleID: String, outcome: MPCChurchBattleOutcome) throws -> Bool {
        guard var p = cases[id] else { throw MPCChurchBountyError.unavailable }
        if p.settledBattleIDs.contains(battleID) { return false }
        guard p.activeBattleID == battleID else { throw MPCChurchBountyError.invalidBattle }
        p.activeBattleID = nil; p.settledBattleIDs.insert(battleID)
        if outcome == .victory { p.victoriousBattleID = battleID }
        cases[id] = p; return true
    }
    /// Host applies this one-time receipt and saves ledger + wallet atomically.
    public mutating func claim(_ id: String) throws -> MPCChurchBountyReward? {
        guard let b = MPCChurchBountyCatalog.bounty(id:id), var p = cases[id] else { throw MPCChurchBountyError.unavailable }
        if p.claimed { return nil }
        guard p.victoriousBattleID != nil else { throw MPCChurchBountyError.invalidBattle }
        guard [Self.churchLocation,Self.tavernLocation].contains(p.currentLocation) else { throw MPCChurchBountyError.wrongLocation }
        p.claimed = true; cases[id] = p
        return .init(receiptID:"bounty-close-"+id,caseID:id,copper:b.copper,merit:b.merit)
    }
}
