import Foundation
import MistportCombatCore

enum DistrictMissionKind: String, Hashable {
    case combat
    case elite
    case boss

    var title: String {
        switch self {
        case .combat: "清剿"
        case .elite: "精英"
        case .boss: "区域首领"
        }
    }

    var symbol: String {
        switch self {
        case .combat: "bolt.fill"
        case .elite: "shield.lefthalf.filled"
        case .boss: "crown.fill"
        }
    }
}

enum GrowthMilestone: String, Hashable {
    case weaponResonance
    case skillEvolution
    case talentAwakening
    case advancementProof

    var title: String {
        switch self {
        case .weaponResonance: "武装共鸣"
        case .skillEvolution: "技能进化"
        case .talentAwakening: "天赋觉醒"
        case .advancementProof: "晋阶演证"
        }
    }

    var symbol: String {
        switch self {
        case .weaponResonance: "hammer.fill"
        case .skillEvolution: "sparkles"
        case .talentAwakening: "point.3.filled.connected.trianglepath.dotted"
        case .advancementProof: "seal.fill"
        }
    }
}

struct DistrictMission: Identifiable, Hashable {
    let id: String
    let districtID: String
    let districtName: String
    let number: Int
    let globalOrder: Int
    let title: String
    let objective: String
    let rewardText: String
    let recommendedPower: Int
    let reputationReward: Int
    let kind: DistrictMissionKind

    var growthMilestone: GrowthMilestone? {
        switch number {
        case 5: .weaponResonance
        case 10: .skillEvolution
        case 15: .talentAwakening
        case 20: .advancementProof
        default: nil
        }
    }

    var difficultyLabel: String {
        switch globalOrder {
        case 1...20: "新手"
        case 21...40: "进阶"
        case 41...60: "危险"
        case 61...80: "噩梦"
        default: "深渊"
        }
    }

    var battleWaveCount: Int {
        switch kind {
        case .combat:
            number >= 16 ? 3 : (number >= 6 ? 2 : 1)
        case .elite:
            number >= 12 ? 3 : 2
        case .boss:
            number >= 15 ? 3 : 2
        }
    }
}

struct ChapterDistrict: Identifiable, Hashable {
    let id: String
    let order: Int
    let name: String
    let subtitle: String
    let symbol: String
    let theme: String
    let question: String
    let bossName: String
    let proofName: String
    let missions: [DistrictMission]
    let teamExpedition: ExpeditionDefinition

    static let reputationPerMission = 5
    static let reputationToAdvance = 100
    static let teamExpeditionUnlockCount = 10
}

private struct MissionSeed {
    let title: String
    let objective: String
    let reward: String
    let kind: DistrictMissionKind

    init(
        _ title: String,
        _ objective: String,
        _ reward: String,
        kind: DistrictMissionKind = .combat
    ) {
        self.title = title
        self.objective = objective
        self.reward = reward
        self.kind = kind
    }
}

private struct DistrictBlueprint {
    let id: String
    let name: String
    let subtitle: String
    let symbol: String
    let story: String
    let question: String
    let bossName: String
    let proofName: String
    let missions: [MissionSeed]
    let expedition: ExpeditionDefinition
}

extension GameContent {
    static let chapterOneDistricts: [ChapterDistrict] = {
        let blueprints = [
            DistrictBlueprint(
                id: "old-clock",
                name: "旧城区·失名者",
                subtitle: "第一地图 · 完成前置后开放",
                symbol: "clock.fill",
                story: "失踪的人都被记为“已由家属领回”，寻找他们的人却从未见到归人。你记得自己的名字，也必须追查是谁替你签下了认领。",
                question: "救援的临时托管，何时变成了不能拒绝的永久归属？",
                bossName: "总签官·瑟维安",
                proofName: "身份演证·归一档案残页",
                missions: [
                    MissionSeed("雨夜醒来", "空壳守卫身上的记录正在把你改成另一个人。先用普攻观察，再由玛拉交出第一张技能牌。", "永久获得第一张牌「错步穿行」。"),
                    MissionSeed("雾都幽灵", "两只雾都幽灵浮现于旧城区。冷青与淡紫的怨影被打散后，各分裂为两道赤红幽灵，攻势更快；留下的名字指向旧邮务间。", "无新技能；记下守钟人留下的名字。"),
                    MissionSeed("循名而来的猎犬", "守钟人的记忆中浮现出一个名字，追索记录的地狱犬随之而来。", "获得遗落物「假面谕令」；技能槽扩展至2格。"),
                    MissionSeed("猎犬试探", "猎犬先用小火试探，再蓄力射出两颗追索大火球。留住假面接下双焰，抓住认错名字后的反击破绽。", "掌握假面承接双焰与破绽反击。"),
                    MissionSeed("不肯落幕", "守钟人留下的线索指向旧邮务间。翠焰亡灵先释放不断加浓、伤害递增的毒雾；全身绿焰是强力重击的预兆，要留住假面手动应对。", "击退翠焰亡灵，让毒雾散去。"),
                    MissionSeed("档案街入口", "邮务回执指向失名档案街。档案守卫封存入口，出击后的校准空档是突破防线的机会。", "守卫青铜与补录批次线索。"),
                    MissionSeed("空白身份牌", "两具守卫使用同一身份编号，后排寄忆核心不断把受损守卫修回保存的版本。切断核心，停止复制。", "调查物证「空白身份牌」。"),
                    MissionSeed("不属于我的名字", "记忆蛭藏在补录台下，用陌生的声音夺走你的名字。将4层误认转换成错位，拖延它的吞名蓄力。", "战前获得「身份错置」，通关取得记忆丝。"),
                    MissionSeed("被改写的证词", "抄录书记员守住原件，寄忆核心持续覆盖证词。先切断支援，取回真正的记录。", "战后获得「伪证烙印」，开放4点天赋。"),
                    MissionSeed("失踪者名单", "名单上每个失踪者都被替换成同一个名字。双影追猎回应了你；普通技能槽扩展到4格。", "获得技能「双影追猎」。"),
                    MissionSeed("不属于我的家人", "两只记忆蛭共享一段家庭记忆，空壳守卫负责执行统一。用已掌握的牌拆解共享记忆，战后从矛盾中习得荒谬归结。", "获得技能「荒谬归结」。"),
                    MissionSeed("强制校正", "两名抄录书记员交替合账封存与校正，校正会抹除护盾。突破后才习得反客为主。", "获得技能「反客为主」。"),
                    MissionSeed("救援命令", "录音要求救出被困者，寄忆核心却把他们标成待封存对象。失令救援者执行着错误的搬运命令；击破配合后才习得无名宣告。", "获得终极技能「无名宣告」。", kind: .elite),
                    MissionSeed("错误名牌", "名牌被分发给错误的人。记忆蛭吞读名字，抄录书记员校正外部记录；两者的误认与错位分别保存，切换目标时要衔接后续技能。", "查清错误名牌的来源。"),
                    MissionSeed("归属标签", "织幕女主牵住归属标签，两枚寄忆核心维持记录。先拆支援，再集中处理丝线的主人。", "查清归属标签与封锁线的关联。"),
                    MissionSeed("销号追索", "召回声这次不再响起。同一条项圈带着销号命令，旧地狱犬第三次挡住去路。终止它的本地追索后，项圈上的外海编号仍在：委托并未随执行犬一起消失。", "首通收获见关卡清单。"),
                    MissionSeed("自动补位", "机械笔臂正替被截停的流程自动补位。你截下备用签发目录，发现五路市政供能都通向同一枚私印，钟环另有五格储备。毁掉这台执行者，只能停下自动签发，不能撤销私印。", "首通收获见关卡清单。", kind: .elite),
                    MissionSeed("无效的许可", "一份早已失效的许可，仍让裁定卫守住五处市政锚的记录。摧毁执役体、保住锚位图，才能区分供能与授权：杀死守卫并不会让城市失去封口。", "首通收获见关卡清单。", kind: .elite),
                    MissionSeed("外海收件人", "宿舍床位、押运时刻与收件印对上了。外海接收的不是死档案，而是还会呼吸的人。终止此处翠焰执役者的有限执役周期后，赫斯沿已经查明的路线截断战后追踪。", "首通收获见关卡清单。"),
                    MissionSeed("押运中的活档案", "押运匣里传来敲击。你必须先解除沿车的拘束，让这一批活档案离车。押运锤卫仍护着余车撤走；拦下的这一车人，证明救援比追杀更急迫。", "首通收获见关卡清单。", kind: .elite),
                    MissionSeed("原始救援条款", "洛克还记得原始条款：安置完成后，被救者可以离开。毁掉独立转接核心，再拆除背架上的个人根输入，才能让他真正摆脱遥控。他留下来继续救援。", "首通收获见关卡清单。"),
                    MissionSeed("不属于你的庇护", "监管织室开放复核接口时，维娅主动将陌生人的名字填入补位栏。她仍想以别人的自由换取庇护。阻止这次越权后，监管继续；这是她必须承担的选择。", "首通收获见关卡清单。"),
                    MissionSeed("不以人名封口", "替代材料通过了独立验证：封口不必绑定一个人名。清除裁定守备，保住市政主锚。守灯天使伊莱娅说明，必须观察五次完整回流，才能同时切断五路外接供能。", "首通收获见关卡清单。", kind: .elite),
                    MissionSeed("地下泊位", "地下泊位的守备犬与幽灵看守着最后一处转运口。你终于救出真正的伊恩，他认得诊所那只缺角杯，也记得黑盐岸的检疫路线。根授权仍能追索他，事情还未结束。", "首通收获见关卡清单。"),
                    MissionSeed("自愿断线", "维娅在清醒、自愿的状态下同意断契。契约自动防御拦住拆线，却不能代替她的选择。协助她解除归属后，她重新作证并接受审理，永久退出敌对。", "首通收获见关卡清单。"),
                    MissionSeed("最后一趟押运", "同一具押运锤卫守着最后一趟车。先切掉供能，再承受它余力驱动的重锤。此次它被永久摧毁；总签钥与最后一份运输记录留在断开的车链旁。", "首通收获见关卡清单。", kind: .elite),
                    MissionSeed("未签署的归属", "夺回原始档案，未签署的归属栏旁仍是你当初自己报出的名字。外部追索比入港更早，总签官没有创造那段过去。封存交易存根指向第七住客，名字仍被遮住。", "首通收获见关卡清单。"),
                    MissionSeed("五次回流", "瑟维安独自站在五路回流中央。撑过五次完整行动，让每处供能暴露真实回路。最后一击落定且你仍活着时，伊莱娅才同时切源；他带着钟环储备退入签发廊。", "首通收获见关卡清单。", kind: .boss),
                    MissionSeed("最后的代签", "瑟维安以五格储备维持最后的代签，新执行者与空壳守卫护在两侧。五次完整行动耗尽储备后，他使用一次性归庭印撤回总册。清除留下的手下，你才能继续追入。", "首通收获见关卡清单。", kind: .boss),
                    MissionSeed("无主者的签名", "替代封口已经稳定，私印再也接不回旧链。瑟维安仍想以自己的签名认领所有人，这次你必须真正击败他的本体。伊恩回诊所泡茶，洛克安置居民，维娅接受审理；更早的外部追索却迫使你沿赫斯维持的单向航线离港，去往黑盐岸。", "首通收获见关卡清单。", kind: .boss)
                ],
                expedition: ExpeditionDefinition(
                    id: "old-clock-tower",
                    title: "归名档案回廊",
                    city: "旧城区",
                    estimatedMinutes: 12,
                    objective: "六人分路破解四座身份档案节点，并在归一校正完成前摧毁档案机芯。",
                    storyReason: "普通调查已定位归名档案核心；团队副本是可选的高难回声，不阻挡区域推进。"
                )
            ),
            DistrictBlueprint(
                id: "salt-warehouse",
                name: "盐栈区·借来的身体",
                subtitle: "第二地图 · 完成旧城区后开放",
                symbol: "shippingbox.fill",
                story: "特殊盐晶可以保存并植入记忆。盐壳者同时承受陌生人的童年、疼痛与身份，议会正寻找能稳定容纳完整人格的新身体。",
                question: "把记忆放进另一个身体，那个人会复活吗？",
                bossName: "白盐母体",
                proofName: "躯体演证·无主盐胚",
                missions: [
                    MissionSeed("白色仓门", "盐壳力工与空壳守卫守住白色仓门，先判断谁在借用谁的身体。", "盐栈材料。"),
                    MissionSeed("被保存的人", "两名盐壳力工共享同一段童年记忆，穿甲后再决定是否救回它。", "穿甲材料。"),
                    MissionSeed("盐晶编号", "寄忆核心为盐壳力工修复记忆。优先打断后排修复。", "盐晶编号。"),
                    MissionSeed("第二具身体", "白盐医师强行统一人格，空壳守卫替它拖延时间。", "医师档案。"),
                    MissionSeed("她叫我的名字", "失名猎犬与白盐医师同时锁定一个名字，先保证主角活下来。", "生存补给。"),
                    MissionSeed("容器", "两名盐壳力工和寄忆核心把人当作容器，完成一场持久战。", "容器碎片。"),
                    MissionSeed("复写记录", "抄录傀儡与白盐医师同时改写记录，先拆掉支援。", "复写记录。"),
                    MissionSeed("旧伤不存在", "精英盐壳力工否认自己身上的旧伤，测试高防御敌人的处理顺序。", "盐壳核心。", kind: .elite),
                    MissionSeed("不同的血", "记忆蛭把陌生血缘植入白盐医师，先削弱再击破。", "净化盐。"),
                    MissionSeed("借来的丈夫", "盐壳力工、白盐医师和寄忆核心共同保存一段婚姻。", "剧情证词。"),
                    MissionSeed("身体仓", "两名空壳守卫与白盐医师封锁身体仓，保持目标链不被打断。", "仓门钥片。"),
                    MissionSeed("保存失败", "狂暴失名猎犬与盐壳力工进入失控状态，处理爆发窗口。", "狂暴犬齿。"),
                    MissionSeed("被替换的伤疤", "寄忆核心与抄录傀儡把伤疤从一个身体转存到另一个身体。", "替换记录。"),
                    MissionSeed("第二次醒来", "精英白盐医师持续恢复盐壳力工，不能让治疗循环拖长。", "医师印记。", kind: .elite),
                    MissionSeed("不能回家的男人", "两个盐壳力工和一名空壳守卫护送一个不再拥有家的男人。", "回家证词。"),
                    MissionSeed("盐仓封锁", "两名空壳守卫和寄忆核心封死盐仓出口，保持左到右的行动序列。", "盐仓封条。"),
                    MissionSeed("母体呼吸", "白盐医师与寄忆核心共同维持母体呼吸，先处理修复链。", "母体线索。"),
                    MissionSeed("储存室", "两名寄忆核心和盐壳力工守住最后一间储存室。", "保存容器。"),
                    MissionSeed("保存执行队", "精英空壳守卫与白盐医师组成首领前哨，检查构筑完整度。", "母仓通行证。", kind: .elite),
                    MissionSeed("借来的身体", "击败白盐母体，决定被保存的记忆是否应该回到原来的身体。", "躯体演证·无主盐胚。", kind: .boss)
                ],
                expedition: ExpeditionDefinition(
                    id: "salt-mother-vault",
                    title: "沉盐母仓",
                    city: "盐栈区",
                    estimatedMinutes: 14,
                    objective: "护送炼成装置穿过结晶潮，切断三条盐脉并封存母晶。",
                    storyReason: "母仓会周期性重结晶，可作为本区唯一的团队挑战。"
                )
            ),
            DistrictBlueprint(
                id: "mirror-theater",
                name: "镜剧区·替身拒演",
                subtitle: "第三地图 · 完成盐栈区后开放",
                symbol: "theatermasks.fill",
                story: "剧院与镜像工坊把记忆模板写入替身。瑟维安亡妻的复制体拥有她全部记忆，却拒绝继续扮演她。",
                question: "拥有同样记忆的复制体，必须继续扮演原主吗？",
                bossName: "总排演官",
                proofName: "身份演证·拒演面具",
                missions: [
                    MissionSeed("同一个演员", "第一名拼接替身拥有完整的原主记忆，却不承认自己的姓名。", "镜剧材料。"),
                    MissionSeed("第二份台词", "两名拼接替身共享台词，但状态彼此独立。", "目标链练习。"),
                    MissionSeed("排演命令", "抄录傀儡为拼接替身增加增益，先处理支援。", "排演命令。"),
                    MissionSeed("她记得我的家", "拼接替身记得主角的家，空壳守卫却否认这段记忆。", "剧情证词。"),
                    MissionSeed("拒演", "精英拼接替身拒绝继续扮演原主，检查错位兑现。", "拒演证据。", kind: .elite),
                    MissionSeed("纠正动作", "抄录傀儡与空壳守卫让每一个动作都符合模板。", "增益图鉴。"),
                    MissionSeed("不一样的习惯", "两名拼接替身暴露出不同的生活习惯，避免只看外观选目标。", "习惯记录。"),
                    MissionSeed("原主人的孩子", "拼接替身与寄忆核心争夺一个孩子的记忆归属。", "身份标记。"),
                    MissionSeed("失败替身", "失名猎犬追踪逃离舞台的拼接替身。", "追踪材料。"),
                    MissionSeed("完美排演", "两名拼接替身与抄录傀儡完成完美排演；本区团队副本开放。", "开放镜剧院团队副本。"),
                    MissionSeed("被删的台词", "空壳守卫与抄录傀儡删掉拒演者的台词，反制增益。", "删改台词。"),
                    MissionSeed("她不是她", "精英拼接替身公开拒绝成为瑟维安的亡妻。", "关键剧情。", kind: .elite),
                    MissionSeed("替身宿舍", "三名拼接替身在宿舍里共享一份身份档案。", "宿舍钥片。"),
                    MissionSeed("编号Z-0", "寄忆核心与抄录傀儡守护零号替身线索。", "零号档案。"),
                    MissionSeed("原作不存在", "两名抄录傀儡与拼接替身试图证明原作从未存在。", "矛盾证词。"),
                    MissionSeed("拒绝归位", "精英空壳守卫押送拼接替身回到原位。", "盟友支援。", kind: .elite),
                    MissionSeed("逃出演区", "失名猎犬与两名拼接替身封锁逃生路线。", "逃生路线。"),
                    MissionSeed("最后一次排演", "抄录傀儡与寄忆核心准备最后一次排演。", "首领线索。"),
                    MissionSeed("总排演室", "精英拼接替身与抄录傀儡守住中央排演室。", "首领前哨。", kind: .elite),
                    MissionSeed("替身拒演", "击败总排演官，让拒演者保留不再扮演原主的权利。", "身份演证·拒演面具。", kind: .boss)
                ],
                expedition: ExpeditionDefinition(
                    id: "mirror-theater-echo",
                    title: "镜剧院·潮汐回声",
                    city: "镜剧区",
                    estimatedMinutes: 16,
                    objective: "六人分别面对自己的镜像，破坏三面锚镜并救出被替换的观众。",
                    storyReason: "团队必须同时击败六条路径的倒影；该副本不要求固定队伍或公会。"
                )
            ),
            DistrictBlueprint(
                id: "tide-gate",
                name: "潮门港·死者归航",
                subtitle: "第四地图 · 完成镜剧区后开放",
                symbol: "water.waves",
                story: "一艘多年前沉没的船重新靠岸。船员肉体早已死亡，但船内保存着他们死亡前的完整记忆。",
                question: "死者留下的完整记忆，算不算仍然活着？",
                bossName: "归航船心",
                proofName: "延续演证·末航日志",
                missions: [
                    MissionSeed("死者靠岸", "第一名溺忆水手从沉船靠岸，仍记得自己死亡前的钥匙。", "港口材料。"),
                    MissionSeed("他记得钥匙", "两名溺忆水手寻找同一把不存在的钥匙。", "潮雾材料。"),
                    MissionSeed("锚链", "锚链卫士保护溺忆水手，先拆掉前排保护。", "锚链碎片。"),
                    MissionSeed("死亡记录", "寄忆核心与溺忆水手争夺死亡记录。", "死亡记录。"),
                    MissionSeed("第二次回家", "失名猎犬与锚链卫士封锁回家航线；获得技能「后手改写」。", "获得技能「后手改写」。"),
                    MissionSeed("没有心跳", "两名溺忆水手没有心跳，却仍会对伤害作出反应。", "持久战材料。"),
                    MissionSeed("归航名单", "空壳守卫把归航名单交给议会，溺忆水手被标记为错误。", "归航名单。"),
                    MissionSeed("死亡前一分钟", "精英溺忆水手重复死亡前一分钟的动作。", "高吸血材料。", kind: .elite),
                    MissionSeed("不愿回家的人", "锚链卫士与寄忆核心试图把一名死者拖回原航线。", "剧情证词。"),
                    MissionSeed("归航者营地", "两名溺忆水手和锚链卫士守住归航营地；本区团队副本开放。", "开放深潮闸心。"),
                    MissionSeed("海上回收队", "失名猎犬与空壳守卫回收死者记忆。", "回收材料。"),
                    MissionSeed("第二份死亡证明", "寄忆核心与锚链卫士出示第二份死亡证明。", "死亡证明。"),
                    MissionSeed("船底声音", "两名溺忆水手与寄忆核心从船底传出同一段声音。", "船底残响。"),
                    MissionSeed("不肯消失", "精英溺忆水手拒绝从名单上消失。", "残响印记。", kind: .elite),
                    MissionSeed("我已经死过", "三名溺忆水手各自记得不同的死亡。", "剧情选择。"),
                    MissionSeed("封港命令", "两名空壳守卫与锚链卫士执行封港命令。", "封港凭证。"),
                    MissionSeed("船心供能", "两名寄忆核心为船心持续供能。", "船心线索。"),
                    MissionSeed("返航失败", "狂暴失名猎犬与溺忆水手阻止船只返航。", "狂暴冥火。"),
                    MissionSeed("最后一批归航者", "精英空壳守卫与溺忆水手守住最后一批归航者。", "首领前哨。", kind: .elite),
                    MissionSeed("死者归航", "击败归航船心，决定完整记忆是否足以让死者继续活着。", "延续演证·末航日志；归航盐片。", kind: .boss)
                ],
                expedition: ExpeditionDefinition(
                    id: "deep-tide-gate",
                    title: "深潮闸心",
                    city: "潮门港",
                    estimatedMinutes: 18,
                    objective: "分组三路维持闸压，在水位淹没战场前关闭深潮裂口。",
                    storyReason: "闸心需要多人同时操作，但可由 AI 潮汐化身补齐空位。"
                )
            ),
            DistrictBlueprint(
                id: "mist-crown",
                name: "雾岬上城·不存在的灾难",
                subtitle: "第五地图 · 完成潮门港后开放",
                symbol: "building.columns.fill",
                story: "上城官方记录否认前四区发生过任何灾难，并把证人标记为记忆污染者，准备以公共档案反向覆盖全城记忆。",
                question: "如果官方记录说灾难从未发生，灾难是否就不存在？",
                bossName: "瑟维安 + 归一档案库",
                proofName: "历史演证·未删原卷",
                missions: [
                    MissionSeed("一切正常", "公共记录员用单一版本解释上城的一切。", "上城材料。"),
                    MissionSeed("没有灾难", "删改官与公共记录员否认三年前的灾难。", "删改记录。"),
                    MissionSeed("无效证据", "空壳守卫与删改官宣布所有证据无效。", "议会凭证。"),
                    MissionSeed("玛拉不存在", "两名删改官从档案中抹去玛拉。", "玛拉证词。"),
                    MissionSeed("死亡证明", "失名猎犬与公共记录员共同确认主角的死亡证明。", "主角档案。"),
                    MissionSeed("伪造照片", "寄忆核心与删改官伪造四区的照片。", "照片底片。"),
                    MissionSeed("三年前的今天", "空壳守卫与公共记录员复演灾难发生前的日期。", "日期记录。"),
                    MissionSeed("被删除的街道", "两名空壳守卫与删改官封锁一条不存在的街道。", "街道残图。"),
                    MissionSeed("无人死亡", "两名公共记录员把四区死者改成无人死亡。", "公开证词。"),
                    MissionSeed("正确版本", "空壳守卫、寄忆核心与公共记录员完成正确版本；本区团队副本开放。", "开放雾冠议厅。"),
                    MissionSeed("Z-0档案", "精英删改官守住零号档案。", "零号档案。", kind: .elite),
                    MissionSeed("第一份记录", "公共记录员与寄忆核心共同提交第一份记录。", "Boss 背景。"),
                    MissionSeed("瑟维安", "精英空壳守卫执行瑟维安的旧命令。", "瑟维安历史。", kind: .elite),
                    MissionSeed("被保存的人", "失名猎犬与删改官追捕一名被保存的人。", "开场回扣。"),
                    MissionSeed("唯一身份", "两名空壳守卫与公共记录员要求全城只承认一个身份。", "身份标签。"),
                    MissionSeed("删除命令", "精英删改官与寄忆核心执行删除命令。", "删除封签。", kind: .elite),
                    MissionSeed("玛拉的五份档案", "两名公共记录员分别保存五个互相冲突的玛拉。", "玛拉伏笔。"),
                    MissionSeed("归一启动", "两名寄忆核心与空壳守卫启动归一档案库。", "Boss 线索。"),
                    MissionSeed("最后一份异议", "精英空壳守卫与删改官守住最后一份异议。", "首领前哨。", kind: .elite),
                    MissionSeed("不存在的灾难", "击败瑟维安与归一档案库，并决定是否保留所有互相冲突的记忆。", "历史演证·未删原卷；晋升序列8。", kind: .boss)
                ],
                expedition: ExpeditionDefinition(
                    id: "mist-crown-council",
                    title: "雾冠议厅",
                    city: "雾岬上城",
                    estimatedMinutes: 20,
                    objective: "六条路径分别解除一项议会权柄，最终共同击败雾冠执政官。",
                    storyReason: "这是第一章唯一的终区团队副本，但区域通关仍可由单人任务完成。"
                )
            )
        ]

        return blueprints.enumerated().map { districtOffset, blueprint in
            ChapterDistrict(
                id: blueprint.id,
                order: districtOffset + 1,
                name: blueprint.name,
                subtitle: blueprint.subtitle,
                symbol: blueprint.symbol,
                theme: blueprint.story,
                question: blueprint.question,
                bossName: blueprint.bossName,
                proofName: blueprint.proofName,
                missions: makeDistrictMissions(blueprint: blueprint, districtOffset: districtOffset),
                teamExpedition: blueprint.expedition
            )
        }
    }()

    private static func makeDistrictMissions(
        blueprint: DistrictBlueprint,
        districtOffset: Int
    ) -> [DistrictMission] {
        precondition(blueprint.missions.count == (blueprint.id == "old-clock" ? 30 : 20), "Mission count must match the authored district")
        return blueprint.missions.enumerated().map { offset, seed in
            let number = offset + 1
            let globalOrder = districtOffset * 20 + number
            return DistrictMission(
                id: "\(blueprint.id)-\(number)",
                districtID: blueprint.id,
                districtName: blueprint.name,
                number: number,
                globalOrder: globalOrder,
                title: blueprint.id == "old-clock" ? (MPCChapterOneCatalog.mission(forOldClockMissionNumber: number)?.name ?? seed.title) : seed.title,
                objective: blueprint.id == "old-clock" ? (MPCChapterOneCatalog.mission(forOldClockMissionNumber: number)?.storyText ?? seed.objective) : seed.objective,
                rewardText: seed.reward,
                recommendedPower: 100 + (globalOrder - 1) * 25,
                reputationReward: ChapterDistrict.reputationPerMission,
                kind: seed.kind
            )
        }
    }
}
