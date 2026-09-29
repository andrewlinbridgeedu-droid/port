import Foundation

/// Content preview of the first world event, 《谁让雾港重新亮灯》: overview,
/// the eight main articles L01–L08, both project ledgers and the result.
/// Every number comes from a hypothetical snapshot, never from real players;
/// articles are chosen by what the snapshot actually records, so a headline
/// is never printed for a fact that did not happen. Nothing here moves money.
public enum MPCLightsEventPreview {
    public static let ruleVersion = "lights-event-preview-v1"
    public static let hypotheticalNotice = "假设快照：数字由开发夹具生成，不是任何真实玩家的行动。"
    public static let kitSlots = 12
    /// First-test quote: 2 filter cloth (12) + 2 straps (9) + 2 tins (9).
    public static let kitPrice = 60
    public static let fundingCap = 1200
    public static let perAccountCap = 120
    public static let minimumSuccessfulAccounts = 4

    public typealias Faction = MPCWorldCampaignPrototype.Faction

    public enum Phase: Codable, Equatable, Sendable {
        case preparation(day: Int)   // days 1–7
        case publicAction(day: Int)  // days 8–9
        case core                    // day 10
        case settled

        public var dayIndex: Int {
            switch self {
            case .preparation(let day): min(max(day, 1), 7)
            case .publicAction(let day): min(max(day, 8), 9)
            case .core: 10
            case .settled: 11
            }
        }
        public var title: String {
            switch self {
            case .preparation(let day): "准备期 · 第\(dayIndex)日"
            case .publicAction: "公共行动 · 第\(dayIndex)日"
            case .core: "核心窗口 · 第10日"
            case .settled: "已结算"
            }
        }
    }

    public struct Ledger: Codable, Equatable, Sendable {
        public let raised: Int
        public let investors: Int
        public let installedKits: Int
        /// Funded orders placed but not yet delivered and installed.
        public let orderedKits: Int
        public let publicScore: Int
        public let successfulAccounts: Int

        public init(raised: Int, investors: Int, installedKits: Int, orderedKits: Int,
                    publicScore: Int = 0, successfulAccounts: Int = 0) {
            self.raised = raised; self.investors = investors; self.installedKits = installedKits
            self.orderedKits = orderedKits; self.publicScore = publicScore; self.successfulAccounts = successfulAccounts
        }

        public var spent: Int { installedKits * kitPrice }
        public var committed: Int { orderedKits * kitPrice }
        public var cash: Int { raised - spent - committed }
        public var missingKits: Int { kitSlots - installedKits - orderedKits }
        /// New orders the remaining cash can actually pay for.
        public var fundableKits: Int { min(missingKits, cash / kitPrice) }
        public var worksComplete: Bool { installedKits == kitSlots }
        public var qualified: Bool { worksComplete && successfulAccounts >= minimumSuccessfulAccounts }

        public var isConsistent: Bool {
            raised >= 0 && raised <= fundingCap && investors >= 0 && raised <= investors * perAccountCap
                && installedKits >= 0 && orderedKits >= 0 && missingKits >= 0 && cash >= 0
                && publicScore >= 0 && successfulAccounts >= 0
        }
    }

    public enum Contract: Equatable, Sendable {
        case awarded(Faction)
        case interim(InterimReason)
    }
    public enum InterimReason: String, Equatable, Sendable { case tie, noneQualified, bothDead }
    public enum Failure: Error, Equatable { case unreachableOutcome, inconsistentLedger }

    /// Section 7 table of the event design. Death combinations that no legal
    /// ticket can produce are refused rather than mapped to a contract.
    public static func contract(pumps: Ledger, shipping: Ledger, aidaDead: Bool, rowanDead: Bool) throws -> Contract {
        let pq = pumps.qualified, sq = shipping.qualified
        switch (aidaDead, rowanDead) {
        case (false, false):
            if pq && sq {
                if pumps.publicScore == shipping.publicScore { return .interim(.tie) }
                return .awarded(pumps.publicScore > shipping.publicScore ? .pumps : .shipping)
            }
            if pq { return .awarded(.pumps) }
            if sq { return .awarded(.shipping) }
            return .interim(.noneQualified)
        case (true, false), (false, true):
            guard pq || sq else { throw Failure.unreachableOutcome }
            let survivor: Faction = aidaDead ? .shipping : .pumps
            let survivorQualified = survivor == .pumps ? pq : sq
            return survivorQualified ? .awarded(survivor) : .interim(.noneQualified)
        case (true, true):
            guard pq && sq else { throw Failure.unreachableOutcome }
            return .interim(.bothDead)
        }
    }

    /// Core opportunities once the public window closes: leader 6 / trailing 4,
    /// tie 5 / 5, a lone qualified side 6 / 0. Candidate counts may lower them.
    public static func coreOpportunities(pumps: Ledger, shipping: Ledger) -> [Faction: Int] {
        switch (pumps.qualified, shipping.qualified) {
        case (true, true):
            if pumps.publicScore == shipping.publicScore { return [.pumps: 5, .shipping: 5] }
            return pumps.publicScore > shipping.publicScore ? [.pumps: 6, .shipping: 4] : [.pumps: 4, .shipping: 6]
        case (true, false): return [.pumps: 6, .shipping: 0]
        case (false, true): return [.pumps: 0, .shipping: 6]
        case (false, false): return [.pumps: 0, .shipping: 0]
        }
    }

    public struct Snapshot: Codable, Equatable, Sendable, Identifiable {
        public let id: String
        public let label: String
        public let phase: Phase
        public let pumps: Ledger
        public let shipping: Ledger
        public let aidaDead: Bool
        public let rowanDead: Bool

        public init(id: String, label: String, phase: Phase, pumps: Ledger, shipping: Ledger,
                    aidaDead: Bool = false, rowanDead: Bool = false) {
            self.id = id; self.label = label; self.phase = phase; self.pumps = pumps
            self.shipping = shipping; self.aidaDead = aidaDead; self.rowanDead = rowanDead
        }

        public func ledger(_ faction: Faction) -> Ledger { faction == .pumps ? pumps : shipping }

        /// Deaths are only settled facts; before settlement both are alive.
        public func validate() throws {
            guard pumps.isConsistent, shipping.isConsistent else { throw Failure.inconsistentLedger }
            if phase != .settled, aidaDead || rowanDead { throw Failure.unreachableOutcome }
            if phase == .settled { _ = try MPCLightsEventPreview.contract(pumps: pumps, shipping: shipping, aidaDead: aidaDead, rowanDead: rowanDead) }
        }

        public var contract: Contract? {
            guard phase == .settled else { return nil }
            return try? MPCLightsEventPreview.contract(pumps: pumps, shipping: shipping, aidaDead: aidaDead, rowanDead: rowanDead)
        }
    }

    public static func projectName(_ faction: Faction) -> String { faction == .pumps ? "泵站联合会项目" : "灰帆联营项目" }
    public static func sideName(_ faction: Faction) -> String { faction == .pumps ? "泵站联合会" : "灰帆联营" }

    // MARK: Articles

    public enum Link: String, Codable, Sendable { case plans, ledger, result }

    public struct Article: Equatable, Sendable, Identifiable {
        public let id: String
        public let day: String
        public let headline: String
        /// Which branch of the article the snapshot selected.
        public let variant: String
        public let paragraphs: [String]
        public let links: [Link]
    }

    /// Articles already due in this snapshot, oldest first.
    public static func articles(for s: Snapshot) -> [Article] {
        let day = s.phase.dayIndex
        var out: [Article] = []
        out.append(Article(id: "L01", day: "第1日", headline: "第三夜熄灯：旧港剩余的燃料只能先送往一条线路", variant: "开场", paragraphs: [
            "夜班药剂师把最后一盏灯移到配药台，住宅楼的楼梯又一次陷入黑暗。诊所尚能依靠备用供能维持，但工坊已开始取消夜班。",
            "泵站联合会要把供能先接回居民区；灰帆联营坚持先让码头和工坊复工，才能买到下一船燃料。两家提交了互不兼容的接驳方案，争的是未来三十天的供能经营权。",
            "外港转运站的维修和采购即将开放。你可以支持一方、出售他们需要的物资，也可以先看看两份计划。",
        ], links: [.plans]))
        guard day >= 2 else { return out }
        out.append(Article(id: "L02", day: "第2日", headline: "两份账册放上同一张桌子", variant: "配置已冻结", paragraphs: [
            "艾妲在账册上先圈出了诊所和住宅支路。罗文把一张迟到的燃料船回执压在旁边：他认为先恢复装卸，城市才付得起后续的修理。",
            "两人同意公布本次采购与施工记录，却没有接受共用主接驳装置的提议。投资人取得的是项目收益份额，不是保本凭据。你可以支持其中一方，也可以等第一批订单完成后再决定。",
        ], links: [.plans, .ledger]))
        guard day >= 3 else { return out }
        out.append(orderArticle(s))
        guard day >= 4 else { return out }
        out.append(Article(id: "L04", day: "第4—5日", headline: "谁先锁住了总闸", variant: "记录公开", paragraphs: [
            "公报拿到了两张带日期的记录：灰帆先扣下了一批原应交给维修队的燃料，联合会随后封存调试权限。记录足以说明各自做过什么，不能证明另一方的一切指控。",
            "外港已经出现武装封锁。艾妲以两名护卫维持阵列，罗文让支援者轮流给控制装置回流。调查员把已核实的攻击征兆一并公开：别把别人的失败当作必须买某件昂贵封印物的证明。",
        ], links: [.plans]))
        guard day >= 7 else { return out }
        out.append(eveArticle(s))
        guard day >= 8 else { return out }
        out.append(publicArticle(s))
        guard day >= 10 else { return out }
        out.append(coreArticle(s))
        if let contract = s.contract { out.append(resultArticle(s, contract)) }
        return out
    }

    private static func orderArticle(_ s: Snapshot) -> Article {
        let lines = Faction.allCases.map { f -> String in
            let l = s.ledger(f)
            if l.worksComplete { return "\(projectName(f))：本阶段验收完毕，不再收取多余物资。" }
            if l.orderedKits > 0 {
                let n = l.orderedKits * 2
                return "\(projectName(f))目前还可验收过滤布\(n)件、维修绑带\(n)件、锡罐\(n)件；它们将组成检修组具，安装在这条支路的十二个滤筒位。"
            }
            return "\(projectName(f))：尚无可付款的新订单，已做成的商品仍属卖家。"
        }
        let variant = Faction.allCases.map { f -> String in
            let l = s.ledger(f)
            return l.worksComplete ? "已满" : l.orderedKits > 0 ? "有资金" : "预算不足"
        }.joined(separator: " / ")
        return Article(id: "L03", day: "第3日", headline: "第一批订单，不收没有去处的货", variant: variant,
                       paragraphs: ["转运站开放了有资金的采购。"] + lines
                           + ["已安装的部分会留在设施上，不因合同落败退回投资者。请先查看当前剩余订单，再决定是否生产。个人战斗用药不在这张工程单里。"],
                       links: [.ledger])
    }

    private static func eveArticle(_ s: Snapshot) -> Article {
        let lines = Faction.allCases.map { f -> String in
            let l = s.ledger(f)
            var text = "\(projectName(f))已验收\(l.installedKits)/\(kitSlots)处滤筒位，已花\(l.spent)铜，还有\(l.committed)铜对应未完成订单。"
            if !l.worksComplete { text += "尚缺\(kitSlots - l.installedKits)套组具，其中\(l.missingKits)套还没有下单，账上现金可再付\(l.fundableKits)套。" }
            return text
        }
        let ready = s.pumps.worksComplete && s.shipping.worksComplete
        return Article(id: "L05", day: "第7日", headline: "最后一夜，准备账不替任何人许诺胜利", variant: ready ? "两方工程完成" : "尚有缺口",
                       paragraphs: ["截至第7日快照："] + lines + [
                           "公共行动将在第8日开放。免费支持者同样可以参加。普通目标有实际贡献；高难节点需要更准确地处理机制。投资不会买到挑战资格，带药也不是报名条件。未准备好的项目仍可在公开截止前补缺，规则不会临时加码。",
                       ], links: [.ledger])
    }

    private static func publicArticle(_ s: Snapshot) -> Article {
        let p = s.pumps, g = s.shipping
        if p.publicScore == 0 && g.publicScore == 0 {
            return Article(id: "L06", day: "第8—9日", headline: "这不是只有十二个人的名字", variant: "尚无记录", paragraphs: [
                "尚无完成记录，不能据此判断谁已占据上风。普通行动、困难节点和已验收工程将分别列出。",
            ], links: [.ledger])
        }
        let scores = "\(sideName(.pumps))累计\(p.publicScore)点（\(p.successfulAccounts)个账号成功），\(sideName(.shipping))累计\(g.publicScore)点（\(g.successfulAccounts)个账号成功）。"
        return Article(id: "L06", day: "第8—9日", headline: "这不是只有十二个人的名字",
                       variant: p.publicScore == g.publicScore ? "同分" : "有领先方", paragraphs: [
            scores,
            "公共行动的领先方先取得合同候选资格，也得到更多最终突破机会。工匠的货物已经安装在哪些位置、普通行动解除过哪些阻碍，都保留在事件记录中；最后一击不会吞掉这些贡献。",
        ], links: [.ledger])
    }

    private static func coreArticle(_ s: Snapshot) -> Article {
        let chances = coreOpportunities(pumps: s.pumps, shipping: s.shipping)
        let status = Faction.allCases.map { f -> String in
            let l = s.ledger(f)
            if l.qualified { return "\(sideName(f))取得资格，获得\(chances[f, default: 0])次突破机会" }
            if !l.worksComplete { return "\(sideName(f))工程未完成，未取得资格" }
            return "\(sideName(f))成功账号不足\(minimumSuccessfulAccounts)个，未取得资格"
        }.joined(separator: "；")
        return Article(id: "L07", day: "第10日", headline: "工程优先权已定，人物命运仍未定",
                       variant: s.pumps.qualified || s.shipping.qualified ? "有资格方" : "双方均无资格", paragraphs: [
            "公共窗口已经关闭。\(status)。工程验收和最终人物状态将在结算时一并确认，合同尚未发放。",
            "此前完成的普通节点已经影响这个结果。核心行动非常危险；它能使对方负责人永久退出这条世界线，也可能改变经营权归属。没有取得核心名额的人仍能关注公开回执与准备账，不必额外交钱才能保住已有贡献。",
        ], links: [.ledger])
    }

    public static func npcResult(aidaDead: Bool, rowanDead: Bool) -> String {
        switch (aidaDead, rowanDead) {
        case (false, false): "两位负责人均存活"
        case (true, false): "艾妲·维恩确认死亡，联合会由副手主持清算"
        case (false, true): "罗文·凯尔确认死亡，联营由副手主持清算"
        case (true, true): "两位负责人均确认死亡"
        }
    }

    private static func resultArticle(_ s: Snapshot, _ contract: Contract) -> Article {
        let npc = npcResult(aidaDead: s.aidaDead, rowanDead: s.rowanDead)
        let mine = "你在这份快照中没有投资、交货或行动记录"
        switch contract {
        case .awarded(.pumps):
            return Article(id: "L08", day: "结算后", headline: "灯亮起来以后", variant: "联合会取得合同", paragraphs: [
                "旧港住宅支路在今晚恢复了新增供能，诊所的第二张工作台重新开灯。联合会取得三十日经营权。\(npc)。",
                "转运站采购过的物资已经成为设施的一部分。项目能否回本，还要看之后有没有真实客户；今天没有按投资额发放胜利奖金。\(mine)。",
            ], links: [.result, .ledger])
        case .awarded(.shipping):
            return Article(id: "L08", day: "结算后", headline: "灯亮起来以后", variant: "灰帆取得合同", paragraphs: [
                "外港吊机重新转动，第一批经确认的燃料货物开始按新班次装卸。灰帆取得三十日经营权；部分住宅增量线路仍列在下一阶段施工单上。\(npc)。",
                "班次增加不代表每船都有人买单。项目账将分别公开实际服务收入、采购成本与可分配经营现金。\(mine)。",
            ], links: [.result, .ledger])
        case .interim(let reason):
            let why = switch reason {
            case .tie: "两方都取得工程资格，公共分相同，人物均存活"
            case .noneQualified: "没有一方同时完成十二处工程并有至少四个账号成功"
            case .bothDead: "两位负责人均确认死亡，合同不同时发给两家"
            }
            let works = Faction.allCases.map { "\(projectName($0))\(s.ledger($0).installedKits)处滤筒位" }.joined(separator: "、")
            return Article(id: "L08", day: "结算后", headline: "灯亮起来以后", variant: "临时接管", paragraphs: [
                "本轮未能确定唯一的合格经营者，市政启用事先保留的基础应急供能。\(why)。这不等于过去十天什么都没有留下：\(works)已经验收，相关交货和行动仍在记录中。",
                "未使用资金按合同清算；未交付或未安装的物资仍在各自账上，不为制造战损而抹去。新的负责人和下一次合同会另行公布，死者不会重新回来当首领。",
            ], links: [.result, .ledger])
        }
    }

    // MARK: Fixtures

    /// Hypothetical snapshots for the content preview; labelled as such everywhere.
    public static let fixtures: [Snapshot] = [
        Snapshot(id: "prep-day3", label: "准备期第3日：两方都在筹资",
                 phase: .preparation(day: 3),
                 pumps: Ledger(raised: 840, investors: 9, installedKits: 5, orderedKits: 2),
                 shipping: Ledger(raised: 360, investors: 4, installedKits: 2, orderedKits: 0)),
        Snapshot(id: "prep-day7", label: "准备末期：联合会完工，灰帆尚缺三套",
                 phase: .preparation(day: 7),
                 pumps: Ledger(raised: 1200, investors: 12, installedKits: 12, orderedKits: 0),
                 shipping: Ledger(raised: 720, investors: 7, installedKits: 9, orderedKits: 0)),
        Snapshot(id: "public-day9", label: "公共行动第9日：联合会领先",
                 phase: .publicAction(day: 9),
                 pumps: Ledger(raised: 1200, investors: 12, installedKits: 12, orderedKits: 0, publicScore: 38, successfulAccounts: 21),
                 shipping: Ledger(raised: 900, investors: 9, installedKits: 12, orderedKits: 0, publicScore: 31, successfulAccounts: 17)),
        Snapshot(id: "settled-pumps", label: "结算：联合会领先取得合同，两人存活",
                 phase: .settled,
                 pumps: Ledger(raised: 1200, investors: 12, installedKits: 12, orderedKits: 0, publicScore: 44, successfulAccounts: 24),
                 shipping: Ledger(raised: 900, investors: 9, installedKits: 12, orderedKits: 0, publicScore: 37, successfulAccounts: 19)),
        Snapshot(id: "settled-shipping-aida-dead", label: "结算：艾妲死亡，落后的灰帆取得合同",
                 phase: .settled,
                 pumps: Ledger(raised: 1200, investors: 12, installedKits: 12, orderedKits: 0, publicScore: 44, successfulAccounts: 24),
                 shipping: Ledger(raised: 900, investors: 9, installedKits: 12, orderedKits: 0, publicScore: 37, successfulAccounts: 19),
                 aidaDead: true),
        Snapshot(id: "settled-interim-tie", label: "结算：同分，两人存活，临时接管",
                 phase: .settled,
                 pumps: Ledger(raised: 1200, investors: 12, installedKits: 12, orderedKits: 0, publicScore: 40, successfulAccounts: 22),
                 shipping: Ledger(raised: 960, investors: 9, installedKits: 12, orderedKits: 0, publicScore: 40, successfulAccounts: 20)),
    ]
}
