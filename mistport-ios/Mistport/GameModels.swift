import SwiftUI

enum CharacterGender: String, CaseIterable, Identifiable, Hashable {
    case male
    case female

    var id: Self { self }

    var title: String {
        switch self {
        case .male: "男性"
        case .female: "女性"
        }
    }
}

struct Pathway: Identifiable, Hashable {
    enum ID: String, CaseIterable, Hashable {
        case fool
        case priestess
        case chariot
        case magician
        case justice
        case star
    }

    let id: ID
    let arcana: String
    let name: String
    let sequenceNineTitle: String
    let symbol: String
    let artName: String
    let femaleArtName: String
    let tint: Color
    let principle: String
    let description: String
    let abilityName: String
    let abilityDescription: String
    let soloVerb: String
    let teamRole: String
    let authority: String

    func artName(for gender: CharacterGender) -> String {
        gender == .female ? femaleArtName : artName
    }

    func displayName(for gender: CharacterGender) -> String {
        guard id == .priestess else { return name }
        return gender == .female ? "女祭司·潮听" : "祭司·潮听"
    }

    func sequenceNineTitle(for gender: CharacterGender) -> String {
        switch (id, gender) {
        case (.fool, .male): "街头戏法师"
        case (.fool, .female): "幻面戏法师"
        case (.priestess, .male): "潮声灵视者"
        case (.priestess, .female): "月潮灵视者"
        case (.chariot, .male): "铁壁夜巡者"
        case (.chariot, .female): "赤锋夜巡者"
        case (.magician, .male): "盐晶炼金师"
        case (.magician, .female): "星火炼金师"
        case (.justice, .male): "誓约裁定者"
        case (.justice, .female): "誓约审判官"
        case (.star, .male): "星路测绘师"
        case (.star, .female): "星海领航员"
        }
    }

    func characterDescription(for gender: CharacterGender) -> String {
        let pronoun = gender == .female ? "她" : "他"
        return switch id {
        case .fool: "\(pronoun)擅长伪装、误导与从常理的裂缝中脱身；出售幻象时，也始终记得自己是谁。"
        case .priestess: "\(pronoun)能窥见梦境、灵性残响与被遮蔽的线索；知晓越多，也越难回到无知。"
        case .chariot: "\(pronoun)以意志驾驭身体与局势，是黑夜里可靠的前锋；唯有停下时，恐惧才会追上来。"
        case .magician: "\(pronoun)擅长拆解材料、改造机关并重塑战场；废料可以成为钥匙，交换法则也终会追债。"
        case .justice: "\(pronoun)能识别契约、分配代价并约束异常；秩序保护众人，也会首先审判立誓者。"
        case .star: "\(pronoun)观测可能性、折叠短距并寻找绝境航路；每一次捷径，也让远方更清楚地看见自己。"
        }
    }
}

struct ResourceDelta: Hashable {
    var acting = 0
    var clues = 0
    var materials = 0
    var instability = 0

    static let none = ResourceDelta()
}

struct StoryChoice: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let result: String
    let delta: ResourceDelta
    let isPathAligned: Bool
}

struct Encounter: Identifiable, Hashable {
    let id: String
    let district: String
    let artName: String
    let title: String
    let body: String
    let alignedChoices: [Pathway.ID: StoryChoice]
    let fallbackChoice: StoryChoice
}

enum GamePhase: Equatable {
    case title
    case pathSelection
    case cityHub
    case districtMap
    case dungeon
    case adventure
    case ritual
    case ending(success: Bool)
}

enum GameContent {
    static let initiallyAvailablePathIDs: Set<Pathway.ID> = [
        .fool,
        .priestess,
        .chariot
    ]

    static var initiallyAvailablePathways: [Pathway] {
        pathways.filter { initiallyAvailablePathIDs.contains($0.id) }
    }

    static let pathways: [Pathway] = [
        Pathway(
            id: .fool,
            arcana: "0",
            name: "愚者",
            sequenceNineTitle: "街头戏法师",
            symbol: "theatermasks.fill",
            artName: "PathFoolMale",
            femaleArtName: "PathFoolFemale",
            tint: Color(red: 0.78, green: 0.55, blue: 0.94),
            principle: "利用错误掩盖真实，再从破绽中穿过",
            description: "愚者不追求制造完美幻象，而是让错误先被相信。误认会成为武器，也会慢慢改写你对自己的记忆。",
            abilityName: "误认编排",
            abilityDescription: "每次利用错误都会扩大下一次破绽，但失控侵蚀也会更接近你。",
            soloVerb: "制造误认、错置身份、利用错误穿行",
            teamRole: "控场与欺敌",
            authority: "身份与错误"
        ),
        Pathway(
            id: .priestess,
            arcana: "II",
            name: "女祭司·潮听",
            sequenceNineTitle: "灵视者",
            symbol: "moon.stars.fill",
            artName: "PathPriestessMale",
            femaleArtName: "PathPriestessFemale",
            tint: Color(red: 0.45, green: 0.74, blue: 0.98),
            principle: "从沉默与细节中听见真相",
            description: "窥见梦境、灵性残响与被遮蔽的线索。知晓越多，越难回到无知。",
            abilityName: "灵性聆听",
            abilityDescription: "本次行动额外获得 1 条仪式线索，但失控侵蚀 +1。",
            soloVerb: "读取记忆、进入梦境、辨认灵性残响",
            teamRole: "调查与治疗",
            authority: "记忆与梦"
        ),
        Pathway(
            id: .chariot,
            arcana: "VII",
            name: "战车·远征",
            sequenceNineTitle: "夜巡者",
            symbol: "shield.lefthalf.filled",
            artName: "PathChariotMale",
            femaleArtName: "PathChariotFemale",
            tint: Color(red: 1.0, green: 0.70, blue: 0.32),
            principle: "在恐惧中仍向目标前进",
            description: "以意志驾驭身体与局势，成为黑夜里可靠的前锋。停下时，恐惧才会追上来。",
            abilityName: "意志冲锋",
            abilityDescription: "本次行动额外获得 1 份超凡材料，但失控侵蚀 +1。",
            soloVerb: "追猎、护送、突破危险封锁",
            teamRole: "前锋与守护",
            authority: "意志与动量"
        ),
        Pathway(
            id: .magician,
            arcana: "I",
            name: "魔术师·炼成",
            sequenceNineTitle: "盐晶学徒",
            symbol: "wand.and.stars",
            artName: "PathMagicianMale",
            femaleArtName: "PathMagicianFemale",
            tint: Color(red: 0.34, green: 0.88, blue: 0.72),
            principle: "每一次创造都必须付出等价之物",
            description: "拆解材料、改造机关并临时重塑战场。你能让废料成为钥匙，也会被交换法则追债。",
            abilityName: "等价炼成",
            abilityDescription: "为线索与材料中较少的一项补充 1 点，但失控侵蚀 +1。",
            soloVerb: "拆解机关、炼制道具、重构环境",
            teamRole: "制造与范围输出",
            authority: "物质与交换"
        ),
        Pathway(
            id: .justice,
            arcana: "XI",
            name: "正义·誓衡",
            sequenceNineTitle: "誓约见证人",
            symbol: "scalemass.fill",
            artName: "PathJusticeMale",
            femaleArtName: "PathJusticeFemale",
            tint: Color(red: 0.96, green: 0.48, blue: 0.42),
            principle: "只许下自己愿意承担代价的誓言",
            description: "识别契约、分配代价并约束异常。秩序能保护所有人，也会首先审判立誓者。",
            abilityName: "誓衡校准",
            abilityDescription: "本次行动抵消 1 点失控侵蚀；已有侵蚀也可被净化。",
            soloVerb: "审讯证词、订立契约、裁定代价",
            teamRole: "护盾与净化",
            authority: "秩序与誓言"
        ),
        Pathway(
            id: .star,
            arcana: "XVII",
            name: "星星·星渡",
            sequenceNineTitle: "星图测绘师",
            symbol: "sparkles",
            artName: "PathStarMale",
            femaleArtName: "PathStarFemale",
            tint: Color(red: 0.44, green: 0.64, blue: 1.0),
            principle: "先为迷路的人指出仍可抵达的方向",
            description: "观测可能性、折叠短距并从绝境中寻找航路。每一次捷径，都让远方更清楚地看见你。",
            abilityName: "可能航线",
            abilityDescription: "本次行动额外获得 1 点扮演与 1 条线索，但失控侵蚀 +1。",
            soloVerb: "测绘异境、预判路线、跨越空间断层",
            teamRole: "远程与位移",
            authority: "距离与可能"
        )
    ]

    static let encounters: [Encounter] = [
        Encounter(
            id: "clockmaker",
            district: "旧城区 · 雨夜巷口",
            artName: "SceneClockDistrictV2",
            title: "被保存的人",
            body: "一个陌生人把自己的死亡记录交给你：档案写着他已经被保存，但街上仍有人用他的名字生活。雨水正在冲淡身份牌上的字。",
            alignedChoices: [
                .fool: choice("clock-fool", "戴上钟表匠的旧礼帽，演一场“本人归来”的戏", "用假身份换来进入现场的十分钟。", "你的假身份骗过了巡夜人。", ResourceDelta(acting: 1, materials: 1)),
                .priestess: choice("clock-priestess", "触摸积水里的怀表残响，听最后一段滴答", "灵性残响指向码头方向。", "银色水汽在你指尖停留。", ResourceDelta(acting: 1, clues: 1)),
                .chariot: choice("clock-chariot", "顶着雨翻过封锁线，沿屋檐脚印追向街口", "不让雨水先于你抹去真相。", "你找到一枚带盐味的齿轮。", ResourceDelta(acting: 1, materials: 1)),
                .magician: choice("clock-magician", "拆开停摆的街灯，用铜线复原齿轮留下的磁痕", "废旧零件也会记得自己曾经如何转动。", "磁痕指向港区，你收起一枚盐蚀簧片。", ResourceDelta(acting: 1, materials: 1)),
                .justice: choice("clock-justice", "核对封锁记录，让每位巡夜人重新确认自己的证词", "相互矛盾的誓言会在纸面上留下重量。", "缺失的十分钟指向一位白手套访客。", ResourceDelta(acting: 1, clues: 1)),
                .star: choice("clock-star", "以钟楼为原点重绘雨幕中的移动轨迹", "先找出仍然可以抵达的方向。", "一条不合常理的路线直通月桂街。", ResourceDelta(acting: 1, clues: 1))
            ],
            fallbackChoice: choice("clock-fallback", "替女儿安抚巡夜人，争取调查时间", "稳妥，但对消化帮助有限。", "你得到一张进入钟楼的通行证。", ResourceDelta(clues: 1, instability: 1), false)
        ),
        Encounter(
            id: "letter",
            district: "月桂街 · 茶馆二层",
            artName: "SceneLaurelTeaHouse",
            title: "一封没有署名的信",
            body: "信纸上只写着一句：别在镜子里寻找他。茶馆主人坚持说，这封信是自己长腿走进来的。",
            alignedChoices: [
                .fool: choice("letter-fool", "把墨迹改成另一人的笔迹，试探客人的反应", "让隐秘自己露出破绽。", "白手套客人下意识握紧了茶匙。", ResourceDelta(acting: 1, clues: 1)),
                .priestess: choice("letter-priestess", "辨认纸纤维里的灵性回声，追溯投信者的情绪", "恐惧来自北边，混着海盐气味。", "夹层里藏着一片银盐。", ResourceDelta(clues: 1, materials: 1)),
                .chariot: choice("letter-chariot", "在白手套客人离席时拦下他，逼他交代入口", "恐惧也要向目标让路。", "他交代了剧院的位置。", ResourceDelta(acting: 1, clues: 1)),
                .magician: choice("letter-magician", "用茶炉蒸汽分离信纸夹层里的银盐", "任何造物都要留下材料与工序。", "银盐显出废弃剧院的压印。", ResourceDelta(clues: 1, materials: 1)),
                .justice: choice("letter-justice", "请所有在场者签下“未触碰此信”的临时证言", "说出口的事实必须承担重量。", "一人的签名迅速褪色，他承认见过投信者。", ResourceDelta(acting: 1, materials: 1)),
                .star: choice("letter-star", "把纸张折成港区星图，对照缺失的经纬刻线", "不存在的地址也可能是一条航线。", "折痕在废弃剧院的位置交汇。", ResourceDelta(clues: 1, materials: 1))
            ],
            fallbackChoice: choice("letter-fallback", "记录纹样，与钟楼齿轮进行比对", "不惊动任何人。", "纹样与港区的古老剧院相同。", ResourceDelta(clues: 1, instability: 1), false)
        ),
        Encounter(
            id: "theater",
            district: "潮汐码头 · 废弃剧院",
            artName: "SceneMirrorTheater",
            title: "镜中观众",
            body: "剧院舞台空无一人，观众席的镜子却映出满座人影。它们正整齐地转头，看向你。",
            alignedChoices: [
                .fool: choice("theater-fool", "走上舞台，宣布今晚的演员已经换人", "用更大的幻象吞没旧幻象。", "一枚裂纹面具从镜中滑落。", ResourceDelta(acting: 1, materials: 1)),
                .priestess: choice("theater-priestess", "保持静默，辨认倒影里重复的同一双眼睛", "在噪声里听出唯一的真相。", "钟表匠被困在最深处的镜子后。", ResourceDelta(acting: 1, clues: 1)),
                .chariot: choice("theater-chariot", "直入观众席，用灯火和脚步打破幻觉", "你选择成为第一个移动的人。", "镜面碎裂，露出台阶与潮汐符号。", ResourceDelta(clues: 1, materials: 1)),
                .magician: choice("theater-magician", "用舞台铜轨拼出共振器，让所有镜面同时失谐", "让环境本身成为你的工具。", "碎片落下，露出地下祭室的结构图。", ResourceDelta(acting: 1, clues: 1)),
                .justice: choice("theater-justice", "指出观众与演员的契约从未成立，要求镜像退席", "无效的契约没有资格索取代价。", "第一排镜影消散，留下潮汐盐晶。", ResourceDelta(clues: 1, materials: 1)),
                .star: choice("theater-star", "沿唯一没有倒影的座位折跃到镜幕后方", "错误的空间里仍有正确的出口。", "你看见被困的钟表匠与祭室入口。", ResourceDelta(acting: 1, materials: 1))
            ],
            fallbackChoice: choice("theater-fallback", "用粉笔标记镜子的变化规律", "后退半步，先记住规则。", "涨潮时，镜像会短暂失去力量。", ResourceDelta(clues: 1, instability: 1), false)
        ),
        Encounter(
            id: "ritual",
            district: "剧院地下 · 盐雾祭室",
            artName: "SceneSaltRitual",
            title: "倒走的仪式",
            body: "钟表匠被缚在仪式中央。海水正从地缝倒流进祭坛；再过片刻，他的记忆会被换给镜里的某个东西。",
            alignedChoices: [
                .fool: choice("ritual-fool", "让祭坛相信你才是被献祭者", "诱导仪式把目标投向错误的人。", "祭坛迟疑了，你扯断了主阵纹路。", ResourceDelta(acting: 1, clues: 1)),
                .priestess: choice("ritual-priestess", "听清逆读祷词，再以正序念出", "让被颠倒的真相回到原位。", "盐雾凝成一颗可用的潮汐盐晶。", ResourceDelta(acting: 1, materials: 1)),
                .chariot: choice("ritual-chariot", "穿过倒流的海水，把钟表匠拖出祭坛", "在恐惧的中心继续前行。", "你的伤口化为炽热的仪式印记。", ResourceDelta(acting: 1, materials: 1)),
                .magician: choice("ritual-magician", "以裂镜、盐晶与发条重铸祭坛的能量回路", "交换可以发生，但由你决定等价物。", "仪式开始消耗自身，而不是钟表匠。", ResourceDelta(acting: 1, materials: 1)),
                .justice: choice("ritual-justice", "代钟表匠承认一项真实的遗憾，废除伪造的献祭契约", "唯有自愿承担的誓言才具有力量。", "锁链松开，祭坛承认契约无效。", ResourceDelta(acting: 1, materials: 1)),
                .star: choice("ritual-star", "标出祭坛与镜中世界错位的一寸，把人移回正确坐标", "最短的航线有时只差一步。", "钟表匠跌出阵心，潮汐盐晶留在原地。", ResourceDelta(acting: 1, materials: 1))
            ],
            fallbackChoice: choice("ritual-fallback", "砸碎引流槽，强行打断海水回流", "能救下他，但镜中之物会记住你。", "仪式暂停，代价是更多侵蚀。", ResourceDelta(materials: 1, instability: 1), false)
        )
    ]

    private static func choice(
        _ id: String,
        _ title: String,
        _ detail: String,
        _ result: String,
        _ delta: ResourceDelta,
        _ isPathAligned: Bool = true
    ) -> StoryChoice {
        StoryChoice(id: id, title: title, detail: detail, result: result, delta: delta, isPathAligned: isPathAligned)
    }
}
