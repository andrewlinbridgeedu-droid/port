import SwiftUI
import Observation
import AppKit
import MistportCombatCore

@MainActor @Observable final class SandboxModel {
    var scenario: MPCCampaignScenario = .guardOrdinary
    var gearFloor = 30
    var passive = "none"
    var medicines = 3
    var useMedal = true
    var driver: MPCCampaignBattleDriver?
    var running = false
    var message = "选择一场演练，然后开始。所有数据只存在本窗口。"
    var exportLocation = ""
    func start() {
        do {
            _ = try FoolCombatConfigurationLoader.bundled()
            driver = try .init(scenario: scenario, gearFloor: gearFloor, passive: passive == "none" ? nil : passive, medicines: medicines, medal: useMedal)
            running = true; message = "演练开始：点击敌人选择目标，再使用技能。"; exportLocation = ""
        } catch { message = "无法开始：\(error)"; running = false }
    }
    func tick() {
        guard running, var battle = driver else { return }
        do { try battle.advance(to: battle.time + 0.05) }
        catch { message = "战斗错误：\(error)"; running = false }
        driver = battle
        if battle.session.outcome != .inProgress {
            running = false
            message = battle.session.outcome == .victory ? "演练胜利。此处不发奖励，不改变世界人物。" : "演练失败。可以调整配装或打法重试。"
        }
    }
    func target(_ id: String) { guard running else { return }; driver?.select(id) }
    func cast(_ skill: FoolSkillID?) { guard running else { return }; _ = driver?.cast(skill) }
    func medicine() { guard running else { return }; _ = driver?.medicine() }
    func medal() { guard running else { return }; _ = driver?.medal() }
    func export() {
        guard let driver else { return }
        running = false
        let folder = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("Records", isDirectory: true)
        let filename = "campaign-\(driver.session.campaignPrototype!.scenario.rawValue)-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(8)).json"
        let url = folder.appendingPathComponent(filename)
        do {
            struct Report: Encodable {
                let version: String, scenario: String, outcome: String
                let time: Double, minimumHP: Int, timeBelowQuarterHP: Double
                let events: [MPCCampaignBattleEvent]
            }
            let report = Report(version: "sandbox-v2.1", scenario: driver.session.encounter.id, outcome: driver.session.outcome.rawValue, time: driver.time, minimumHP: driver.minimumHP, timeBelowQuarterHP: driver.timeBelowQuarterHP, events: driver.session.campaignPrototype!.events)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try encoder.encode(report).write(to: url, options: .atomic)
            exportLocation = url.path; message = "记录已导出，演练已暂停。"
        } catch { message = "导出失败：\(error)" }
    }
}

@main struct CampaignSandboxApp: App {
    var body: some Scene {
        Window("雾港 · 世界事件演练", id: "campaign-sandbox") {
            TabView {
                WorkshopPlaytestView().tabItem { Text("事件试玩") }
                SandboxView().tabItem { Text("机制对照（开发）") }
            }.frame(minWidth: 1060, minHeight: 760)
        }
        .defaultSize(width: 1180, height: 840)
        .windowResizability(.contentMinSize)
    }
}

struct SandboxView: View {
    @State private var model = SandboxModel()
    private let pulse = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private let gold = Color(red: 0.9, green: 0.72, blue: 0.4)
    var body: some View {
        HStack(spacing: 0) {
            controls.frame(width: 235).padding(22).background(Color.black.opacity(0.2))
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("雾港 / 阵营世界事件").font(.caption).foregroundStyle(gold)
                            Text(model.driver?.session.encounter.name ?? "战斗演练室").font(.largeTitle.bold())
                        }
                        Spacer()
                        Text("隔离原型 · v2.1").font(.caption).padding(9).background(.white.opacity(0.08), in: Capsule())
                    }
                    Text("复用 Swift 战斗规则 · 功能与难度实验 · Unity 演出尚未接入")
                        .font(.caption).foregroundStyle(.secondary)
                    if let d = model.driver { battle(d) }
                    else {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("先拆防护，还是争取抢攻？").font(.title2.bold())
                            Text("护卫阵：存活护卫降低核心所受伤害。24秒开始蓄力，4秒内击杀护卫可以打断；护卫全灭时，打掉核心8%生命也可打断。")
                            Text("回流阵：支援者每20秒读条治疗核心。5秒内打掉该支援者15%生命可打断。核心半血后进入8秒恢复，并可能呼叫援军。")
                            Text("普通与高难使用不同生命与攻击数值；所有数值仍待真人试玩调整。")
                        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                    }
                    Text(model.message).foregroundStyle(gold).textSelection(.enabled)
                    if !model.exportLocation.isEmpty { Text(model.exportLocation).font(.caption).textSelection(.enabled) }
                }.padding(28)
            }
        }
        .foregroundStyle(.white)
        .background(Color(red: 0.055, green: 0.08, blue: 0.12))
        .preferredColorScheme(.dark)
        .onReceive(pulse) { _ in model.tick() }
        .onDisappear { model.running = false }
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("演练配置").font(.title2.bold())
            Group {
                Picker("遭遇", selection: $model.scenario) {
                    ForEach(MPCCampaignScenario.allCases, id: \.self) { Text($0.name).tag($0) }
                }
                Picker("已获得塔装备", selection: $model.gearFloor) {
                    Text("30层累计").tag(30); Text("100层累计").tag(100)
                }
                Picker("普通封印物", selection: $model.passive) {
                    Text("不携带").tag("none")
                    Text("返礼银扣").tag("relic_return_gift_clasp")
                    Text("缄卷镇纸").tag("relic_sealed_paperweight")
                    Text("盐封呼吸囊").tag("relic_salt_sealed_breathing_bag")
                }
                Picker("携带药品", selection: $model.medicines) { Text("0瓶").tag(0); Text("3瓶").tag(3) }
                Toggle("携带僭命勋章", isOn: $model.useMedal)
            }.disabled(model.running)
            Text("配置在开始时冻结；暂停后的修改只影响下一场。使用Q30已获得天赋与四技能，不新增真实权益。")
                .font(.caption).foregroundStyle(.secondary)
            Button(model.driver == nil ? "开始演练" : "重新开始", action: model.start)
                .buttonStyle(.borderedProminent).tint(gold).foregroundStyle(.black)
            if let d = model.driver {
                Button(model.running ? "暂停演练" : "继续演练") { model.running.toggle() }
                    .disabled(d.session.outcome != .inProgress)
                Button("导出到记录文件夹", action: model.export)
                Divider()
                Text(String(format: "%.1f / 180 秒", d.time)).font(.title3.monospacedDigit())
                Text("最低生命 \(d.minimumHP)").font(.caption)
                Text(String(format: "低于25%%生命 %.1f秒", d.timeBelowQuarterHP)).font(.caption)
            }
            Spacer()
            Text("不读写存档\n不结算铜币、贡献或NPC死亡\n演练可重复，正式世界尝试另行实现")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func battle(_ d: MPCCampaignBattleDriver) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            player(d)
            HStack(alignment: .top, spacing: 12) {
                ForEach(d.session.enemies) { enemy in
                    enemyCard(enemy, driver: d)
                }
            }
            if let state = d.session.campaignPrototype {
                VStack(alignment: .leading, spacing: 7) {
                    if let due = state.chargeUntil {
                        Label(String(format: "核心蓄力！剩余 %.1f秒", max(0, due - d.time)), systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("击杀一名护卫；若无护卫，造成核心最大生命8%的有效伤害。已累计\(state.chargeDamage)。").font(.caption)
                    } else if d.time < state.recoveryUntil {
                        Text(String(format: "核心恢复中 · %.1f秒", state.recoveryUntil - d.time)).foregroundStyle(.mint)
                    } else { Text(String(format: "下次机制 · %.1f秒", max(0, state.nextMechanic - d.time))).foregroundStyle(.secondary) }
                    if let due = state.reserveAt { Text(String(format: "援军预计 %.1f秒后抵达", max(0, due - d.time))).foregroundStyle(.orange) }
                    if state.poisonRemaining > 0 { Text("持续伤害剩余\(state.poisonRemaining)次").foregroundStyle(.orange) }
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            }
            HStack {
                ForEach(d.session.loadout.normalSkillIDs, id: \.self) { skill in
                    let ready = max(0, d.scheduler.readyAt[skill, default: 0] - d.time)
                    Button { model.cast(skill) } label: {
                        VStack(spacing: 4) {
                            Text(MPCChapterOneCatalog.skills.first { $0.id == skill }?.name ?? skill.rawValue)
                            Text(ready > 0 ? String(format: "%.1f秒", ready) : "就绪").font(.caption.monospacedDigit())
                        }.frame(maxWidth: .infinity).padding(.vertical, 6)
                    }.disabled(!model.running || !d.canAct || ready > 0)
                }
                Button("普攻") { model.cast(nil) }.disabled(!model.running || !d.canAct)
            }.buttonStyle(.bordered)
            if d.session.outcome != .inProgress {
                Text(d.session.outcome == .victory ? "演练通过 · 候选公共贡献预览 \(d.session.campaignPrototype!.scenario.isHard ? 2 : 1)点" : "演练未通过 · 无贡献")
                    .font(.headline).foregroundStyle(d.session.outcome == .victory ? .mint : .orange)
                Text("此预览没有写入公共进度，不触发关键人物死亡或投资结算。").font(.caption).foregroundStyle(.secondary)
            }
            Text("战况记录").font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array((d.session.campaignPrototype?.events ?? []).filter { !["damage", "attack_windup", "enemy_hit", "cast", "target"].contains($0.kind) }.suffix(9).reversed())) { event in
                    Text(String(format: "%05.1f  ", event.at) + label(event)).font(.caption.monospacedDigit()).textSelection(.enabled)
                }
            }.frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        }
    }
    private func player(_ d: MPCCampaignBattleDriver) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("主角  \(d.session.playerHP) / \(d.session.playerMaxHP)").font(.headline.monospacedDigit())
                Text("护盾 \(d.session.playerShield)").font(.caption).foregroundStyle(.cyan)
                Spacer()
                Button("药品 ×\(d.session.consumables["consumable_pain_salve", default: 0])") { model.medicine() }
                    .disabled(!model.running || !d.canUseMedicine)
                Button(d.session.isUsurpedLifeMedalActive ? "勋章生效中" : "僭命勋章") { model.medal() }
                    .disabled(!model.running || d.session.loadout.selectedActiveRelicID == nil || d.session.isUsurpedLifeMedalActive || d.time < d.session.usurpedLifeMedalReadyAt)
            }
            ProgressView(value: Double(d.session.playerHP), total: Double(d.session.playerMaxHP)).tint(.mint)
        }
    }
    private func enemyCard(_ enemy: MPCRuntimeEnemy, driver d: MPCCampaignBattleDriver) -> some View {
        Button { model.target(enemy.id) } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: enemy.contentID.hasSuffix("_core") ? "crown.fill" : "shield.fill")
                    Text(enemy.name).font(.headline)
                }
                Text("\(enemy.hp) / \(enemy.maxHP)").monospacedDigit()
                ProgressView(value: Double(enemy.hp), total: Double(enemy.maxHP)).tint(.orange)
                if !enemy.isAlive { Text("已击破").foregroundStyle(.secondary) }
                else if let channel = d.session.campaignPrototype?.channels[enemy.id] {
                    Text(String(format: "回流 %.1f秒", max(0, channel.until - d.time))).foregroundStyle(.orange)
                    Text("打断 \(channel.damage)/\((enemy.maxHP * 15 + 99) / 100)").font(.caption)
                } else if let at = d.attacks[enemy.id] {
                    Text(String(format: "攻击前摇 %.1f秒", max(0, at - d.time))).foregroundStyle(.orange)
                } else { Text(d.session.campaignActorPaused(enemy.id) ? "暂停攻击" : "交战中").foregroundStyle(.secondary) }
                Text(d.selectedTarget == enemy.id ? "当前目标" : "点击选中").font(.caption).foregroundStyle(gold)
            }.frame(maxWidth: .infinity, minHeight: 135, alignment: .topLeading).padding(13)
                .background(d.selectedTarget == enemy.id ? gold.opacity(0.13) : .white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(d.selectedTarget == enemy.id ? gold : .clear, lineWidth: 1))
        }.buttonStyle(.plain).disabled(!model.running || !enemy.isAlive)
        .accessibilityLabel("\(enemy.name)，生命\(enemy.hp)，\(d.selectedTarget == enemy.id ? "已选中" : "选择目标")")
    }
    private func label(_ e: MPCCampaignBattleEvent) -> String {
        let names = ["start": "演练开始", "charge_start": "核心蓄力", "charge_interrupt": "蓄力打断", "charge_release": "蓄力爆发", "channel_start": "支援回流", "channel_interrupt": "回流打断", "core_heal": "核心恢复", "reserve_warning": "援军预警", "reserve_arrive": "援军抵达", "reserve_cancel": "援军取消", "half_health": "半血转阶段", "recovery": "核心恢复期", "medicine": "使用药品", "medal": "激活勋章", "poison_tick": "持续伤害", "timeout": "演练超时", "outcome": "战斗结束", "target_lost": "目标已倒下", "attack_cancel": "攻击取消"]
        return (names[e.kind] ?? e.kind) + (e.amount != 0 ? " \(e.amount)" : "") + (e.detail.isEmpty ? "" : " · \(e.detail)")
    }
}
