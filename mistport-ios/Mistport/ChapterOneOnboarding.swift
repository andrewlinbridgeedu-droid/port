import SwiftUI
import UIKit
import Vision
import CoreImage

private struct ChapterOneTutorialPage {
    let kicker: String
    let message: String
    let actionTitle: String

    /// Dialogue is authored as story beats, but the bubble is a fixed game UI
    /// surface. Split long beats into smaller display pages instead of letting
    /// their text resize the bubble.
    func paginated(maximumCharacters: Int = 54) -> [ChapterOneTutorialPage] {
        let paragraphs = message
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !paragraphs.isEmpty else { return [self] }

        var chunks: [String] = []
        var current = ""

        for paragraph in paragraphs.flatMap({ Self.split($0, limit: maximumCharacters) }) {
            let candidate = current.isEmpty ? paragraph : "\(current)\n\(paragraph)"
            if !current.isEmpty, candidate.count > maximumCharacters {
                chunks.append(current)
                current = paragraph
            } else {
                current = candidate
            }
        }

        if !current.isEmpty {
            chunks.append(current)
        }

        return chunks.enumerated().map { index, chunk in
            ChapterOneTutorialPage(
                kicker: kicker,
                message: chunk,
                actionTitle: index == chunks.count - 1 ? actionTitle : "下一页"
            )
        }
    }

    private static func split(_ text: String, limit: Int) -> [String] {
        guard text.count > limit else { return [text] }

        let preferredBreaks = CharacterSet(charactersIn: "。！？；……，、")
        var result: [String] = []
        var remainder = text[...]

        while remainder.count > limit {
            let proposedEnd = remainder.index(remainder.startIndex, offsetBy: limit)
            let proposed = remainder[..<proposedEnd]
            let breakIndex = proposed.indices.reversed().first { index in
                String(proposed[index]).rangeOfCharacter(from: preferredBreaks) != nil
            }
            var end = breakIndex.map { remainder.index(after: $0) } ?? proposedEnd
            // Keep closing quotes with their sentence; a lone ” used to open
            // the next page (playtest 2026-10-04, Q4 aftermath).
            while end < remainder.endIndex, "”’」』）》".contains(remainder[end]) {
                end = remainder.index(after: end)
            }
            result.append(String(remainder[..<end]).trimmingCharacters(in: .whitespacesAndNewlines))
            remainder = remainder[end...].drop { $0.isWhitespace }
        }

        if !remainder.isEmpty {
            result.append(String(remainder).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return result
    }
}

enum ChapterOneTutorialCue: String {
    case opening
    case cityMission
    case mapEntry
    case firstBattle
    case rainFirstAftermath
    case secondBattle
    case fogGhostPrelude
    case houndPrelude
    case rainInterlude
    case q3Aftermath
    case q4Aftermath
    case q5PaperDoubleIntervention
    case q9Prelude, q10Prelude, q9Aftermath, q10Aftermath
    case q5Delivery, q6Prelude, q7Prelude, q8Prelude, q5Aftermath, q6Aftermath, q7Aftermath, q8Aftermath
    case q11Prelude, q12Prelude, q13Prelude, q14Prelude, q15Prelude, q16Prelude, q17Prelude, q18Prelude, q19Prelude, q20Prelude
    case q11Aftermath, q12Aftermath, q13Aftermath, q14Aftermath, q15Aftermath, q16Aftermath, q17Aftermath, q18Aftermath, q19Aftermath, q20Aftermath

    case q21Prelude, q21Aftermath, q22Prelude, q22Aftermath, q23Prelude, q23Aftermath, q24Prelude, q24Aftermath, q25Prelude, q25Aftermath, q26Prelude, q26Aftermath, q27Prelude, q27Aftermath, q28Prelude, q28Aftermath, q29Prelude, q29Aftermath, q30Prelude, q30Aftermath

    var persistenceKey: String {
        if self == .q5Delivery { return "chapter-one.tutorial.q5EncoreDelivery" }
        return "chapter-one.tutorial.\(rawValue)"
    }

    var message: String {
        switch self {
        case .q30Aftermath:
            "瑟维安的本体倒下，私印失效。这一次，他再也没有退路。\n伊恩回到诊所，给奥黛尔倒了一杯热茶。洛克安置获救居民，维娅提交证词、接受审理。\n更早的外部追索却开始收紧。赫斯只维持住一条通往黑盐岸的单向航线，你不得不离开雾港。\n玛拉把原档递还给你：“至少下一次，别让别人替你签。”"
        case .q30Prelude:
            "替代封口已经稳定，外接供能与钟环储备都不再回应。瑟维安仍握着私印：“没有主人，你们以为自己是谁？”\n这一次，没有召回，也没有可借的身体。"
        case .q29Aftermath:
            "第五次完整行动耗尽钟环储备，瑟维安以一次性归庭印退回总册。你随后清除了留下的执行者与守卫。\n他的退路已用完，但本体仍在。只有追入总册，才能结束这份私有授权。"
        case .q29Prelude:
            "新一台执行者与空壳守卫站到瑟维安两侧。它不是你在自动补位处摧毁的那台。\n钟环五格储备逐一燃起。瑟维安要用最后的代签，为自己留下归庭的出口。"
        case .q28Aftermath:
            "第五次行动落定，你仍站着。五盏灯同时亮起，伊莱娅切断全部外接供能。\n瑟维安没有死。他抬起仍亮着五格储备的钟环，退入签发廊：“我还有自己的余款。”"
        case .q28Prelude:
            "瑟维安独自站在回流中央，铜手合上档案书：“你拿到了纸，就以为能离开名字？”\n远处灯火不动。伊莱娅在等五次完整回流，不会替你接下尚未落定的一击。"
        case .q27Aftermath:
            "原档里的名字，是你入港时自己报出的。外部追索却比入港更早，瑟维安并没有创造那段过去。\n封存交易存根指向“第七住客”，那个人的名字仍被遮住。你拿起原档，走向五路回流的中央。"
        case .q27Prelude:
            "档案守卫与守备犬挡住原始档案库。库内保存着最早的归属记录，也保存着尚未签署的一栏。\n你想知道，究竟是谁先写下你的名字。"
        case .q26Aftermath:
            "押运锤卫永久停机，最后一趟车被截住。总签钥与末班运输记录留在断链旁。\n它不会再护着另一趟车回来。原始档案库终于露出了入口。"
        case .q26Prelude:
            "护送余车撤走的同一具锤卫，守在最后一趟押运前。车链仍给它输送力量。\n先打断900点车链供能，再击败锤卫。结算的『对敌伤害』只统计锤卫本体。"
        case .q25Aftermath:
            "最后一处根结解除，维娅活着走出归属网。她重新作证，也接受接下来的审理。\n她不会再成为敌人。肯断线并不抹去此前主动补位的责任。"
        case .q25Prelude:
            "维娅清醒地把手从红线上移开：“这一次，是我自己同意。”\n目标是拆除1800点根结，不是击杀维娅；等她恢复或校准时攻击，才能推进拆线。她会活着离场。"
        case .q24Aftermath:
            "你找到了真正的伊恩。他认得杯子的缺角，也能说出诊所热茶的味道。\n他交出黑盐岸检疫路线，却仍能感觉到根授权的牵引。人救出来了，追索还没解除。"
        case .q24Prelude:
            "守备犬堵住地下泊位，认领失败的幽灵徘徊在闸口。幽灵的形体裂开时，里面还有两道赤红的怨影。\n船舱内有人问：“奥黛尔还留着那只缺角的杯子吗？”"
        case .q23Aftermath:
            "非人名封口通过验证，市政主锚完好。\n伊莱娅：“替代办法能用。瑟维安每完成一次行动，才会显出一条真正回路。五次都看清，我才能同时切源。”地下泊位还有人等待离开。"
        case .q23Prelude:
            "替代材料进入独立验证，裁定守备却仍按旧许可封锁主锚。\n守灯天使伊莱娅在灯后等候：“保住锚。我要看清五路回流，才动那五根线。”"
        case .q22Aftermath:
            "你制止了越权补位，没有杀死维娅。她的主动操作和监管续押都被写入记录。\n玛拉：“想让他们有家，不能拿另一个人去填。”监管继续，你们需要不以人名封口的办法。"
        case .q22Prelude:
            "监管织室开放复核接口。维娅主动把一个陌生名字填进补位栏，红线随即绷紧。\n维娅：“只缺这一个。他们就能继续住下去。”这一次，没有人替她做选择。"
        case .q21Aftermath:
            "转接核心破碎，个人根输入被拆除。洛克终于能说完整句话：“安置完成后，被救者可以自行离开。”\n他留下救援条款，转身去安置居民。他的救援还没有结束，却不再由别人遥控。"
        case .q21Prelude:
            "洛克胸前的根输入再次收紧，独立转接核心正在覆盖他的声音。\n洛克：“原来的条款……不是不许走。”先断转接，再解除背架控制。"
        case .q9Prelude:
            "寻人证词正在被书记员改写。“伊恩没有回来”，被一笔笔覆盖成“本人因误会重复报案”。\n书记员守着原件，寄忆核心继续写入。先处理持续覆盖证词的核心；这一关仍只有两格。"
        case .q10Prelude:
            "名单上的许多地址根本不存在。翻到下一页，你看见自己的名字，也被填进一户所谓“自己的家”。\n档案守卫与另一只猎犬守住名单；它不是追过你的旧犬。可带上伪证烙印，让后续伤害利用标记；通关后才开放四格。"
        case .q9Aftermath:
            "你取回原件。奥黛尔报的是失踪，留下的记录却让她成了因误会反复报案的人。\n玛拉将两份证词的矛盾封成『伪证烙印』：先留下标记，再接伤害技能。普通技能槽仍为两格；角色页开放四点天赋。\n证词背面压着失踪者名单。去找这些记录被送往了哪里。"
        case .q10Aftermath:
            "你保住了名单。那户人家的地址没有被划掉，记录坚持那里就是你的归属。\n你学会追索被覆盖的残影：『双影追猎』。普通技能槽扩为四格。\n去看看是谁在家里等你，又是谁替你编好了这段生活。"
        case .q11Prelude:
            "门里的人叫着你的名字，自称你的家人。他们指着桌上的杯子：“这是你小时候一直用的。”\n两只记忆蛭轮流维持共同记忆，守卫守住门。杯沿那个缺角，让你想起刚去过的诊所。"
        case .q12Prelude:
            "调拨处正在把新的陌生人补进空缺。两名书记员交替封存、校正与重击，校正会抹去你的护盾。\n玛拉：“先停下这份调拨。我有一件事，必须亲口告诉你。”"
        case .q13Prelude:
            "洛克背着救援架，仍在重复救人的动作。寄忆核心却把被困者标成待搬走的货物，让他的双手一次次伸向错误的人。\n玛拉：“他还活着。打断这里的控制，别让他继续把人送进去。”"
        case .q14Prelude:
            "伊恩的名牌就在箱里，背后牵着一根红线。记忆蛭吞读名字，书记员把每次挣扎校正成自愿认领。\n每个目标的误认与错位分别保存。先决定要控制谁，再把后续牌接到同一个目标上。"
        case .q15Prelude:
            "维娅挡在归属网前。她知道那些家庭是假的，却坚持网一断，里面的人就会再次失去彼此。\n两枚寄忆核心轮流把受损记录写回，红线缠在她的支架上。先切断支援，控制住她，查明网后面还连着谁。"
        case .q16Prelude:
            "旧猎犬第三次挡住出口。项圈上还是同一个追索编号，召回声却不再响起。\n玛拉：“它接到了销号命令。这一次，没有人为它留下退路。”"
        case .q17Prelude:
            "机械笔臂正在补齐被截断的签发手续。一张被抽走的纸，立刻被另一张替上。\n玛拉：“别只追那枚章。看看是谁一直给它送纸。”"
        case .q18Prelude:
            "裁定卫举起一份早已失效的许可，仍坚持不让任何人查询市政主锚。\n纸上的日期没有变，门后的命令也没有停。"
        case .q19Prelude:
            "盐栈床位、押运时刻与收件印终于对上。翠焰执役者守着这份记录，火光照出了床位上尚未擦去的人名。\n外海要接收的，从来不是死档案。"
        case .q20Prelude:
            "押运匣内传来敲击。锤卫守着车链，余车正驶向另一条岔路。\n目标是解除1600点拘束、救出车里的人，不必击杀锤卫。它恢复或校准时攻击，才能推进拘束解除。"
        case .q11Aftermath:
            "杯底是诊所药柜的编号。你刚刚才在奥黛尔那里见过它，却被说成了从小使用的杯子。\n这份家庭记忆取用了你近期见过的东西，再把它缝进不存在的童年。你没有忘记自己的家，是有人正在替你造一个。\n你从矛盾中习得『荒谬归结』。玛拉看着家庭回执，终于不再回避你的目光。"
        case .q12Aftermath:
            "玛拉：“我签过一张临时救援回执。我以为先让人有地方住，之后还能把名字改回来。”\n“后来才知道，一处归属空了，就要再找一个人补上。我一直没敢承认，那里面也有我的签名。”\n你习得『反客为主』，可在下一战手动编入序列。回执附着救援录音，调拨正在把被困者送往排渠。"
        case .q13Aftermath:
            "核心停止写入，洛克跪倒在救援架旁，终于说出被困者的位置。你留下他的性命，切断了本地的搬运命令。\n他胸前还有一根细线在抽紧：控制的根仍在别处。你从两份命令的回声中习得终极技能『无名宣告』，每场战斗可手动释放一次。\n洛克指向名牌箱：“他们把人的名字放在那里。”"
        case .q14Aftermath:
            "你取出伊恩的名牌，红线却没有断。它穿过排渠，连向那些亮着灯的假家庭。\n玛拉：“拔掉一块牌，只会让他们再补一个人。我们得找到织网的人。”\n顺着红线，你听见一个女人叫人关好家门。"
        case .q15Aftermath:
            "维娅被制住，仍请求你不要立刻扯断整张网。她保护的假家庭里，也有不愿再孤身一人的活人。\n玛拉留下证词，将她交付看管。归属网还没有解除，伊恩也尚未获救；线的另一头有人准备封死出口。\n先返回主城整理物证。后续调查将在对应关卡开放后继续。"
        case .q16Aftermath:
            "旧猎犬倒下，销号项圈不再发亮。这条从街口追来的犬不会再出现。\n项圈外侧的外海编号仍然有效：执行者死了，委托却没有撤销。"
        case .q17Aftermath:
            "这台执行者停止了。你取下自动补位目录和五路供能图，发现总签官的钟环另藏五格储备。\n签发能被截停，私印却仍握在主人手里。"
        case .q18Aftermath:
            "裁定卫倒下，失效许可与五锚回流图被完整保住。\n玛拉：“供能是一回事，准许他继续用，又是另一回事。”市政封口仍在运行，不必拿活人去堵。"
        case .q19Aftermath:
            "翠焰熄灭，你拿到盐栈床位表与外海收件凭据。\n雨烬馆的赫斯沿你查明的路线切断战后追踪：“路是你们找的。我只替你们关一扇门。”下一批押运已经出发。"
        case .q20Aftermath:
            "拘束解除，被押的人离开了车厢。锤卫护着余车撤退；它还活着。\n你记录下截运批次和余车路线。获救者记得一个背着救援架的人，他曾告诉他们：安置完成就可以离开。"
        case .q5Delivery:
            "诊所寄出的寻人信，全被盖成“已送达”退了回来。旧邮务间的翠焰亡灵仍在重复最后一次投递。\n毒雾会不断加浓，直到战斗结束。它全身燃起绿焰时，重击就要来了。选好主动遗落物，再进去取回真实的回执。"
        case .q6Prelude:
            "档案门卫拒绝寻人申请：“无监护人资格，不得查询已认领者。”\n玛拉：“伊恩不是谁的所有物。”门卫只抬起盾，重复同一句规定。\n封存时装甲严丝合缝，出击后才需要重新对齐。抓住收盾后的空隙。"
        case .q7Prelude:
            "补录处的两具空壳守卫共用一份指令，后方寄忆核心不断修复它们。\n台上露出伊恩的领药号，正要被覆盖成另一个人的编号。必须停下写入，保住这条属于诊所的线索。"
        case .q8Prelude:
            "记忆蛭张开口器，一段你刚经历过的片段被扯出：诊所的桌面，还有那只缺角茶杯。\n玛拉错开牌上重叠的名字：“让错误彼此争抢，它就会迟疑。”\n你习得『张冠李戴』：误认不足四层时仍会造成伤害并增加一层；满四层再释放，才会转成错位、延迟目标行动。战斗按点击的编排顺序自动出牌。"
        case .q5Aftermath:
            "翠焰亡灵退入雨幕，毒雾散去。柜台下压着一批根本没有送出的寻人信，却封着同样的“已送达”印记。\n伊恩的回执也在里面，去向写着档案街监护登记处。玛拉收好原件：“有人替收件人作了答复。”"
        case .q6Aftermath:
            "门卫停下，查询口终于打开。所谓监护资格，竟只需要一张登记认可的认领回执。\n回执没有伊恩的签名，却已经替他指定了归属。去补录台找最早的记录。"
        case .q7Aftermath:
            "核心熄灭，修复停止。空白身份牌背面保留着伊恩的领药号，证明他曾以自己的身份来过诊所。\n你收好身份牌作为物证。台下的记忆蛭却开始念另一个名字，试图替这份记录作答。"
        case .q8Aftermath:
            "记忆蛭松开口器。它抽取的是你刚在诊所看过的茶杯，并非什么久远的过去。\n留下的记忆丝连着一份寻人证词。玛拉：“先去找原件。别让它们替我们留下答案。”"
        case .opening:
            "先别追问这里属于谁的梦。三条途径在雾港留下了回声。\n此刻，只有愚者的道路向你敞开。"
        case .cityMission:
            "欢迎来到雾港。旧城区有一份委托正在等你。\n先处理那里，其余地区暂时与你无关。"
        case .mapEntry:
            "从紫藤街口进去。现在能够通行的路只有这一条。"
        case .firstBattle:
            "第三次了。你留下的伤口正在按某种记录复原。\n不是你没有击中，也不是它无法被杀死——有人不允许它在这里倒下。\n玛拉交给你『错步穿行』。教学战会从头重开；请手动点这张牌，重新编排后再开始。"
        case .rainFirstAftermath:
            "你记得自己的名字。空壳守卫却坚持记录上写着“已认领”，不许你自行离开。\n契约完成，『错步穿行』属于你。目前只能装备这一张技能牌。玛拉递来临时通行证和一罐止痛膏：“先活着走出这条街，再问是谁替你签了字。”"
        case .fogGhostPrelude:
            "两道幽灵守着被退回的寻人信，不肯离开。\n信页翻动时，一个声音反复说：“别送我回家。”"
        case .houndPrelude:
            "寻人信上的追索记录惊动了猎犬。它从雾里走来，径直盯住你。"
        case .secondBattle:
            "猎犬喉间两团火一起亮起时，使用遗落物『无主假面』，让幻影接住两发追索火球。\n它认错名字后的三秒，就是反击的机会。假面不占技能编排，每隔十八秒可以再次手动使用，幻影只维持四秒。"
        case .rainInterlude:
            "残影平息，被退回的寻人信落在地上。纸上仍留下那句请求：“别送我回家。”\n玛拉收好信：“旧邮务间应该能查到它为什么被退回。”雾里响起犬吠，追索者已经找来了。"
        case .q3Aftermath:
            "猎犬退入雾里，留下刻有外部编号的项圈碎片。那不是街口守卫使用的格式，来源还不能确定。\n你收好碎片与它撞落的迟秒怀表，作为调查物证。"
        case .q4Aftermath:
            "召回信号响起，旧犬停止追索，撤入雾里。玛拉带你去诊所，奥黛尔将一枚旧铜勋章交给你。\n“僭命勋章。借你八秒强盛，期限一到，收走你尚存生命的一半。它不会替你挡毒与刀。上路前，在它与假面之间选一个。”\n桌上留着一只缺角茶杯，茶已经凉了。奥黛尔：“伊恩去送药，一直没回来。他每次回来，都嫌我留的茶凉。”\n她没有倒掉冷茶，只把被退回的寻人信交给你。信上竟写着“已送达”。去旧邮务间查清这份答复。"
        case .q5PaperDoubleIntervention:
            "看它身上的绿焰。\n那是重击将至的信号。\n现在手动使用『无主假面』，让幻影接下这一击。\n毒雾仍会加浓，必须尽快结束战斗。"
        }
    }

    var kicker: String {
        switch self {
        case .q30Aftermath: "无主者的签名 · 事后"
        case .q30Prelude: "无主者的签名"
        case .q29Aftermath: "最后的代签 · 事后"
        case .q29Prelude: "最后的代签"
        case .q28Aftermath: "五次回流 · 事后"
        case .q28Prelude: "五次回流"
        case .q27Aftermath: "未签署的归属 · 事后"
        case .q27Prelude: "未签署的归属"
        case .q26Aftermath: "最后一趟押运 · 事后"
        case .q26Prelude: "最后一趟押运"
        case .q25Aftermath: "自愿断线 · 事后"
        case .q25Prelude: "自愿断线"
        case .q24Aftermath: "地下泊位 · 事后"
        case .q24Prelude: "地下泊位"
        case .q23Aftermath: "不以人名封口 · 事后"
        case .q23Prelude: "不以人名封口"
        case .q22Aftermath: "不属于你的庇护 · 事后"
        case .q22Prelude: "不属于你的庇护"
        case .q21Aftermath: "原始救援条款 · 事后"
        case .q21Prelude: "原始救援条款"
        case .q5Delivery: "旧邮务间 · 不肯落幕"
        case .q6Prelude: "档案街入口 · 监护资格"
        case .q9Prelude: "工坊 · 证词覆写"
        case .q10Prelude: "失踪名单 · 虚假的地址"
        case .q9Aftermath: "证词取回 · 伪证烙印"
        case .q10Aftermath: "残影追索 · 四格编排"
        case .q11Prelude: "假家庭 · 借来的日常"
        case .q12Prelude: "调拨处 · 空缺补位"
        case .q13Prelude: "洛克 · 被篡改的救援"
        case .q14Prelude: "伊恩的名牌 · 红线"
        case .q15Prelude: "维娅 · 归属网"
        case .q16Prelude: "销号追索"
        case .q17Prelude: "自动补位"
        case .q18Prelude: "无效的许可"
        case .q19Prelude: "外海收件人"
        case .q20Prelude: "押运中的活档案"
        case .q11Aftermath: "杯底编号 · 假家的破绽"
        case .q12Aftermath: "玛拉的回执 · 补位规则"
        case .q13Aftermath: "本地控制解除 · 根仍在"
        case .q14Aftermath: "名牌取回 · 红线未断"
        case .q15Aftermath: "维娅被拘 · 网未解除"
        case .q16Aftermath: "销号追索 · 事后"
        case .q17Aftermath: "自动补位 · 事后"
        case .q18Aftermath: "无效的许可 · 事后"
        case .q19Aftermath: "外海收件人 · 事后"
        case .q20Aftermath: "押运中的活档案 · 事后"
        case .q7Prelude: "补录处 · 寄忆核心"
        case .q8Prelude: "不属于我的名字 · 张冠李戴"
        case .q5Aftermath: "虚假签收 · 档案街回执"
        case .q6Aftermath: "监护登记 · 没有本人签名"
        case .q7Aftermath: "调查物证 · 空白身份牌"
        case .q8Aftermath: "茶杯里的近期记忆"
        case .opening: "静幕引路人"
        case .cityMission: "第一项委托"
        case .mapEntry: "跟随指引"
        case .firstBattle: "第一场战斗 · 雨中的空壳"
        case .rainFirstAftermath: "契约成立 · 第一张牌"
        case .fogGhostPrelude: "雾都幽灵 · 退回的寻人信"
        case .houndPrelude: "循名而来的猎犬"
        case .secondBattle: "假面与追索之火"
        case .rainInterlude: "第二关 · 契约确认"
        case .q3Aftermath: "项圈上的外部编号"
        case .q4Aftermath: "诊所 · 缺角的茶杯"
        case .q5PaperDoubleIntervention: "第五关 · 不肯落幕"
        }
    }

    var actionTitle: String {
        switch self {
        case .q21Prelude, .q22Prelude, .q23Prelude, .q24Prelude, .q25Prelude, .q26Prelude, .q27Prelude, .q28Prelude, .q29Prelude, .q30Prelude: "编排技能"
        case .q21Aftermath, .q22Aftermath, .q23Aftermath, .q24Aftermath, .q25Aftermath, .q26Aftermath, .q27Aftermath, .q28Aftermath, .q29Aftermath: "返回主城"
        case .q30Aftermath: "告别雾港"
        case .q5Delivery: "准备迎战"
        case .q9Prelude, .q10Prelude, .q6Prelude, .q7Prelude, .q8Prelude: "编排技能"
        case .q9Aftermath, .q10Aftermath, .q5Aftermath, .q6Aftermath, .q7Aftermath, .q8Aftermath: "返回主城"
        case .q11Prelude, .q12Prelude, .q13Prelude, .q14Prelude, .q15Prelude, .q16Prelude, .q17Prelude, .q18Prelude, .q19Prelude, .q20Prelude: "编排技能"
        case .q11Aftermath, .q12Aftermath, .q13Aftermath, .q14Aftermath, .q15Aftermath, .q16Aftermath, .q17Aftermath, .q18Aftermath, .q19Aftermath, .q20Aftermath: "返回主城"
        case .opening: "继续选择"
        case .cityMission: "前往旧城区"
        case .mapEntry: "进入紫藤街口"
        case .rainFirstAftermath: "确认契约"
        case .rainInterlude: "继续调查"
        case .q3Aftermath, .q4Aftermath: "前往下一站"
        case .fogGhostPrelude, .houndPrelude: "准备迎战"
        case .firstBattle, .secondBattle: "明白了"
        case .q5PaperDoubleIntervention: "留意绿焰"
        }
    }

    fileprivate var pages: [ChapterOneTutorialPage] {
        if self == .q30Aftermath {
            let paragraphs = message.components(separatedBy: "\n")
            return paragraphs.enumerated().map { index, paragraph in
                .init(kicker: kicker, message: paragraph,
                      actionTitle: index == paragraphs.count - 1 ? actionTitle : "继续聆听")
            }
        }
        if self == .q3Aftermath {
            return [
                .init(kicker: "项圈上的外部编号", message: "猎犬退入雾里，留下带有外部编号的项圈碎片。编号的来源还不能确定。\n收好碎片与它撞落的迟秒怀表，作为调查物证。", actionTitle: "前往下一站")
            ]
        }
        if self == .houndPrelude {
            return [
                .init(kicker: "循名而来的猎犬", message: "寻人信上的追索记录惊动了猎犬。\n它从雾里走来，径直盯住你。", actionTitle: "继续聆听"),
                .init(kicker: "玛拉的赠予", message: "玛拉从衣袋里取出一张旧假面，递到你手中。\n“这件遗落物叫『无主假面』。让追猎者相信，站在你身旁的幻影才是真正的你。”", actionTitle: "接过无主假面"),
                .init(kicker: "以假乱真", message: "假面不需要编入技能。开战后，由你点击使用。\n它唤出的幻影只维持四秒，最多承受两次直接攻击；十八秒后才能再次使用，持续伤害无法阻挡。眼前两场猎犬教学不损耗假面。之后每次使用都会留一道永久紫裂纹，十道后失效。\n猎犬喉间两团火一起亮起，就是它要扑来的信号——立刻点假面。", actionTitle: "继续聆听"),
                .init(kicker: "烧不掉的记录", message: "打断它的追猎，留下项圈。\n我想知道，究竟是谁命令它来找你。", actionTitle: "准备迎战")
            ]
        }
        if self == .fogGhostPrelude {
            return [
                .init(kicker: "退回的寻人信", message: "两道幽灵守着一叠寻人信。\n它们一次次送出，又一次次被退回来。", actionTitle: "继续聆听"),
                .init(kicker: "不愿回家的人", message: "纸页间传来同一句话：“别送我回家。”\n玛拉伸手按住信页：“先把信留下。我们还不知道，它们怕的究竟是什么。”", actionTitle: "继续聆听"),
                .init(kicker: "雾都幽灵", message: "怨影被打散后，还会各分成两道赤红残影，攻势会更快。\n平息它们，再查清这批寻人信。", actionTitle: "准备迎战")
            ]
        }
        if case .firstBattle = self {
            return [
                .init(
                    kicker: "第三次命中",
                    message: "第三次了。你留下的伤口正在随钟声复原。\n不是你没有击中，也不是它无法被杀死——\n有人不允许它在这里倒下。",
                    actionTitle: "继续"
                ),
                .init(
                    kicker: "玛拉",
                    message: "至于我，你可以叫我玛拉。\n你记得自己的名字；有问题的是它那份“已认领”的记录。\n接住这张牌，试着从它认定安全的位置穿过去。",
                    actionTitle: "接过卡牌"
                ),
                .init(
                    kicker: "错步穿行",
                    message: "不要继续攻击盔甲表面。\n那只是它希望你看见的防御。\n使用这张牌，攻击偏离的位置。",
                    actionTitle: "使用错步穿行"
                )
            ]
        }
        guard self == .opening else {
            return [.init(kicker: kicker, message: message, actionTitle: actionTitle)]
        }
        return [
            .init(
                kicker: "途径选择",
                message: "先别追问这里属于谁的梦。三条途径在雾港留下了回声。\n此刻，只有愚者的道路向你敞开。",
                actionTitle: "继续聆听"
            ),
            .init(
                kicker: "愚者",
                message: "愚者利用错误掩盖真实，在对手发现伤口之前制造破绽。\n选择这条途径之后，你需要记住一件事——谎言用得越久，\n就越容易忘记自己原本是谁。",
                actionTitle: "继续聆听"
            ),
            .init(
                kicker: "祭司",
                message: "祭司行走于梦境与沉默之间，寻找那些被人遗忘的名字。\n她能够听见常人无法察觉的声音，但听得太多，\n也可能分不清哪些记忆属于自己。",
                actionTitle: "继续聆听"
            ),
            .init(
                kicker: "战车",
                message: "战车相信意志能够先于恐惧抵达。\n它会帮助你突破封锁，正面击溃敌人。\n不过，每一次向前，都意味着退路会变得更远。",
                actionTitle: "继续聆听"
            ),
            .init(
                kicker: "选择",
                message: "沿着愚者的道路，试着穿过雾港。\n命运或许正在旁观，但它不会替你承担结果。",
                actionTitle: "选择我的途径"
            )
        ]
    }
}

struct TutorialButtonEmphasis: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(GameSettingsKeys.reduceMotion, store: .standard) private var reducesInterfaceMotion = false
    private var reduceMotion: Bool { systemReduceMotion || reducesInterfaceMotion }
    @State private var isPulsing = false
    let isActive: Bool
    let tint: Color

    func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? tint.opacity(isPulsing ? 0.78 : 0.34) : .clear, radius: isPulsing ? 14 : 7)
            .overlay {
                if isActive {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(tint.opacity(isPulsing ? 0.96 : 0.58), lineWidth: isPulsing ? 2.2 : 1.2)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard isActive, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
            .onChange(of: isActive) { _, active in
                guard active, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func tutorialButtonEmphasis(_ isActive: Bool, tint: Color = .yellow) -> some View {
        modifier(TutorialButtonEmphasis(isActive: isActive, tint: tint))
    }
}

struct TutorialCardFocusHalo: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(GameSettingsKeys.reduceMotion, store: .standard) private var reducesInterfaceMotion = false
    private var reduceMotion: Bool { systemReduceMotion || reducesInterfaceMotion }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate

            GeometryReader { proxy in
                ZStack {
                    TutorialCardHolographicSurface(seconds: seconds, size: proxy.size)
                    TutorialCardSurfaceMotes(seconds: seconds)
                }
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
        }
        .accessibilityHidden(true)
    }

}

/// A visible cyan-violet-magenta holographic film. The complete effect lives
/// inside the card: colour regions travel slowly while a prismatic highlight
/// crosses the artwork, as on a premium animated card foil.
private struct TutorialCardHolographicSurface: View {
    let seconds: TimeInterval
    let size: CGSize

    var body: some View {
        let breathing = 0.80 + 0.16 * (sin(seconds * 0.48) + 1) / 2
        let cyanPulse = 0.66 + 0.34 * (sin(seconds * 1.04 + 0.7) + 1) / 2
        let magentaPulse = 0.64 + 0.36 * (sin(seconds * 0.83 + 2.1) + 1) / 2
        let goldPulse = 0.52 + 0.48 * (sin(seconds * 0.91 + 4.0) + 1) / 2
        let violetPulse = 0.58 + 0.42 * (sin(seconds * 0.74 + 5.2) + 1) / 2
        let cyanScale = CGFloat(0.86 + 0.20 * (sin(seconds * 0.72 + 1.4) + 1) / 2)
        let magentaScale = CGFloat(0.84 + 0.24 * (sin(seconds * 0.66 + 3.0) + 1) / 2)
        let goldScale = CGFloat(0.82 + 0.28 * (sin(seconds * 0.81 + 2.6) + 1) / 2)
        let violetScale = CGFloat(0.84 + 0.25 * (sin(seconds * 0.62 + 0.3) + 1) / 2)

        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.88, blue: 1.0).opacity(0.32),
                    Color(red: 0.24, green: 0.38, blue: 1.0).opacity(0.18),
                    Color(red: 0.76, green: 0.10, blue: 0.94).opacity(0.34),
                    Color(red: 1.0, green: 0.18, blue: 0.68).opacity(0.24),
                    Color(red: 0.03, green: 0.74, blue: 1.0).opacity(0.27)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .blendMode(.color)
            .opacity(breathing)

            RadialGradient(
                colors: [Color.cyan.opacity(0.36), Color(red: 0.20, green: 0.30, blue: 0.98).opacity(0.20), .clear],
                center: .center,
                startRadius: 0,
                endRadius: size.width * 0.62
            )
            .frame(width: size.width * 1.1, height: size.height * 0.92)
            .scaleEffect(cyanScale)
            .opacity(cyanPulse)
            .position(
                x: size.width * (0.18 + 0.035 * CGFloat(sin(seconds * 0.58))),
                y: size.height * (0.40 + 0.025 * CGFloat(cos(seconds * 0.71)))
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [Color(red: 0.95, green: 0.16, blue: 0.82).opacity(0.38), Color(red: 0.48, green: 0.12, blue: 0.92).opacity(0.21), .clear],
                center: .center,
                startRadius: 0,
                endRadius: size.width * 0.68
            )
            .frame(width: size.width * 1.14, height: size.height * 0.96)
            .scaleEffect(magentaScale)
            .opacity(magentaPulse)
            .position(
                x: size.width * (0.83 + 0.03 * CGFloat(cos(seconds * 0.63))),
                y: size.height * (0.58 + 0.03 * CGFloat(sin(seconds * 0.76)))
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [Color(red: 1.0, green: 0.76, blue: 0.24).opacity(0.28), Color(red: 0.86, green: 0.34, blue: 0.74).opacity(0.15), .clear],
                center: .center,
                startRadius: 0,
                endRadius: size.width * 0.55
            )
            .frame(width: size.width, height: size.height * 0.76)
            .scaleEffect(goldScale)
            .opacity(goldPulse)
            .position(
                x: size.width * (0.48 + 0.025 * CGFloat(sin(seconds * 0.69))),
                y: size.height * (0.18 + 0.02 * CGFloat(cos(seconds * 0.84)))
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [Color(red: 0.56, green: 0.30, blue: 1.0).opacity(0.34), Color(red: 0.12, green: 0.62, blue: 1.0).opacity(0.15), .clear],
                center: .center,
                startRadius: 0,
                endRadius: size.width * 0.60
            )
            .frame(width: size.width * 1.05, height: size.height * 0.82)
            .scaleEffect(violetScale)
            .opacity(violetPulse)
            .position(
                x: size.width * (0.50 + 0.03 * CGFloat(cos(seconds * 0.57))),
                y: size.height * (0.82 + 0.025 * CGFloat(sin(seconds * 0.78)))
            )
            .blendMode(.screen)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}

/// A fine, evenly scattered layer of enchanted gold dust. Each mote twinkles
/// independently, so the card shimmers without forming a sweep or burst.
private struct TutorialCardSurfaceMotes: View {
    let seconds: TimeInterval

    var body: some View {
        Canvas { context, size in
            let columns = 14
            let rows = 15
            for index in 0..<(columns * rows) {
                let seed = Double(index) * 9.23
                let speed = 0.30 + Double(random(seed + 4.8)) * 0.44
                let cycle = seconds * speed + Double(index) * 0.137
                let life = CGFloat(cycle - floor(cycle))
                let fade = pow(max(0, sin(life * CGFloat.pi)), 1.65)
                let column = index % columns
                let row = index / columns
                let point = CGPoint(
                    x: size.width * ((CGFloat(column) + 0.12 + random(seed + 0.7) * 0.76) / CGFloat(columns)),
                    y: size.height * ((CGFloat(row) + 0.10 + random(seed + 2.1) * 0.80) / CGFloat(rows))
                )
                let isGlimmer = index.isMultiple(of: 19)
                let dotSize: CGFloat = isGlimmer
                    ? (1.55 + random(seed + 8.4) * 0.75)
                    : (0.68 + random(seed + 8.4) * 0.82)
                let color: Color
                switch index % 12 {
                case 0: color = .white
                case 1: color = Color(red: 0.38, green: 0.91, blue: 1.0)
                case 2: color = Color(red: 0.76, green: 0.48, blue: 1.0)
                default: color = Color(red: 1.0, green: 0.76, blue: 0.20)
                }

                if isGlimmer {
                    let haloSize = 6.0 + fade * 5.6
                    let haloRect = CGRect(
                        x: point.x - haloSize / 2,
                        y: point.y - haloSize / 2,
                        width: haloSize,
                        height: haloSize
                    )
                    context.fill(
                        Path(ellipseIn: haloRect),
                        with: .radialGradient(
                            Gradient(colors: [Color.white.opacity(0.42 * fade), color.opacity(0.48 * fade), .clear]),
                            center: point,
                            startRadius: 0,
                            endRadius: haloSize / 2
                        )
                    )
                }

                let rect = CGRect(
                    x: point.x - dotSize / 2,
                    y: point.y - dotSize / 2,
                    width: dotSize,
                    height: dotSize
                )
                let opacity = (0.72 + random(seed + 9.6) * 0.28) * (0.18 + fade * 0.82)
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
            }
        }
        .allowsHitTesting(false)
    }

    private func random(_ seed: Double) -> CGFloat {
        let value = sin(seed * 12.9898) * 43_758.5453
        return CGFloat(value - floor(value))
    }
}


/// A quiet cloud silhouette keeps the guide's dialogue distinct from the
/// rectangular combat HUD without introducing a large, literal speech tail.
private struct GuideCloudBubble: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        var path = Path()

        path.move(to: CGPoint(x: width * 0.15, y: height * 0.04))
        path.addCurve(
            to: CGPoint(x: width * 0.34, y: height * 0.07),
            control1: CGPoint(x: width * 0.23, y: -height * 0.035),
            control2: CGPoint(x: width * 0.31, y: height * 0.015)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.70, y: height * 0.06),
            control1: CGPoint(x: width * 0.44, y: -height * 0.015),
            control2: CGPoint(x: width * 0.62, y: -height * 0.025)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.93, y: height * 0.22),
            control1: CGPoint(x: width * 0.83, y: -height * 0.025),
            control2: CGPoint(x: width * 1.02, y: height * 0.05)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.91, y: height * 0.54),
            control1: CGPoint(x: width * 1.02, y: height * 0.33),
            control2: CGPoint(x: width * 1.0, y: height * 0.48)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.78, y: height * 0.86),
            control1: CGPoint(x: width * 1.01, y: height * 0.70),
            control2: CGPoint(x: width * 0.91, y: height * 0.94)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.51, y: height * 0.91),
            control1: CGPoint(x: width * 0.68, y: height * 0.99),
            control2: CGPoint(x: width * 0.61, y: height * 0.90)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.22, y: height * 0.88),
            control1: CGPoint(x: width * 0.38, y: height * 1.01),
            control2: CGPoint(x: width * 0.28, y: height * 0.96)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.07, y: height * 0.64),
            control1: CGPoint(x: width * 0.08, y: height * 0.96),
            control2: CGPoint(x: width * -0.02, y: height * 0.79)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.10, y: height * 0.30),
            control1: CGPoint(x: width * -0.04, y: height * 0.51),
            control2: CGPoint(x: width * 0.005, y: height * 0.38)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.15, y: height * 0.04),
            control1: CGPoint(x: width * -0.01, y: height * 0.13),
            control2: CGPoint(x: width * 0.04, y: -height * 0.015)
        )
        path.closeSubpath()
        return path
    }
}

struct ChapterOneTutorialOverlay: View {
    let cue: ChapterOneTutorialCue
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(GameSettingsKeys.reduceMotion, store: .standard) private var reducesInterfaceMotion = false
    private var reduceMotion: Bool { systemReduceMotion || reducesInterfaceMotion }
    @State private var visibleCharacterCount = 0
    @State private var pageIndex = 0
    @State private var acceptsPageAdvance = true
    @State private var showsGuideContent = false
    @State private var battleFadeProgress: Double = 0

    private var pages: [ChapterOneTutorialPage] {
        cue.pages.flatMap { $0.paginated() }
    }
    private var page: ChapterOneTutorialPage { pages[pageIndex] }
    private var characters: [Character] { Array(page.message) }
    private var displayedText: String { String(characters.prefix(visibleCharacterCount)) }
    private var isComplete: Bool { visibleCharacterCount >= characters.count }
    private var isLastPage: Bool { pageIndex == pages.count - 1 }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Fade the battle away before revealing the first guide portrait.
            Color.black.opacity(cue == .firstBattle ? battleFadeProgress : 1)
                .ignoresSafeArea()

            if showsGuideContent {
                guideContent
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .transition(.asymmetric(insertion: .identity, removal: .opacity))
        .zIndex(110)
        .task {
            if cue == .firstBattle {
                do { try await Task.sleep(for: .milliseconds(20)) }
                catch { return }
                withAnimation(.linear(duration: 1)) { battleFadeProgress = 1 }
                do { try await Task.sleep(for: .seconds(1)) }
                catch { return }
            }
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeIn(duration: 0.65)) {
                showsGuideContent = true
            }
        }
        .task(id: "\(cue.rawValue)-\(pageIndex)-\(showsGuideContent)") {
            guard showsGuideContent else { return }
            await typewrite()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showsGuideContent ? "玛拉引导：\(page.message)" : "")
        .accessibilityHint(isComplete ? page.actionTitle : "显示完整文字")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { if showsGuideContent { advanceDialogue() } }
    }

    private var guideContent: some View {
        ZStack(alignment: .bottom) {
            MirielStardustAura()
                .frame(width: 450, height: 610)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 208)
                .offset(x: 38)
                .accessibilityHidden(true)

            GuideMirielPortrait()
                .frame(width: 270, height: 500, alignment: .bottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                // Keep her centered slightly to the right, but let the full
                // silhouette sit lower in the composition so the upper-left
                // remains available for the guide's spoken line.
                .padding(.top, 236)
                .offset(x: 40)
                .zIndex(2)
                .accessibilityHidden(true)

            MirielFireAura()
                .frame(width: 225.5, height: 270)
                .mask {
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white, location: 0.18),
                        .init(color: .white, location: 0.82),
                        .init(color: .clear, location: 1)
                    ], startPoint: .leading, endPoint: .trailing)
                }
                .mask {
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white, location: 0.12),
                        .init(color: .white, location: 0.55),
                        .init(color: .clear, location: 0.90)
                    ], startPoint: .top, endPoint: .bottom)
                }
                .blendMode(.screen)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 215)
                .offset(x: 40)
                .zIndex(1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            MirielGoldenNameplate()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 48)
                .padding(.bottom, 48)
                .offset(x: 22)
                .zIndex(0.5)

            dialogueBubble
                .frame(maxWidth: .infinity, alignment: .leading)
                // The physical iPhone viewport clips the old cloud at x = 0.
                // Give the irregular silhouette a generous leading safe lane.
                .padding(.leading, 10)
                .padding(.trailing, 18)
                .padding(.top, 30)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .zIndex(1)

            // Playtest 2026-10-04: 5–8 pages between short fights. Skipping
            // runs the same completion as reading the last page.
            if !isLastPage {
                Button {
                    guard acceptsPageAdvance else { return }
                    acceptsPageAdvance = false
                    onDismiss()
                } label: {
                    Text("跳过对白 ›")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.55))
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Capsule().fill(Color.black.opacity(0.55)))
                        .overlay(Capsule().stroke(Color(red: 1.0, green: 0.75, blue: 0.24).opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chapter-one-guide-skip")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 20)
                .padding(.bottom, 132)
                .zIndex(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var dialogueBubble: some View {
        Button(action: advanceDialogue) {
            VStack(alignment: .leading, spacing: 7) {
                dialogueHeader
                dialogueMessage
                dialogueFooter
            }
            // The cloud silhouette has deep inward curves. Keep every text
            // row and the next control inside a conservative safe rectangle.
            .padding(.horizontal, 38)
            .padding(.top, 24)
            .padding(.bottom, 12)
            .frame(width: 326, height: 216, alignment: .topLeading)
            // Keep the tappable region aligned with the fixed cloud frame.
            // The action label must not render below the button's hit area.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(dialogueBubbleBackground)
        .accessibilityHint(isComplete ? "继续" : "显示完整文字")
    }

    private var dialogueHeader: some View {
        HStack(spacing: 7) {
            Image(systemName: "moon.stars.fill")
                .foregroundStyle(Color(red: 0.72, green: 0.62, blue: 1))
            Text("玛拉")
                .font(.system(size: 15, weight: .black, design: .rounded))
            Text(page.kicker)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.76, green: 0.66, blue: 1).opacity(0.82))
            Spacer(minLength: 0)
        }
        .frame(height: 22, alignment: .leading)
    }

    private var dialogueMessage: some View {
        Text(displayedText)
            .font(.system(size: 15, weight: .medium, design: .serif))
            .foregroundStyle(.white.opacity(0.96))
            .lineSpacing(4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
    }

    private var dialogueFooter: some View {
        Group {
            if isComplete {
                Text(page.actionTitle)
                    .font(.system(size: isLastPage ? 12 : 11, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        isLastPage
                            ? Color(red: 1.0, green: 0.82, blue: 0.35)
                            : Color(red: 1.0, green: 0.78, blue: 0.31)
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        Capsule()
                            .fill(Color(red: 0.34, green: 0.22, blue: 0.08).opacity(0.72))
                            .overlay {
                                Capsule()
                                    .stroke(Color(red: 1.0, green: 0.75, blue: 0.24).opacity(0.52), lineWidth: 1)
                            }
                    }
                    .shadow(
                        color: Color(red: 1.0, green: 0.62, blue: 0.12).opacity(0.32),
                        radius: 7
                    )
            } else {
                Color.clear.frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        // The lower-right cloud lobe narrows inward; keep the action in its
        // safe content column without reserving a separate empty row.
        .padding(.trailing, 18)
        .padding(.bottom, 12)
    }

    private var dialogueBubbleBackground: some View {
        GuideCloudBubble()
            .fill(Color(red: 0.13, green: 0.12, blue: 0.22).opacity(0.84))
            .shadow(color: Color(red: 0.42, green: 0.30, blue: 0.72).opacity(0.16), radius: 14, y: 5)
    }

    private func advanceDialogue() {
        guard acceptsPageAdvance else { return }
        if !isComplete {
            visibleCharacterCount = characters.count
        } else if !isLastPage {
            // Debounce only the page transition. Without this gate, several
            // taps in one display frame start competing typewriter tasks and
            // make the page counter visibly shake.
            acceptsPageAdvance = false
            pageIndex += 1
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(220))
                acceptsPageAdvance = true
            }
        } else {
            onDismiss()
        }
    }

    @MainActor
    private func typewrite() async {
        visibleCharacterCount = 0
        if reduceMotion {
            visibleCharacterCount = characters.count
            return
        }
        for index in characters.indices {
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .milliseconds(12))
            guard !Task.isCancelled else { return }
            visibleCharacterCount = index + 1
        }
    }
}

private struct MirielStardustAura: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(GameSettingsKeys.reduceMotion, store: .standard) private var reducesInterfaceMotion = false
    private var reduceMotion: Bool { systemReduceMotion || reducesInterfaceMotion }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                ZStack {
                    Ellipse()
                        .fill(Color(red: 0.84, green: 0.65, blue: 0.22).opacity(0.065))
                        .frame(width: 310, height: 440)
                        .blur(radius: 34)
                        .position(x: proxy.size.width * 0.51, y: proxy.size.height * 0.52)

                    ForEach(0..<38, id: \.self) { index in
                        let phase = time * (0.42 + Double(index % 5) * 0.055) + Double(index) * 1.73
                        let shimmer = (sin(phase * 2.4) + 1) * 0.5
                        let baseX = CGFloat(0.16 + Double((index * 37) % 70) / 100)
                        let baseY = CGFloat(0.22 + Double((index * 53) % 58) / 100)
                        let x = proxy.size.width * baseX + CGFloat(sin(phase * 0.61)) * 5
                        let y = proxy.size.height * baseY - CGFloat(sin(phase * 0.37)) * 7
                        let size = CGFloat(1.5 + Double((index * 11) % 5) * 0.65)
                        let opacity = 0.09 + 0.86 * shimmer * shimmer * shimmer
                        let isBrightStar = index.isMultiple(of: 7)
                        let glowSize = size * (isBrightStar ? 5.4 : 3.6)
                        let coreSize = size * (isBrightStar ? 1.35 : 0.82)

                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.white.opacity(isBrightStar ? 0.68 : 0.34),
                                            Color(red: 1.0, green: 0.76, blue: 0.24)
                                                .opacity(isBrightStar ? 0.34 : 0.20),
                                            .clear
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: glowSize / 2
                                    )
                                )
                                .frame(width: glowSize, height: glowSize)
                                .blur(radius: isBrightStar ? 1.8 : 1.1)

                            Circle()
                                .fill(
                                    isBrightStar
                                        ? Color.white
                                        : Color(red: 1.0, green: 0.88, blue: 0.52)
                                )
                                .frame(width: coreSize, height: coreSize)
                        }
                        .scaleEffect(0.82 + shimmer * (isBrightStar ? 0.38 : 0.18))
                        .position(x: x, y: y)
                        .opacity(opacity)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

enum MirielFireAuraPlumeStyle: Equatable {
    case ceremonial
    case roundedHellfire
}

/// Color and silhouette variants of one shared animated fire language. The
/// geometry, embers and timing belong to `MirielFireAura`; combat can choose
/// hellfire without copying that animation into a second component.
struct MirielFireAuraPalette {
    let brightFlame: Color
    let middleFlame: Color
    let outerFlame: Color
    let core: Color
    let coreMiddle: Color
    let coreOuter: Color
    let ember: Color
    let shard: Color
    let plumeOpacity: Double
    let coreOpacity: Double
    let plumeStyle: MirielFireAuraPlumeStyle
    let emitsShardBursts: Bool

    static let goddess = MirielFireAuraPalette(
        brightFlame: Color(red: 1.0, green: 0.70, blue: 0.22),
        middleFlame: Color(red: 1.0, green: 0.28, blue: 0.035),
        outerFlame: Color(red: 0.73, green: 0.055, blue: 0.018).opacity(0.58),
        core: .white.opacity(0.88),
        coreMiddle: Color(red: 1.0, green: 0.82, blue: 0.34).opacity(0.86),
        coreOuter: Color(red: 1.0, green: 0.31, blue: 0.035).opacity(0.50),
        ember: Color(red: 1.0, green: 0.68, blue: 0.20),
        shard: Color(red: 1.0, green: 0.78, blue: 0.32),
        plumeOpacity: 1,
        coreOpacity: 1,
        plumeStyle: .ceremonial,
        emitsShardBursts: true
    )

    static let hellHound = MirielFireAuraPalette(
        brightFlame: Color(red: 1.0, green: 0.39, blue: 0.050),
        middleFlame: Color(red: 0.69, green: 0.018, blue: 0.008),
        outerFlame: Color(red: 0.20, green: 0.004, blue: 0.009).opacity(0.62),
        core: Color(red: 1.0, green: 0.72, blue: 0.16).opacity(0.92),
        coreMiddle: Color(red: 1.0, green: 0.46, blue: 0.07).opacity(0.90),
        coreOuter: Color(red: 0.98, green: 0.15, blue: 0.028).opacity(0.56),
        ember: Color(red: 1.0, green: 0.58, blue: 0.12),
        shard: Color(red: 1.0, green: 0.70, blue: 0.20),
        plumeOpacity: 0.90,
        coreOpacity: 0.68,
        plumeStyle: .roundedHellfire,
        emitsShardBursts: false
    )
}

/// Reusable visual skill: drifting embers rise, burst into shards, then fade.
/// Keep this independent from the goddess portrait so later cards, relics or
/// encounter transitions can reuse the same fire-language.
struct MirielFireAura: View {
    var hidesBase = false
    /// Defaults to the goddess's slow, ceremonial cadence. Combat callers can
    /// reuse the same canvas effect at a faster tempo without duplicating it.
    var speed: Double = 1
    /// Lets multiple instances share the same implementation while their
    /// individual tongues and embers resolve on different animation phases.
    var phase: Double = 0
    var palette: MirielFireAuraPalette = .goddess
    /// The goddess silhouette needs a broad fire ridge; directional combat
    /// casts reuse the plumes, core and embers without that back-wall shape.
    var showsRidge = true
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(GameSettingsKeys.reduceMotion, store: .standard) private var reducesInterfaceMotion = false
    private var reduceMotion: Bool { systemReduceMotion || reducesInterfaceMotion }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let animationTime = time * speed + phase

            Canvas { context, size in
                let centerX = size.width * 0.50
                // Card framing hides the filled base below the canvas so the
                // flame ridge cannot leave a visible horizontal cut line.
                let fireBase = size.height * (hidesBase ? 1.14 : 0.94)
                let fireTime = animationTime
                    + sin(animationTime * 0.57) * 0.65
                    + sin(animationTime * 0.21 + 1.2) * 0.42
                let usesRoundedHellfire = palette.plumeStyle == .roundedHellfire

                let leftPeak = size.height * (0.43 + CGFloat(sin(fireTime * 1.72)) * 0.16)
                let centerPeak = size.height * (0.25 + CGFloat(sin(fireTime * 1.31 + 1.1)) * 0.22)
                let rightPeak = size.height * (0.39 + CGFloat(sin(fireTime * 1.93 + 2.4)) * 0.15)
                let leftValley = size.height * (0.50 + CGFloat(sin(fireTime * 1.47 + 0.3)) * 0.075)
                let rightValley = size.height * (0.47 + CGFloat(sin(fireTime * 1.58 + 1.8)) * 0.085)

                var flameRidge = Path()
                flameRidge.move(to: CGPoint(x: size.width * 0.04, y: fireBase))
                flameRidge.addCurve(
                    to: CGPoint(x: size.width * 0.22, y: leftPeak),
                    control1: CGPoint(x: size.width * -0.02, y: size.height * 0.76),
                    control2: CGPoint(x: size.width * 0.15, y: leftPeak - size.height * 0.035)
                )
                flameRidge.addCurve(
                    to: CGPoint(x: size.width * 0.36, y: leftValley),
                    control1: CGPoint(x: size.width * 0.28, y: leftPeak - size.height * 0.012),
                    control2: CGPoint(x: size.width * 0.31, y: leftValley + size.height * 0.018)
                )
                flameRidge.addCurve(
                    to: CGPoint(x: size.width * 0.56, y: centerPeak),
                    control1: CGPoint(x: size.width * 0.43, y: leftValley - size.height * 0.09),
                    control2: CGPoint(x: size.width * 0.50, y: centerPeak - size.height * 0.028)
                )
                flameRidge.addCurve(
                    to: CGPoint(x: size.width * 0.75, y: rightValley),
                    control1: CGPoint(x: size.width * 0.63, y: centerPeak - size.height * 0.015),
                    control2: CGPoint(x: size.width * 0.70, y: rightValley - size.height * 0.11)
                )
                flameRidge.addCurve(
                    to: CGPoint(x: size.width * 0.87, y: rightPeak),
                    control1: CGPoint(x: size.width * 0.79, y: rightValley + size.height * 0.012),
                    control2: CGPoint(x: size.width * 0.82, y: rightPeak - size.height * 0.02)
                )
                flameRidge.addCurve(
                    to: CGPoint(x: size.width * 0.96, y: size.height * 0.62),
                    control1: CGPoint(x: size.width * 0.92, y: rightPeak),
                    control2: CGPoint(x: size.width * 0.94, y: size.height * 0.53)
                )
                flameRidge.addLine(to: CGPoint(x: size.width * 0.96, y: fireBase))
                flameRidge.closeSubpath()

                if showsRidge {
                    context.drawLayer { ridgeContext in
                        ridgeContext.addFilter(.blur(radius: 10))
                        ridgeContext.blendMode = .plusLighter
                        ridgeContext.opacity = 0.42
                        ridgeContext.fill(
                            flameRidge,
                            with: .linearGradient(
                                Gradient(colors: [
                                    palette.brightFlame,
                                    palette.middleFlame,
                                    palette.outerFlame,
                                    .clear
                                ]),
                                startPoint: CGPoint(x: centerX, y: fireBase),
                                endPoint: CGPoint(x: centerX, y: centerPeak)
                            )
                        )
                    }
                }

                context.drawLayer { plumeContext in
                    plumeContext.addFilter(.blur(radius: usesRoundedHellfire ? 6 : 16))
                    plumeContext.blendMode = .plusLighter

                    if usesRoundedHellfire {
                        // A continuous, curved silhouette prevents the large
                        // combat instance from reading as a geometric wedge.
                        let bodySway = CGFloat(sin(fireTime * 1.42)) * size.width * 0.055
                        let tipSway = CGFloat(sin(fireTime * 1.93 + 0.7)) * size.width * 0.070
                        let rootY = fireBase
                        let outerTipY = rootY - size.height * 0.64
                        let innerTipY = rootY - size.height * 0.40

                        var outerFlame = Path()
                        outerFlame.move(to: CGPoint(x: centerX - size.width * 0.28, y: rootY))
                        outerFlame.addCurve(
                            to: CGPoint(x: centerX - size.width * 0.42 + bodySway * 0.22, y: rootY - size.height * 0.22),
                            control1: CGPoint(x: centerX - size.width * 0.40, y: rootY - size.height * 0.04),
                            control2: CGPoint(x: centerX - size.width * 0.48 + bodySway * 0.18, y: rootY - size.height * 0.15)
                        )
                        outerFlame.addCurve(
                            to: CGPoint(x: centerX - size.width * 0.13 + bodySway, y: rootY - size.height * 0.47),
                            control1: CGPoint(x: centerX - size.width * 0.42 + bodySway * 0.52, y: rootY - size.height * 0.36),
                            control2: CGPoint(x: centerX - size.width * 0.24 + bodySway * 0.78, y: rootY - size.height * 0.49)
                        )
                        outerFlame.addCurve(
                            to: CGPoint(x: centerX + size.width * 0.04 + tipSway, y: outerTipY + size.height * 0.045),
                            control1: CGPoint(x: centerX - size.width * 0.05 + bodySway, y: rootY - size.height * 0.61),
                            control2: CGPoint(x: centerX - size.width * 0.02 + tipSway, y: outerTipY)
                        )
                        outerFlame.addCurve(
                            to: CGPoint(x: centerX + size.width * 0.15 + tipSway, y: outerTipY + size.height * 0.080),
                            control1: CGPoint(x: centerX + size.width * 0.07 + tipSway, y: outerTipY - size.height * 0.028),
                            control2: CGPoint(x: centerX + size.width * 0.14 + tipSway, y: outerTipY - size.height * 0.004)
                        )
                        outerFlame.addCurve(
                            to: CGPoint(x: centerX + size.width * 0.31 + bodySway, y: rootY - size.height * 0.40),
                            control1: CGPoint(x: centerX + size.width * 0.23 + tipSway, y: rootY - size.height * 0.52),
                            control2: CGPoint(x: centerX + size.width * 0.38 + bodySway * 0.75, y: rootY - size.height * 0.48)
                        )
                        outerFlame.addCurve(
                            to: CGPoint(x: centerX + size.width * 0.42 + bodySway * 0.18, y: rootY - size.height * 0.16),
                            control1: CGPoint(x: centerX + size.width * 0.39 + bodySway * 0.42, y: rootY - size.height * 0.30),
                            control2: CGPoint(x: centerX + size.width * 0.47 + bodySway * 0.12, y: rootY - size.height * 0.22)
                        )
                        outerFlame.addCurve(
                            to: CGPoint(x: centerX + size.width * 0.28, y: rootY),
                            control1: CGPoint(x: centerX + size.width * 0.40, y: rootY - size.height * 0.05),
                            control2: CGPoint(x: centerX + size.width * 0.35, y: rootY - size.height * 0.015)
                        )
                        outerFlame.closeSubpath()

                        plumeContext.opacity = 0.62 * palette.plumeOpacity
                        plumeContext.fill(
                            outerFlame,
                            with: .linearGradient(
                                Gradient(colors: [
                                    palette.brightFlame,
                                    palette.middleFlame,
                                    palette.outerFlame,
                                    .clear
                                ]),
                                startPoint: CGPoint(x: centerX, y: rootY),
                                endPoint: CGPoint(x: centerX + tipSway, y: outerTipY)
                            )
                        )

                        var innerFlame = Path()
                        innerFlame.move(to: CGPoint(x: centerX - size.width * 0.18, y: rootY - size.height * 0.015))
                        innerFlame.addCurve(
                            to: CGPoint(x: centerX - size.width * 0.20 + bodySway * 0.45, y: rootY - size.height * 0.22),
                            control1: CGPoint(x: centerX - size.width * 0.25, y: rootY - size.height * 0.09),
                            control2: CGPoint(x: centerX - size.width * 0.28 + bodySway * 0.32, y: rootY - size.height * 0.18)
                        )
                        innerFlame.addCurve(
                            to: CGPoint(x: centerX - size.width * 0.04 + tipSway * 0.58, y: innerTipY),
                            control1: CGPoint(x: centerX - size.width * 0.15 + bodySway * 0.62, y: rootY - size.height * 0.33),
                            control2: CGPoint(x: centerX - size.width * 0.08 + tipSway * 0.62, y: rootY - size.height * 0.42)
                        )
                        innerFlame.addCurve(
                            to: CGPoint(x: centerX + size.width * 0.10 + tipSway * 0.58, y: innerTipY + size.height * 0.045),
                            control1: CGPoint(x: centerX + size.width * 0.01 + tipSway * 0.58, y: innerTipY - size.height * 0.024),
                            control2: CGPoint(x: centerX + size.width * 0.09 + tipSway * 0.58, y: innerTipY - size.height * 0.002)
                        )
                        innerFlame.addCurve(
                            to: CGPoint(x: centerX + size.width * 0.18, y: rootY - size.height * 0.015),
                            control1: CGPoint(x: centerX + size.width * 0.17 + bodySway * 0.44, y: rootY - size.height * 0.19),
                            control2: CGPoint(x: centerX + size.width * 0.24, y: rootY - size.height * 0.09)
                        )
                        innerFlame.closeSubpath()

                        plumeContext.opacity = 0.58 * palette.plumeOpacity
                        plumeContext.fill(
                            innerFlame,
                            with: .linearGradient(
                                Gradient(colors: [
                                    palette.core,
                                    palette.brightFlame,
                                    palette.middleFlame,
                                    .clear
                                ]),
                                startPoint: CGPoint(x: centerX, y: rootY),
                                endPoint: CGPoint(x: centerX + tipSway * 0.58, y: innerTipY)
                            )
                        )
                    } else {
                        // Preserve the goddess's existing ceremonial flame geometry.
                        for index in 0..<7 {
                            let localTime = fireTime
                                + sin(animationTime * (0.31 + Double(index) * 0.017) + Double(index)) * 0.24
                            let phase = localTime * (0.42 + Double(index % 3) * 0.055)
                                + Double(index) * 1.61
                            let xOffset = CGFloat(index - 3) * size.width * 0.075
                            let sway = CGFloat(sin(phase)) * size.width * 0.045
                            let plumeWidth = size.width * (0.25 + CGFloat(index % 3) * 0.035)
                            let distanceFromCenter = CGFloat(abs(index - 3))
                            let heightFalloff = 1 - distanceFromCenter * 0.105
                            let verticalFlicker = 1
                                + CGFloat(sin(phase * 1.46)) * (index == 3 ? 0.22 : 0.15)
                                + CGFloat(sin(phase * 2.31 + 0.8)) * 0.06
                            let plumeHeight = size.height
                                * (0.58 + CGFloat(index % 4) * 0.045)
                                * heightFalloff
                                * verticalFlicker
                            let topY = fireBase - plumeHeight

                            var plume = Path()
                            plume.move(to: CGPoint(x: centerX + xOffset - plumeWidth * 0.58, y: fireBase))
                            plume.addCurve(
                                to: CGPoint(x: centerX + xOffset + sway, y: topY),
                                control1: CGPoint(x: centerX + xOffset - plumeWidth * 0.72, y: fireBase - plumeHeight * 0.30),
                                control2: CGPoint(x: centerX + xOffset - plumeWidth * 0.20 + sway, y: fireBase - plumeHeight * 0.73)
                            )
                            plume.addCurve(
                                to: CGPoint(x: centerX + xOffset + plumeWidth * 0.58, y: fireBase),
                                control1: CGPoint(x: centerX + xOffset + plumeWidth * 0.28 + sway, y: fireBase - plumeHeight * 0.70),
                                control2: CGPoint(x: centerX + xOffset + plumeWidth * 0.76, y: fireBase - plumeHeight * 0.28)
                            )
                            plume.closeSubpath()

                            plumeContext.opacity = (0.16 + Double(index % 3) * 0.035) * palette.plumeOpacity
                            plumeContext.fill(
                                plume,
                                with: .linearGradient(
                                    Gradient(colors: [
                                        palette.brightFlame,
                                        palette.middleFlame,
                                        palette.outerFlame,
                                        .clear
                                    ]),
                                    startPoint: CGPoint(x: centerX, y: fireBase),
                                    endPoint: CGPoint(x: centerX, y: topY)
                                )
                            )
                        }
                    }
                }

                context.drawLayer { coreContext in
                    coreContext.addFilter(.blur(radius: 15))
                    coreContext.blendMode = .plusLighter
                    coreContext.opacity = palette.coreOpacity
                    let pulse = 1
                        + CGFloat(sin(animationTime * 1.8)) * 0.07
                        + CGFloat(sin(animationTime * 3.1 + 0.6)) * 0.025
                    let coreWidth = size.width * 0.33 * pulse
                    let coreHeight = size.height * 0.23 * pulse
                    let coreLift = CGFloat(sin(animationTime * 2.25)) * size.height * 0.012
                    let coreRect = CGRect(
                        x: centerX - coreWidth / 2,
                        y: fireBase - coreHeight * 0.92 - coreLift,
                        width: coreWidth,
                        height: coreHeight
                    )
                    coreContext.fill(
                        Path(ellipseIn: coreRect),
                        with: .radialGradient(
                            Gradient(colors: [
                                palette.core,
                                palette.coreMiddle,
                                palette.coreOuter,
                                .clear
                            ]),
                            center: CGPoint(x: centerX, y: fireBase - coreHeight * 0.42),
                            startRadius: 1,
                            endRadius: coreWidth * 0.56
                        )
                    )
                }

                for index in 0..<22 {
                    let emberSpeed = 0.075 + Double(index % 5) * 0.012
                    let travel = (animationTime * emberSpeed + Double(index) * 0.137)
                        .truncatingRemainder(dividingBy: 1)
                    let y = fireBase - CGFloat(travel) * size.height * 0.82
                    let drift = CGFloat(sin(animationTime * 0.9 + Double(index) * 1.91)) * 17
                    let x = centerX
                        + CGFloat((index * 47) % 100 - 50) / 100 * size.width * 0.72
                        + drift
                    let emberSize = CGFloat(0.8 + Double(index % 4) * 0.55)
                    let opacity = max(0, sin(travel * .pi)) * 0.72

                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: x - emberSize / 2,
                            y: y - emberSize * 1.7,
                            width: emberSize,
                            height: emberSize * 3.4
                        )),
                        with: .color(palette.ember.opacity(opacity))
                    )

                    // Before an ember fades, let it crack into a tiny radial
                    // burst so the particles feel magical rather than simply
                    // being removed at the top of the aura.
                    let burst = max(0, min(1, (travel - 0.78) / 0.22))
                    if palette.emitsShardBursts && burst > 0 {
                        for shard in 0..<18 {
                            let shardAngle = Double(shard) * (.pi / 9) + Double(index) * 0.41
                            let distance = CGFloat(burst) * (4.0 + CGFloat((shard * 7 + index) % 5) * 1.7)
                            let shardPoint = CGPoint(
                                x: x + CGFloat(cos(shardAngle)) * distance,
                                y: y + CGFloat(sin(shardAngle)) * distance
                            )
                            let shardSize = max(0.34, emberSize * (0.42 - burst * 0.12))
                            context.fill(
                                Path(ellipseIn: CGRect(
                                    x: shardPoint.x - shardSize / 2,
                                    y: shardPoint.y - shardSize / 2,
                                    width: shardSize,
                                    height: shardSize * 1.8
                                )),
                                with: .color(palette.shard.opacity((1 - burst) * 0.82))
                            )
                        }
                    }
                }
            }
        }
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: 0.12),
                    .init(color: .white, location: 0.88),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct MirielGoldenNameplate: View {
    private let gold = LinearGradient(
        colors: [
            Color(red: 0.66, green: 0.42, blue: 0.12),
            Color(red: 1.0, green: 0.91, blue: 0.62),
            Color(red: 0.93, green: 0.68, blue: 0.22),
            Color(red: 1.0, green: 0.95, blue: 0.76),
            Color(red: 0.64, green: 0.39, blue: 0.10)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 10) {
                ornamentLine
                Image(systemName: "diamond.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.40))
                    .shadow(color: Color(red: 1.0, green: 0.72, blue: 0.22).opacity(0.8), radius: 5)
                ornamentLine
            }

            Text("玛拉")
                .font(.system(size: 27, weight: .semibold, design: .serif))
                .tracking(2.2)
                .foregroundStyle(gold)
                .shadow(color: Color(red: 1.0, green: 0.72, blue: 0.20).opacity(0.34), radius: 8)
                .shadow(color: .black.opacity(0.82), radius: 2, y: 2)

            Text("静幕引路人  ·  三途初启")
                .font(.system(size: 9, weight: .semibold, design: .serif))
                .tracking(2.6)
                .foregroundStyle(Color(red: 0.94, green: 0.79, blue: 0.46).opacity(0.72))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("玛拉，旧城区引路人")
    }

    private var ornamentLine: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, Color(red: 0.93, green: 0.67, blue: 0.22).opacity(0.72), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(maxWidth: 72, maxHeight: 1)
    }
}

private struct GuideMirielPortrait: View {
    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width, proxy.size.height * 2 / 3)
            let height = width * 1.5
            ZStack {
                Image("GuideMaraLayered")
                    .resizable()
                    .scaledToFit()
                MirielCardFlight()
            }
            .frame(width: width, height: height)
            .position(x: proxy.size.width / 2, y: proxy.size.height - height / 2)
        }
    }
}

private struct MirielClothSprite: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(GameSettingsKeys.reduceMotion, store: .standard) private var reducesInterfaceMotion = false
    private var reduceMotion: Bool { systemReduceMotion || reducesInterfaceMotion }
    @State private var frame = 0

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 543.0, proxy.size.height / 724.0)
            let frameWidth = 543.0 * scale
            let frameHeight = 724.0 * scale
            Image("MirielClothSprite")
                .resizable()
                .interpolation(.high)
                .frame(width: frameWidth * 4, height: frameHeight)
                .offset(x: -frameWidth * CGFloat(frame))
                .frame(width: frameWidth, height: frameHeight, alignment: .leading)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation(.easeInOut(duration: 0.16)) {
                    frame = (frame + 1) % 4
                }
            }
        }
    }
}

private struct MirielCardFlight: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(GameSettingsKeys.reduceMotion, store: .standard) private var reducesInterfaceMotion = false
    private var reduceMotion: Bool { systemReduceMotion || reducesInterfaceMotion }
    @State private var started = Date()
    private let homes: [CGPoint] = [
        CGPoint(x: 0.267, y: 0.174), CGPoint(x: 0.732, y: 0.211),
        CGPoint(x: 0.823, y: 0.177), CGPoint(x: 0.759, y: 0.245),
        CGPoint(x: 0.849, y: 0.238)
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSince(started)
            GeometryReader { proxy in
                ZStack {
                    ForEach(0..<5, id: \.self) { index in
                        let cycle = 11.0 + Double(index) * 1.7
                        let phase = (time + Double(index) * 1.8).truncatingRemainder(dividingBy: cycle) / cycle
                        let departure = reduceMotion ? 0 : min(1, max(0, (phase - 0.70) / 0.055))
                        let returning = min(1, max(0, (phase - 0.84) / 0.16))
                        let travel = departure * (1 - returning * returning * (3 - 2 * returning))
                        let side = index == 0 ? -1.0 : 1.0
                        let bob = reduceMotion ? 0 : sin(time * (1.3 + Double(index) * 0.17) + Double(index)) * 4
                        let tilt = index == 0 ? -5.0 : Double(index - 2) * 18
                        MaraTarotCard(design: index)
                            .frame(width: index == 0 ? 17 : 13, height: index == 0 ? 29 : 25)
                            .rotation3DEffect(.degrees(reduceMotion ? 0 : sin(time * 0.8 + Double(index)) * 22 + travel * 150), axis: (x: 0, y: 1, z: 0))
                            .rotationEffect(.degrees(tilt + travel * side * 65))
                            .opacity(phase > 0.755 && phase < 0.84 && !reduceMotion ? 0 : 1 - travel * 0.75)
                            .shadow(color: .purple.opacity(0.7), radius: 4)
                            .position(
                                x: homes[index].x * proxy.size.width + travel * side * 90,
                                y: homes[index].y * proxy.size.height + bob + travel * 32
                            )
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

 }

/// Vector engraving stays crisp as the floating cards tilt and approach the viewer.
private struct MaraTarotCard: View {
    let design: Int

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 100, y: size.height / 180)
            let gold = Color(red: 0.87, green: 0.73, blue: 0.46)
            let silver = Color(red: 0.86, green: 0.83, blue: 1)
            let bounds = CGRect(x: 0, y: 0, width: 100, height: 180)
            let outline = Path(roundedRect: bounds.insetBy(dx: 1, dy: 1), cornerRadius: 6)
            context.fill(outline, with: .linearGradient(
                Gradient(colors: [Color(red: 0.20, green: 0.12, blue: 0.35), Color(red: 0.035, green: 0.025, blue: 0.09), Color(red: 0.12, green: 0.07, blue: 0.24)]),
                startPoint: .zero, endPoint: CGPoint(x: 100, y: 180)))
            context.stroke(outline, with: .color(silver), lineWidth: 1.8)
            for inset in [5.0, 9.0] {
                context.stroke(Path(roundedRect: bounds.insetBy(dx: inset, dy: inset), cornerRadius: 3), with: .color(gold.opacity(0.8)), lineWidth: 0.9)
            }
            // Corner scrolls and inset diamonds, mirrored around the card.
            for x in [16.0, 84.0] {
                for y in [21.0, 159.0] {
                    let sx = x < 50 ? 1.0 : -1.0
                    let sy = y < 90 ? 1.0 : -1.0
                    var scroll = Path()
                    scroll.move(to: CGPoint(x: x, y: y + sy * 17))
                    scroll.addCurve(to: CGPoint(x: x + sx * 16, y: y), control1: CGPoint(x: x + sx * 19, y: y + sy * 14), control2: CGPoint(x: x - sx * 5, y: y - sy * 8))
                    context.stroke(scroll, with: .color(gold), lineWidth: 1.1)
                    var diamond = Path()
                    diamond.move(to: CGPoint(x: x, y: y - 3))
                    diamond.addLine(to: CGPoint(x: x + 2, y: y))
                    diamond.addLine(to: CGPoint(x: x, y: y + 3))
                    diamond.addLine(to: CGPoint(x: x - 2, y: y))
                    diamond.closeSubpath()
                    context.fill(diamond, with: .color(silver))
                }
            }
            // Astral dial: three engraved rings and minute marks.
            for radius in [27.0, 31.0, 35.0] {
                context.stroke(Path(ellipseIn: CGRect(x: 50-radius, y: 90-radius, width: radius*2, height: radius*2)), with: .color(gold.opacity(0.85)), lineWidth: radius == 31 ? 1.1 : 0.65)
            }
            for i in 0..<40 {
                let angle = Double(i) * .pi / 20
                let inner = i.isMultiple(of: 5) ? 28.0 : 32.0
                var tick = Path()
                tick.move(to: CGPoint(x: 50 + cos(angle)*inner, y: 90 + sin(angle)*inner))
                tick.addLine(to: CGPoint(x: 50 + cos(angle)*35, y: 90 + sin(angle)*35))
                context.stroke(tick, with: .color(gold), lineWidth: 0.7)
            }
            // A fine constellation replaces the oversized generic sparkle.
            var star = Path()
            let points = design.isMultiple(of: 2) ? 8 : 6
            for i in 0..<(points*2) {
                let angle = Double(i) * .pi / Double(points) - .pi/2
                let radius = i.isMultiple(of: 2) ? 22.0 : 7.0
                let point = CGPoint(x: 50 + cos(angle)*radius, y: 90 + sin(angle)*radius)
                if i == 0 { star.move(to: point) } else { star.addLine(to: point) }
            }
            star.closeSubpath()
            context.fill(star, with: .color(silver.opacity(0.14)))
            context.stroke(star, with: .color(silver), lineWidth: 1.1)
            context.fill(Path(ellipseIn: CGRect(x: 47, y: 87, width: 6, height: 6)), with: .color(gold))
            for i in 0..<18 {
                let x = 18 + Double((i*37 + design*11)%64)
                let y = 36 + Double((i*43)%108)
                if abs(y-90) > 38 {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.2, height: 1.2)), with: .color(silver.opacity(0.65)))
                }
            }
            context.draw(Text(["XVIII", "II", "XVII", "I", "XXI"][design % 5]).font(.system(size: 9, weight: .medium, design: .serif)).foregroundStyle(gold), at: CGPoint(x: 50, y: 22))
            for y in [43.0, 137.0] {
                var ornament = Path()
                ornament.move(to: CGPoint(x: 35, y: y))
                ornament.addQuadCurve(to: CGPoint(x: 65, y: y), control: CGPoint(x: 50, y: y + (y < 90 ? 10 : -10)))
                context.stroke(ornament, with: .color(gold), lineWidth: 1)
            }
            context.draw(Text("✦").font(.system(size: 10, design: .serif)).foregroundStyle(gold), at: CGPoint(x: 50, y: 158))
        }
    }
}

struct PathSelectionMistReveal: View {
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(GameSettingsKeys.reduceMotion, store: .standard) private var reducesInterfaceMotion = false
    private var reduceMotion: Bool { systemReduceMotion || reducesInterfaceMotion }
    @State private var revealProgress: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .opacity(1 - revealProgress)

                ForEach(0..<7, id: \.self) { index in
                    Ellipse()
                        .fill(Color(white: 0.48).opacity(0.52 - Double(index) * 0.045))
                        .frame(
                            width: geometry.size.width * (0.72 + CGFloat(index % 3) * 0.23),
                            height: 150 + CGFloat(index % 4) * 54
                        )
                        .blur(radius: 30 + CGFloat(index % 3) * 13)
                        .offset(
                            x: (CGFloat(index % 3) - 1) * geometry.size.width * 0.27
                                + (index.isMultiple(of: 2) ? -1 : 1) * revealProgress * geometry.size.width,
                            y: CGFloat(index) * geometry.size.height / 8 - geometry.size.height * 0.4
                        )
                        .opacity(1 - revealProgress)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .contentShape(.rect)
        .onAppear {
            if reduceMotion {
                revealProgress = 1
                onComplete()
                return
            }
            withAnimation(.easeInOut(duration: 2.4)) {
                revealProgress = 1
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.45))
                onComplete()
            }
        }
        .accessibilityHidden(true)
    }
}

private enum GuideMirielForegroundCutout {
    static func make() -> UIImage? {
        guard let original = UIImage(named: "GuideMiriel"),
              let cgImage = original.cgImage else { return nil }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)

        do {
            try handler.perform([request])
            guard let observation = request.results?.first else { return nil }
            let maskedBuffer = try observation.generateMaskedImage(
                ofInstances: observation.allInstances,
                from: handler,
                croppedToInstancesExtent: false
            )
            let maskedCIImage = CIImage(cvPixelBuffer: maskedBuffer)
            let context = CIContext(options: nil)
            guard let maskedImage = context.createCGImage(maskedCIImage, from: maskedCIImage.extent) else {
                return nil
            }
            return UIImage(cgImage: maskedImage, scale: original.scale, orientation: original.imageOrientation)
        } catch {
            return nil
        }
    }
}
