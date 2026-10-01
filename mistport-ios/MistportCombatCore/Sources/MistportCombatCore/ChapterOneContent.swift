import Foundation

public enum MPCContentRarity: String, Codable, CaseIterable, Sendable {
    case common, uncommon, rare, story
}

public enum MPCUnlockStage: Int, Codable, CaseIterable, Comparable, Sendable {
    case prologue = 0
    case investigationOne = 1
    case investigationTwo = 2
    case investigationThree = 3
    case investigationFour = 4
    case echoReplay = 5

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct MPCSkillContent: Identifiable, Equatable, Sendable {
    public let id: FoolSkillID
    public let name: String
    public let summary: String
    public let unlockStage: MPCUnlockStage
    public let isUltimate: Bool
    public let tags: [String]
}

public struct MPCComboContent: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let sequence: String
    public let purpose: String
}

public struct MPCPassiveContent: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let summary: String
    public let unlockStage: MPCUnlockStage
    public let tags: [String]
}

public struct MPCRelicContent: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let rarity: MPCContentRarity
    public let mechanism: String
    public let cost: String
    public let buildDirection: String
    public let story: String
    public let unlockStage: MPCUnlockStage
}

public enum MPCItemKind: String, Codable, Sendable {
    case currency, material, consumable, keyItem, cosmetic
}

public struct MPCItemContent: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let kind: MPCItemKind
    public let rarity: MPCContentRarity
    public let description: String
    public let maxStack: Int
    public let isTradable: Bool
    public let unlockStage: MPCUnlockStage
}

public enum MPCCompanionRole: String, Codable, Sendable {
    case protector, healer, construct
}

public struct MPCCompanionContent: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let pathName: String
    public let role: MPCCompanionRole
    public let normalSkillIDs: [String]
    public let ultimateSkillID: String
    public let passiveID: String
    public let unlockStage: MPCUnlockStage
}

public enum MPCEnemyContentRank: String, Codable, Sendable {
    case normal, elite, boss
}

public enum MPCEnemySkillTarget: String, Codable, Sendable {
    case player
    case selfUnit
    case lowestHealthAlly
}

/// Data-driven hostile intent effects. The runtime keeps legacy intent
/// fallbacks for older enemies, while authored enemies can opt into reusable
/// support, healing, shielding and transfer behavior without new branches.
public struct MPCEnemySkillDefinition: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let intent: String
    public let target: MPCEnemySkillTarget
    public let damageBasisPoints: Int
    public let healing: Int
    public let healingBasisPoints: Int
    public let defenseBonusBP: Int
    public let tags: [String]
    public let archiveDescription: String
    public let vfxID: String

    public init(
        id: String,
        name: String = "",
        intent: String,
        target: MPCEnemySkillTarget = .player,
        damageBasisPoints: Int = 1_000,
        healing: Int = 0,
        healingBasisPoints: Int = 0,
        defenseBonusBP: Int = 0,
        tags: [String] = [],
        archiveDescription: String = "",
        vfxID: String = ""
    ) {
        self.id = id
        self.name = name.isEmpty ? id : name
        self.intent = intent
        self.target = target
        self.damageBasisPoints = max(0, damageBasisPoints)
        self.healing = max(0, healing)
        self.healingBasisPoints = min(10_000, max(0, healingBasisPoints))
        self.defenseBonusBP = min(10_000, max(0, defenseBonusBP))
        self.tags = tags
        self.archiveDescription = archiveDescription
        self.vfxID = vfxID
    }
}

public struct MPCEnemyContent: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let rank: MPCEnemyContentRank
    public let maxHP: Int
    public let attack: Int
    public let defense: Int
    public let intentPattern: [String]
    public let teachingPurpose: String
    public let skills: [MPCEnemySkillDefinition]
}

public struct MPCEncounterWave: Equatable, Sendable {
    public let enemyIDs: [String]
}

public struct MPCEncounterContent: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let investigationID: String
    public let waves: [MPCEncounterWave]
    public let companionSlots: Int
    public let fixedRewardItemIDs: [String]
    public let firstClearRelicID: String?
    public let recommendedTags: [String]
}

public struct MPCInvestigationContent: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let location: String
    public let encounterIDs: [String]
    public let unlockSkillIDs: [FoolSkillID]
    public let unlockPassiveIDs: [String]
    public let unlockItemIDs: [String]
    public let unlockRelicIDs: [String]
    public let narrativeOutcome: String
}

/// The player never sees these identifiers. They make authored mission gates
/// inspect what happened in battle instead of brittle card-name strings.
public enum MPCChapterOneBehaviorTag: String, Codable, CaseIterable, Hashable, Sendable {
    case applyIllusion = "APPLY_ILLUSION"
    case reachFourIllusion = "REACH_4_ILLUSION"
    case convertToMisalignment = "CONVERT_TO_MISALIGNMENT"
    case consumeOrCheckMisalignment = "CONSUME_OR_CHECK_MISALIGNMENT"
    case gainFinaleReady = "GAIN_FINALE_READY"
    case castFinale = "CAST_FINALE"
    case defensiveResponse = "DEFENSIVE_RESPONSE"
    case targetChainValid = "TARGET_CHAIN_VALID"
}

public enum MPCSkillUnlockState: String, Codable, Equatable, Sendable {
    case locked = "LOCKED"
    case trial = "TRIAL"
    case permanent = "PERMANENT"
}

public struct MPCComboExecutionRecord: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let comboID: String
    public let battleID: String
    public let missionID: String?
    public let skillSequence: [FoolSkillID]
    public let behaviorTags: Set<MPCChapterOneBehaviorTag>
    public let validTargetChain: Bool

    public init(
        comboID: String,
        battleID: String,
        missionID: String? = nil,
        skillSequence: [FoolSkillID],
        behaviorTags: Set<MPCChapterOneBehaviorTag>,
        validTargetChain: Bool
    ) {
        self.id = "\(battleID)-\(comboID)-\(skillSequence.map(\.rawValue).joined(separator: "-"))"
        self.comboID = comboID
        self.battleID = battleID
        self.missionID = missionID
        self.skillSequence = skillSequence
        self.behaviorTags = behaviorTags
        self.validTargetChain = validTargetChain
    }
}

public struct MPCChapterOneMissionDefinition: Identifiable, Equatable, Sendable {
    public let id: String
    public let number: Int
    public let name: String
    public let location: String
    public let encounterID: String
    public let storyText: String
    public let trialSkillID: FoolSkillID?
    public let permanentSkillIDs: [FoolSkillID]
    public let rewardItemIDs: [String]
    public let companionIDs: [String]
    public let requiredBehaviorTags: Set<MPCChapterOneBehaviorTag>

    public init(
        id: String,
        number: Int,
        name: String,
        location: String,
        encounterID: String,
        storyText: String,
        trialSkillID: FoolSkillID? = nil,
        permanentSkillIDs: [FoolSkillID] = [],
        rewardItemIDs: [String] = [],
        companionIDs: [String] = [],
        requiredBehaviorTags: Set<MPCChapterOneBehaviorTag> = []
    ) {
        self.id = id
        self.number = number
        self.name = name
        self.location = location
        self.encounterID = encounterID
        self.storyText = storyText
        self.trialSkillID = trialSkillID
        self.permanentSkillIDs = permanentSkillIDs
        self.rewardItemIDs = rewardItemIDs
        self.companionIDs = companionIDs
        self.requiredBehaviorTags = requiredBehaviorTags
    }
}

public enum MPCChapterOneCatalog {
    /// Temporarily paused by design; historical ownership remains in saves.
    public static let relicsEnabled = false
    public static let usurpedLifeMedalRelicID = "relic_usurped_life_medal"
    public static let saltSealedBreathingBagRelicID = "relic_salt_sealed_breathing_bag"
    public static let returnGiftClaspRelicID = "relic_return_gift_clasp"
    public static let ownerlessMaskRelicID = "relic_ownerless_mask"
    public static func isRelicEnabled(_ id: String) -> Bool {
        relicsEnabled || [ownerlessMaskRelicID, usurpedLifeMedalRelicID, saltSealedBreathingBagRelicID, returnGiftClaspRelicID, "relic_deferred_stamp", "relic_reflecting_ink_mirror", "relic_sealed_paperweight", "relic_countertide_anchor", "relic_ownership_severing_needle", "relic_blank_name_card"].contains(id)
    }
    public static var visibleSkills: [MPCSkillContent] { skills.filter { $0.id != .maskedWhisper } }
    public static func encounterID(forOldClockMissionNumber number: Int) -> String? {
        missions.first(where: { $0.number == number })?.encounterID
    }

    /// Returns the authored Fool encounter for any Chapter One district.
    /// Old-clock missions have narrative-specific definitions above; the four
    /// later districts use the same map mission numbers but their own enemy
    /// compositions and first-clear relic nodes.
    public static func encounterID(forDistrictID districtID: String, missionNumber: Int) -> String? {
        if districtID == "old-clock" {
            return encounterID(forOldClockMissionNumber: missionNumber)
        }
        let id = "\(districtID)-q\(String(format: "%02d", missionNumber))_encounter"
        return encounters.contains(where: { $0.id == id }) ? id : nil
    }

    public static func mission(forOldClockMissionNumber number: Int) -> MPCChapterOneMissionDefinition? {
        missions.first(where: { $0.number == number })
    }

    public static func mission(forEncounterID encounterID: String) -> MPCChapterOneMissionDefinition? {
        missions.first(where: { $0.encounterID == encounterID })
    }

    public static let missions: [MPCChapterOneMissionDefinition] = [
        .init(id: "chapter01_q01", number: 1, name: "雨夜醒来", location: "旧城区·紫藤街口", encounterID: "chapter01_q01_encounter", storyText: "你记得自己的名字，却在雨中的街口被空壳守卫拦下：“已认领人员，不得离开保管区域。”玛拉示意先观察它的出招；她递来的通行证，背面留着一栏旧签收。", trialSkillID: .sidestepStrike, permanentSkillIDs: [.sidestepStrike], rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 1)!.itemIDs),
        .init(id: "chapter01_q02", number: 2, name: "雾都幽灵", location: "旧城区·紫藤街口", encounterID: "chapter01_q02_encounter", storyText: "两道幽灵围住一批退回的寻人信，反复说着“别送我回家”。被击散后，它们各裂成两只赤红子体。不同收件人的退信上，却盖着同一个理由：家属已领回。", rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 2)!.itemIDs),
        .init(id: "chapter01_q03", number: 3, name: "循名而来的猎犬", location: "旧城区·失名档案街", encounterID: "chapter01_q03_encounter", storyText: "旧地狱犬循着你的名字追来。玛拉在战前交付假面谕令。击退后，项圈露出你的名字、旧邮务追索号与一道格式不同的外部委托编号；迟秒怀表只是核对邮路的物证。", permanentSkillIDs: [], rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 3)!.itemIDs),
        .init(id: "chapter01_q04", number: 4, name: "猎犬试探", location: "旧城区·雾灯街", encounterID: "chapter01_q04_encounter", storyText: "同一只猎犬再次追来，喉间双焰引出两颗追索火球。让假面承接双焰，抓住三秒破绽。战后召回声带走猎犬，奥黛尔的诊所里，却仍留着失踪抄方员伊恩的一杯冷茶。", rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 4)!.itemIDs, requiredBehaviorTags: []),
        .init(id: "chapter01_q05", number: 5, name: "不肯落幕", location: "旧城区·雾灯街", encounterID: "chapter01_q05_encounter", storyText: "旧邮务间的翠焰执役者不停将退信盖成“已送达”。只要还有退件，它就不能结束执役。毒雾不断加浓，绿焰预示重击；你要终止这条把求救当成已送达邮件的流程。", rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 5)!.itemIDs, requiredBehaviorTags: []),
        .init(id: "chapter01_q06", number: 6, name: "档案街入口", location: "旧城区·失名档案街", encounterID: "chapter01_q06_encounter", storyText: "注销底联没有家属签名，只有档案系统的接收章。白门卫承认通行证有效，却要求领回你的监护人提出查阅申请。它的真盾与出击后的校准破绽，挡在原始记录之前。", rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 6)!.itemIDs),
        .init(id: "chapter01_q07", number: 7, name: "空白身份牌", location: "旧城区·失名档案街", encounterID: "chapter01_q07_encounter", storyText: "两具空壳守卫看守的空白身份牌并非废品，而是等待填写归属的成品。寄忆核心持续修复守卫；其中一张牌背面的领药编号，属于本来就有姓名和工作的伊恩。", rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 7)!.itemIDs),
        .init(id: "chapter01_q08", number: 8, name: "不属于我的名字", location: "旧城区·失名档案街", encounterID: "chapter01_q08_encounter", storyText: "补录台下的记忆蛭试着给你安上别人的名字。它抽出的记忆里，竟有刚在诊所见过的缺角茶杯。战前习得身份错置，以四层误认转为错位，打断它的吞名。", permanentSkillIDs: [.identityDisplacement], rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 8)!.itemIDs),
        .init(id: "chapter01_q09", number: 9, name: "被改写的证词", location: "旧城区·齿轮工坊", encounterID: "chapter01_q09_encounter", storyText: "书记员正将奥黛尔的“伊恩没有回来”改为“因误会重复报案”，核心持续维护覆盖后的版本。保住前后两份证词，才能让这次失踪不再被一句手续完成抹掉。三教会存证页上留着伊莱娅的批注，错乱灯流在她经过后重新归正。", permanentSkillIDs: [.fabricatedEvidence], rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 9)!.itemIDs),
        .init(id: "chapter01_q10", number: 10, name: "失踪者名单", location: "旧城区·齿轮工坊", encounterID: "chapter01_q10_encounter", storyText: "名单上的伊恩和其他失踪者，都被标记为“已领回”。你的名字也在其中，地址指向一个所谓的家。铠甲执行犬与白门卫守住原件；它们不是早先被召回的旧犬。赫斯认出名单上的旧地址：这是一条投递路线，不是找到家人的证明。", permanentSkillIDs: [.mirrorPursuit], rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 10)!.itemIDs),
        .init(id: "chapter01_q11", number: 11, name: "不属于我的家人", location: "旧城区·齿轮工坊", encounterID: "chapter01_q11_encounter", storyText: "门后的声音说，桌上的缺角茶杯是你从小用惯的。杯底却印着奥黛尔诊所的药柜编号。两只记忆蛭正用真实片段拼出假的亲情，空壳守卫等待完成接收。", permanentSkillIDs: [.absurdFinale], rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 11)!.itemIDs),
        .init(id: "chapter01_q12", number: 12, name: "强制校正", location: "旧城区·雨水排渠", encounterID: "chapter01_q12_encounter", storyText: "两名书记员轮番合账，试图将异常家庭档案重新编入调拨队列。调拨单显示：移出一个名字，就要从后面补上另一个。玛拉终于把旧通行证翻了过来。", permanentSkillIDs: [.turnTheTables], rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 12)!.itemIDs),
        .init(id: "chapter01_q13", number: 13, name: "救援命令", location: "旧城区·雨水排渠", encounterID: "chapter01_q13_encounter", storyText: "救援者洛克接到的录音，本该在“安置完成”后允许人离开，却被改成等待调拨。摧毁转接核心、解除本地控制，让他活着说出背架根授权的去向。", permanentSkillIDs: [.namelessStage], rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 13)!.itemIDs),
        .init(id: "chapter01_q14", number: 14, name: "错误名牌", location: "旧城区·雨水排渠", encounterID: "chapter01_q14_encounter", storyText: "记忆蛭处理人的记忆，书记员处理外部文字。伊恩的名牌被挂进一个根本不认识他的家庭，背面牵着细红线。沿这条实物联系，寻找替所有家庭代签的人。", rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 14)!.itemIDs),
        .init(id: "chapter01_q15", number: 15, name: "归属标签", location: "旧城区·雨水排渠", encounterID: "chapter01_q15_encounter", storyText: "维娅用假家庭换取没有身份者的庇护，却让其他人承担补位的代价。两枚核心维持她的归属网。切断网络并将她押送监管织室，保留证词，追查真正将人转走的上游签发权。", rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 15)!.itemIDs),
        .init(id: "chapter01_q16", number: 16, name: "销号追索", location: "雾港·签发与押运线", encounterID: "chapter01_q16_encounter", storyText: "召回声这次不再响起。同一条项圈带着销号命令，旧地狱犬第三次挡住去路。终止它的本地追索后，项圈上的外海编号仍在：委托并未随执行犬一起消失。", rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 16)!.itemIDs),
        .init(id: "chapter01_q17", number: 17, name: "自动补位", location: "雾港·签发与押运线", encounterID: "chapter01_q17_encounter", storyText: "机械笔臂正替被截停的流程自动补位。你截下备用签发目录，发现五路市政供能都通向同一枚私印，钟环另有五格储备。毁掉这台执行者，只能停下自动签发，不能撤销私印。", rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 17)!.itemIDs),
        .init(id: "chapter01_q18", number: 18, name: "无效的许可", location: "雾港·签发与押运线", encounterID: "chapter01_q18_encounter", storyText: "一份早已失效的许可，仍让裁定卫守住五处市政锚的记录。摧毁执役体、保住锚位图，才能区分供能与授权：杀死守卫并不会让城市失去封口。", rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 18)!.itemIDs),
        .init(id: "chapter01_q19", number: 19, name: "外海收件人", location: "雾港·签发与押运线", encounterID: "chapter01_q19_encounter", storyText: "宿舍床位、押运时刻与收件印对上了。外海接收的不是死档案，而是还会呼吸的人。终止此处翠焰执役者的有限执役周期后，赫斯沿已经查明的路线截断战后追踪。", rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 19)!.itemIDs),
        .init(id: "chapter01_q20", number: 20, name: "押运中的活档案", location: "雾港·签发与押运线", encounterID: "chapter01_q20_encounter", storyText: "押运匣里传来敲击。你必须先解除沿车的拘束，让这一批活档案离车。押运锤卫仍护着余车撤走；拦下的这一车人，证明救援比追杀更急迫。", rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 20)!.itemIDs),
        .init(id: "chapter01_q21", number: 21, name: "原始救援条款", location: "雾港·签发与押运线", encounterID: "chapter01_q21_encounter", storyText: "洛克还记得原始条款：安置完成后，被救者可以离开。毁掉独立转接核心，再拆除背架上的个人根输入，才能让他真正摆脱遥控。他留下来继续救援。", rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 21)!.itemIDs),
        .init(id: "chapter01_q22", number: 22, name: "不属于你的庇护", location: "雾港·签发与押运线", encounterID: "chapter01_q22_encounter", storyText: "监管织室开放复核接口时，维娅主动将陌生人的名字填入补位栏。她仍想以别人的自由换取庇护。阻止这次越权后，监管继续；这是她必须承担的选择。", rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 22)!.itemIDs),
        .init(id: "chapter01_q23", number: 23, name: "不以人名封口", location: "雾港·签发与押运线", encounterID: "chapter01_q23_encounter", storyText: "替代材料通过了独立验证：封口不必绑定一个人名。清除裁定守备，保住市政主锚。守灯天使伊莱娅说明，必须观察五次完整回流，才能同时切断五路外接供能。", rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 23)!.itemIDs),
        .init(id: "chapter01_q24", number: 24, name: "地下泊位", location: "雾港·签发与押运线", encounterID: "chapter01_q24_encounter", storyText: "地下泊位的守备犬与幽灵看守着最后一处转运口。你终于救出真正的伊恩，他认得诊所那只缺角杯，也记得黑盐岸的检疫路线。根授权仍能追索他，事情还未结束。", rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 24)!.itemIDs),
        .init(id: "chapter01_q25", number: 25, name: "自愿断线", location: "雾港·签发与押运线", encounterID: "chapter01_q25_encounter", storyText: "维娅在清醒、自愿的状态下同意断契。契约自动防御拦住拆线，却不能代替她的选择。协助她解除归属后，她重新作证并接受审理，永久退出敌对。", rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 25)!.itemIDs),
        .init(id: "chapter01_q26", number: 26, name: "最后一趟押运", location: "雾港·签发与押运线", encounterID: "chapter01_q26_encounter", storyText: "同一具押运锤卫守着最后一趟车。先切掉供能，再承受它余力驱动的重锤。此次它被永久摧毁；总签钥与最后一份运输记录留在断开的车链旁。", rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 26)!.itemIDs),
        .init(id: "chapter01_q27", number: 27, name: "未签署的归属", location: "雾港·签发与押运线", encounterID: "chapter01_q27_encounter", storyText: "夺回原始档案，未签署的归属栏旁仍是你当初自己报出的名字。外部追索比入港更早，总签官没有创造那段过去。封存交易存根指向第七住客，名字仍被遮住。", rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 27)!.itemIDs),
        .init(id: "chapter01_q28", number: 28, name: "五次回流", location: "雾港·签发与押运线", encounterID: "chapter01_q28_encounter", storyText: "瑟维安独自站在五路回流中央。撑过五次完整行动，让每处供能暴露真实回路。最后一击落定且你仍活着时，伊莱娅才同时切源；他带着钟环储备退入签发廊。", rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 28)!.itemIDs),
        .init(id: "chapter01_q29", number: 29, name: "最后的代签", location: "雾港·签发与押运线", encounterID: "chapter01_q29_encounter", storyText: "瑟维安以五格储备维持最后的代签，新执行者与空壳守卫护在两侧。五次完整行动耗尽储备后，他使用一次性归庭印撤回总册。清除留下的手下，你才能继续追入。", rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 29)!.itemIDs),
        .init(id: "chapter01_q30", number: 30, name: "无主者的签名", location: "雾港·签发与押运线", encounterID: "chapter01_q30_encounter", storyText: "替代封口已经稳定，私印再也接不回旧链。瑟维安仍想以自己的签名认领所有人，这次你必须真正击败他的本体。伊恩回诊所泡茶，洛克安置居民，维娅接受审理；更早的外部追索却迫使你沿赫斯维持的单向航线离港，去往黑盐岸。", rewardItemIDs: MPCChapterOneThirtyMissionContract.firstClear(for: 30)!.itemIDs)
    ]

    public static let skills: [MPCSkillContent] = [
        .init(id: .sidestepStrike, name: "错步穿行", summary: "基础攻击110%；目标有「误认」或「错位」时伤害提高25%，若存在第二个敌人，第二目标承受50%伤害。", unlockStage: .prologue, isUltimate: false, tags: ["双目标攻击", "利用错误"]),
        .init(id: .maskedWhisper, name: "假面谕令", summary: "造成60%伤害并施加2层误认；召出幻影承接两次敌方攻击。CD 12秒，重复施放刷新次数，不叠加。", unlockStage: .investigationOne, isUltimate: false, tags: ["铺垫", "误认×2", "幻影承伤×2"]),
        .init(id: .identityDisplacement, name: "身份错置", summary: "误认未满4层时造成80%伤害并追加1层；达到4层时消耗误认，施加2回合「错位」并延迟目标下一次行动。", unlockStage: .investigationTwo, isUltimate: false, tags: ["误认转换", "错位", "行动延迟"]),
        .init(id: .fabricatedEvidence, name: "伪证烙印", summary: "造成70%伤害，施加1层误认；后续2个伤害技能各获得15%增伤。", unlockStage: .investigationTwo, isUltimate: false, tags: ["铺垫", "后续增伤"]),
        .init(id: .mirrorPursuit, name: "双影追猎", summary: "造成两段65%伤害；目标处于错位时，第二段伤害提高50%。", unlockStage: .investigationThree, isUltimate: false, tags: ["两段伤害", "错位兑现"]),
        .init(id: .absurdFinale, name: "荒谬归结", summary: "造成150%伤害；若目标处于错位，消耗错位并追加80%伤害，同时获得30%穿甲。", unlockStage: .investigationThree, isUltimate: false, tags: ["终结", "错位兑现", "30%穿甲"]),
        .init(id: .turnTheTables, name: "反客为主", summary: "驱散一个敌方增益；成功时施加1回合错位，若没有可驱散增益则施加2层误认。", unlockStage: .investigationFour, isUltimate: false, tags: ["反制", "驱散", "错位"]),
        .init(id: .backstageChange, name: "后手改写", summary: "划去一项敌人施加的持续伤害（毒雾先降回初始浓度），并使下一张铺垫技能额外施加1层误认。", unlockStage: .investigationFour, isUltimate: false, tags: ["净化", "强化铺垫"]),
        .init(id: .namelessStage, name: "无名宣告", summary: "每场一次：所有敌人获得4层误认，并获得「归结准备」；下一次伤害提高25%，下一次身份错置只需消耗2层误认。", unlockStage: .investigationFour, isUltimate: true, tags: ["终极", "全体误认", "快速启动"])
    ]

    public static let combos: [MPCComboContent] = [
        .init(id: "K01", name: "假面试探", sequence: "假面谕令 → 错步穿行", purpose: "让第二张牌利用第一张牌制造的误认"),
        .init(id: "K02", name: "双面伪局", sequence: "假面谕令 → 伪证烙印", purpose: "稳定叠加误认并强化下一轮伤害"),
        .init(id: "K03", name: "身份翻面", sequence: "假面谕令 → 身份错置", purpose: "把误认转换成错位并延迟敌人"),
        .init(id: "K04", name: "双影兑现", sequence: "身份错置 → 双影追猎", purpose: "用两段攻击兑现错位"),
        .init(id: "K05", name: "错位归结", sequence: "身份错置 → 荒谬归结", purpose: "消费错位完成高穿甲终结"),
        .init(id: "K06", name: "误认终结", sequence: "假面谕令 → 伪证烙印 → 身份错置 → 双影追猎 → 荒谬归结", purpose: "愚者的标准完整爆发"),
        .init(id: "K08", name: "夺席终演", sequence: "反客为主 → 错步穿行 → 荒谬归结", purpose: "敌人有增益时跳过常规铺垫"),
        .init(id: "K09", name: "后手重写", sequence: "后手改写 → 假面谕令 → 身份错置", purpose: "被施加负面后重建循环"),
        .init(id: "K10", name: "无名开幕", sequence: "无名宣告 → 身份错置 → 双影追猎 → 荒谬归结", purpose: "每场一次快速启动")
    ]

    public static let passives: [MPCPassiveContent] = [
        .init(id: "fool_passive_01", name: "幕间观察", summary: "首次揭示敌方意图时获得50护盾。", unlockStage: .investigationOne, tags: ["intent", "shield"]),
        .init(id: "fool_passive_02", name: "不可靠叙述者", summary: "每回合首次施加误认时额外施加1层，随后本回合受到伤害增加5%。", unlockStage: .investigationTwo, tags: ["misrecognition", "risk"]),
        .init(id: "fool_passive_03", name: "借来的名字", summary: "身份错置成功后恢复80生命。", unlockStage: .investigationTwo, tags: ["conversion", "heal"]),
        .init(id: "fool_passive_04", name: "迟到的掌声", summary: "多段技能完整命中后下一次单段技能伤害提高10%。", unlockStage: .investigationThree, tags: ["multi_hit", "damage"]),
        .init(id: "fool_passive_05", name: "纸幕后路", summary: "纸偶成功承受攻击后，获得1点幕势。", unlockStage: .investigationThree, tags: ["paper_double", "momentum"]),
        .init(id: "fool_passive_06", name: "未写结局", summary: "每场战斗第一次低于30%生命时获得一次闪避。", unlockStage: .investigationFour, tags: ["survival", "evasion"])
    ]

    public static let relics: [MPCRelicContent] = [
        relic("relic_deferred_stamp", "迟签印章", .uncommon, "技能的一笔直接伤害延后3秒，并追加有限伤害。", "目标离场或届时真免伤则作废；12秒冷却。", "签下不能撤回的迟到伤害", "它总要等到约定的第三秒才肯落印。", .investigationTwo),
        relic("relic_reflecting_ink_mirror", "反照墨镜", .uncommon, "锁定2秒后普攻赠血，换另一个敌人的一次直击反射。", "先送血再等4秒，落空不退；8秒冷却。", "把好意和恶意折向同一人", "镜里的人必须先收下一份礼物。", .investigationTwo),
        relic("relic_sealed_paperweight", "缄卷镇纸", .uncommon, "封掉固定第3槽的一次技能，建立4秒一次直伤收容。", "原技能全部效果消失，卡牌冷却照常；18秒冷却。", "以未曾发生的一招换取庇护", "第三行永远压在它的下面。", .investigationTwo),
        relic("relic_countertide_anchor", "逆潮铜锚", .uncommon, "同敌同招首击后2秒内下两段收容有限直伤。", "首击额外承受5%入场生命；10秒冷却。", "先付逆潮的第一笔代价", "没有后浪，第一道伤口也不会归还。", .investigationTwo),
        relic("relic_ownership_severing_needle", "归属断线针", .uncommon, "截取选中敌人收到的外来治疗给自己。", "随后6秒自己不能回血；每场两次、12秒冷却。", "割走别人的治愈也割断自己的", "它挑断归属，却不问你下一次何时需要援手。", .investigationTwo),
        relic("relic_blank_name_card", "空栏名片", .uncommon, "主动3秒与固定敌人互不承受彼此直伤。", "自己的技能照常消耗；第三方、毒伤和控制不受影响。18秒冷却。", "彼此的直接伤害找不到收件人", "空白只属于这一对互相拒绝认领的人。", .investigationTwo),
        relic(saltSealedBreathingBagRelicID, "盐封呼吸囊", .uncommon, "被动吸收部分持续伤害，容量有限；不吸收直接攻击或遗落物自身代价。", "每吸收10点伤害，正常生命上限暂时封存1点；战后解封不补血。第4关后商店120铜币。", "以呼吸空间换取耐毒", "被封在盐囊里的毒气，逐渐挤走持有者能容纳的生命。", .investigationOne),
        relic(returnGiftClaspRelicID, "返礼银扣", .uncommon, "就绪时吸收下一次直接攻击，最多为入场生命上限的30%。", "攻击者立即获得吸收量一半的普通护盾；8秒冷却与赠盾破除均满足才再就绪。第4关后160铜币。", "挡伤并偿还敌人护盾", "每次拒绝收到的礼物，它都会给送礼者一份新的保护。", .investigationOne),
        relic(usurpedLifeMedalRelicID, "僭命勋章", .story, "手动发动8秒：当前生命与生命上限提高50%，攻击力提高30%。24秒冷却，与假面互斥。", "结束时交出剩余生命的一半，再恢复正常上限；胜利和撤退同样清算。绑定不可出售。", "借取强盛", "猎犬试探结束后，奥黛尔交付一枚没有授予对象的旧铜勋章。", .investigationOne),
        relic(ownerlessMaskRelicID, "假面谕令", .story, "手动使用，4秒内承接最多两次直接攻击；所有持续伤害均无效且不消耗次数。18秒冷却，不占卡牌编排。", "每次使用永久增加一道暗紫裂纹，十道后彻底失效；第十次正常生效。第3、4关教学不增加裂纹。失败或退出不返还。", "手动幻影承伤", "迎战循名猎犬前，玛拉交付的无主假面。它让追猎者将幻影认成持有者。", .investigationOne),
        relic("relic_encore_bell", "不肯落幕的铃", .story, "手动打断翠焰亡灵蓄力，使本次攻击延后3秒；返场时该次攻击伤害提高50%。", "延后的攻击不会消失，返场时会以更高伤害归还。", "返场延后", "旧邮务间按取回条交出的异常物。铃声不能免除欠下的攻击，只能让它晚三秒落下。", .investigationOne),
        relic("relic_cracked_monocle", "偏差透镜", .common, "攻击4层误认目标时获得20%穿甲。攻击0层误认目标时伤害降低8%。", "必须在目标状态之间做取舍。", "误认兑现", "镜片里总有一个稍晚眨眼的人。", .investigationOne),
        relic("relic_late_second_watch", "迟滞铜片", .common, "成功应对已公布的强攻或避开攻击后，下回合额外执行1张普通技能；每场最多2次。", "只奖励对敌方意图的准确判断。", "意图应对", "它永远比归一系统慢半拍。", .investigationOne),
        relic("relic_memory_leech_vial", "记忆蛭标本", .rare, "后手改写再净化一项持续伤害，下一张铺垫技能再多1层误认。", "首次触发损失5%当前生命。", "净化连段", "瓶中生物记得每位持有者的噩梦。", .investigationTwo),
        relic("relic_borrowed_bell", "借声铜铃", .common, "AI第一次造成破绽或降低防御时，获得10%最大生命护盾。", "同一轮不能重复触发。", "队伍协同", "铜铃从不发出自己的声音。", .investigationTwo),
        relic("relic_thirteenth_record", "预警录片", .common, "每3回合揭示额外敌方意图。揭示回合玩家伤害降低8%。", "信息越多，行动越需要克制。", "观察控制", "录片上有一声不属于任何人。", .investigationThree),
        relic("relic_clock_chaser_spur", "追猎者断刺", .rare, "完成一轮普通技能而未使用荒谬归结时，下一轮第一张伤害技能提高25%。", "只有坚持循环才会生效。", "循环奖励", "它来自一位追逐错误的人。", .investigationThree),
        relic("relic_mirror_thread", "镜潮银线", .rare, "双影追猎第二击命中错位目标后，敌方下一次攻击提高20%。", "风险会被转移，但不会消失。", "多段协同", "银线连接的两端从不属于同一倒影。", .investigationThree),
        relic("relic_trimmed_nameplate", "裁去的名牌", .rare, "敌方驱散玩家增益时，给该敌人施加2层误认。", "每次触发使玩家下一次治疗减少30%。", "反驱散", "名字被削掉后，职责仍留在背面。", .investigationFour),
        relic("relic_unified_gear", "三证环", .story, "一轮内完成铺垫、攻击、反制或净化三种不同类别行动时，获得10%最大生命护盾，并强化下一次有伤害的攻击20%。", "触发后，下一次实际结算到自身生命或护盾的敌方直接攻击提高25%；幻影承伤不消耗此负面，重复触发只刷新、不叠加。", "类别轮换与承伤风险", "三种互相矛盾的证明暂时保护持有者，也使归一系统更清楚地锁定其身体。", .investigationFour),
        relic("relic_blank_ticket", "空白戏票", .rare, "荒谬归结未消耗错位时，下一轮第一张身份错置额外施加1层误认；每场最多2次。", "需要主动保留一次错误。", "终结容错", "票面没有剧名，却写着你的座位。", .investigationFour),
        relic("relic_mist_anchor_shard", "雾锚碎片", .rare, "返场或其他复起效果触发后，获得15%最大生命护盾，下一次伤害降低20%。", "每场战斗只承认第一次归来。", "副本生存", "它记住了某次本不该发生的归来。", .investigationFour),
        relic("relic_blank_nameplate", "空白名牌", .common, "首次攻击新目标时，额外施加1层误认。", "换目标本身就是一种叙述。", "换目标", "没有名字的牌最容易被贴错。", .investigationOne),
        relic("relic_contradictory_testimony", "矛盾证词", .rare, "同时拥有误认和错位的目标，额外承受10%玩家伤害。", "必须先完成转换再兑现。", "双状态", "两份互相冲突的证词都盖着真的印章。", .investigationTwo),
        relic("relic_recovery_seal", "回收封签", .common, "身份错置消耗误认时恢复4%最大生命，每回合一次。", "把错误回收，才有下一次犯错的余地。", "转换续航", "封签背面写着一个已经被删除的住址。", .investigationTwo),
        relic("relic_reposition_knot", "借位绳结", .common, "目标死亡或切换目标后，下一次攻击提高15%，新目标额外获得1层误认。", "鼓励主动切换攻击对象。", "换位追击", "绳结系住的不是人，而是位置。", .investigationThree),
        relic("relic_red_wax_seal", "红蜡证印", .common, "伪证烙印额外施加1层误认，但该技能基础伤害降低10%。", "更强铺垫换来更慢的当下。", "铺垫强化", "红蜡封住证词，却没有封住怀疑。", .investigationThree),
        relic("relic_salt_crystal_record", "盐晶存片", .story, "身份错置将4层误认转换为错位时，保留2层误认。", "让转换后的循环更快回到上限。", "持续转换", "盐晶里保存着一个不愿被归档的下午。", .investigationThree),
        relic("relic_refusal_deed", "拒认契据", .rare, "敌方成功驱散玩家增益时，该敌人获得1回合错位；每场最多2次。", "把对方的校正变成破绽。", "反制校正", "契据最后一行拒绝承认签名。", .investigationFour),
        relic("relic_returning_route", "折返路签", .story, "每4张普通技能执行后，以60%效果重复本轮第一张技能；重复不会再次触发自身。", "固定循环可以被一次折返打乱。", "循环重演", "路签指向已经走过，却没有人记得。", .investigationFour),
        relic("relic_additional_testimony", "追加证词", .story, "每个循环第一次使用铺垫技能后，下一张攻击技能额外重复一次，重复效果为50%。", "只在铺垫确实转入攻击时生效。", "循环追加", "被删掉的证词从页边重新长了回来。", .investigationFour),
        relic("relic_errata_clip", "错页夹", .rare, "第1格与第2格属于不同技能类别时，第2格技能效果提高15%。", "战前顺序必须有意制造类别差异。", "首二格编排", "夹住的不是错页，而是两种互相矛盾的答案。", .investigationFour),
        relic("relic_returning_salt", "归航盐片", .common, "生命首次低于40%时恢复6%最大生命；下一次行动延迟无效。", "每场只承认第一次濒危。", "潮门续航", "盐片里仍有一条船没有驶回港口。", .investigationFour),
        relic("relic_nameless_seal", "无主印章", .story, "装备后，无名宣告对全体敌人施加2层误认；无名宣告后，下一次满足原有4层条件的成功身份错置不消耗误认，成功使用后恢复正常。", "用较少的初始误认换取一次不消耗误认的转换；条件不足时不消耗这次机会。", "终极分支", "没有主人承认的印章无法制造完整身份，却能留下不被转换抹去的残余证明。", .investigationFour)
    ]

    public static let items: [MPCItemContent] = [
        item(MPCLocalWorkshopLedger.hideID, "盾颚韧皮", .material, .common, "工坊开放后，从教会塔第1层的新胜利中取得。1份韧皮可加工3条维修绑带。", Int.max, false, .investigationOne),
        item(MPCLocalWorkshopLedger.strapID, "维修绑带", .material, .common, "皮革工坊制品。检修单只采购2条，交货后安装才消耗；剩余成品可以保存。", Int.max, false, .investigationOne),
        item(MPCTowerMaterials.gland, "盐囊腺", .material, .common, "盐囊瘴魔的材料，教会塔每次胜利都会掉落。药剂工坊用它熬止痛膏。", Int.max, false, .investigationOne),
        item(MPCTowerMaterials.membrane, "寄囊膜", .material, .common, "囊背寄魔的材料。用于第30层档的工坊装备。", Int.max, false, .investigationOne),
        item(MPCTowerMaterials.chitin, "剪刃甲片", .material, .common, "剪肢螳魔的材料。用于第50层档起的工坊装备。", Int.max, false, .investigationOne),
        item(MPCTowerMaterials.silk, "共鸣丝", .material, .common, "裂冠啸魔的材料。用于第50层档起的工坊装备。", Int.max, false, .investigationOne),
        item(MPCTowerMaterials.talon, "骨爪", .material, .common, "骨爪掠魔的材料。用于第70层档起的工坊装备。", Int.max, false, .investigationOne),
        item(MPCTowerMaterials.fiber, "蛙喉丝", .material, .common, "金喉树蛙的材料。织造工坊用它织过滤布。", Int.max, false, .investigationOne),
        item(MPCTowerMaterials.scale, "杂鳞", .material, .common, "塔里小恶魔的鳞片。金属工坊用它打修甲片和低档刃。", Int.max, false, .investigationOne),
        item(MPCChurchGearLedger.bladeKitID, "修甲片", .material, .common, "金属工坊制品。修理工坊刃的耐久；诊所、港务处和教会也会收购。", Int.max, false, .investigationOne),
        item(MPCCraftingCatalog.clothID, "过滤布", .material, .common, "织造工坊制品。泵站和诊所收购。", Int.max, false, .investigationOne),
        item("chapter30_e02", "寻人退件索引", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e03", "具名项圈拓印", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e05", "召回节律手记", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e06", "伊恩失踪登记", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e08", "监护门禁回执", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e10", "吞名核验记录", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e14", "药柜编号比对记录", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e16", "临时救援回执摘录", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e20", "维娅监管移交书", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e21", "销号项圈", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e22", "五路供能与五格储备图", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e23", "自动补位与备用签发目录", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e24", "失效许可裁定记录", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e25", "五锚回流位置图", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e26", "盐栈床位与押运时刻表", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e27", "外海收件凭据", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e28", "截运批次与余车路线", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e29", "原始救援条款", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e30", "背架根输入拆除记录", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e31", "主动补位与监管续押记录", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e32", "非人名封口验证书", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e33", "伊恩救援记录", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e34", "黑盐岸检疫路线", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e35", "自由作证记录", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e36", "总签钥", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e37", "最终押运记录", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e38", "自报名册", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e39", "未签署归属栏", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e40", "入港前外部追索记录", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e41", "第七住客封存交易存根", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e42", "五次回流定位记录", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e43", "储备耗尽与归庭记录", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_e44", "根授权撤销书", .keyItem, .story, "绑定调查物证。用于核验认领、签发与押运记录；不可装备、消耗或出售。", 1, false, .investigationOne),
        item("chapter30_p04_personal_proof", "个人演证", .keyItem, .story, "绑定凭据；跨章保留，不自动消耗，也不代表已经举行晋阶仪式。", 1, false, .investigationFour),
        item("chapter30_p05_paradox_proof", "悖论见证", .keyItem, .story, "绑定凭据；跨章保留，不自动消耗，也不代表已经举行晋阶仪式。", 1, false, .investigationFour),
        item("chapter30_p06_ownerless_echo", "无主回响", .keyItem, .story, "绑定凭据；跨章保留，不自动消耗，也不代表已经举行晋阶仪式。", 1, false, .investigationFour),
        item("chapter30_u01_needle_permit", "归属断线针制作许可", .keyItem, .story, "绑定凭据；跨章保留，不自动消耗，也不代表已经举行晋阶仪式。", 1, false, .investigationFour),
        item("chapter30_u02_church_continuation", "教会异地续借许可", .keyItem, .story, "绑定凭据；跨章保留，不自动消耗，也不代表已经举行晋阶仪式。", 1, false, .investigationFour),
        item("evidence_delivery_stub", "注销底联", .keyItem, .story, "邮务执役者留下的已送达底联。家属签名处为空，只有档案系统的接收章。", 1, false, .investigationOne),
        item("evidence_testimony_versions", "寻人证词双本", .keyItem, .story, "奥黛尔原述“伊恩没有回来”，覆写本却称重复报案。两个版本的差异是共同存证的依据。", 1, false, .investigationOne),
        item("evidence_missing_register", "失踪者名单", .keyItem, .story, "伊恩和多名失踪者被标记为已领回。你的姓名旁，写着一个陌生家庭的地址。", 1, false, .investigationOne),
        item("evidence_family_dossier", "家庭档案", .keyItem, .story, "假家庭借诊所的茶杯记忆制造熟悉感。多个家庭的担保栏，都由同一人代签。", 1, false, .investigationOne),
        item("evidence_transfer_order", "调拨单", .keyItem, .story, "名额必须补齐：移出一位被托管者，就由另一位符合条件者补位。玛拉承认旧回执是自己所签。", 1, false, .investigationOne),
        item("evidence_nameplate_box", "封存名牌箱", .keyItem, .story, "伊恩的名牌被归入陌生家庭。牌背细红线连接着担保人的归属网。", 1, false, .investigationOne),
        item("evidence_belonging_threads", "归属丝线", .keyItem, .story, "维娅的归属网络被切断后保留的证据，连接名单、家庭档案、调拨单、录音与名牌。维娅被拘束，仍可作证。", 1, false, .investigationOne),
        item("item_hound_trace", "追索印记拓片", .keyItem, .story, "同一旧犬第4关依召回信号撤离后取得。保留本地追索号与格式不同的外部委托编号。", 1, false, .investigationOne),
        item("item_sealed_transfer", "封存物移交单", .keyItem, .story, "退回寻人信附带的移交单。不同收件人的退件都注明“家属已领回”，却没有对应的家属签名。", 1, false, .investigationOne),
        item("item_blank_identity", "空白身份牌", .keyItem, .story, "第7关取得的待填归属身份牌。背面领药编号属于诊所抄方员伊恩，证明并非只有失名者会被收走。", 1, false, .investigationOne),
        item("currency_copper", "雾岬铜币", .currency, .common, "旧城区基础交易货币。", 99_999, true, .prologue),
        item("item_old_clock_pass", "旧城区通行证", .keyItem, .story, "玛拉交付的临时救援通行证。它证明获准通行，不代表任何人有权永久认领持有人。背面保留旧签收栏。", 1, false, .prologue),
        item("consumable_pain_salve", "止痛膏", .consumable, .common, "战斗中恢复25%最大生命。", 9, false, .prologue),
        item("item_memory_filament", "记忆丝", .material, .uncommon, "守钟人怨影或寄忆核心留下的记忆导丝。", 99, false, .investigationOne),
        item("item_tracking_module", "巡救追踪模块", .keyItem, .story, "从第10关押运队取得的定位模块，保存已领回名单的运送编号；不是第13关救援者提前掉落的物品。", 1, false, .investigationOne),
        item("item_late_second_watch", "迟秒怀表", .keyItem, .story, "与旧邮務追索编号对应的迟秒怀表。仅用于调查邮路，不可装备，没有遗落物能力。", 1, false, .investigationOne),
        item("material_skill_dust", "技能粉尘", .material, .common, "用于强化已解锁技能。每级提升10%直接伤害或自身护盾，最多5级；第9、14关每次胜利获得30份。", 9_999, false, .investigationOne),
        item("material_clock_bronze", "旧城区青铜", .material, .common, "空壳守卫与失名猎犬掉落的公开素材。", 999, true, .investigationOne),
        item("material_memory_filament", "记忆丝", .material, .uncommon, "记忆蛭和镜面替身留下的异路径素材。", 999, true, .investigationTwo),
        item("consumable_salt_tea", "盐雾醒神茶", .consumable, .common, "战斗中恢复20%最大生命。", 9, false, .investigationOne),
        item("consumable_mirror_salve", "镜银药膏", .consumable, .uncommon, "战斗中立即获得100护盾。", 9, false, .investigationTwo),
        item("consumable_clock_key", "一次性校时钥", .consumable, .uncommon, "战斗中令剩余冷却最长的普通技能立即可用。", 3, false, .investigationThree),
        item("key_thirteenth_recording", "归一档案录音", .keyItem, .story, "洛克救援站的命令录音。“安置完成”后，本该“允许离开”，却接成“等待调拨”。本地控制解除，根授权仍在。", 1, false, .investigationThree),
        item("key_old_clock_attestation", "旧城区身份演证", .keyItem, .story, "完成旧城区调查后获得的个人凭证。", 1, false, .investigationFour),
        item("key_authority_echo", "权柄回声", .keyItem, .story, "用于阶位8误导训练预演。", 1, false, .investigationFour),
        item("cosmetic_clockface_fragment", "归一档案碎片", .cosmetic, .rare, "归一档案回声模式的外观兑换物。", 999, false, .echoReplay)
    ]

    public static let companions: [MPCCompanionContent] = [
        .init(id: "ally_norn_kade", name: "诺恩·凯德", pathName: "雾灯巡官", role: .protector, normalSkillIDs: ["ally_guard_wall", "ally_armor_break", "ally_intercept"], ultimateSkillID: "ally_unbroken_march", passiveID: "ally_passive_stand_fast", unlockStage: .investigationOne),
        .init(id: "ally_chariot_warden", name: "铁誓·洛恩", pathName: "远征之径", role: .protector, normalSkillIDs: ["ally_guard_wall", "ally_armor_break", "ally_intercept"], ultimateSkillID: "ally_unbroken_march", passiveID: "ally_passive_stand_fast", unlockStage: .investigationTwo),
        .init(id: "ally_tide_mender", name: "潮医·赛芙", pathName: "潮忆之径", role: .healer, normalSkillIDs: ["ally_memory_mend", "ally_cleanse_tide", "ally_vulnerability_echo"], ultimateSkillID: "ally_returning_tide", passiveID: "ally_passive_gentle_recall", unlockStage: .investigationThree),
        .init(id: "ally_alchemy_construct", name: "铜枝构装·柒", pathName: "炼成之径", role: .construct, normalSkillIDs: ["ally_catalyst_bolt", "ally_sunder_formula", "ally_emergency_plating"], ultimateSkillID: "ally_grand_transmutation", passiveID: "ally_passive_recycle_heat", unlockStage: .investigationThree)
    ]

    public static let enemies: [MPCEnemyContent] = [
        enemy("enemy_codex_executor", "自动签发执行者", .elite, 2200, 104, 20, ["calibration", "strike", "thirteenth_charge", "recover"], "截停自动补位签发；P17与P29是独立实例，数值待整关样本"),
        enemy("enemy_archive_adjudicator", "裁定锤卫", .elite, 2400, 112, 22, ["guard", "strike", "thirteenth_charge", "recover"], "执役许可与物理市政锚分离；新数值等待完整战斗样本"),
        enemy("enemy_archive_convoy", "押运锤卫", .elite, 3200, 120, 24, ["guard", "strike", "thirteenth_charge", "recover"], "首次截救后撤离，末次切供能后真正摧毁；不以生命归零伪造逃离"),
        enemy("boss_chronarch_sovereign", "瑟维安 · 总签官", .boss, 5200, 140, 24, ["strike", "calibration", "thirteenth_charge", "recover"], "同体三战；28与29完整行动循环，30唯一真死；数值待整关验证"),
        enemy("enemy_archive_gatekeeper", "档案守卫", .normal, 1500, 200, 12,
              ["guard", "archive_slam", "recover"], "观察封存防御与出击后的校准空档，利用空档输出",
              skills: [
                .init(id: "archive-gate-seal", name: "封存装甲", intent: "guard", target: .selfUnit,
                      damageBasisPoints: 0, tags: ["defense"], archiveDescription: "装甲闭合，减轻受到的攻击。"),
                .init(id: "archive-gate-slam", name: "封档重击", intent: "archive_slam",
                      damageBasisPoints: 2_000, tags: ["damage"], archiveDescription: "解开封存，以重击驱逐未登记者。"),
                .init(id: "archive-gate-recover", name: "重新校准", intent: "recover", target: .selfUnit,
                      damageBasisPoints: 0, tags: ["vulnerable"], archiveDescription: "出击后重新对齐装甲，暴露短暂空档。")
              ]),
        enemy("enemy_clockwork_rat", "失名鼠", .normal, 250, 38, 6, ["scavenge", "bite"], "两目标与普通攻击重定向"),
        enemy(
            "enemy_memory_leech_node", "寄忆核心", .normal, 360, 46, 10,
            ["memory_strike", "archive_repair", "calibrate", "transfer"],
            "后排支援单位；冲击、修复、防御校正与低血转存",
            skills: [
                .init(
                    id: "memory-core-impact",
                    name: "记忆冲击",
                    intent: "memory_strike",
                    target: .player,
                    damageBasisPoints: 600,
                    tags: ["damage", "priority_target"],
                    archiveDescription: "寄忆核心把未经归档的记忆压缩成冲击，直接命中主角。"
                ),
                .init(
                    id: "memory-core-repair",
                    name: "归档修复",
                    intent: "archive_repair",
                    target: .lowestHealthAlly,
                    damageBasisPoints: 0,
                    healingBasisPoints: 1_000,
                    tags: ["heal", "lowest_health_ally", "priority_target"],
                    archiveDescription: "寄忆核心把稳定版本写回生命最低的友军，恢复其最大生命的10%。"
                ),
                .init(
                    id: "memory-core-calibration",
                    name: "校正",
                    intent: "calibrate",
                    target: .lowestHealthAlly,
                    damageBasisPoints: 0,
                    defenseBonusBP: 1_000,
                    tags: ["defense", "lowest_health_ally"],
                    archiveDescription: "寄忆核心为一个友军补上统一防御记录，令其防御提高10%，持续2幕。"
                ),
                .init(
                    id: "memory-core-transfer",
                    name: "转存",
                    intent: "transfer",
                    target: .selfUnit,
                    damageBasisPoints: 0,
                    tags: ["transfer_buff_below_half"],
                    archiveDescription: "寄忆核心生命低于50%时，把自身仍在生效的增益转存给另一名友军。"
                )
            ]
        ),
        enemy(
            "boss_hollow_clock_guard", "归名执事·赫恩", .boss, 900, 118, 24,
            ["strike", "guard", "thirteenth_charge"],
            "双重铺垫、防御与误认转错位",
            skills: clockGuardSkills + [clockGuardThirteenthSkill]
        ),
        enemy(
            "enemy_hollow_clockmaker", "空壳守卫", .normal, 520, 72, 12,
            ["strike", "guard"], "读取基础意图",
            skills: clockGuardSkills
        ),
        enemy(
            "enemy_hollow_clockmaker_q1", "空壳守卫", .normal, 240, 56, 12,
            ["strike", "strike"], "破除控制印记后练习手动出牌与普攻；最迟第十回合结束",
            skills: clockGuardSkills
        ),
        enemy(
            "enemy_resonant_clock_guard_q2", "雾都幽灵", .normal, 520, 42, 12,
            ["strike", "strike"], "两只雾都幽灵以雾钟震魂与幽雾追魂独立施法",
            skills: fogGhostSkills
        ),
        enemy(
            "enemy_resonant_clock_guard_q2_split", "赤怨幽灵", .normal, 260, 32, 12,
            ["strike", "strike"], "雾都幽灵被击散后分裂为两只赤红怨影，攻击频率提高50%，不再分裂",
            skills: fogGhostSkills
        ),
        enemy(
            "enemy_clockwork_hound", "失名猎犬", .normal, 620, 88, 10,
            ["memory_breath"], "撕咬、冥火喷吐与认名扑杀",
            skills: [
                .init(
                    id: "hell-hound-bite",
                    name: "撕咬",
                    intent: "bite",
                    damageBasisPoints: 1_000,
                    tags: ["damage", "hell_hound", "basic_attack"],
                    archiveDescription: "失名猎犬原地撕咬被标记为身份冲突的目标。",
                    vfxID: "hell_hound_bite"
                ),
                .init(
                    id: "hell-hound-memory-breath",
                    name: "冥火喷吐",
                    intent: "memory_breath",
                    damageBasisPoints: 1_500,
                    tags: ["damage", "hell_hound", "charged_attack"],
                    archiveDescription: "失名猎犬原地蓄力，从口中喷出记忆冥火。狂暴时倍率提高至180%。",
                    vfxID: "hell_hound_memory_breath"
                ),
                .init(
                    id: "hell-hound-name-hunt",
                    name: "认名扑杀",
                    intent: "name_hunt",
                    damageBasisPoints: 1_000,
                    tags: ["damage", "hell_hound", "lowest_health", "repeat_bonus"],
                    archiveDescription: "失名猎犬优先扑向当前生命最低的目标；连续锁定同一目标时伤害逐次提高，最多3层。"
                )
            ]
        ),
        enemy("enemy_emerald_revenant", "翠焰亡灵", .normal, 2_400, 110, 10, ["memory_breath", "charge", "emerald_burst"], "毒雾持续加浓；绿焰预告致命返场，用假面承接", skills: emeraldRevenantSkills),
        enemy("enemy_memory_leech", "记忆蛭", .normal, 430, 58, 8, ["parasite", "transfer", "bite"], "目标优先级与记忆转存"),
        enemy("enemy_mirror_double", "拼接替身", .normal, 560, 76, 14, ["feint", "real_strike"], "按意图而非外观判断"),
        enemy("enemy_calibration_puppet", "抄录傀儡", .normal, 780, 70, 25, ["fortify", "calibrate", "slam"], "区分护甲与意志"),
        enemy("enemy_salt_shell_worker", "盐壳力工", .normal, 700, 86, 20, ["strike", "guard"], "高防御与穿甲处理"),
        enemy(
            "enemy_white_salt_doctor", "白盐医师", .normal, 620, 58, 14,
            ["archive_repair", "calibrate", "strike"],
            "支援优先与持续修复",
            skills: [
                .init(
                    id: "salt-doctor-repair",
                    name: "白盐再生",
                    intent: "archive_repair",
                    target: .lowestHealthAlly,
                    damageBasisPoints: 0,
                    healingBasisPoints: 800,
                    tags: ["heal", "lowest_health_ally"],
                    archiveDescription: "白盐医师为生命最低的友军恢复最大生命的8%。"
                ),
                .init(
                    id: "salt-doctor-preserve",
                    name: "保存",
                    intent: "calibrate",
                    target: .lowestHealthAlly,
                    damageBasisPoints: 0,
                    defenseBonusBP: 1_200,
                    tags: ["defense", "lowest_health_ally"],
                    archiveDescription: "白盐医师为一个友军增加12%防御，持续2幕。"
                )
            ]
        ),
        enemy("enemy_drowned_sailor", "溺忆水手", .normal, 650, 82, 12, ["strike", "recover"], "吸血与死亡残响"),
        enemy("enemy_anchor_guard", "锚链卫士", .normal, 900, 94, 24, ["guard", "slam"], "前排保护与强攻"),
        enemy("enemy_public_recorder", "公共记录员", .normal, 520, 60, 12, ["archive", "calibration"], "强化与档案覆盖"),
        enemy("enemy_redaction_official", "删改官", .normal, 800, 80, 20, ["trim_buff", "shear"], "驱散玩家增益与删改证据"),
        enemy("enemy_lampeater_spawn", "吞灯幼体", .normal, 480, 66, 9, ["dim", "bite", "hide_minor_intent"], "有限信息处理"),
        enemy("elite_clock_chaser", "精英空壳守卫", .elite, 1_450, 104, 22, ["feint", "strike", "thirteenth_charge"], "保留冷却应对周期强攻"),
        enemy("elite_memory_trimmer", "精英记忆蛭", .elite, 1_300, 92, 18, ["trim_buff", "shear", "archive"], "状态管理与驱散"),
        enemy("boss_salt_mother", "白盐母体", .boss, 3_600, 108, 30, ["recover", "guard", "summon"], "再生、保存与容器召唤"),
        enemy("boss_total_rehearsal_officer", "总排演官", .boss, 3_900, 112, 26, ["calibration", "replay", "replace"], "校准、重演与替身替换"),
        enemy("boss_returning_ship_heart", "归航船心", .boss, 4_200, 116, 26, ["pulse", "recover", "sail"], "归航脉冲、回收与水手召唤"),
        enemy("boss_severian_unified_clock", "瑟维安 + 归一档案库", .boss, 4_800, 118, 28, ["calibration", "unified_moment", "thirteenth_bell"], "综合连段与三阶段规则")
    ]

    public static let encounters: [MPCEncounterContent] = [
        encounter("chapter01_q01_encounter", "雨夜醒来", "chapter01_q01", [["enemy_hollow_clockmaker_q1"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 1)!.itemIDs, nil, ["seal_break", "single_card"]),
        encounter("chapter01_q02_encounter", "雾都幽灵", "chapter01_q02", [[
            "enemy_resonant_clock_guard_q2",
            "enemy_resonant_clock_guard_q2"
        ]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 2)!.itemIDs, nil, ["single_card_mastery", "dual_target"]),
        encounter("chapter01_q03_encounter", "循名而来的猎犬", "chapter01_q03", [["enemy_clockwork_hound"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 3)!.itemIDs, nil, ["hell_hound", "stolen_name"]),
        encounter("chapter01_q04_encounter", "猎犬试探", "chapter01_q04", [["enemy_clockwork_hound"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 4)!.itemIDs, nil, ["illusion_payoff", "hound_fireball", "K01"]),
        encounter("chapter01_q05_encounter", "不肯落幕", "chapter01_q05", [["enemy_emerald_revenant"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 5)!.itemIDs, nil, ["emerald_revenant", "escalating_poison", "return_attack"]),
        encounter("chapter01_q06_encounter", "档案街入口", "chapter01_old_district", [["enemy_archive_gatekeeper"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 6)!.itemIDs, nil, ["guard_window", "archive"]),
        encounter("chapter01_q07_encounter", "空白身份牌", "chapter01_old_district", [["enemy_hollow_clockmaker", "enemy_hollow_clockmaker", "enemy_memory_leech_node"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 7)!.itemIDs, nil, ["rear_first", "identity"]),
        encounter("chapter01_q08_encounter", "不属于我的名字", "chapter01_old_district", [["enemy_memory_leech"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 8)!.itemIDs, nil, ["conversion", "misalignment"]),
        encounter("chapter01_q09_encounter", "被改写的证词", "chapter01_old_district", [["enemy_calibration_puppet", "enemy_memory_leech_node"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 9)!.itemIDs, nil, ["setup", "fortify"]),
        encounter("chapter01_q10_encounter", "失踪者名单", "chapter01_old_district", [["enemy_clockwork_hound", "enemy_calibration_puppet"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 10)!.itemIDs, nil, ["K04", "four_slots"]),
        encounter("chapter01_q11_encounter", "不属于我的家人", "chapter01_old_district", [["enemy_memory_leech", "enemy_memory_leech", "enemy_hollow_clockmaker"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 11)!.itemIDs, nil, ["K05", "dual_leech"]),
        encounter("chapter01_q12_encounter", "强制校正", "chapter01_old_district", [["enemy_calibration_puppet", "enemy_calibration_puppet"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 12)!.itemIDs, nil, ["dispel", "counter"]),
        encounter("chapter01_q13_encounter", "救援命令", "chapter01_old_district", [["elite_clock_chaser", "enemy_memory_leech_node"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 13)!.itemIDs, nil, ["ultimate", "elite"]),
        encounter("chapter01_q14_encounter", "错误名牌", "chapter01_old_district", [["enemy_memory_leech", "enemy_calibration_puppet"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 14)!.itemIDs, nil, ["target_switch", "status"]),
        encounter("chapter01_q15_encounter", "归属标签", "chapter01_old_district", [["enemy_hollow_clockmaker", "enemy_memory_leech_node", "enemy_memory_leech_node"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 15)!.itemIDs, "relic_unified_gear", ["three_targets", "relic_cycle"]),
        encounter("chapter01_q16_encounter", "销号追索", "chapter01_old_district", [["enemy_clockwork_hound"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 16)!.itemIDs, nil, ["chapter30_v3"]),
        encounter("chapter01_q17_encounter", "自动补位", "chapter01_old_district", [["enemy_codex_executor"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 17)!.itemIDs, nil, ["chapter30_v3"]),
        encounter("chapter01_q18_encounter", "无效的许可", "chapter01_old_district", [["enemy_archive_adjudicator"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 18)!.itemIDs, nil, ["chapter30_v3"]),
        encounter("chapter01_q19_encounter", "外海收件人", "chapter01_old_district", [["enemy_emerald_revenant"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 19)!.itemIDs, nil, ["chapter30_v3"]),
        encounter("chapter01_q20_encounter", "押运中的活档案", "chapter01_old_district", [["enemy_archive_convoy"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 20)!.itemIDs, nil, ["chapter30_v3"]),
        encounter("chapter01_q21_encounter", "原始救援条款", "chapter01_old_district", [["elite_clock_chaser", "enemy_memory_leech_node"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 21)!.itemIDs, nil, ["chapter30_v3"]),
        encounter("chapter01_q22_encounter", "不属于你的庇护", "chapter01_old_district", [["enemy_hollow_clockmaker"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 22)!.itemIDs, nil, ["chapter30_v3"]),
        encounter("chapter01_q23_encounter", "不以人名封口", "chapter01_old_district", [["enemy_archive_adjudicator"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 23)!.itemIDs, nil, ["chapter30_v3"]),
        encounter("chapter01_q24_encounter", "地下泊位", "chapter01_old_district", [["enemy_clockwork_hound", "enemy_resonant_clock_guard_q2"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 24)!.itemIDs, nil, ["chapter30_v3"]),
        encounter("chapter01_q25_encounter", "自愿断线", "chapter01_old_district", [["enemy_hollow_clockmaker"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 25)!.itemIDs, nil, ["chapter30_v3"]),
        encounter("chapter01_q26_encounter", "最后一趟押运", "chapter01_old_district", [["enemy_archive_convoy"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 26)!.itemIDs, nil, ["chapter30_v3"]),
        encounter("chapter01_q27_encounter", "未签署的归属", "chapter01_old_district", [["enemy_archive_gatekeeper", "enemy_clockwork_hound"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 27)!.itemIDs, nil, ["chapter30_v3"]),
        encounter("chapter01_q28_encounter", "五次回流", "chapter01_old_district", [["boss_chronarch_sovereign"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 28)!.itemIDs, nil, ["chapter30_v3"]),
        encounter("chapter01_q29_encounter", "最后的代签", "chapter01_old_district", [["boss_chronarch_sovereign", "enemy_codex_executor", "enemy_hollow_clockmaker"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 29)!.itemIDs, nil, ["chapter30_v3"]),
        encounter("chapter01_q30_encounter", "无主者的签名", "chapter01_old_district", [["boss_chronarch_sovereign"]], 0, MPCChapterOneThirtyMissionContract.firstClear(for: 30)!.itemIDs, nil, ["chapter30_v3"]),
        encounter("encounter_rain_01", "雨中的空壳", "investigation_rain_bell", [["enemy_hollow_clockmaker"]], 0, ["currency_copper", "material_clock_bronze"], nil, ["intent"]),
        encounter("encounter_rain_02", "猎犬蓄火", "investigation_rain_bell", [["enemy_clockwork_hound"]], 0, ["material_skill_dust"], "relic_late_second_watch", ["guard", "evasion"]),
        encounter("encounter_stolen_01", "盐晶植入街口", "investigation_stolen_day", [["enemy_memory_leech", "enemy_hollow_clockmaker"]], 1, ["material_memory_filament"], nil, ["focus_fire"]),
        encounter("encounter_stolen_02", "盐晶植入室", "investigation_stolen_day", [["enemy_calibration_puppet", "enemy_lampeater_spawn"]], 1, ["consumable_mirror_salve"], "relic_cracked_monocle", ["will_break", "armor"]),
        encounter("encounter_thirteenth_01", "替身拒演排练厅", "investigation_thirteenth", [["enemy_mirror_double", "enemy_mirror_double", "enemy_lampeater_spawn"]], 2, ["material_skill_dust"], nil, ["intent", "multi_target"]),
        encounter("encounter_thirteenth_02", "总排演官后台", "investigation_thirteenth", [["elite_clock_chaser", "enemy_hollow_clockmaker"]], 2, ["key_thirteenth_recording"], "relic_thirteenth_record", ["cooldown_hold", "elite"]),
        encounter("encounter_midnight_01", "档案裁定官列阵", "investigation_midnight", [["elite_memory_trimmer", "enemy_mirror_double"], ["enemy_calibration_puppet", "enemy_clockwork_hound"]], 2, ["consumable_clock_key"], nil, ["dispel", "timeline"]),
        encounter("encounter_midnight_02", "不存在的灾难", "investigation_midnight", [["boss_severian_unified_clock"]], 2, ["key_old_clock_attestation", "key_authority_echo"], "relic_unified_gear", ["boss", "phase", "finisher"])
    ] + generatedDistrictEncounters

    /// Map missions are deliberately authored here instead of falling back to
    /// the old prototype dungeon. This keeps the first chapter's five areas
    /// on the same combat core while preserving their distinct questions,
    /// enemies and relic milestones from the design baseline.
    private static let generatedDistrictEncounters: [MPCEncounterContent] =
        districtEncounters(
            districtID: "salt-warehouse",
            districtName: "盐栈区·借来的身体",
            waves: [
                [["enemy_salt_shell_worker"]],
                [["enemy_salt_shell_worker", "enemy_salt_shell_worker"]],
                [["enemy_memory_leech_node", "enemy_salt_shell_worker"]],
                [["enemy_white_salt_doctor", "enemy_hollow_clockmaker"]],
                [["enemy_clockwork_hound", "enemy_white_salt_doctor"]],
                [["enemy_salt_shell_worker", "enemy_salt_shell_worker", "enemy_memory_leech_node"]],
                [["enemy_calibration_puppet", "enemy_white_salt_doctor"]],
                [["elite_clock_chaser"]],
                [["enemy_memory_leech", "enemy_white_salt_doctor"]],
                [["enemy_salt_shell_worker", "enemy_white_salt_doctor", "enemy_memory_leech_node"]],
                [["enemy_hollow_clockmaker", "enemy_hollow_clockmaker", "enemy_white_salt_doctor"]],
                [["enemy_clockwork_hound", "enemy_salt_shell_worker"]],
                [["enemy_memory_leech_node", "enemy_calibration_puppet"]],
                [["enemy_white_salt_doctor", "enemy_salt_shell_worker"]],
                [["enemy_salt_shell_worker", "enemy_salt_shell_worker", "enemy_hollow_clockmaker"]],
                [["enemy_hollow_clockmaker", "enemy_hollow_clockmaker", "enemy_memory_leech_node"]],
                [["enemy_white_salt_doctor", "enemy_memory_leech_node"]],
                [["enemy_memory_leech_node", "enemy_memory_leech_node", "enemy_salt_shell_worker"]],
                [["elite_clock_chaser", "enemy_white_salt_doctor"]],
                [["boss_salt_mother"]]
            ],
            relics: [
                5: "relic_memory_leech_vial",
                10: "relic_borrowed_bell",
                15: "relic_salt_crystal_record",
                18: "relic_recovery_seal",
                20: "relic_cracked_monocle"
            ]
        )
        + districtEncounters(
            districtID: "mirror-theater",
            districtName: "镜剧区·替身拒演",
            waves: [
                [["enemy_mirror_double"]],
                [["enemy_mirror_double", "enemy_mirror_double"]],
                [["enemy_calibration_puppet", "enemy_mirror_double"]],
                [["enemy_mirror_double", "enemy_hollow_clockmaker"]],
                [["enemy_mirror_double"]],
                [["enemy_calibration_puppet", "enemy_hollow_clockmaker"]],
                [["enemy_mirror_double", "enemy_mirror_double"]],
                [["enemy_mirror_double", "enemy_memory_leech_node"]],
                [["enemy_clockwork_hound", "enemy_mirror_double"]],
                [["enemy_mirror_double", "enemy_mirror_double", "enemy_calibration_puppet"]],
                [["enemy_hollow_clockmaker", "enemy_calibration_puppet"]],
                [["enemy_mirror_double"]],
                [["enemy_mirror_double", "enemy_mirror_double", "enemy_mirror_double"]],
                [["enemy_memory_leech_node", "enemy_calibration_puppet"]],
                [["enemy_calibration_puppet", "enemy_calibration_puppet", "enemy_mirror_double"]],
                [["elite_clock_chaser", "enemy_mirror_double"]],
                [["enemy_clockwork_hound", "enemy_mirror_double", "enemy_mirror_double"]],
                [["enemy_calibration_puppet", "enemy_memory_leech_node"]],
                [["enemy_mirror_double", "enemy_calibration_puppet"]],
                [["boss_total_rehearsal_officer"]]
            ],
            relics: [
                5: "relic_thirteenth_record",
                10: "relic_clock_chaser_spur",
                15: "relic_mirror_thread",
                18: "relic_red_wax_seal",
                20: "relic_blank_ticket"
            ]
        )
        + districtEncounters(
            districtID: "tide-gate",
            districtName: "潮门港·死者归航",
            waves: [
                [["enemy_drowned_sailor"]],
                [["enemy_drowned_sailor", "enemy_drowned_sailor"]],
                [["enemy_anchor_guard", "enemy_drowned_sailor"]],
                [["enemy_memory_leech_node", "enemy_drowned_sailor"]],
                [["enemy_clockwork_hound", "enemy_anchor_guard"]],
                [["enemy_drowned_sailor", "enemy_drowned_sailor"]],
                [["enemy_hollow_clockmaker", "enemy_drowned_sailor"]],
                [["elite_memory_trimmer"]],
                [["enemy_anchor_guard", "enemy_memory_leech_node"]],
                [["enemy_drowned_sailor", "enemy_drowned_sailor", "enemy_anchor_guard"]],
                [["enemy_clockwork_hound", "enemy_hollow_clockmaker"]],
                [["enemy_memory_leech_node", "enemy_anchor_guard"]],
                [["enemy_drowned_sailor", "enemy_drowned_sailor", "enemy_memory_leech_node"]],
                [["elite_memory_trimmer", "enemy_anchor_guard"]],
                [["enemy_drowned_sailor", "enemy_drowned_sailor", "enemy_drowned_sailor"]],
                [["enemy_hollow_clockmaker", "enemy_hollow_clockmaker", "enemy_anchor_guard"]],
                [["enemy_memory_leech_node", "enemy_memory_leech_node"]],
                [["enemy_clockwork_hound", "enemy_drowned_sailor"]],
                [["elite_clock_chaser", "enemy_drowned_sailor"]],
                [["boss_returning_ship_heart"]]
            ],
            relics: [
                5: "relic_late_second_watch",
                10: "relic_mist_anchor_shard",
                15: "relic_refusal_deed",
                18: "relic_reposition_knot",
                20: "relic_returning_route"
            ]
        )
        + districtEncounters(
            districtID: "mist-crown",
            districtName: "雾岬上城·不存在的灾难",
            waves: [
                [["enemy_public_recorder"]],
                [["enemy_redaction_official", "enemy_public_recorder"]],
                [["enemy_hollow_clockmaker", "enemy_redaction_official"]],
                [["enemy_redaction_official", "enemy_redaction_official"]],
                [["enemy_clockwork_hound", "enemy_public_recorder"]],
                [["enemy_memory_leech_node", "enemy_redaction_official"]],
                [["enemy_hollow_clockmaker", "enemy_public_recorder"]],
                [["enemy_hollow_clockmaker", "enemy_hollow_clockmaker", "enemy_redaction_official"]],
                [["enemy_public_recorder", "enemy_public_recorder"]],
                [["enemy_hollow_clockmaker", "enemy_memory_leech_node", "enemy_public_recorder"]],
                [["elite_memory_trimmer"]],
                [["enemy_public_recorder", "enemy_memory_leech_node"]],
                [["elite_clock_chaser"]],
                [["enemy_clockwork_hound", "enemy_redaction_official"]],
                [["enemy_hollow_clockmaker", "enemy_hollow_clockmaker", "enemy_public_recorder"]],
                [["elite_memory_trimmer", "enemy_memory_leech_node"]],
                [["enemy_public_recorder", "enemy_public_recorder"]],
                [["enemy_memory_leech_node", "enemy_memory_leech_node", "enemy_hollow_clockmaker"]],
                [["elite_clock_chaser", "enemy_redaction_official"]],
                [["boss_severian_unified_clock"]]
            ],
            relics: [
                5: "relic_blank_nameplate",
                10: "relic_contradictory_testimony",
                15: "relic_recovery_seal",
                18: "relic_additional_testimony",
                20: "relic_errata_clip"
            ]
        )

    public static let investigations: [MPCInvestigationContent] = [
        investigation("chapter01_q01", "雨夜醒来", "旧城区·紫藤街口", ["chapter01_q01_encounter"], [.sidestepStrike], [], ["item_old_clock_pass", "consumable_pain_salve"], [], "完成错步穿行的契约，第一张技能牌正式归属玩家。"),
        investigation("chapter01_q02", "雾都幽灵", "旧城区·紫藤街口", ["chapter01_q02_encounter"], [], [], ["item_memory_filament", "item_sealed_transfer"], [], "以单牌完成一次完整战斗，确认多目标技能仍按目标状态分别结算，并取回旧邮务间的移交条。"),
        investigation("chapter01_q03", "循名而来的猎犬", "旧城区·失名档案街", ["chapter01_q03_encounter"], [], [], ["item_late_second_watch"], [ownerlessMaskRelicID], "守钟人的记忆引来了循名猎犬。玛拉先交给你「假面谕令」，再迎战猎犬，揭开项圈上的名字。"),
        investigation("chapter01_q04", "猎犬试探", "旧城区·雾灯街", ["chapter01_q04_encounter"], [], [], ["item_hound_trace"], [], "同一只猎犬留在远处蓄力，随后喷出冥火球；通过实战理解假面承接与误认反击。"),
        investigation("chapter01_q05", "不肯落幕", "旧城区·雾灯街", ["chapter01_q05_encounter"], [], [], [], [], "毒雾持续加浓直到战斗结束；绿焰预告强力返场。根据持续毒雾与直接重击选择遗落物，终止邮务执役。"),
        investigation("chapter01_old_district", "旧城区·失名者", "旧城区", (6...30).map { String(format: "chapter01_q%02d_encounter", $0) }, [], ["fool_passive_01", "fool_passive_02", "fool_passive_03", "fool_passive_04"], ["material_memory_filament", "key_old_clock_attestation", "key_authority_echo"], [], "从失踪者证词追到上游私印，终止认领并保存居民自由；更早的外部追索迫使主角离港。"),
        investigation("investigation_rain_bell", "雨中的空壳", "旧城区·雨水排渠", ["encounter_rain_01", "encounter_rain_02"], [.maskedWhisper, .sidestepStrike], ["fool_passive_01"], ["consumable_salt_tea"], ["relic_late_second_watch"], "确认系统把人标记为版本，而非简单删除。"),
        investigation("investigation_stolen_day", "借来的身体", "盐栈区", ["encounter_stolen_01", "encounter_stolen_02"], [.identityDisplacement, .fabricatedEvidence], ["fool_passive_02", "fool_passive_03"], ["material_memory_filament"], ["relic_cracked_monocle"], "确认正确记忆不能单独证明人格连续。"),
        investigation("investigation_thirteenth", "替身拒演", "镜剧区", ["encounter_thirteenth_01", "encounter_thirteenth_02"], [.mirrorPursuit, .absurdFinale], ["fool_passive_04", "fool_passive_05"], ["key_thirteenth_recording"], ["relic_thirteenth_record"], "替身拒绝继续扮演原主，证明记忆相同不等于身份相同。"),
        investigation("investigation_midnight", "不存在的灾难", "雾岬上城", ["encounter_midnight_01", "encounter_midnight_02"], [.turnTheTables, .backstageChange, .namelessStage], ["fool_passive_06"], ["key_old_clock_attestation", "key_authority_echo"], ["relic_unified_gear"], "保留被删除的证据，停止归一档案库对城市事实的统一裁定。"),
        investigation("chapter01_district_missions", "第一章区域战斗", "雾港五区", [], [], [], [], [], "区域地图任务由章节进度统一结算；战斗本身只负责记录敌人、技能与调查物证。")
    ]

    private static func districtEncounters(
        districtID: String,
        districtName: String,
        waves: [[[String]]],
        relics: [Int: String]
    ) -> [MPCEncounterContent] {
        waves.enumerated().map { index, encounterWaves in
            let number = index + 1
            let paddedNumber = String(format: "%02d", number)
            return encounter(
                "\(districtID)-q\(paddedNumber)_encounter",
                "\(districtName)·第\(number)关",
                "chapter01_district_missions",
                encounterWaves,
                0,
                ["material_skill_dust"],
                relics[number],
                ["district", districtID, "mission_\(number)"]
            )
        }
    }

    public static func validationErrors() -> [String] {
        var errors: [String] = []
        validateUnique(skills.map { $0.id.rawValue }, label: "skill", into: &errors)
        validateUnique(passives.map(\.id), label: "passive", into: &errors)
        validateUnique(relics.map(\.id), label: "relic", into: &errors)
        validateUnique(items.map(\.id), label: "item", into: &errors)
        validateUnique(companions.map(\.id), label: "companion", into: &errors)
        validateUnique(enemies.map(\.id), label: "enemy", into: &errors)
        validateUnique(encounters.map(\.id), label: "encounter", into: &errors)
        validateUnique(investigations.map(\.id), label: "investigation", into: &errors)

        let enemyIDs = Set(enemies.map(\.id))
        let itemIDs = Set(items.map(\.id))
        let relicIDs = Set(relics.map(\.id))
        let encounterIDs = Set(encounters.map(\.id))
        let investigationIDs = Set(investigations.map(\.id))
        let passiveIDs = Set(passives.map(\.id))
        let skillIDs = Set(skills.map(\.id))

        for encounter in encounters {
            if !investigationIDs.contains(encounter.investigationID) { errors.append("\(encounter.id): unknown investigation") }
            for id in encounter.waves.flatMap(\.enemyIDs) where !enemyIDs.contains(id) { errors.append("\(encounter.id): unknown enemy \(id)") }
            for id in encounter.fixedRewardItemIDs where !itemIDs.contains(id) { errors.append("\(encounter.id): unknown item \(id)") }
            if let id = encounter.firstClearRelicID, !relicIDs.contains(id) { errors.append("\(encounter.id): unknown relic \(id)") }
        }
        for investigation in investigations {
            for id in investigation.encounterIDs where !encounterIDs.contains(id) { errors.append("\(investigation.id): unknown encounter \(id)") }
            for id in investigation.unlockSkillIDs where !skillIDs.contains(id) { errors.append("\(investigation.id): unknown skill \(id.rawValue)") }
            for id in investigation.unlockPassiveIDs where !passiveIDs.contains(id) { errors.append("\(investigation.id): unknown passive \(id)") }
            for id in investigation.unlockItemIDs where !itemIDs.contains(id) { errors.append("\(investigation.id): unknown item \(id)") }
            for id in investigation.unlockRelicIDs where !relicIDs.contains(id) { errors.append("\(investigation.id): unknown relic \(id)") }
        }
        return errors
    }

    private static func validateUnique(_ ids: [String], label: String, into errors: inout [String]) {
        if Set(ids).count != ids.count { errors.append("duplicate \(label) id") }
    }

    private static func relic(_ id: String, _ name: String, _ rarity: MPCContentRarity, _ mechanism: String, _ cost: String, _ direction: String, _ story: String, _ stage: MPCUnlockStage) -> MPCRelicContent {
        .init(id: id, name: name, rarity: rarity, mechanism: mechanism, cost: cost, buildDirection: direction, story: story, unlockStage: stage)
    }

    private static func item(_ id: String, _ name: String, _ kind: MPCItemKind, _ rarity: MPCContentRarity, _ description: String, _ maxStack: Int, _ tradable: Bool, _ stage: MPCUnlockStage) -> MPCItemContent {
        .init(id: id, name: name, kind: kind, rarity: rarity, description: description, maxStack: maxStack, isTradable: tradable, unlockStage: stage)
    }

    private static func enemy(
        _ id: String,
        _ name: String,
        _ rank: MPCEnemyContentRank,
        _ hp: Int,
        _ attack: Int,
        _ defense: Int,
        _ pattern: [String],
        _ teaching: String,
        skills: [MPCEnemySkillDefinition] = []
    ) -> MPCEnemyContent {
        .init(id: id, name: name, rank: rank, maxHP: hp, attack: attack, defense: defense, intentPattern: pattern, teachingPurpose: teaching, skills: skills)
    }

    private static let fogGhostSkills: [MPCEnemySkillDefinition] = [
        .init(id: "fog-ghost-chime", name: "雾钟震魂", intent: "strike", damageBasisPoints: 900,
              tags: ["damage", "ghost", "mist"], archiveDescription: "冷青幽灵凝聚雾核，钟纹声波在命中处扩散。", vfxID: "projectile-fog-chime-v1"),
        .init(id: "fog-ghost-wisp", name: "幽雾追魂", intent: "strike", damageBasisPoints: 900,
              tags: ["damage", "ghost", "mist"], archiveDescription: "淡紫幽灵放出三缕追魂雾，交错飞向目标后散开。", vfxID: "projectile-ghost-wisp-v1")
    ]

    private static let clockGuardSkills: [MPCEnemySkillDefinition] = [
        .init(
            id: "clock-guard-crimson-crescent",
            name: "赤弧斩",
            intent: "strike",
            damageBasisPoints: 900,
            tags: ["damage", "sword", "hollow_guard"],
            archiveDescription: "空壳守卫以断裂金属牵引赤色弯月剑气，从外向内撕开目标。",
            vfxID: "clock_guard_crimson_crescent"
        ),
        .init(
            id: "clock-guard-violet-mantle",
            name: "重甲架势",
            intent: "guard",
            target: .selfUnit,
            damageBasisPoints: 0,
            defenseBonusBP: 1_200,
            tags: ["guard", "defense", "hollow_guard"],
            archiveDescription: "守卫压低重心，临时提高防御，等待下一次校正重击。",
            vfxID: "clock_guard_violet_mantle"
        )
    ]

    private static let clockGuardThirteenthSkill = MPCEnemySkillDefinition(
        id: "clock-guard-thirteenth-bell",
        name: "校正重击",
        intent: "thirteenth_charge",
        damageBasisPoints: 1_600,
        tags: ["heavy_attack", "sword", "correction"],
        archiveDescription: "校正命令锁定目标，空壳守卫蓄力后用重刃完成高倍率攻击。",
        vfxID: "clock_guard_thirteenth_bell"
    )

    private static let emeraldRevenantSkills: [MPCEnemySkillDefinition] = [
        .init(
            id: "emerald-revenant-memory-breath",
            name: "翠毒漫天",
            intent: "memory_breath",
            damageBasisPoints: 1_800,
            tags: ["damage", "emerald_revenant", "charged_attack", "encore"],
            archiveDescription: "开场释放持续毒雾，每3秒造成伤害并加浓，伤害逐渐提高，直到战斗结束。毒雾不消耗假面的承伤次数。",
            vfxID: "emerald_revenant_breath"
        ),
        .init(
            id: "emerald-revenant-toxic-burst",
            name: "返场毒爆",
            intent: "emerald_burst",
            damageBasisPoints: 1_800,
            tags: ["damage", "emerald_revenant", "charged_attack", "encore"],
            archiveDescription: "身上燃起绿焰后释放强力毒爆；无护盾时两次命中足以致命。保留假面，在蓄力时手动释放承接重击。",
            vfxID: "emerald_revenant_burst"
        )
    ]

    private static func encounter(_ id: String, _ name: String, _ investigation: String, _ waves: [[String]], _ slots: Int, _ rewards: [String], _ relic: String?, _ tags: [String]) -> MPCEncounterContent {
        .init(id: id, name: name, investigationID: investigation, waves: waves.map { MPCEncounterWave(enemyIDs: $0) }, companionSlots: slots, fixedRewardItemIDs: rewards, firstClearRelicID: relicsEnabled ? relic : nil, recommendedTags: tags)
    }

    private static func investigation(_ id: String, _ name: String, _ location: String, _ encounters: [String], _ skills: [FoolSkillID], _ passives: [String], _ items: [String], _ relics: [String], _ outcome: String) -> MPCInvestigationContent {
        .init(id: id, name: name, location: location, encounterIDs: encounters, unlockSkillIDs: skills.filter { $0 != .maskedWhisper }, unlockPassiveIDs: passives, unlockItemIDs: items, unlockRelicIDs: relics.filter(isRelicEnabled), narrativeOutcome: outcome)
    }
}
