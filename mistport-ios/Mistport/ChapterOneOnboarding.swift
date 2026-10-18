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

        // A page ends on a full stop where it can (2026-10-18 rewrite: "说签了，" closed a page of
        // 玛拉's confession); a comma only when no sentence ends in the last two thirds.
        let sentenceEnds = CharacterSet(charactersIn: "。！？；…")
        let preferredBreaks = CharacterSet(charactersIn: "。！？；……，、")
        var result: [String] = []
        var remainder = text[...]

        while remainder.count > limit {
            let proposedEnd = remainder.index(remainder.startIndex, offsetBy: limit)
            let proposed = remainder[..<proposedEnd]
            let earliestSentenceEnd = remainder.index(remainder.startIndex, offsetBy: limit / 3)
            let sentenceBreak = proposed.indices.reversed().first { index in
                index >= earliestSentenceEnd && String(proposed[index]).rangeOfCharacter(from: sentenceEnds) != nil
            }
            let breakIndex = sentenceBreak ?? proposed.indices.reversed().first { index in
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

enum ChapterOneTutorialCue: String, CaseIterable {
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

    /// The story beat (2026-10-18 rewrite, user: 更像人类，更悲情，更呈现人性). People and
    /// things, not procedures; how a fight or a new card works lives in `hint`, on its own page.
    var message: String {
        switch self {
        case .q30Aftermath:
            "私印从他手里滑落，在地上滚了半圈。\n瑟维安死了。巡官翻遍总册，找不到一个能替他收尸的名字。最后是玛拉在认领栏上签了字。\n三天后，诊所的门被推开了。伊恩瘦了很多，站在门口，好像不敢进来。\n奥黛尔没有起身，只把那只缺角的杯子推到桌子对面。茶是凉的。\n伊恩端起来，一口喝完了。这一次，他什么也没说。\n洛克拿着一本名册挨家挨户地敲门，上面是他亲手送走的每一个人。找到一个，他就划掉一个。有几个名字，他一直没能划掉。\n维娅在审理庭上说了实话，所有的实话。听审的人里，没有阿洛。\n外海的追索没有停。它比你来雾港还早，早到你自己都记不起。赫斯替你守住了一条去黑盐岸的航线，只有单程。\n码头上，玛拉把原档递还给你：“我得留下。有太多签名，要我自己一个一个去认。”\n“你也是。下一次，别让别人替你签。”\n船开了。雾港的灯在你身后一盏一盏变小。你没有回头，可你知道她一直站在那里。"
        case .q30Prelude:
            "瑟维安的钟环已经全暗了。他站在总册中间，像守着一间空柜台的老店员。\n“你知道没有主人的人在雾港会怎样吗？没有床，没有名字，死在排渠里，三天都没人来认。我给了他们主人。主人至少会来收尸。”\n“我七岁那年，在码头等了一整个冬天。没有人来领我。”\n他握紧私印：“所以别跟我说自由。自由是给有人在等的人的。”"
        case .q29Aftermath:
            "第五格熄灭的时候，瑟维安按下一枚一次性的归庭印，退回了总册。\n他留下的手下，你一个一个清掉了。\n他的退路用完了。现在，只剩他自己。"
        case .q29Prelude:
            "签发廊里，一台新的执行者和一具空壳守卫站在瑟维安两边。不是你在补位处砸掉的那台。\n钟环上的格子一格一格亮起来。他要用最后的积蓄，替自己签一条退路。"
        case .q28Aftermath:
            "第五次落下，你还站着。五盏灯同时亮起，伊莱娅切断了所有的线。\n瑟维安没有倒。他低头看了看钟环，上面还亮着五格。\n“我还有自己的积蓄。”他说得像个精明的老店员，转身退进了签发廊。"
        case .q28Prelude:
            "瑟维安一个人站在回流中间。他比你想的老，白头发，一双铜铸的手合着一本档案书。\n“你拿到了一张纸，”他说，“就以为能离开名字了？”\n远处的灯一动不动。伊莱娅在等五次完整的回流，还没落定的那一击，她不会替你挡。"
        case .q27Aftermath:
            "你找到了自己的原档。名字那一栏，是你上岸那天自己报的，字是你的字。\n不是瑟维安领走了你。追索你的那张单子，比你上岸还早。\n封存的交易存根上写着：第七住客。名字被涂黑了。\n你把原档揣进怀里，走向五路回流的中央。"
        case .q27Prelude:
            "原始档案库在地底，冷得像冰窖。最早的记录都在这里，也包括你的。\n档案守卫和守备犬挡在门口。\n你想知道，第一个写下你名字的人是谁。"
        case .q26Aftermath:
            "锤卫停了。它倒下的时候锤子还举着，像是忘了放下。\n车链断开，最后一趟车停在岸边。总签钥和末班的运输记录掉在链子旁。\n不会再有车开出去了。原始档案库的门，露了出来。"
        case .q26Prelude:
            "还是那具锤卫，守着最后一趟车。车链在给它送力气，锤子比上次更沉。\n这是最后一趟了。车上的人要是送走，就再也找不回来。"
        case .q25Aftermath:
            "最后一根红线断了。\n网里的灯一盏接一盏地灭。同桌吃了三年饭的人，在同一刻忘了彼此是谁。\n阿洛站在门口看着维娅，礼貌又陌生：“阿姨，你找谁？”\n维娅蹲下来，替他把扣歪的扣子重新扣好：“不找谁。外面冷，快进去吧。”\n她站起来，走向等着带她去受审的巡官，一次也没有回头。"
        case .q25Prelude:
            "维娅自己来了。她看起来老了很多。\n“这一次，是我自己同意的。”她把手从红线上拿开，“拆吧。”\n可网不肯。那些线自己缠了上来，护着她，像护着一个不愿意醒的梦。"
        case .q24Aftermath:
            "你找到了伊恩。他瘦得认不出来，可他认得那只杯子的缺角。他说那是他自己摔的，怕奥黛尔骂，一直没敢说。\n他交出了黑盐岸的检疫路线。\n可他一直在发抖，说身上还有什么东西在往外拽他。人救出来了，认领他的那张单子还没撕。"
        case .q24Prelude:
            "地下泊位的闸口有守备犬，还有几道认领失败的幽灵在徘徊：没被领走，也没能回家的人。\n船舱里有个声音在问：“奥黛尔还留着那只缺角的杯子吗？”"
        case .q23Aftermath:
            "验过了。不用任何人的名字，封口一样牢。\n玛拉听到结果，在台阶上坐了很久：“三年前要是有人知道……”她没说完。\n伊莱娅说，瑟维安每出一次手，就会露出一条真的回路：“五次都看清，我才能一起切断。”\n地下泊位，还有人在等船。"
        case .q23Prelude:
            "替代的材料送去验了：一块旧钟铜，一捧码头的盐，一页没写名字的白纸。只要验得过，封口就不必绑在一个人身上。\n裁定守备还按着旧许可守住主锚，不肯让开。\n灯后站着一个人，安静得像一盏灯。她叫伊莱娅，守灯会的天使。“保住锚，”她说，“我要看清那五条线。”"
        case .q22Aftermath:
            "你按住了她的手。那个码头工的名字被划掉了，墨还没干。\n维娅没有挣扎：“你知道那个人是谁吗？你不知道。我也不知道。所以我才选了他。”\n“我只是想让一个孩子有家。这有什么错？”\n玛拉替她回答，声音很轻：“我也这么想过。”\n她被带了回去，看管照旧。你们得找到一种办法，不用拿任何人的名字去填这个洞。"
        case .q22Prelude:
            "复核接口开着，补位栏空着一格。\n维娅的手很稳。她填进一个陌生人的名字：码头的临时工，没有家人，不会有人来找。\n“只要这一格，”她没有回头，“阿洛就能继续叫我妈妈。他晚上怕黑，没有我睡不着。”\n阿洛不是她的儿子。她的儿子死在三年前那场火里。这一点，她比谁都清楚。"
        case .q21Aftermath:
            "转接核心碎了。背架上的线一根根松开，洛克终于把那句话说完了：\n“安置好了，你们就能走。本来就是这么写的。”\n他把救援架背正，往排渠走：“我送进去的人，我一个一个去接回来。”\n你问他记不记得有多少。他说：“三百一十二个。”"
        case .q21Prelude:
            "洛克又来了。他胸前那根线勒得更紧，救援架里有个不属于他的声音，一句一句替他说话。\n他看着你，嘴唇在动，说不出一句完整的话：“原来的条款……不是……不许走。”"
        case .q9Prelude:
            "齿轮工坊里，一个书记员正在改一份证词。\n“伊恩没有回来”，他用很好看的字，一笔一笔改成：“本人因误会，重复报案。”\n那是奥黛尔的证词。她去报了七次案。"
        case .q10Prelude:
            "名单很长。很多地址根本不存在，有一户写着“排渠第三格”，那是一道铁栅栏。\n翻到下一页，你看见了自己的名字。后面也填着一个地址，一户你从没听说过的人家：已领回。\n一只铠甲猎犬守着原件。它不是追过你的那条老狗。它更年轻，眼睛里什么都没有。"
        case .q9Aftermath:
            "你抢回了原件。奥黛尔报了七次案，签了七次名，最后一次的字已经抖得不成样子。改过的记录里，她只是一个糊涂的、反复给人添麻烦的老医生。\n原件背面有一行陌生的批注，墨是淡金色的：“誊本不会替你作证。”你不知道是谁写的。\n证词底下压着一份失踪者名单。"
        case .q10Aftermath:
            "名单保住了。你名字后面那个地址没有被划掉，墨迹很新，像是昨天才填的。\n雨烬馆的赫斯看了一眼名单，指着其中几处：“这几户，三年前就烧没了。”他没再多说。\n有人替你编好了一个家，还在那里等你回去。"
        case .q11Prelude:
            "开门的是个中年女人。她看见你，眼圈一下就红了。\n“你可回来了。”她把你拉进屋，桌上摆着四副碗筷，“你的杯子我一直留着，你小时候就用这个。”\n是那只缺角的茶杯。\n屋里的弟弟妹妹都在笑，笑得一模一样。墙角的阴影里，两只记忆蛭正一口一口往这间屋子里吐回忆。"
        case .q12Prelude:
            "调拨处的灯一直亮着。两个书记员坐在长桌两头，一个划掉名字，一个补上名字，配合得很默契。\n移出一个，补进一个。账总是平的。\n玛拉站在门口没有动：“先停下这份调拨。然后，我有件事要告诉你。”"
        case .q13Prelude:
            "排渠里有个男人背着救援架，在齐膝的水里来回走。他把困在里面的人一个个扶起来，轻声说：“别怕，安置好就能走。”然后把他们送进铁门后面。\n是录音里那个声音。\n他叫洛克。他每天救很多人，却不知道自己把他们救去了哪里。"
        case .q14Prelude:
            "名牌箱里挂满了名牌，一排一排，像晾在绳上的衣服。伊恩的那块在最里面，背后牵着一根细红线，一直通到看不见的地方。\n记忆蛭在吞名字，书记员在旁边记：自愿认领。每一次挣扎，都被记成一次点头。"
        case .q15Prelude:
            "织网的女人叫维娅。她站在红线中间，手上缠满了线头，指尖都勒破了。\n“我知道那些家是假的。可网一断，他们今晚住哪儿？那个老头又得一个人睡桥洞。那个孩子……”\n她没说完。屋里有个孩子在喊：“妈妈。”"
        case .q16Prelude:
            "老猎犬第三次挡在路口。项圈还是那一条，名字还是你的名字。\n这一次，远处没有哨声。\n玛拉的声音很低：“他们给它下了销号令，不会再叫它回去了。”老狗站在雨里，好像也知道。"
        case .q17Prelude:
            "签发处里，一台机械笔臂在不停地写。你抽走一张纸，下一张立刻补上，字迹一模一样，连墨点都落在同一个位置。\n“别只盯着那枚章，”玛拉说，“看是谁一直在给它送纸。”"
        case .q18Prelude:
            "裁定卫举着一份许可，纸已经黄了，日期是三年前的冬天。它挡在门前，不许任何人查城里的五处主锚。\n许可早就失效了。可一直没人来收回它，它就一直站在这里。"
        case .q19Prelude:
            "盐栈的宿舍里是一排排床铺，床头都钉着一块小木牌。木牌上的名字，有的擦掉了，有的还没来得及擦。\n床位表、押运时刻和收件印，终于对上了。\n外海要的从来不是什么旧档案，是还会呼吸的人。"
        case .q20Prelude:
            "押运车的木匣里有人在敲。很轻，很有规律：三下，停一停，再三下。\n锤卫守着车链。后面还有车，正拐向另一条岔路。\n你只救得下这一车。"
        case .q11Aftermath:
            "记忆蛭死了，屋里的笑声一下子停了。弟弟和妹妹愣愣地对看着，像两个在街上撞见的陌生人。\n只有那个女人没动。她把缺角的杯子捧在手里，杯底印着奥黛尔诊所的药柜编号。\n“我知道你不是。”她轻声说，“我儿子十二岁那年掉进排渠，到现在也没捞上来。他们说，签个字，就能再有一个孩子回家吃饭。”\n“你就不能……再坐一会儿吗？”\n你没有坐下。杯子你带走了，它属于一间还在等人的诊所。\n玛拉站在门外的雨里，一直没进来。你出门时，她终于开口：“明天，我有件事要告诉你。”"
        case .q12Aftermath:
            "调拨单最后一行，签着玛拉·格雷。\n她没有辩解，在排渠边坐了下来。雨水顺着灯罩往下滴。\n“三年前码头着火，三十一个人没地方睡。港册说，没有归属的人不能进避难所。有人递给我一张临时回执，说签了，他们今晚就有床。”\n“我签了。我以为过几天，就能把名字改回来。”\n“后来才知道，一张床空出来，就得有另一个人去填。被填进去的人里，有一个送药的年轻人。”\n她把通行证翻过来。背面那栏旧签收，是她自己的笔迹。\n“伊恩是因为我的名字不见的。那天晚上我去紫藤街口，是因为又看见一个人被写上‘已认领’。我欠的人太多了，总得先救下一个。”\n回执上夹着一卷救援录音。录音里有个男人在说：别怕，安置好就能走。"
        case .q13Aftermath:
            "核心停了。洛克跪在水里，看着自己的手，好像第一次看见它们。\n“十四个。这个月我送进去十四个。我都记得他们的脸。有个老太太，一直跟我说谢谢。”\n他胸前还有一根细线在抽紧，控制他的根不在这里。他抬手指了指名牌箱：“名字都在那里面。去吧。我……我再待一会儿。”"
        case .q14Aftermath:
            "你把伊恩的名牌摘了下来。红线没有断。它穿过排渠，连到一扇扇亮着灯的窗户，每扇窗户里都有一家人在吃晚饭。\n“拔掉一块牌，他们就会再补一个人，”玛拉说，“得找到织网的人。”\n顺着红线，你听见一个女人在叫孩子回家：“阿洛，进来，外面冷。”"
        case .q15Aftermath:
            "维娅被制住了，没有哭，也没有骂。她只求你一件事：别马上扯断整张网。\n“里面有人是真的不想再一个人了。我也是。”\n玛拉把她交给了巡官。押走的时候，她回头看了一眼那扇窗户。窗里的孩子还在等她吃饭。"
        case .q16Aftermath:
            "老猎犬倒下了。最后它没有再扑你，只是趴下来，把下巴搁在前爪上，像一条终于可以睡觉的狗。\n项圈外侧那串外海编号还亮着。追你的狗死了，要你的人还在。"
        case .q17Aftermath:
            "笔臂停了，悬在半空，最后一个字只写了一半。\n你从它底下翻出一份备用目录和一张供能图：五条线从城里五个地方接过来，最后都通向同一枚私印。私印的主人叫瑟维安，人们叫他总签官。他的钟环里，还另藏着五格积蓄。\n机器停了。签字的人还在。"
        case .q18Aftermath:
            "裁定卫倒下，那张旧许可飘到你脚边。签发日期，正是码头起火的第二天。\n玛拉捡起来看了很久：“那天晚上，所有人都在签字。签什么都行，只要能有张床。”\n五处主锚的图完整保住了。原来堵住城里裂口的，从来不必是人。"
        case .q19Aftermath:
            "翠焰熄了。你在最后一张床的枕头底下找到一只布兔子，耳朵缝过两次。\n雨烬馆的赫斯来了，沿着你查到的路线，把战后的追踪切断：“路是你们找的。我只替你们关一扇门。”\n下一批押运，已经出发了。"
        case .q20Aftermath:
            "木匣打开，里面挤着十几个人。敲匣子的是个小女孩，她敲了一路，怕外面的人忘了里面还有人。\n锤卫护着剩下的车撤走了，你记下了那条路线。\n获救的人说，送他们上车的是一个背救援架的男人。他一直在说：别怕，安置好就能走。"
        case .q5Delivery:
            "旧邮务间的灯还亮着。一个烧着绿火的邮差在柜台后面盖章，一封接一封：已送达，已送达。\n它生前大概是个很尽职的人。退回来的信堆到了天花板，它一封也不肯扔。\n柜台底下，压着诊所寄出的寻人信。"
        case .q6Prelude:
            "档案街的门卫是一具白漆的空壳，盾牌擦得能照出人影。\n“无监护人资格，不得查询已认领者。”\n“伊恩不是谁的东西。”玛拉说。\n门卫只是抬起盾，把那句话又说了一遍，一个字都没改。"
        case .q7Prelude:
            "补录处很安静，只有笔尖划纸的声音。两具空壳守卫站在台前一动不动，像两个等着下班的职员。\n台上摊着一叠空白身份牌。最上面那张背面露出一串领药号，是诊所的号码。有人正要把它刮掉，写上别人的。"
        case .q8Prelude:
            "记忆蛭张开口器，从你脑子里扯出一段东西：诊所的桌面，一只缺角的茶杯，还冒着一点热气。\n可你看到那杯茶的时候，它明明已经凉了。\n“它在拿你刚见过的东西，给你编一个从前，”玛拉说，“别认。”"
        case .q5Aftermath:
            "绿火灭了。那个邮差倒下前，把最后一封信端端正正放回柜台，盖上章：已送达。\n柜台下压着一捆根本没寄出去的寻人信，每一封都盖着同样的章。有人替收信的人回了话，替他们说：已经到家了。\n伊恩的回执也在里面，去向一栏写着：档案街监护登记处。\n玛拉把回执攥在手里，指节都白了。"
        case .q6Aftermath:
            "门卫倒下，查询口开了。\n所谓监护资格，只要一张登记过的认领回执。不用本人签字，不用本人到场，甚至不用本人知道。\n伊恩的那张回执上，签名栏是空的。去补录台，找最早的那份记录。"
        case .q7Aftermath:
            "核心熄了。你把那张身份牌翻过来，领药号还在，是伊恩自己的笔迹，最后一笔拖得很长，像在赶时间。\n他来过这里，是以自己的名字来的。\n台下有东西在动。一只记忆蛭正低声念着另一个名字，好像在替这张牌答到。"
        case .q8Aftermath:
            "记忆蛭松开了。它偷走的，只是你今天下午见过的一只杯子，算不上什么过去。\n可那一瞬间，你几乎信了。你几乎想起了一个从没去过的家。\n留下的记忆丝连着一份寻人证词。玛拉把它绕在指头上：“去找原件。别让它们替我们回答。”"
        case .opening:
            "先别追问这是谁的梦。三条途径在雾港留下了回声。\n此刻，只有帷幕之径向你敞开。"
        case .cityMission:
            "欢迎来到雾港。这里雾大，人多，名字很容易丢。\n旧城区有一份委托在等你。先去那里。"
        case .mapEntry:
            "从紫藤街口进去。现在能走的路，只有这一条。"
        case .firstBattle:
            "第三次了。你明明砍进了它的肩甲，伤口却跟着钟声一点点合拢。\n不是你没打中。是有人不许它在这里倒下。"
        case .rainFirstAftermath:
            "守卫倒在水洼里，胸牌还亮着：已认领。\n玛拉替你拧干领口的雨水，动作熟得像做过很多次。她递来一张旧通行证、一罐止痛膏。手指在通行证背面停了一下，又收了回去。\n“先活着走出这条街。是谁替你签的字，明天再问。”"
        case .fogGhostPrelude:
            "两道幽灵守着一叠被退回的寻人信，不肯走。\n信页翻动时，有个孩子的声音一遍遍地说：“别送我回家。”"
        case .houndPrelude:
            "寻人信上的追索记录惊动了它。一条老猎犬从雾里走出来，径直盯住了你。"
        case .secondBattle:
            "猎犬喉间两团火一起亮起时，使用遗落物『无主假面』，让幻影接住两发追索火球。\n挡住两颗火球后，三秒内点击『反击』：普通牌冷却刷新，从编排第一张重新出手。常态护体会削弱你的输出，反击时才能打开缺口。先『污名记』、后『侧身刺』，连招会更有力。假面不占技能编排，每隔十八秒可以再次手动使用，幻影只维持四秒。反击不刷新假面和大招，也不会额外收费。之后防住精英与强敌的重招，同样能获得反击机会。"
        case .rainInterlude:
            "幽灵散了，那叠信落在水里。你捡起最上面那封，墨已经化开，只有“别送我回家”几个字还看得清。\n玛拉把信折好，收进了自己怀里，没有交给你。\n“旧邮务间该有底联。”她说。雾里响起犬吠，有什么东西循着你的名字找来了。"
        case .q3Aftermath:
            "猎犬退进雾里，留下半截项圈。皮子内侧刻着你的名字，字迹工整，像在替人填表。\n名字旁边还有一串编号，不是雾港的格式。你把项圈碎片和它撞落的迟秒怀表一起收好。"
        case .q4Aftermath:
            "召回的哨声从远处响起。老猎犬犹豫了一下，转身走了，像是被人叫回家吃饭。\n玛拉送你到诊所门口，自己没有进去。\n奥黛尔·芬是个瘦小的女人，白大褂的袖口磨起了毛。桌上摆着两只杯子，一只是她的，一只缺了个角，茶早凉透了。\n“伊恩的。他去送药，一直没回来。这孩子每次进门都嫌我的茶凉，可我还是每天给他倒一杯。倒了，就好像他今天会回来。”\n她推过来一叠退回的寻人信，每一封都盖着：已送达。\n“他们说他被家里人领走了。”她笑了一下，“伊恩没有家里人。他只有这间诊所。”\n你出门时，玛拉还站在雨里，背对着诊所的窗。去旧邮务间，查清这份“已送达”。"
        case .q5PaperDoubleIntervention:
            "看它身上的绿焰。\n那是重击将至的信号。\n现在手动使用『无主假面』，让幻影接下这一击。\n重击被接住后，三秒内点击『反击』，重启普通牌的编排。毒雾仍会加浓，必须尽快结束战斗。"
        }
    }

    /// How the fight or the new card works, as the last page after the story (2026-10-18:
    /// story and rules no longer share a page). Goals that `prebattleObjective` already
    /// shows above the battle are not repeated here.
    var hint: String? {
        switch self {
        case .rainFirstAftermath: "『侧身刺』现在属于你了。下一关会得到第二张技能牌。"
        case .q4Aftermath: "奥黛尔交给你『僭命勋章』：借你八秒强盛，期限一到，收走你剩下生命的一半，挡不了毒，也挡不了刀。出发前，在它和假面之间选一个。"
        case .q5Delivery: "毒雾会越来越浓，直到战斗结束。它全身燃起绿焰时，重击就要来了。选好主动遗落物再进去。"
        case .q6Prelude: "它封存时装甲严丝合缝，出击后才要重新对齐。等它收盾的空隙再打。"
        case .q7Prelude: "后方的寄忆核心在不断修复守卫。先停下它，保住那张牌。"
        case .q8Prelude: "你习得『错认喜剧』：误认不足四层时造成伤害并加一层；满四层再释放，会转成错位，推迟目标的行动。战斗按编排顺序自动出牌。"
        case .q9Prelude: "先打掉持续覆盖证词的核心。这一关仍只有两个技能格。"
        case .q9Aftermath: "改过的记录给奥黛尔记了一笔污名。玛拉把这笔污名封成『污名记』：先留下标记，再接伤害技能。技能格仍为两格；角色页开放四点天赋。"
        case .q10Prelude: "可以带上『污名记』，让后面的伤害吃到标记。通关后开放四个技能格。"
        case .q10Aftermath: "你学会追索被覆盖的残影：『双星追猎』。技能格扩为四格。"
        case .q11Prelude: "两只记忆蛭轮流维持这屋子的回忆，空壳守卫守着门。"
        case .q11Aftermath: "你从这场荒唐里习得『归谬法』。"
        case .q12Prelude: "两个书记员交替封存、校正和重击。校正会抹掉你的护盾。"
        case .q12Aftermath: "你习得『突转』，下一战可以编入序列。"
        case .q13Prelude: "寄忆核心在改写他的命令。打掉核心，切断这里的控制，留他活着。"
        case .q13Aftermath: "你从两份命令的回声里习得终极技能『我名无人』，每场战斗可以手动放一次。"
        case .q14Prelude: "每个目标的误认和错位分开记。先决定控制谁，再把后面的牌接到同一个目标上。"
        case .q15Prelude: "两枚寄忆核心轮流把记录写回去。先切断支援，再制住她。她要活着。"
        case .q15Aftermath: "先回主城整理物证。后面的调查，要等对应关卡开放。"
        case .q21Prelude: "先打掉转接核心，再拆背架上的控制。"
        case .q22Prelude: "阻止她补位。她会活下来。"
        case .q24Prelude: "幽灵被打散后，会分出两道赤红子体。"
        case .q26Prelude: "结算的『对敌伤害』只算锤卫本体。"
        default: nil
        }
    }

    var kicker: String {
        switch self {
        case .q30Aftermath: "无主者的签名 · 尾声"
        case .q30Prelude: "无主者的签名"
        case .q29Aftermath: "最后的代签 · 事后"
        case .q29Prelude: "最后的代签"
        case .q28Aftermath: "五次回流 · 事后"
        case .q28Prelude: "五次回流"
        case .q27Aftermath: "未签署的归属 · 事后"
        case .q27Prelude: "未签署的归属"
        case .q26Aftermath: "最后一趟押运 · 事后"
        case .q26Prelude: "最后一趟押运"
        case .q25Aftermath: "阿姨，你找谁"
        case .q25Prelude: "自愿断线"
        case .q24Aftermath: "他自己摔的"
        case .q24Prelude: "地下泊位"
        case .q23Aftermath: "不以人名封口 · 事后"
        case .q23Prelude: "不以人名封口"
        case .q22Aftermath: "没干的墨"
        case .q22Prelude: "不属于你的庇护"
        case .q21Aftermath: "三百一十二个"
        case .q21Prelude: "原始救援条款"
        case .q5Delivery: "旧邮务间 · 不肯落幕"
        case .q6Prelude: "档案街入口 · 监护资格"
        case .q9Prelude: "工坊 · 证词覆写"
        case .q10Prelude: "失踪名单 · 虚假的地址"
        case .q9Aftermath: "七次报案"
        case .q10Aftermath: "烧没了的地址"
        case .q11Prelude: "四副碗筷"
        case .q12Prelude: "调拨处 · 空缺补位"
        case .q13Prelude: "排渠里的救援者"
        case .q14Prelude: "伊恩的名牌 · 红线"
        case .q15Prelude: "维娅 · 归属网"
        case .q16Prelude: "销号追索"
        case .q17Prelude: "自动补位"
        case .q18Prelude: "无效的许可"
        case .q19Prelude: "外海收件人"
        case .q20Prelude: "押运中的活档案"
        case .q11Aftermath: "再坐一会儿"
        case .q12Aftermath: "玛拉的签名"
        case .q13Aftermath: "十四张脸"
        case .q14Aftermath: "亮着灯的窗户"
        case .q15Aftermath: "窗里的孩子"
        case .q16Aftermath: "老狗睡了"
        case .q17Aftermath: "自动补位 · 事后"
        case .q18Aftermath: "无效的许可 · 事后"
        case .q19Aftermath: "布兔子"
        case .q20Aftermath: "敲匣子的人"
        case .q7Prelude: "补录处 · 寄忆核心"
        case .q8Prelude: "不属于我的名字 · 错认喜剧"
        case .q5Aftermath: "已送达"
        case .q6Aftermath: "空着的签名栏"
        case .q7Aftermath: "赶时间的笔迹"
        case .q8Aftermath: "从没去过的家"
        case .opening: "静幕引路人"
        case .cityMission: "第一项委托"
        case .mapEntry: "跟随指引"
        case .firstBattle: "第一场战斗 · 雨中的空壳"
        case .rainFirstAftermath: "已认领"
        case .fogGhostPrelude: "雾都幽灵 · 退回的寻人信"
        case .houndPrelude: "循名而来的猎犬"
        case .secondBattle: "假面与追索之火"
        case .rainInterlude: "别送我回家"
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
            return [.init(kicker: kicker, message: message, actionTitle: actionTitle)]
        }
        if self == .houndPrelude {
            return [
                .init(kicker: "循名而来的猎犬", message: "寻人信上的追索记录惊动了它。\n一条老猎犬从雾里走出来。项圈勒进脖子上的毛里，磨秃了一圈。它不叫，只盯着你，像在核对一张画像。", actionTitle: "继续聆听"),
                .init(kicker: "玛拉的赠予", message: "玛拉从衣袋里摸出一张旧假面，边角都磨圆了。\n“『无主假面』。追你的东西，会把它变出来的影子当成你。”她顿了顿，“我戴过很多年。”", actionTitle: "接过无主假面"),
                .init(kicker: "以假乱真", message: "假面不需要编入技能。开战后，由你点击使用。\n它唤出的幻影只维持四秒，最多承受两次直接攻击；十八秒后才能再次使用，持续伤害无法阻挡。眼前两场猎犬教学不损耗假面。之后每次使用都会留一道永久紫裂纹，十道后失效。\n猎犬喉间两团火一起亮起，就是连续两次喷吐的信号——立刻点假面。硬扛两次喷吐会倒下，一次假面可以全部承接。双喷之间它仍会咬击，下一轮喷吐前，假面的冷却会结束。", actionTitle: "继续聆听"),
                .init(kicker: "烧不掉的记录", message: "别杀它。打退它，留下项圈。\n我想知道，是谁让它来找你的。", actionTitle: "准备迎战")
            ]
        }
        if self == .fogGhostPrelude {
            return [
                .init(kicker: "退回的寻人信", message: "两道幽灵蹲在邮筒边，把同一叠信塞进去，又被退出来，一遍又一遍。", actionTitle: "继续聆听"),
                .init(kicker: "别送我回家", message: "最上面那封的字很歪，像刚学会写字：\n“妈妈，我在这里有床睡，有饭吃。他们说下个月送我回家。我不认识那个家。别送我回家。”\n退信戳盖得端端正正：家属已领回。", actionTitle: "继续聆听"),
                .init(kicker: "玛拉", message: "玛拉按住那封信，很久没说话。\n“先把信留下，”她说，“它们怕的不是你。”", actionTitle: "继续聆听"),
                .init(kicker: "提示", message: "怨影被打散后，会各分成两道赤红残影，攻势更快。", actionTitle: "准备迎战")
            ]
        }
        if case .firstBattle = self {
            return [
                .init(
                    kicker: "第三次命中",
                    message: message,
                    actionTitle: "继续"
                ),
                .init(
                    kicker: "玛拉",
                    message: "雨棚下站着一个提灯的女人。她没问你从哪里来，只看了一眼守卫胸前的牌子。\n“它说你已经被人领走了。”她把灯压低，“可你还记得自己叫什么，对吧？那就先别信它。”\n“我叫玛拉。接着。”",
                    actionTitle: "接过卡牌"
                ),
                .init(
                    kicker: "侧身刺",
                    message: "别再砍它的盔甲了。\n那只是它想让你看见的地方。\n用这张牌，打它没防着的那一侧。",
                    actionTitle: "使用侧身刺"
                )
            ]
        }
        guard self == .opening else {
            guard let hint else { return [.init(kicker: kicker, message: message, actionTitle: actionTitle)] }
            return [
                .init(kicker: kicker, message: message, actionTitle: "继续"),
                .init(kicker: "提示", message: hint, actionTitle: actionTitle)
            ]
        }
        return [
            .init(
                kicker: "途径选择",
                message: "先别追问这是谁的梦。三条途径在雾港留下了回声。\n此刻，只有帷幕之径向你敞开。",
                actionTitle: "继续聆听"
            ),
            .init(
                kicker: "帷幕之径",
                message: "帷幕之径借错误掩盖真实，在对手发现伤口之前制造破绽。\n选择这条途径之后，你需要记住一件事——谎言用得越久，就越容易忘记自己原本是谁。",
                actionTitle: "继续聆听"
            ),
            .init(
                kicker: "潮忆之径",
                message: "潮忆之径行走于梦境与沉默之间，寻找那些被人遗忘的名字。\n她能够听见常人无法察觉的声音，但听得太多，也可能分不清哪些记忆属于自己。",
                actionTitle: "继续聆听"
            ),
            .init(
                kicker: "远征之径",
                message: "远征之径相信意志能够先于恐惧抵达。\n它会帮助你突破封锁，正面击溃敌人。\n不过，每一次向前，都意味着退路会变得更远。",
                actionTitle: "继续聆听"
            ),
            .init(
                kicker: "选择",
                message: "沿着帷幕之径，试着穿过雾港。\n命运或许正在旁观，但它不会替你承担结果。",
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
        GeometryReader { proxy in
            // Reserve the nameplate and its bottom inset even on shorter screens.
            let portraitTop: CGFloat = 188
            let nameplateClearance: CGFloat = 132
            let portraitHeight = min(500, max(0, proxy.size.height - portraitTop - nameplateClearance))

            ZStack(alignment: .bottom) {
                MirielStardustAura()
                    .frame(width: 450, height: 610)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 160)
                    .offset(x: 38)
                    .accessibilityHidden(true)

                GuideMirielPortrait()
                    .frame(width: 270, height: portraitHeight, alignment: .bottom)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    // Lift the full silhouette above the reserved nameplate area.
                    .padding(.top, portraitTop)
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
                    .padding(.top, 167)
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

                // The only skip control lives in the bubble footer (user, 2026-10-05:
                // two skip buttons on one page is one too many).
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private var dialogueBubble: some View {
        // The bubble itself advances on tap; the footer holds real buttons so
        // "跳过对白" also lives inside the bubble. The bottom-left skip capsule
        // never received taps after a battle (playtest 2026-10-05, Q10–Q13),
        // while the bubble always did.
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
        .onTapGesture(perform: advanceDialogue)
        .background(dialogueBubbleBackground)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isComplete ? "继续" : "显示完整文字")
    }

    private func skipDialogue() {
        #if DEBUG
        NSLog("[MistportGuide] skip tapped cue=%@ page=%d accepts=%d", cue.rawValue, pageIndex, acceptsPageAdvance ? 1 : 0)
        #endif
        guard acceptsPageAdvance else { return }
        acceptsPageAdvance = false
        onDismiss()
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
        HStack(spacing: 8) {
            if isComplete, !isLastPage {
                Button(action: skipDialogue) {
                    Text("跳过对白 ›")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.55).opacity(0.9))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.black.opacity(0.35)))
                        .overlay(Capsule().stroke(Color(red: 1.0, green: 0.75, blue: 0.24).opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chapter-one-guide-skip")
            }
            Spacer(minLength: 0)
            if isComplete {
                Button(action: advanceDialogue) {
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
                }
                .buttonStyle(.plain)
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
