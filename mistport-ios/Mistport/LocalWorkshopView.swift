import SwiftUI
import MistportCombatCore

/// Production save-backed workshop; never constructs an isolated playtest fixture.
struct LocalWorkshopView: View {
    @Bindable var game: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var showsTower = false
    @State private var message = ""
    @State private var confirmsExtraBatch = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 16) {
                        Image("GameNavWorkshopAnime")
                            .resizable().scaledToFit().frame(width: 84, height: 84)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("凭手艺赚铜币").font(.title2.bold())
                            Text("取材 · 制作 · 交货")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Text("先看工坊需要什么，再把塔里的材料做成货物。")
                        .font(.callout)
                    HStack {
                        Label("\(game.venueCoins) 铜", systemImage: "circle.circle")
                        Spacer()
                        Text("皮革 \(game.localWorkshop.proficiency) / 20")
                    }.font(.headline).monospacedDigit()
                    Text("韧皮 \(game.workshopHideCount) · 维修绑带 \(game.workshopStrapCount)")
                        .accessibilityIdentifier("workshop.inventory")
                    if !game.cityServiceIsUnlocked(.workshop) {
                        Text("完成第16关后开放基础皮革工艺。")
                    } else if !game.workshopLedgerIsReadable {
                        Text("工坊账本暂时无法读取，已停止扣款与交货。原存档保留。")
                    } else if !game.churchMistportFieldworkAvailable {
                        Text("你已离开雾港，现场工坊暂时停用。材料、图纸、熟练度和检修记录均已保留，等待后续剧情开放回访。")
                    } else {
                        gathering
                        recipe
                        order
                    }
                    if !message.isEmpty {
                        Text(message).foregroundStyle(.yellow).accessibilityIdentifier("workshop.message")
                    }
                    Text("更多专业与城市事件随后续剧情开放。当前检修单只采购2条，不会每天刷新；剩余成品保留在背包。")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(20)
            }
            .background(Color(red: 0.055, green: 0.08, blue: 0.12))
            .navigationTitle("百工坊")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("返回", action: { dismiss() }) } }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showsTower) { ChurchSanctuaryView(game: game) }
        .confirmationDialog("这个检修单已收满，继续制作的成品暂时没有买家。仍花13铜制作？", isPresented: $confirmsExtraBatch) {
            Button("仍然制作 · 13铜") { craft() }
            Button("取消", role: .cancel) {}
        }
    }

    private var gathering: some View {
        GroupBox("01 · 取材") {
            VStack(alignment: .leading, spacing: 12) {
                Text("教会塔第1层的盾颚魔，每次新战斗胜利可取1份韧皮。旧的通关记录不会补发。")
                    .font(.callout)
                Button("前往教会塔取材") { showsTower = true }
                    .buttonStyle(.bordered)
                Text("首通铜币、功勋与装备仍按原规则结算；韧皮在胜利时直接收入背包。")
                    .font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
        }
    }
    private var recipe: some View {
        GroupBox("02 · 皮革制作　维修绑带") {
            VStack(alignment: .leading, spacing: 12) {
                Text("1份韧皮 + 12铜底料 + 1铜耗材 → 3条绑带")
                Text("每成功制作一批，皮革熟练度+1，本阶段上限20。高级配方另需序列8、熟练度20和对应图纸，当前尚未开放。")
                    .font(.caption).foregroundStyle(.secondary)
                if !game.localWorkshop.learnedBasics {
                    Button("学习基础图纸 · 免费") {
                        perform("已学会维修绑带。图纸与熟练度会随存档保留。") { try game.learnWorkshopBasics() }
                    }.buttonStyle(.borderedProminent)
                } else {
                    Button("制作一批 · 13铜") {
                        if game.localWorkshop.order != .offered { confirmsExtraBatch = true }
                        else { craft() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(game.workshopHideCount < 1 || game.venueCoins < 13)
                    if game.workshopHideCount < 1 { Text("还缺1份韧皮，先去第1层取材。 ").font(.caption) }
                    else if game.venueCoins < 13 { Text("还差\(13-game.venueCoins)铜；不会透支。 ").font(.caption) }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
        }
    }
    private var order: some View {
        GroupBox("03 · 工坊检修架") {
            VStack(alignment: .leading, spacing: 12) {
                switch game.localWorkshop.order {
                case .offered:
                    Text("检修架的旧绑带已经开裂。工坊收购2条新绑带，总价18铜，交货后再安装。")
                    Text("剩余采购预算：\(game.localWorkshop.procurementCopper)铜 · 只收2条")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("交付2条 · 收18铜") {
                        perform("已交付2条，收到18铜。接下来把它们安装到检修架。") { try game.deliverWorkshopStraps() }
                    }.buttonStyle(.borderedProminent).disabled(game.workshopStrapCount < 2)
                case .delivered:
                    Text("2条绑带已交货，货款已付。安装不会再扣钱，也不会再次发钱。")
                    Button("安装已交付的2条绑带") {
                        perform("检修架重新固定，绑带已经用在这里。余下成品仍在背包。") { try game.installWorkshopStraps() }
                    }.buttonStyle(.borderedProminent)
                case .installed:
                    Label("检修架已验收", systemImage: "checkmark.seal.fill").foregroundStyle(.mint)
                    Text("你制作的两条绑带固定在支架上。此单已完成，不再追加采购。")
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
        }
    }
    private func craft() {
        perform("制成3条维修绑带，熟练度已保存（本阶段上限20）。") { try game.craftWorkshopStraps() }
    }
    private func perform(_ success: String, action: () throws -> Void) {
        do { try action(); message = success }
        catch let error as MPCLocalWorkshopLedger.Failure {
            switch error {
            case .locked: message = "条件未满足，请检查主线进度和已学图纸。"
            case .funds: message = "铜币不足，本次没有扣款。"
            case .stock: message = "材料或待安装货物不足，本次没有扣款。"
            case .exhausted: message = "检修单已收满，成品保留在背包。"
            case .conflict: message = "操作回执冲突，本次没有重复结算。"
            }
        } catch { message = "账本未能保存，本次操作未完成。" }
    }
}
