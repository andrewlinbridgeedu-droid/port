import SwiftUI
import Observation
import MistportCombatCore

@MainActor @Observable final class WorkshopPlaytestModel {
    var trial = MPCWorkshopPlaytest()
    var running = false
    var passive = "none"
    var medal = false
    var message = "先读公报，看看你希望哪条线路先恢复。"
    var exportPath = ""
    var resetConfirmation = false
    func act(_ action: (inout MPCWorkshopPlaytest) throws -> Void) {
        do { try action(&trial); message = trial.entries.last?.text ?? "已完成。" }
        catch { message = explain(error) }
    }
    func start(_ purpose: MPCWorkshopPlaytest.Purpose) {
        do {
            try trial.begin(purpose, passive: passive == "none" ? nil : passive, medal: medal)
            running = true; message = "选择目标后使用技能。1–4为技能，5为普攻，M用药。"
        } catch { message = explain(error) }
    }
    func tick() {
        guard running, let battle = trial.battle else { return }
        do { try trial.advance(to: battle.time + 0.05) }
        catch { running = false; message = explain(error) }
        if trial.canSettleBattle { running = false; message = "战斗已结束，查看结果后领取本场回执。" }
        else if let current = trial.battle,
                !current.session.enemies.contains(where: { $0.id == current.selectedTarget && $0.isAlive }),
                let next = current.session.enemies.last(where: \.isAlive) {
            trial.target(next.id)
            message = "原目标已击破，已切换至\(next.name)。你仍可点击其他敌人切换目标。"
        }
    }
    func reset() { running = false; trial = .init(); passive = "none"; medal = false; exportPath = ""; message = "已新建隔离试玩，不影响任何正式存档。" }
    func export() {
        running = false
        let dir = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("Records", isDirectory: true)
        let url = dir.appendingPathComponent("workshop-\(UUID().uuidString).json")
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try encoder.encode(trial.snapshots).write(to: url, options: .atomic)
            exportPath = url.path; message = "本次已结算钱物与战斗回执已导出；正在进行的战斗未结算，试玩已暂停。"
        } catch { message = "无法导出：\(error)" }
    }
    func explain(_ error: Error) -> String {
        guard let e = error as? MPCWorkshopPlaytest.Failure else { return "暂未完成：\(error)" }
        switch e {
        case .busy: return "先完成或撤退当前战斗，再处理工坊与订单。"
        case .locked: return "条件尚未满足：检查战斗回执、材料、工程或已使用的公共尝试。高级配方另需熟练度20及已学习图纸。"
        case .funds: return "余额不足，不会透支或自动借款。"
        case .stock: return "材料、成品或采购数量不符合要求。"
        case .conflict: return "回执编号冲突；此次操作未生效。"
        case .unfinished: return "战斗尚未结束，不能领取胜利回执。"
        case .closed: return "采购额度或事件已结束；多余物品仍保留在背包。"
        }
    }
}

struct WorkshopPlaytestView: View {
    @State private var model = WorkshopPlaytestModel()
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private let accent = Color(red: 0.83, green: 0.69, blue: 0.43)
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            sidebar.frame(width: 245).padding(24).background(.black.opacity(0.2))
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("雾港公报 / 第三夜熄灯").font(.caption).foregroundStyle(accent)
                    Text("谁让雾港重新亮灯").font(.system(size: 32, weight: .medium, design: .serif))
                    Text("诊所依靠备用灯，工坊取消了夜班。两派争夺有限的供能经营权。你不需要投资，也能让一处工程继续向前。").foregroundStyle(.secondary)
                    if let battle = model.trial.battle { WorkshopBattleView(model: model, battle: battle) }
                    else if model.trial.closed { result }
                    else if model.trial.side == nil { plans }
                    else { workshop }
                    Text(model.message).foregroundStyle(accent).textSelection(.enabled)
                    DisclosureGroup("钱物回执 · 每笔都能对上") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(model.trial.entries.reversed()) { e in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(e.text)
                                    Text("我 \(e.player)铜 · 项目 \(e.project)铜 · 累计外部支付 \(e.external)铜")
                                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                }.padding(.vertical, 4)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text("隔离内容试玩：使用Swift正式战斗规则；材料/配方/项目为首测候选，Unity演出与共享服务器尚未接入。")
                        .font(.caption).foregroundStyle(.secondary)
                    if !model.exportPath.isEmpty { Text(model.exportPath).font(.caption).textSelection(.enabled) }
                }.padding(28)
            }
        }
        .foregroundStyle(.white).background(Color(red: 0.055, green: 0.08, blue: 0.12))
        .preferredColorScheme(.dark)
        .onReceive(timer) { _ in model.tick() }
        .onDisappear { model.running = false }
        .confirmationDialog("结束当前隔离试玩并从头开始？", isPresented: $model.resetConfirmation) {
            Button("新建试玩", role: .destructive) { model.reset() }
        }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("我的这次参与").font(.title2.bold())
            Text(model.trial.side?.name ?? "尚未选择立场").foregroundStyle(accent)
            Label("\(model.trial.copper) 铜", systemImage: "circle.circle").font(.title2.monospacedDigit())
            Text("韧皮 \(model.trial.hide) · 绑带 \(model.trial.straps) · 药品 \(model.trial.battle?.session.consumables["consumable_pain_salve", default: 0] ?? model.trial.medicines)")
            Text("皮革熟练度 \(model.trial.proficiency) / 20").font(.callout)
            Divider()
            Text("取材 → 制作 → 有预算交货 → 安装 → 公共行动 → 结果").font(.callout)
            ProgressView(value: Double(model.trial.installed), total: 12).tint(accent)
            Text("本方工程 \(model.trial.installed)/12 · 我的贡献 \(model.trial.publicPoints)点").font(.caption)
            Text(model.trial.remainingDemand > 0 ? "项目仅再收\(model.trial.remainingDemand)条绑带，每条9铜。卖不出的成品仍属于你。" : "本项目订单已收满，不再追加采购。余下成品仍属于你。")
                .font(.caption).foregroundStyle(.secondary)
            Button("导出本次试玩回执") { model.export() }
            Button("从头体验另一条路线") { model.resetConfirmation = true }
            Spacer(minLength: 16)
            Text(MPCWorkshopPlaytest.fixtureNotice).font(.caption).foregroundStyle(.secondary)
            Text("钱账守恒：\(model.trial.moneyConserved ? "通过" : "异常")").font(.caption)
        }
    }
    private var plans: some View {
        HStack(alignment: .top, spacing: 18) {
            plan(.pumps, quote: "先让居民和诊所的灯稳定下来。", detail: "艾妲希望先恢复民生支路。你可以帮维修队完成最后一个滤筒，再解除调试路线上的危险装置。")
            plan(.shipping, quote: "先让下一船燃料进得来。", detail: "罗文希望先让码头与工坊复工。你可以完成转运检修，再打开被护卫阵锁住的控制点。")
        }
    }
    private func plan(_ side: MPCWorkshopPlaytest.Side, quote: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(side.name).font(.title2.bold()); Text(quote).font(.headline); Text(detail).foregroundStyle(.secondary)
            Button("支持\(side.name)") { model.act { try $0.choose(side) } }.buttonStyle(.borderedProminent)
        }.padding(22).frame(maxWidth: .infinity, alignment: .topLeading).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
    }
    private var workshop: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox("01 · 工程真的缺什么") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(model.trial.installed == 12 ? "12号滤筒已验收。你交付的2条绑带已安装，工程12/12完成。接下来解除供能线路上的危险装置。" : (model.trial.projectStraps == 2 ? "项目已收到你的2条绑带，等待安装到12号滤筒。过滤布和锡罐已经入库。" : "此前11套组具已安装。12号滤筒的过滤布和锡罐已经入库，还缺2条维修绑带。你的货会安装在这里，不是交完就消失。"))
                    HStack {
                        Button("去教会塔F1取材") { model.start(.tower) }.disabled(model.trial.pendingHide)
                        Button("领取本场韧皮") { model.act { _ = try $0.claimHide(id: UUID().uuidString) } }.disabled(!model.trial.pendingHide)
                    }
                    Text("新增候选：本次盾颚魔胜利掉1份韧皮；不发旧首通铜币、功勋或装备。").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
            }
            GroupBox("02 · 皮革工坊") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("1韧皮＋12铜底料＋1铜耗材 → 3条维修绑带。熟练度按成功批次+1。")
                    HStack {
                        Button("制作3条绑带 · 13铜") { model.act { _ = try $0.craft(id: UUID().uuidString) } }.disabled(model.trial.hide<1 || model.trial.copper<13)
                        Button("卖2条 · 收18铜") { model.act { _ = try $0.sell(id: UUID().uuidString, quantity: 2) } }.disabled(model.trial.straps<2 || model.trial.remainingDemand<2)
                        Button("安装到12号滤筒") { model.act { _ = try $0.install(id: UUID().uuidString) } }.disabled(model.trial.projectStraps<2 || model.trial.installed==12)
                    }
                    Text("高级图纸：需序列8、皮革熟练度20及已学习图纸；本试玩尚未学习。多制作不保证有买家。").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
            }
            if model.trial.installed == 12 {
                GroupBox("03 · 让工程真正接通") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(model.trial.publicAttempted ? "本次公共行动已结算，你贡献\(model.trial.publicPoints)点。工程和交货记录已保留；现在可以查看世界结果与账单。" : "工程已经验收。你还有一次公共行动：普通成功1点，高难2点；失败不扣别人的贡献。用药和昂贵装备都不是报名条件。")
                        if !model.trial.publicAttempted {
                        HStack {
                            Picker("已持有的普通封印物", selection: $model.passive) {
                                Text("不携带").tag("none"); Text("返礼银扣").tag("relic_return_gift_clasp"); Text("盐封呼吸囊").tag("relic_salt_sealed_breathing_bag")
                            }.frame(maxWidth: 320)
                            Toggle("带僭命勋章", isOn: $model.medal)
                        }
                        if let relic = MPCChapterOneCatalog.relics.first(where: { $0.id == model.passive }) {
                            Text("\(relic.name)：\(relic.mechanism)\n代价：\(relic.cost)")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        if model.medal, let relic = MPCChapterOneCatalog.relics.first(where: { $0.id == MPCChapterOneCatalog.usurpedLifeMedalRelicID }) {
                            Text("\(relic.name)：\(relic.mechanism)\n代价：\(relic.cost)")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        HStack {
                            Button("买1瓶止痛膏 · 9铜") { model.act { _ = try $0.buyMedicine(id: UUID().uuidString) } }.disabled(model.trial.medicines>=3 || model.trial.copper<9)
                            Button("普通公共行动") { model.start(.ordinary) }.disabled(model.trial.publicAttempted)
                            Button("高难公共行动") { model.start(.hard) }.disabled(model.trial.publicAttempted)
                        }
                        Text("回流阵：读条时切支援者打断回血；护卫阵：先拆护卫，蓄力时击杀护卫可中断。药品恢复25%最大生命，实际服用才减少库存。")
                            .font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(10)
                }
            }
            Button("结束本次事件 · 查看世界与账单") { model.act { try $0.close() } }
                .disabled(!model.trial.publicAttempted || model.trial.pendingHide)
        }
    }
    private var result: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(model.trial.winner == .pumps ? "住宅支路，今晚恢复供能" : "外港吊机重新转动").font(.title.bold())
            Text("\(model.trial.winner?.name ?? "临时管理者")取得本轮合同。双方负责人仍存活；这条试玩只验证生产与公共行动，没有替其他人编造核心击杀。")
            Text(model.trial.installed==12 ? "你交出的2条绑带已经留在12号滤筒上。即使阵营落败，这处施工也不会被抹掉。" : "尚未验收的工程不被新闻写成已经完成。")
            Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 12) {
                GridRow { Text("制作支付"); Text("\(model.trial.paidInputs)铜") }
                GridRow { Text("实际卖货收入"); Text("\(model.trial.sold * 9)铜") }
                GridRow { Text("已购药品"); Text("\(model.trial.medicineSpend)铜") }
                GridRow { Text("现金变化（不估值余货）"); Text("\(model.trial.copper - 48)铜") }
                GridRow { Text("仍属你的库存"); Text("绑带\(model.trial.straps)条 · 药品\(model.trial.medicines)瓶") }
                GridRow { Text("我的公共贡献"); Text("\(model.trial.publicPoints)点") }
            }.padding(20).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
            Text("待验证的玩家问题：你是否理解为什么支持这一派？余下的绑带是否让你愿意寻找别的买家？准备是否改变了战斗体验？这三点不能由程序替真人回答。")
                .foregroundStyle(.secondary)
        }
    }
}

private struct WorkshopBattleView: View {
    @Bindable var model: WorkshopPlaytestModel
    let battle: MPCCampaignBattleDriver
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(battle.session.encounter.name).font(.title2.bold()); Spacer()
                Text(String(format: "%.1f / 180秒", battle.time)).monospacedDigit()
                Button(model.running ? "暂停" : "继续") {
                    model.running.toggle()
                    model.message = model.running ? "战斗继续。选择目标后使用技能。" : "已暂停；准备好后继续。"
                }.disabled(battle.isComplete)
            }
            Text("主角生命 \(battle.session.playerHP) / \(battle.session.playerMaxHP) · 护盾\(battle.session.playerShield)").monospacedDigit()
            ProgressView(value: Double(battle.session.playerHP), total: Double(battle.session.playerMaxHP)).tint(.mint)
            HStack(alignment: .top) {
                ForEach(battle.session.enemies) { e in
                    Button { model.trial.target(e.id) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(e.name).font(.headline)
                            Text("\(e.hp) / \(e.maxHP)").monospacedDigit()
                            ProgressView(value: Double(e.hp), total: Double(e.maxHP)).tint(.orange)
                            Text(e.isAlive ? (battle.selectedTarget == e.id ? "当前目标" : "点击切换") : "已击破").font(.caption)
                            if let channel = battle.session.campaignPrototype?.channels[e.id] {
                                Text(String(format: "回流读条 %.1f秒", max(0, channel.until-battle.time))).foregroundStyle(.orange)
                            }
                        }.padding(14).frame(maxWidth: .infinity, minHeight: 115, alignment: .leading)
                            .background(battle.selectedTarget==e.id ? .orange.opacity(0.15) : .white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain).disabled(!model.running || !e.isAlive)
                }
            }
            if let due = battle.session.campaignPrototype?.chargeUntil {
                Text(String(format: "核心蓄力 %.1f秒：击杀护卫可打断；无护卫时需造成核心8%%生命伤害。", max(0,due-battle.time))).foregroundStyle(.orange)
            }
            HStack {
                ForEach(Array(battle.session.loadout.normalSkillIDs.enumerated()), id: \.element) { i, skill in
                    let content = MPCChapterOneCatalog.skills.first { $0.id == skill }
                    let remaining = max(0, battle.scheduler.readyAt[skill, default: 0] - battle.time)
                    Button { _ = model.trial.cast(skill) } label: {
                        VStack(spacing: 4) {
                            Text("\(content?.name ?? skill.rawValue) [\(i+1)]")
                            Text(remaining > 0 ? String(format: "冷却 %.1f秒", remaining) : "技能就绪")
                                .font(.caption.monospacedDigit())
                        }
                    }
                        .help(content?.summary ?? "")
                        .keyboardShortcut(KeyEquivalent(Character(String(i+1))), modifiers: [])
                        .disabled(!model.running || !battle.canAct || battle.scheduler.readyAt[skill, default: 0]>battle.time)
                }
                Button { _ = model.trial.cast(nil) } label: {
                    VStack(spacing: 4) {
                        Text("普攻 [5]")
                        Text(battle.basicCooldownRemaining > 0 ? String(format: "冷却 %.1f秒", battle.basicCooldownRemaining) : "普攻就绪")
                            .font(.caption.monospacedDigit())
                    }
                }.keyboardShortcut("5", modifiers: [])
                    .disabled(!model.running || !battle.canAct || battle.basicCooldownRemaining > 0)
            }
            if !battle.isComplete {
                Text(!model.running ? "已暂停；继续后可以行动。" : (battle.canAct ? "可行动：点击技能，或按1–5。" : String(format: "动作衔接中 · %.1f秒后可继续", max(0, battle.actionReadyAt - battle.time))))
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("止痛膏 [M] ×\(battle.session.consumables["consumable_pain_salve", default: 0])") { _ = model.trial.useMedicine() }
                    .keyboardShortcut("m", modifiers: []).disabled(!model.running || !battle.canUseMedicine)
                Button(battle.session.isUsurpedLifeMedalActive ? "僭命勋章生效中" : (battle.session.usurpedLifeMedalReadyAt > battle.time ? String(format: "勋章冷却 %.1f秒", battle.session.usurpedLifeMedalReadyAt - battle.time) : "发动僭命勋章")) { _ = model.trial.useMedal() }
                    .disabled(!model.running || battle.session.loadout.selectedActiveRelicID == nil || battle.session.isUsurpedLifeMedalActive || battle.session.usurpedLifeMedalReadyAt > battle.time)
                Spacer()
                if battle.isComplete {
                    Button(battle.session.outcome == .victory ? "确认胜利回执" : "确认本次结果") { model.act { try $0.settleBattle() } }.buttonStyle(.borderedProminent)
                } else {
                    Button("撤退并结算本次消耗") { model.running = false; model.act { try $0.settleBattle(retreat: true) } }
                }
            }
            Text("每次动作有接触时间与公共间隔；暂停不走时钟。击杀后等待尚未落下的既定攻击结算。").font(.caption).foregroundStyle(.secondary)
        }
    }
}
