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
            .init(id:"witness",speaker:"诺恩",location:"封锁公告处",dialogue:"两个人。卖炭的老周，还有个出门买退烧药的女人，都死在封锁线外，同一段封锁里。第一声钟响时，巡逻队还没换班。",evidence:"两起凶案发生于同一封锁时段。"),
            .init(id:"wound",speaker:"奥黛尔",location:"诊所",dialogue:"剑从左上斜劈下来，同一处缺口留下两枚短齿痕，不是摔的。她手里那包退烧药，我替她送回家了。",evidence:"独立验伤：左斜剑创与双短齿。"),
            .init(id:"exclude",speaker:"值勤登记员",location:"巡逻值房",dialogue:"街上都说是守卫干的，昨晚有人往值房门口泼泔水。登记簿和两个夜班的都能作证：那时候巡逻队在桥那边。",evidence:"排除误导：正常巡逻队有独立不在场证明。",requires:["witness","wound"]),
            .init(id:"compare",speaker:"维拉",location:"铁匠铺",dialogue:"木门上的割痕和剑齿拓片叠起来，两枚短齿分毫不差。油垢只有废岗亭的旧机座才有。这一型，是我师父那辈造来守夜的。",evidence:"实物比对指向废岗亭。",requires:["exclude"]),
            .init(id:"identity",speaker:"废岗亭观察",location:"废岗亭",dialogue:"左肩的七号只剩半截，剑上缺着齿。胸腔里那张处决令早该作废，时间却和两起案子分秒不差。它亮起灯，转向门外的人。",evidence:"目标独立编号与作案工具核验完成。",requires:["compare"])
        ],copper:60,merit:12,closure:"七号停在了废岗亭，命令匣已封存。那张处决令早就撤销了，只是一直没人去告诉它。最后修过它的维修工，诺恩会另外去问，不因为会修就算他有罪。"),
        .init(id:"b02",title:"背架收尸人",unlockMission:14,enemyID:"bounty_b02_abductor",modelID:"bounty-b02",visualIdentity:"旧褐工装，沾血的反扣束带与外锁背架。",nodes:[
            .init(id:"witness",speaker:"奥黛尔",location:"诊所",dialogue:"他运走的那个“死人”，昨天还在这儿签收了咳嗽药，问我能不能便宜两个铜子。死亡证明上却写他前天就死了。",evidence:"被掳者近期仍活着。"),
            .init(id:"wound",speaker:"逃出的工人",location:"避难屋",dialogue:"我看见阿贝还在动。束带扣朝外，那人说，死人用不着自己解。阿贝喊了我一声。我没回头，我先跑了。",evidence:"独立目击：活人被反扣束带拘禁。"),
            .init(id:"exclude",speaker:"救援登记员",location:"市政救援站",dialogue:"都来问洛克。他的编号和救援录音对得上，他那副架子从不从外面锁。别拿他的旧事，往这案子上扣。",evidence:"洛克的救援录音与交接编号相符。",requires:["witness","wound"]),
            .init(id:"compare",speaker:"维拉",location:"渡运台",dialogue:"锁扣上的油，和这张去废浴场的渡运收据对得上。救援架从不从外面锁。从外面锁，是怕背上的人醒过来。",evidence:"油迹与收据交叉定位废浴场。",requires:["exclude"]),
            .init(id:"identity",speaker:"浴场观察",location:"废浴场",dialogue:"空池子里摆着几副外锁背架，束带上的血还没干，其中一副里的人还在挣。赃运收据钉在墙上。他看见你，先去收紧那副背架。",evidence:"活人获救入口与作案者身份核验。",requires:["compare"])
        ],copper:80,merit:16,closure:"收尸人被押走了。他以前真是收尸的，按具算钱；码头大火那年，一夜背了十几趟。后来死的人不够了。阿贝送进了诊所。先跑的那个工友在门外站了一下午，最后还是进去了。"),
        .init(id:"b03",title:"溺钟海盗",unlockMission:23,enemyID:"bounty_b03_drowned_captain",modelID:"bounty-b03",visualIdentity:"海蓝亡魂，胸前船锚章与旧海盗印。",nodes:[
            .init(id:"witness",speaker:"港务员",location:"港务登记处",dialogue:"三艘船都是退潮钟响以后出的港，船期我一个字没改，你可以翻。第三艘的大副没回来。他上个月刚当了爹。",evidence:"独立船期锁定袭船时间。"),
            .init(id:"wound",speaker:"伊莱",location:"钟台",dialogue:"那不是换班口令。倒着敲，三短一长，是老海盗队叫船回来的暗号。别问我怎么知道。这种东西，我卖过。",evidence:"逆钟节拍属于海盗队。"),
            .init(id:"exclude",speaker:"老水手",location:"码头",dialogue:"他们抓了小莫，说他就是船长。可出事后湿甲板上只有我们的脚印。那船长早淹死了。二十年前，是他把我推上救生艇的。",evidence:"排除活人港工；亡魂线索与旧船证一致。",requires:["witness","wound"]),
            .init(id:"compare",speaker:"港务员",location:"沉船档案柜",dialogue:"溺亡船证、潮线上的残盐、袭船的钟点，三样对在一起。潮一退，钟沉船就露出舱口。那张船员表，到今天也没人去注销。",evidence:"三项物证定位钟沉船。",requires:["exclude"]),
            .init(id:"identity",speaker:"沉船观察",location:"钟沉船",dialogue:"舱里坐满了溺死的人，多半只是渔夫。只有一个握着海盗印，一遍遍倒敲船钟，把残影赶向过路的船。他在点名。没人应。",evidence:"海盗印、暗号与攻击行为核验。",requires:["compare"])
        ],copper:100,merit:20,closure:"船长散了。海盗印和赃货账入档，船主们按账取回货物。老水手要走了那张船员表。他说，总得有人把这些名字念完。"),
        .init(id:"b04",title:"铜笔伪造者",unlockMission:19,enemyID:"bounty_b04_forgery_engine",modelID:"enemy_codex_executor",visualIdentity:"铜绿笔端、倒序印号，机械臂留有断齿。",nodes:[
            .init(id:"witness",speaker:"遗产领取者",location:"公证柜台",dialogue:"两份遗嘱，都写唯一继承人，一份是我，一份是我哥。我们半年没说话了。我不要房子，只想知道爸写的是哪一张。",evidence:"两份互斥遗嘱原件。"),
            .init(id:"wound",speaker:"印章员",location:"验印台",dialogue:"章是真的，序号却倒着走。有人拿真章，排了一个假的先后。我盖了三十年章，头一回见真章替人撒谎。",evidence:"独立验印确认倒序号。"),
            .init(id:"exclude",speaker:"维拉",location:"铁匠铺",dialogue:"外头都在骂书记员。普通抄写笔会回弹，这道断笔的间距，是坏齿轮磨出来的。这是机器，不是人手。",evidence:"排除普通书记员，锁定特定机器缺陷。",requires:["witness","wound"]),
            .init(id:"compare",speaker:"印厂旧工",location:"废印厂外",dialogue:"两张纸的间距叠起来，只有三号机印得出。它少的那颗齿，是我当年没修好。有人把它偷运回废印厂了。",evidence:"断笔间距与机器档案唯一匹配。",requires:["exclude"]),
            .init(id:"identity",speaker:"印厂观察",location:"废印厂",dialogue:"三号机还热着。倒序模具卡在臂上，底下压着一张没印完的遗嘱。机身序号和失窃登记一样。桌上一叠收据，一张一个价。",evidence:"机器序号、工具与伪造原件核验。",requires:["compare"])
        ],copper:120,merit:24,closure:"三号机拆了，伪造母版销毁，合法证书退还，遗嘱的先后理清了。兄妹俩在公证柜台前碰了面，谁也没先开口。最后哥哥把父亲的旧怀表推了过去。"),
        .init(id:"b05",title:"赤丝裁衣人",unlockMission:27,enemyID:"bounty_b05_silk_murderer",modelID:"bounty-b05",visualIdentity:"灰白衣、赤丝与小银剪胸针。",nodes:[
            .init(id:"witness",speaker:"衣铺老板",location:"旧衣铺",dialogue:"失踪的人都留了同一种量衣单。有个姑娘订了嫁衣，定金付了，说下个月来取。衣服一直没回来，她也没有。",evidence:"失踪名单与量衣单对应。"),
            .init(id:"wound",speaker:"奥黛尔",location:"诊所",dialogue:"针孔周围有出血。是活着的时候勒紧的，不是死后缝上的。他们那时候，都醒着。",evidence:"独立验伤证实生前侵害。"),
            .init(id:"exclude",speaker:"维娅的封存证言",location:"联络处",dialogue:"这不是我的结。外头多了一道死结，是专门让人喊不出声的。我绑过人，可我从没让谁喊不出声。",evidence:"现场绳结与维娅封存的结法不同，另有操作者。",requires:["witness","wound"]),
            .init(id:"compare",speaker:"染坊学徒",location:"染坊账房",dialogue:"赤染料的批号和收款条对得上，那些量衣单最后都进了后院染坊。师傅叫我别问，我就没问。现在我问了。",evidence:"染料与收款条定位染坊后院。",requires:["exclude"]),
            .init(id:"identity",speaker:"染坊观察",location:"染坊后院",dialogue:"晾布架上挂着失踪者的衣料，尺寸一件件标好。他胸前别着小银剪，把打了死结的赤丝收紧，轻声说：“别动，马上就合身了。”",evidence:"独立凶手与现场罪证匹配。",requires:["compare"])
        ],copper:140,merit:28,closure:"裁衣人被押走时只问了一句：那件嫁衣，能不能让他做完。被缚的人都救了下来，那个姑娘也在，嗓子还哑着。维娅的证言照实入卷，不抵她原有的责任。"),
        .init(id:"b06",title:"无灯押船人",unlockMission:26,enemyID:"bounty_b06_dark_hold_captain",modelID:"enemy_archive_adjudicator",visualIdentity:"漆黑赃甲、划除的军号与船锚腰牌。",nodes:[
            .init(id:"witness",speaker:"港务员",location:"港务登记处",dialogue:"三艘货船进暗航线前都熄了灯。不是没油，补给单上刚加满。舱单写的是咸鱼。咸鱼不会敲舱板。",evidence:"熄灯航线与补给记录冲突。"),
            .init(id:"wound",speaker:"铁匠",location:"军甲修理棚",dialogue:"这块甲片的编号在失窃单上。我只认编号。别见谁穿重甲就抓谁，我儿子也穿，在北门站岗。",evidence:"赃甲序号独立确认。"),
            .init(id:"exclude",speaker:"码头工",location:"报警钟楼",dialogue:"重卫交班的时候，钟还好好的。后来那个挂船锚腰牌的，抡锤把钟舌砸了。我拉了三下绳，一点声都没有。",evidence:"排除正常值勤重卫；具体毁钟者有独立标识。",requires:["witness","wound"]),
            .init(id:"compare",speaker:"港务员",location:"封舱台外",dialogue:"赃甲编号、锤痕、压舱铅痕，都指向同一条船。封舱台就在前面。我记了一辈子账，没想过账上记的是人。",evidence:"三项物证定位封舱台。",requires:["exclude"]),
            .init(id:"identity",speaker:"封舱观察",location:"封舱台",dialogue:"他甲上的军号被刮掉了，腰间挂着船锚牌。舱口挤满了人，他提锤挡在跳板前，一个也不放。有个孩子在哭，他叫人把灯熄了。",evidence:"赃甲、腰牌、现场强迫行为核验。",requires:["compare"])
        ],copper:160,merit:32,closure:"押船头目倒下了。他当过兵，那身甲原本是他的，退伍时被收了回去。人质一个个走下跳板，那个孩子下船时，回头看了一眼船上的灯。失窃军甲与赃物已查扣归档。"),
        .init(id:"b07",title:"三声敲门客",unlockMission:5,enemyID:"bounty_b07_knocker",modelID:"bounty-b07",visualIdentity:"青蓝低伏的铃蛙，金色喉铃和不同门牌的封签。",nodes:[
            .init(id:"witness",speaker:"夜班邮差",location:"旧邮局",dialogue:"同一句“替我开门”，两条街同时有人听见。可说这话的老太太，那会儿正躺在诊所。她每天都来问，有没有她儿子的信。",evidence:"求救声在同一时刻出现在两个街区。"),
            .init(id:"wound",speaker:"奥黛尔",location:"诊所",dialogue:"三户人家的门闩上，都是一样的黏液，还有右前爪缺趾的木屑。老太太醒了，可从那晚起，一个字也说不出来。",evidence:"独立验伤与缺趾爪痕吻合。"),
            .init(id:"exclude",speaker:"修门工",location:"木工街",dialogue:"我的工单、五根手指留下的工具印子、邮差的时间，你们都去查。我是耳朵不好，又不是心不好。街坊现在连门都不让我修了。",evidence:"排除被传闻误指的修门工。",requires:["witness","wound"]),
            .init(id:"compare",speaker:"档案员",location:"旧排水口",dialogue:"门上的木漆、排水口的泥、录下的重复声纹，三样都指向第三间空屋。我小时候，那屋里总飘出炖汤的味道。",evidence:"三种独立痕迹定位第三间空屋。",requires:["exclude"]),
            .init(id:"identity",speaker:"空屋观察",location:"第三间空屋",dialogue:"它伏在门后，喉铃一鼓，就是老太太的声音：“替我开门。”缺趾的爪子搭在门闩上。门外，有人正在掏钥匙。",evidence:"现场行为、喉铃与爪痕共同核实目标。",requires:["compare"])
        ],copper:60,merit:20,closure:"铃蛙不叫了，借声喉膜的拓样已封存。录下的那句求救还给了老太太。她如今说不出话，有时会请邮差替她放一遍，听听自己原来的声音。"),
        .init(id:"b08",title:"借脸人·弥伦",unlockMission:11,enemyID:"bounty_b08_miren",modelID:"bounty-b08",visualIdentity:"半张蜡面具、深蓝礼服、红领饰和短刺；真身右手有旧伤。",nodes:[
            .init(id:"witness",speaker:"被冒名者的雇主",location:"雇工会",dialogue:"同一天，他在两座城里各签了一张收据，不可能都是本人。那孩子老实，多领一个铜子都要还回来。",evidence:"同日异地的两张签收原件。"),
            .init(id:"wound",speaker:"奥黛尔",location:"诊所",dialogue:"那孩子的病历上，右手是好的。可伪签的手压在掌根有道旧伤，这道伤我在另一份病历上见过。他母亲还来问我，儿子怎么忽然不咳了。",evidence:"病历旧伤与伪签手压不符。"),
            .init(id:"exclude",speaker:"港务员",location:"港务登记处",dialogue:"被疑的那个孪生兄弟，出港底片和船员证词都在，他没回来过。上船那天，他在这儿问我外海冷不冷。",evidence:"独立时间线排除孪生兄弟。",requires:["witness","wound"]),
            .init(id:"compare",speaker:"照相师",location:"相片铺",dialogue:"蜡面的反光，和赃收据上沾的乳剂粉，出自同一间旧照相馆。那馆子关门前最后一单是全家福，到今天没人来取。",evidence:"蜡面与相片乳剂定位旧照相馆。",requires:["exclude"]),
            .init(id:"identity",speaker:"照相馆观察",location:"旧照相馆",dialogue:"他攥着失窃的原件，把那个年轻人往暗房里推。蜡面换了一张又一张，右手那道旧伤一直在。他小声练着一个字：“妈。”",evidence:"赃物、旧伤与现场拘禁行为共同核实弥伦。",requires:["compare"])
        ],copper:80,merit:20,closure:"弥伦被押走了。蜡面揭下来，是一张很普通的脸。被锁在暗房的年轻人回了家，他母亲开门看了他很久，才问：“真是你吗？”借面签收的底片已封存。"),
        .init(id:"b09",title:"铜背吞契兽",unlockMission:17,enemyID:"bounty_b09_contract_eater",modelID:"bounty-b09",visualIdentity:"青绿鳞皮、赤铜不对称背甲和夹在甲缝里的旧封签。",nodes:[
            .init(id:"witness",speaker:"两名债户",location:"民事柜台",dialogue:"我们俩都留着还清的原收据，账房的底联却被咬掉一个“清”字。我还了七年，最后一笔是卖了我老婆的缝纫机。",evidence:"两份独立清偿收据与残缺底联。"),
            .init(id:"wound",speaker:"档案员",location:"卷宗室",dialogue:"纸的断口上有唾液，还有同一枚歪铜齿的印子，不是虫蛀。虫子不挑字，它专挑“清”字下嘴。",evidence:"唾液与歪铜齿缺口一致。"),
            .init(id:"exclude",speaker:"账房学徒",location:"质押所外",dialogue:"复写本是公开的，异地登记也查得到，我每一笔都按时销了账。现在有人见我就吐口水，我娘都不敢出门买菜。",evidence:"排除无辜账房学徒。",requires:["witness","wound"]),
            .init(id:"compare",speaker:"档案员",location:"废质押所",dialogue:"纸窖排出来的浆里有同一批票纸和铜屑，破窗上的齿印也对得上。窗台上放着一只碗。有人一直在喂它。",evidence:"票纸、铜屑与破窗齿印定位地下纸窖。",requires:["exclude"]),
            .init(id:"identity",speaker:"纸窖观察",location:"地下纸窖",dialogue:"甲兽趴在一堆咬烂的凭据上，背甲缝里夹满旧封签。你一靠近，它就扑上来。它护着那堆纸，像护着一窝蛋。",evidence:"甲兽被确认是危险现场目标；催债责任仍待查。",requires:["compare"])
        ],copper:110,merit:20,closure:"甲兽已安全收容，清偿凭据一张张复原，还给了债户。窗台上那只碗是谁放的，还在查。卖了缝纫机的那位拿着收据，在柜台前站了很久，说要回去念给老婆听。"),
        .init(id:"b10",title:"换寿先知·绯欠",unlockMission:26,enemyID:"bounty_b10_life_oracle",modelID:"bounty-b10",visualIdentity:"白发、绯月冠架和红白长帷，掌中拿着碎裂账签。",nodes:[
            .init(id:"witness",speaker:"获治病患",location:"施济登记处",dialogue:"收据正面写着免费。我签了字以后，背面又添了一行，写的是别人的寿数。我能下地了。可那是谁的？",evidence:"三张疗契背面出现事后增补条款。"),
            .init(id:"wound",speaker:"奥黛尔",location:"诊所",dialogue:"从没见过这些病人的人，在收据号对应的那几天开始衰弱。卖花的小姑娘，上周还跑着来送花，现在要人扶。",evidence:"独立病历显示转嫁伤害的时间对应。"),
            .init(id:"exclude",speaker:"守灯值班员",location:"守灯诊所",dialogue:"药剂批次是公开的，值班原稿和病人行踪都在，跟那条转接链不沾边。我们救不了所有人，可从没让别人替病人付钱。",evidence:"排除正规诊所，保留其原始记录。",requires:["witness","wound"]),
            .init(id:"compare",speaker:"档案员",location:"施济厅外",dialogue:"封条纤维、账签缺角、转接印，只有封闭的施济厅才有。码头大火那年冬天，门口的队排到了桥上。",evidence:"三项物证定位封闭施济厅。",requires:["exclude"]),
            .init(id:"identity",speaker:"施济厅观察",location:"封闭施济厅",dialogue:"原底稿和改过的伪契摊在同一张桌上。绯欠一抬手，囊体就把别人的疗效送进她身体。“我没骗谁，”她说，“他们都签了字。”",evidence:"现场转接行为、原稿和伪契核实目标。",requires:["compare"])
        ],copper:150,merit:30,closure:"转接链断了，疗契记录还给了受害者，换寿双联账已封存。卖花的小姑娘慢慢能自己走路了。那个先好起来的病人，每周都去买她一束花。")
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
        return .init(question: nodeID == "compare" ? "哪一组证据，能排除看着相似的嫌疑，又能指出地方？" : "已经查实的这些，对得上谁？", choices:[
            .init(id:id,text:correct,explanation:"几样证据各有来处，彼此对得上。记下了。"),
            .init(id:caseID+"_"+nodeID+"_look",text:misleading,explanation:"长得像、干同一行，都不算证据。这一条划掉了。"),
            .init(id:caseID+"_"+nodeID+"_rumor",text:"听街上的，先抓最可疑的那个",explanation:"传闻对不上时间、工具和现场，不能凭这个动手。")
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
