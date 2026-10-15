import SwiftUI
import MistportCombatCore

struct CityBankView: View {
    @Bindable var game: GameStore
    @State private var amount = 20
    @State private var termAmount = 60
    @State private var managerPresented = false
    @State private var busy = false
    @State private var message = ""
    private var now: TimeInterval { game.housingNow.timeIntervalSince1970 }
    private var surplus: Int { max(0, game.venueCoins - game.bankLiquidReserve) }
    private func canSign(_ value: Int) -> Bool {
        !busy && game.churchTowerMissionNumbers.contains(1) && surplus >= value
            && game.cityEconomy.outstanding + value <= MPCCityEconomy.limit(completed: game.churchTowerMissionNumbers)
    }
    var body: some View {
        HomeCounterScene(title: "雾港银行", room: .counter("cityhall"), actorArt: "HomeCivilClerk20260929") {
            Text("可用\(game.venueCoins)铜 · 可存余钱\(surplus)铜").font(.headline.monospacedDigit())
            Text("柜员：先留好生活和晋阶的钱，再选一张存单。").font(.subheadline)
            if !game.churchTowerMissionNumbers.contains(1) {
                Text("完成第1关后，可开零钱账户与新客存单。")
            } else {
                welcomeDeposit
                Divider()
                ordinaryDeposit
            }
            HomeCounterAction(title: "见投资经理", detail: "自行车厂 · 航运 · 商户订单") { managerPresented = true }
                .accessibilityIdentifier("bank-manager-entry")
            DisclosureGroup("预算与取款") { budgetTools }
            if !message.isEmpty { Text(message).foregroundStyle(.orange) }
            if let notice = game.cityEconomy.notices.last { Text(notice).font(.footnote) }
        }.task { await game.openHousingDay() }
            .sheet(isPresented: $managerPresented) { CityBankManagerView(game: game) }
    }
    @ViewBuilder private var welcomeDeposit: some View {
        Text("新客三日存单").font(.headline)
        if let deposit = game.cityEconomy.deposit {
            if deposit.closed { Text("开户奖励已使用").font(.subheadline) }
            else {
                BankDepositReceipt(principal: deposit.principal, profit: deposit.maturityValue - deposit.principal, dueAt: deposit.dueAt)
                Button("取回\(deposit.principal)铜 · 提前取不计息") {
                    run { try await game.cityEconomyAction { try $0.redeemDeposit(now: now, coins: &$1) } }
                }.buttonStyle(GameArtButtonStyle()).disabled(busy)
            }
        } else {
            Picker("新客本金", selection: $amount) { ForEach([20, 40, 60], id: \.self) { Text("\($0)铜").tag($0) } }.pickerStyle(.segmented)
            bankQuote(amount, profit: amount / 20 * 4, term: "72小时")
            Button("存\(amount)铜 · 到期收\(amount / 20 * 24)铜") {
                run { try await game.signBankDeposit(amount: amount, ordinary: false) }
            }.buttonStyle(GameArtButtonStyle()).disabled(!canSign(amount)).accessibilityIdentifier("bank-welcome-sign")
            Text(canSign(amount) ? "仅一次 · 本金可提前取回" : "先留足生活与晋阶预算，或选较小本金").font(.caption)
        }
    }
    @ViewBuilder private var ordinaryDeposit: some View {
        Text("普通七日定期").font(.headline)
        if let deposit = game.cityEconomy.termDeposit, !deposit.closed {
            BankDepositReceipt(principal: deposit.principal, profit: deposit.profit, dueAt: deposit.dueAt)
            Button("取回\(deposit.principal)铜 · 提前取不计息") {
                run { try await game.cityEconomyAction { try $0.redeemTermDeposit(now: now, coins: &$1) } }
            }.buttonStyle(GameArtButtonStyle()).disabled(busy).accessibilityIdentifier("bank-term-redeem")
        } else {
            Picker("定期本金", selection: $termAmount) { ForEach([60, 120], id: \.self) { Text("\($0)铜").tag($0) } }.pickerStyle(.segmented)
            bankQuote(termAmount, profit: MPCCityEconomy.termProfit(termAmount), term: "7日")
            Button("存\(termAmount)铜 · 到期收\(termAmount + MPCCityEconomy.termProfit(termAmount))铜") {
                run { try await game.signBankDeposit(amount: termAmount, ordinary: true) }
            }.buttonStyle(GameArtButtonStyle()).disabled(!canSign(termAmount)).accessibilityIdentifier("bank-term-sign")
            Text("到期可再存 · 自动入钱包，不自动续存").font(.caption)
        }
    }
    private func bankQuote(_ principal: Int, profit: Int, term: String) -> some View {
        HStack {
            Text("\(principal)铜 · \(term)")
            Spacer()
            Text("净赚\(profit)铜").bold().foregroundStyle(Color(red: 0.15, green: 0.39, blue: 0.23))
        }.monospacedDigit().accessibilityElement(children: .combine)
    }
    @ViewBuilder private var budgetTools: some View {
        Text("已留\(game.bankLiquidReserve)铜：三日食宿、药品及本阶段成长准备。").font(.footnote)
        CityWalletSummary(game: game)
        Text("零钱保管\(game.cityEconomy.savings)铜 · 仅分开预算，不计息").font(.footnote)
        Button("取回保管账户全部\(game.cityEconomy.savings)铜") {
            run { try await game.cityEconomyAction { try $0.withdraw($0.savings, coins: &$1) } }
        }.buttonStyle(GameArtButtonStyle()).disabled(busy || game.cityEconomy.savings == 0)
        DisclosureGroup("存单条款") {
            Text("到期本金与利息自动入钱包；提前取回全部本金但本期不计息。新客机会只能使用一次。普通定期每次需重新签单，一次持有一张，与投资共用本阶段在途额度。利息由银行本章有限预算支付。").font(.footnote)
        }
    }
    private func run(_ action: @escaping @MainActor () async throws -> Void) {
        busy = true
        Task { defer { busy = false }; do { try await action(); message = "柜员已记账。" } catch { message = error.localizedDescription } }
    }
}

private struct BankDepositReceipt: View {
    let principal: Int
    let profit: Int
    let dueAt: TimeInterval
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("本金\(principal)铜 · 到期净赚\(profit)铜").monospacedDigit()
            Text("到账：\(Date(timeIntervalSince1970: dueAt).formatted(date: .abbreviated, time: .shortened))").font(.caption)
        }
    }
}

struct CityBankManagerView: View {
    @Bindable var game: GameStore
    @State private var amount = 60
    @State private var acceptsRisk = false
    @State private var busy = false
    @State private var message = ""
    var body: some View {
        HomeCounterScene(title: "银行经理 · 产业投资", room: .counter("cityhall"),
            actorArt: "HomeCivilClerk20260929", illustrationArt: "BankManagerOffice20261014", returnTitle: "返回银行") {
            Text("经理：欢迎。存单赚的是稳当钱，这几份订单则要一起承担生意的风险。")
            Text("港城声望\(game.cityContribution.points) · 可用\(game.venueCoins)铜").font(.headline.monospacedDigit())
            Picker("认购本金", selection: $amount) { ForEach([20, 40, 60, 80, 100, 120, 160], id: \.self) { Text("\($0)").tag($0) } }.pickerStyle(.segmented)
            Toggle("我接受本金可能全部损失", isOn: $acceptsRisk)
            ForEach([MPCCityEconomy.ProjectKind.bicycle, .shipping, .invoice, .workshop], id: \.self) { kind in projectOffer(kind) }
            ForEach(game.cityEconomy.projects.reversed()) { CityProjectCard(game: game, project: $0) }
            if !message.isEmpty { Text(message).foregroundStyle(.orange) }
            DisclosureGroup("投资条款") {
                Text("款项投入生产，不能随时取回。须核对原件并送验，7／10／14日到期，最多延期3日。未交付或验收错误可能损失全部本金，不产生额外欠债。").font(.footnote)
                Text("在途\(game.cityEconomy.outstanding)／\(MPCCityEconomy.limit(completed: game.churchTowerMissionNumbers))铜 · 本批客户余款\(game.cityEconomy.customerBudget)铜").font(.footnote.monospacedDigit())
            }
        }.task { await game.openHousingDay() }
    }
    @ViewBuilder private func projectOffer(_ kind: MPCCityEconomy.ProjectKind) -> some View {
        let open = kind.isOpen(completed: game.churchTowerMissionNumbers, reputation: game.cityContribution.points)
        let validAmount = amount >= kind.minimum && amount <= kind.maximum
        let quoted = validAmount ? amount : kind.minimum
        VStack(alignment: .leading, spacing: 8) {
            Text(kind.title).font(.headline)
            Text("\(quoted)铜 · \(kind.days)日 · 履约净赚\(kind.repayment(quoted) - quoted)铜").font(.subheadline)
            if !open {
                Text(game.cityContribution.points < kind.reputation
                    ? "经理：您目前声望不足。声望到\(kind.reputation)、办妥第\(kind.mission)关后，再来找我。"
                    : "经理：声望我认可了。等您办妥第\(kind.mission)关，我们再谈这笔生意。").font(.subheadline)
            } else if !validAmount { Text("经理：这份订单认购\(kind.minimum)～\(kind.maximum)铜，请换个金额。").font(.caption) }
            Button(open ? "认购\(kind.title)" : "尚未获邀") { subscribe(kind) }
                .buttonStyle(GameArtButtonStyle())
                .disabled(!open || !validAmount || !acceptsRisk || busy || game.venueCoins - amount < game.bankLiquidReserve
                    || game.cityEconomy.outstanding + amount > MPCCityEconomy.limit(completed: game.churchTowerMissionNumbers))
                .accessibilityIdentifier("bank-invest-\(kind.rawValue)")
        }.padding(14).background(.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
    private func subscribe(_ kind: MPCCityEconomy.ProjectKind) {
        busy = true
        Task { defer { busy = false }
            do { try await game.signBankProject(kind: kind, amount: amount); message = "经理：订单已登记，记得回来核验原件。" }
            catch { message = error.localizedDescription }
        }
    }
}

struct CityWalletSummary: View {
    @Bindable var game: GameStore
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("可用 \(game.venueCoins)铜 · 保管 \(game.cityEconomy.savings)铜 · 在途 \(game.cityEconomy.outstanding)铜").font(.headline.monospacedDigit())
            Text("建议留下\(game.cityBudgetReserve)铜：本阶段晋阶储蓄、基础遗落物缺项、三日食宿与备用药。保管与在途资金需先取回或结算才能花。").font(.footnote)
            Text("晋阶主材500＋650＋950铜，仪式300铜；已买\(game.advancementIngredients.count)／3份。资格与凭证不代替付款。").font(.footnote)
        }
    }
}

private struct CityProjectCard: View {
    @Bindable var game: GameStore
    let project: MPCCityEconomy.Project
    @State private var busy = false
    @State private var message = ""
    @State private var workshopOpen = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(project.kind.title).font(.headline)
            Text("本金\(project.committed)铜 · 到期\(Date(timeIntervalSince1970: project.dueAt).formatted(date: .abbreviated, time: .shortened))")
            if project.settled { Text("已结算\(project.repayment)铜" + (project.repayment == 0 ? " · 本金损失" : "")) }
            else if let order = project.bicycle {
                Text(CityBicycleOrderView.summary(order))
                Button(order.stage == .delivered ? "查看车厂订单" : "前往赫伯特车厂") { workshopOpen = true }
                    .accessibilityIdentifier("bicycle-order-open")
            }
            else if !project.inspected {
                Text(project.kind == .bicycle ? "车架订单B-04：蓝蜡原件要求铜铆钉，转抄便条却写成铁钉。"
                    : project.kind == .shipping ? "货运订单H-09：蓝蜡原件写明四箱帆布，转抄便条却写成六箱。"
                    : "原始货单：蓝蜡封，批号R-17；转抄便条写成红蜡封。")
                Button("依据蓝蜡原件验收") { command { try $0.inspectProject(project.id, originalSeal: true, now: game.housingNow.timeIntervalSince1970) } }
                Button("依据转抄便条验收") { command { try $0.inspectProject(project.id, originalSeal: false, now: game.housingNow.timeIntervalSince1970) } }
            } else if !project.delivered {
                Text(project.damaged ? "便条与原封冲突；本批材料已经错配，客户可能拒收。" : "原封已核对，工坊货箱等候送验。")
                Button("送至验收台 · 5体力") { command(stamina: 5) { try $0.deliverProject(project.id, now: game.housingNow.timeIntervalSince1970) } }
            } else { Text("已送验，等待合同到期；若到期前没有交付，最多延期三日再清算。") }
            if !message.isEmpty { Text(message).font(.footnote).foregroundStyle(.orange) }
        }.padding(14).background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
            .buttonStyle(GameArtButtonStyle()).disabled(busy)
            .sheet(isPresented: $workshopOpen) { CityBicycleOrderView(game: game, projectID: project.id) }
    }
    private func command(stamina: Int = 0, _ action: @escaping (inout MPCCityEconomy) throws -> Void) {
        busy = true
        Task { defer { busy = false }; do { try await game.cityEconomyAction(stamina: stamina, receipt: "project-deliver-" + project.id) { economy, _ in try action(&economy) }; message = "手续已记录。" } catch { message = error.localizedDescription } }
    }
}

/// 自行车厂首批订单 (2026-10-14, INVESTMENT_QUESTS_AND_CAPITAL_CALLS_20261014): 赫伯特's workshop.
/// 帕维 hands over two requisition slips to check against the original order, a hub is short,
/// 乔里 test-rides the bikes, 米拉 the buyer offers one more bike, and the bikes go to her shop.
/// Every step goes through the bank journal (GameStore.bicycleOrderStep); stand-in portraits
/// from the existing counters until the order's own characters are painted.
struct CityBicycleOrderView: View {
    @Bindable var game: GameStore
    let projectID: String
    @State private var busy = false
    @State private var message = ""
    typealias Order = MPCCityEconomy.BicycleOrder

    private var project: MPCCityEconomy.Project? { game.cityEconomy.projects.first { $0.id == projectID } }
    private static let originalOrder = "原始采购单（黛娜签核，蓝蜡封）：车架铜铆钉60枚，36辐后轮毂若干。"
    private static let rightSlip = "领料单：车架铜铆钉60枚，36辐后轮毂——库存缺一只。"
    private static let wrongSlip = "领料单：车架铁铆钉60枚，36辐后轮毂——库存缺一只。"

    static func summary(_ order: Order) -> String {
        switch order.stage {
        case .parts: "\(order.bikes)辆车待发料：先对照原始采购单核对领料单。"
        case .sourcing: "车架已发料，还缺一只后轮毂。"
        case .testing: order.failedTests > 0 ? "试车未过（\(order.failedTests)次），需处理后重试。" : "零件齐了，等乔里试车。"
        case .ready: order.expansion == .open ? "试车通过；买家米拉有话要说。" : "\(order.bikes)辆车可以送去米拉的车行。"
        case .assembling: "第四辆车等待装配。"
        case .delivered: "\(order.bikes)辆车已交付，米拉已签收；合同到期付款。"
        }
    }

    private func actor(_ stage: Order.Stage) -> String {
        switch stage {
        case .parts, .sourcing: "HomeLaborClerk20260929"
        case .testing, .assembling: "HomeCarpenter20260929"
        case .ready, .delivered: "HomePhotographer20260929"   // 米拉 (stand-in until her portrait)
        }
    }

    var body: some View {
        let stage = project?.bicycle?.stage ?? .delivered
        HomeCounterScene(title: "赫伯特车厂 · 首批订单", room: .counter("oldstreet"), actorArt: actor(stage), returnTitle: "返回经理室") {
            if let project, let order = project.bicycle {
                Text("\(order.bikes)辆车 · 已投入\(project.committed + order.extraCosts)铜 · 买家托管\(order.bikes * Order.pricePerBike)铜")
                    .font(.headline.monospacedDigit())
                if project.settled {
                    Text(project.repayment > 0 ? "合同已结清，\(project.repayment)铜入账。" : "订单未能按时交付，投入的本金已经损失。")
                } else {
                    // Wrap every line: the slips' last words (the missing hub) were cut off.
                    Group { steps(project, order) }.fixedSize(horizontal: false, vertical: true)
                }
                if !message.isEmpty { Text(message).foregroundStyle(.orange) }
                DisclosureGroup("订单与条款") {
                    Text("每辆车成本\(Order.costPerBike)铜、售价\(Order.pricePerBike)铜。款项先投入采购与装配；米拉签收后，合同到期由她的托管付款。没试过车的货她不收；超过到期后三天仍未交付，本金损失，不追加欠款。").font(.footnote)
                    Text("到期\(Date(timeIntervalSince1970: project.dueAt).formatted(date: .abbreviated, time: .shortened))").font(.footnote)
                }
            } else {
                Text("这份订单已不在账上。")
            }
        }
        .buttonStyle(GameArtButtonStyle()).disabled(busy)
        .task { await game.openHousingDay() }
    }

    @ViewBuilder private func steps(_ project: MPCCityEconomy.Project, _ order: Order) -> some View {
        switch order.stage {
        case .parts:
            Text("赫伯特：车架都焊好了，就等铆钉和轮毂。帕维手上有两张领料单，您核一下。")
            Text("黛娜：照原单发料，别照抄本。").font(.subheadline)
            Text(Self.originalOrder).font(.footnote).padding(8).background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            ForEach(0..<2, id: \.self) { slip in
                VStack(alignment: .leading, spacing: 6) {
                    Text("帕维的第\(slip == 0 ? "一" : "二")张：" + (slip == order.correctSlip ? Self.rightSlip : Self.wrongSlip)).font(.footnote)
                    Button("按这张发料") { step(project.id, "parts") { economy, _, now in try economy.bicycleIssueParts(project.id, slip: slip, now: now); return true } }
                        .accessibilityIdentifier("bicycle-slip-\(slip)")
                }.padding(8).background(.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            }
        case .sourcing:
            Text("帕维：库里真少一只后轮毂。码头仓还压着一批，要么您自己跑一趟，要么花钱叫个跑腿。")
            Button("自己去码头仓取 · \(Order.errandStamina)体力") {
                step(project.id, "hub", stamina: Order.errandStamina) { economy, coins, now in try economy.bicycleSourceHub(project.id, hireRunner: false, now: now, coins: &coins); return true }
            }.accessibilityIdentifier("bicycle-hub-self")
            Button("雇跑腿送来 · \(Order.courierFee)铜") {
                step(project.id, "hub") { economy, coins, now in try economy.bicycleSourceHub(project.id, hireRunner: true, now: now, coins: &coins); return true }
            }.accessibilityIdentifier("bicycle-hub-runner")
        case .testing:
            Text(order.failedTests > 0
                 ? "乔里：车架上的铆钉又被剪断了——这不是铜的。拧得再紧也撑不住。"
                 : "乔里：我骑一圈。刹车发尖，车把往左偏。")
            Button("紧固刹车、校正车把再试") {
                step(project.id, "test-\(order.failedTests)") { economy, coins, now in try economy.bicycleTestRide(project.id, replaceRivets: false, now: now, coins: &coins) }
            }.accessibilityIdentifier("bicycle-test-tighten")
            Button("换上铜铆钉再试 · \(Order.rivetFee)铜") {
                step(project.id, "rivets") { economy, coins, now in try economy.bicycleTestRide(project.id, replaceRivets: true, now: now, coins: &coins) }
            }.accessibilityIdentifier("bicycle-test-rivets")
        case .ready where order.expansion == .open:
            Text("米拉：车我试过了，不错。我店里又有人要一辆。您再投\(Order.costPerBike)铜做第四辆，我另托管\(Order.pricePerBike)铜。")
            let spent = project.committed + order.extraCosts
            Text("扩单：总投入\(spent + Order.costPerBike)铜，回款\((order.bikes + 1) * Order.pricePerBike)铜。不扩：投入\(spent)铜，回款\(order.bikes * Order.pricePerBike)铜。")
                .font(.footnote.monospacedDigit())
            Button("扩单，再投\(Order.costPerBike)铜") {
                step(project.id, "expand") { economy, coins, now in try economy.bicycleAnswerExpansion(project.id, accept: true, completed: game.churchTowerMissionNumbers, now: now, coins: &coins); return true }
            }.accessibilityIdentifier("bicycle-expand-accept")
            Button("按原订单交货") {
                step(project.id, "expand") { economy, coins, now in try economy.bicycleAnswerExpansion(project.id, accept: false, completed: game.churchTowerMissionNumbers, now: now, coins: &coins); return true }
            }.accessibilityIdentifier("bicycle-expand-decline")
        case .assembling:
            Text("赫伯特：第四副车架今天就能装。您在旁边盯着，别再出铆钉的岔子。")
            Button("监督装配第四辆 · \(Order.assemblyStamina)体力") {
                step(project.id, "assemble", stamina: Order.assemblyStamina) { economy, _, now in try economy.bicycleAssembleExtra(project.id, now: now); return true }
            }.accessibilityIdentifier("bicycle-assemble")
        case .ready:
            Text("米拉：车骑到我店里来，我当面验收、签收条。")
            Button("把\(order.bikes)辆车送到米拉车行 · \(Order.deliveryStamina)体力") {
                step(project.id, "deliver", stamina: Order.deliveryStamina) { economy, _, now in try economy.bicycleDeliver(project.id, now: now); return true }
            }.accessibilityIdentifier("bicycle-deliver")
        case .delivered:
            Text("米拉：收条给您。合同到期那天，托管的\(order.bikes * Order.pricePerBike)铜就付过去。")
        }
    }

    private func step(_ id: String, _ name: String, stamina: Int = 0,
                      _ change: @escaping (inout MPCCityEconomy, inout Int, TimeInterval) throws -> Bool) {
        busy = true
        Task { defer { busy = false }
            do {
                let passed = try await game.bicycleOrderStep(id, step: name, stamina: stamina, change)
                message = passed ? "" : "试车没过。"
            } catch { message = error.localizedDescription }
        }
    }
}

struct CityPrivateMeetingView: View {
    @Bindable var game: GameStore
    var privateRoom = false
    @State private var working = false
    @State private var selectedEvidence: Set<String> = []
    @State private var inspectFirst = true
    @State private var payOnDelivery = true
    @State private var limitedLiability = true
    @State private var busy = false
    @State private var message = ""
    var body: some View {
        GameArtPage(title: privateRoom ? "私人会客 · 雨夜的交货单" : "公开会面 · 雨夜的交货单", subtitle: "染坊账房 · 从单据到实际交货") {
            if privateRoom {
                HousingInteriorArtwork(homeID: game.housingHomeID) { message = $0 }
            } else { Image("HomeCityHallEmpty20260929").resizable().scaledToFit().accessibilityLabel("公开公证柜台") }
            HStack(alignment: .top) {
                Image("HomeDyeClerk20260929").resizable().scaledToFit().frame(width: 84, height: 110).accessibilityHidden(true)
                Text("账房：雨布已经订下，可两份交货记录不一样。我需要一个肯对照原件、敢写清责任的人。")
            }
            Text("可用\(game.venueCoins)铜 · 体力\(game.currentStamina) · 每位客户七日内接待一次").font(.footnote.monospacedDigit())
            if let item = game.cityEconomy.meeting { meeting(item) }
            if game.cityEconomy.meeting == nil || [.paid, .failed, .cancelled].contains(game.cityEconomy.meeting!.stage) {
                Text(privateRoom ? "今日付费联排屋／阁楼／高地住户可邀请。招待4／6／10铜，耗10体力；公众柜台仍可承接基础合同。" : "完成第13关认识账房后，可在柜台谈事。招待2铜，耗10体力；住房不是接基础合同的条件。")
                Button(privateRoom ? "写邀请函，请账房来谈" : "请账房在公开柜台会面") { run { try await game.inviteDyeBookkeeper(privateRoom: privateRoom) } }
                    .buttonStyle(GameArtButtonStyle(primary: true)).disabled(busy || !game.churchTowerMissionNumbers.contains(13))
            }
            if !message.isEmpty { Text(message).foregroundStyle(.orange) }
        }.task { await game.openHousingDay() }.sheet(isPresented: $working) { CityContractWorkView(game: game) }
    }
    @ViewBuilder private func meeting(_ item: MPCCityEconomy.Meeting) -> some View {
        Text("招待已付\(item.fee)铜 · 耗材\(item.inputs)铜 · 验收后合同款\(item.payment)铜 · 净收入\(item.payment - item.inputs - item.fee)铜").font(.footnote)
        switch item.stage {
        case .invited:
            Text("交货单：R-17，四箱雨布，蓝蜡原封；封印原件：R-17，四箱。匿名传闻却说红蜡、六箱。请选两项能相互核验的证据。")
            ForEach([("delivery_receipt", "交货单原件"), ("original_seal", "蓝蜡封印原件"), ("anonymous_rumor", "匿名传闻")], id: \.0) { id, title in
                Button { if !selectedEvidence.insert(id).inserted { selectedEvidence.remove(id) } } label: {
                    Label(title, systemImage: selectedEvidence.contains(id) ? "checkmark.circle.fill" : "circle")
                }.buttonStyle(GameArtButtonStyle(selected: selectedEvidence.contains(id)))
            }
            Button("请账房交叉核对") { command { try $0.verifyMeeting(evidence: selectedEvidence) } }.disabled(selectedEvidence.count != 2 || busy)
        case .verified:
            Text("账房：原件是一批货，便条抄错了。只要先验货、由托管付款，责任只限这批耗材，我就签字。")
            Toggle("先验原封与数量，后接货", isOn: $inspectFirst)
            Toggle("验收后付款，签约时托管", isOn: $payOnDelivery)
            Toggle("责任上限是本批耗材", isOn: $limitedLiability)
            Text("签约立即付\(item.inputs)铜耗材；三日内交货，交货满24小时由账房复核付款。逾期或取消不退已付招待与耗材。")
            Button("签署并采购耗材 · \(item.inputs)铜") {
                run { try await game.cityEconomyAction { try $0.contract(inspectFirst: inspectFirst, payOnDelivery: payOnDelivery, limitedLiability: limitedLiability, now: game.housingNow.timeIntervalSince1970, coins: &$1) } }
            }.disabled(busy || game.venueCoins < item.inputs)
        case .contracted:
            Text("工坊收到了耗材款，四箱R-17雨布已备好。期限：\(Date(timeIntervalSince1970: item.deadline).formatted(date: .abbreviated, time: .shortened))")
            Button("去工坊货场提货") { working = true }
        case .collected:
            Text("验印台：箱签R-17，数量四箱。核对原封，别用后来抄写的便条。")
            Button("去市政验印台核对原封") { working = true }
        case .sealed:
            Text("验印一致，签收人是染坊账房。送到染坊后取得收条。")
            Button("去染坊交货 · \(item.deliveryStamina)体力") { working = true }
        case .delivered:
            Text("四箱已收。待复核付款：\(Date(timeIntervalSince1970: item.dueAt!).formatted(date: .abbreviated, time: .shortened))；重复进屋不刷新到期时间。")
            Button("查收账房来信") { run { await game.openHousingDay() } }
        case .paid: Text("合同已履行，\(item.payment)铜已入同一个钱袋。账房留下验印联系方式；新一轮接待需等七日。")
        case .failed: Text("交货超时，合同已关闭。下一次请先留足时间和耗材预算。")
        case .cancelled: Text("会面已结束。已发生的招待和耗材已记账。")
        }
        if ![.delivered, .paid, .failed, .cancelled].contains(item.stage) {
            Button("结束这次会面／取消合同") { command { try $0.cancelMeeting() } }.buttonStyle(GameArtButtonStyle())
        }
    }
    private func command(_ action: @escaping (inout MPCCityEconomy) throws -> Void) {
        run { try await game.cityEconomyAction { economy, _ in try action(&economy) } }
    }
    private func run(_ action: @escaping @MainActor () async throws -> Void) {
        busy = true
        Task { defer { busy = false }; do { try await action(); message = "已记下这一步，可以继续。" } catch { message = error.localizedDescription } }
    }
}

struct CityInstitutionsView: View {
    @Bindable var game: GameStore
    let onOpen: (String) -> Void
    private let counters: [(String, String, String)] = [
        ("bank", "银行", "新客与普通定期；产业投资由经理接待"),
        ("housing-agency", "赁屋行", "Q1铺位；Q5合租；Q13联排；Q20阁楼；Q30高地"),
        ("housing-home", "我的住处", "回房用休息储备；付费联排以上可备战与会客"),
        ("meeting", "公证与公开会面", "Q13染坊账房基础合同；普通住房也可接"),
        ("merchant", "商人与晋阶采购", "Q4遗落物和药；Q17／20／23三份主材"),
        ("postal-work", "邮局", "Q4单据核验与邮务筹资"),
        ("board", "广场委托板", "每日有限委托，街坊故事与贡献条件"),
        ("church", "联合教会", "Q7深井、通缉、借物；塔层继续按日开放"),
        ("workshop", "百工坊与工业委员会", "Q5生产；塔材料与装备；Q16项目订单"),
        ("clinic", "诊所", "Q4伤情与案件验伤；备用药在商人处采购"),
        ("police", "警察厅", "Q4公开登记；Q7后案件调查与证人问话"),
        ("cityhall", "市政厅", "民事登记、验印、公证与合同收条"),
        ("harbor", "港务处", "航运与案件货物核验；饮食登记"),
        ("housing-soup", "汤棚", "基础食宿12铜／日"),
        ("housing-bakery", "面包坊", "登记饮食；合租推荐套餐16铜／日"),
        ("housing-cafe", "午夜钟咖啡馆", "登记饮食；联排推荐套餐22铜／日"),
        ("oldstreet", "旧街铺面", "染坊账房、木工、相片铺与案件联系人"),
        ("newspaper", "报社", "今日主线、塔额与城市事项"),
        ("tavern", "酒馆", "通缉问话；B08结案后常驻牌局，不发新晋阶材料"),
        ("science", "科学委员会", "查看遗落物作用与代价、公开验证记录"),
        ("highland-board", "高地告示处", "Q30后，今日付费高地住户的有限委托"),
        ("palace", "皇宫接待处", "城市历史地标；内廷业务以后续章节为准")
    ]
    var body: some View {
        GameArtPage(title: "港城办事册", subtitle: "第\(game.pacingDay)日 · 钱袋、住处与成长") {
            CityWalletSummary(game: game)
            ForEach(counters, id: \.0) { id, name, detail in
                HomeCounterAction(title: name, detail: detail) { onOpen(id) }
            }
        }
    }
}

struct CityScienceView: View {
    @Bindable var game: GameStore
    var body: some View {
        HomeCounterScene(title: "科学委员会 · 公开鉴定柜", room: .counter("cityhall"), actorArt: "HomeArchivist20260929") {
            Text("研究员把作用、代价与适合的对手写在同一页。买得贵不能代替理解它。")
            ForEach(EarlyRelicShop.ids.filter { game.chapterOneCampaign.ownedRelicIDs.contains($0) }, id: \.self) { id in
                Text(EarlyRelicShop.name(id)).font(.headline)
                Text(EarlyRelicShop.detail(id))
            }
            if game.chapterOneCampaign.ownedRelicIDs.isDisjoint(with: EarlyRelicShop.ids) { Text("Q4后可在商人处购入遗落物，再带来查阅作用与代价。") }
            Text("本章公开柜提供已有遗落物的规则档案；专业研究与新的鉴定剧情随后续章节发布。").font(.footnote)
        }
    }
}

#if DEBUG
/// Only the separately identified playtest app shows time controls and fixture profiles.
/// Each profile has its own suite, persistent receipts and clock offset.
struct InstitutionPlaytestRoot: View {
    @Binding var game: GameStore
    @Bindable var storefront: Storefront
    @State private var settings = false
    @State private var busy = false
    @State private var message = ""
    @State private var bicycleReview: (GameStore, String)?
    private var profile: String { UserDefaults.standard.string(forKey: "institution.profile") ?? "fresh" }
    var body: some View {
        ContentView(game: game, storefront: storefront)
            .defaultAppStorage(UserDefaults(suiteName: "mistport.institutions.playtest.20261013." + profile)!)
            .overlay(alignment: .bottomLeading) {
                if game.phase == .cityHub || game.phase == .title {
                    Button("试玩设置") { settings = true }.font(.caption.bold()).padding(12)
                        .background(.black.opacity(0.6), in: Capsule()).padding(12).padding(.bottom, game.phase == .cityHub ? 100 : 0)
                }
            }
            .sheet(isPresented: $settings) {
                GameArtPage(title: "机构试玩存档", subtitle: "独立 App · 时间操作仅作用于试玩存档") {
                    Text("开局档从180铜开始正常游玩。住房档模拟已完成Q13，提供1200铜和联排租约；这部分是测试夹具，不是真实赢取。两档分别保存银行与合同记录。")
                    Button("切到开局档（保留该档进度）") { switchProfile("fresh") }
                    Button("切到住房档（保留该档进度）") { switchProfile("housing") }
                    Text("当前：\(profile == "fresh" ? "开局" : "住房") · 第\(game.pacingDay)日")
                    Button("试玩时钟前进24小时") {
                        busy = true
                        Task { defer { busy = false }; await game.advanceInstitutionClock(); message = "已前进24小时，日费、到期和日期门槛照规则结算。" }
                    }.disabled(busy)
                    Text("可以用时钟检查72小时存单、合同到账、租约与材料预算；正式日期门槛没有删除。")
                    if !message.isEmpty { Text(message) }
                }.buttonStyle(GameArtButtonStyle())
            }
            .task {
                game.configureInstitutionClock()
                if profile == "housing" { await game.prepareInstitutionHousingFixtureIfNeeded() }
                await storefront.prepare()
                if ProcessInfo.processInfo.arguments.contains("--verify-institutions") { await GameStore.verifyInstitutionIntegration() }
                if let flag = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--review-bicycle-order") }) {
                    bicycleReview = await GameStore.bicycleOrderReview(stage: flag.split(separator: "=").last.map(String.init) ?? "parts")
                }
            }
            .fullScreenCover(isPresented: Binding(get: { bicycleReview != nil }, set: { if !$0 { bicycleReview = nil } })) {
                if let (store, id) = bicycleReview { CityBicycleOrderView(game: store, projectID: id) }
            }
    }
    private func switchProfile(_ id: String) {
        UserDefaults.standard.set(id, forKey: "institution.profile")
        let storage = UserDefaults(suiteName: "mistport.institutions.playtest.20261013." + id)!
        let replacement = GameStore(launchArguments: [], defaults: storage)
        replacement.configureInstitutionClock()
        game = replacement
        if id == "housing" { Task { await game.prepareInstitutionHousingFixtureIfNeeded() } }
        settings = false
    }
}
#endif

struct CityPostalWorkView: View {
    @Bindable var game: GameStore
    var body: some View {
        HomeCounterScene(title: "邮局 · 单据核验", room: .counter("post"), actorArt: "HomePostman20260929") {
            Text("钱袋\(game.venueCoins)铜 · 体力\(game.currentStamina)").font(.headline.monospacedDigit())
            if game.earlyRelicShopUnlocked {
                Text("第\(game.postalJobSerial + 1)份邮单：核对收件人、街道和封记，完成后40铜；一份工作10体力，三个字段只扣一次。")
                Text("原始单据：" + game.postalJobFields.joined(separator: " · ")).padding(10).background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                Text(["核对收件人", "核对投递街道", "核对原始封记"][game.postalJobStep]).font(.headline)
                ForEach(game.postalJobOptions, id: \.self) { answer in
                    let serial = game.postalJobSerial, step = game.postalJobStep
                    Button(answer) { Task { await game.verifyPostalField(answer, serial: serial, step: step) } }.buttonStyle(GameArtButtonStyle())
                }
            } else { Text("Q4后可承接邮务工作；不需要投资或高级住房。") }
            if !game.featureMessage.isEmpty { Text(game.featureMessage).foregroundStyle(.orange) }
        }.task { await game.openHousingDay() }
    }
}

struct CityContractWorkView: View {
    @Bindable var game: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var busy = false
    private var stage: MPCCityEconomy.MeetingStage? { game.cityEconomy.meeting?.stage }
    var body: some View {
        HomeCounterScene(title: stage == .contracted ? "工坊货场 · 提货" : stage == .collected ? "市政验印台" : "染坊 · 收货柜台",
            room: .counter(stage == .contracted ? "harbor" : stage == .collected ? "cityhall" : "oldstreet"),
            actorArt: stage == .contracted ? "HomeLaborClerk20260929" : stage == .collected ? "HomeStampClerk20260929" : "HomeDyeClerk20260929") {
            if let item = game.cityEconomy.meeting {
                Text("交货单 R-17 · 四箱雨布 · 蓝蜡原封").font(.headline)
                Text("交货期限：\(Date(timeIntervalSince1970: item.deadline).formatted(date: .abbreviated, time: .shortened))")
                if stage == .contracted {
                    Text("库管指着货架：左边四箱R-17蓝蜡，中间六箱S-12红蜡。账房的原单订的是哪批？")
                    Button("提取左边四箱 R-17 蓝蜡货") { perform { try await game.cityEconomyAction { economy, _ in try economy.collectGoods(now: game.housingNow.timeIntervalSince1970) } } }
                    Button("提取中间六箱 S-12 红蜡货") { message = "库管摇头：这批是另一位客户的货，与原单不符。" }
                } else if stage == .collected {
                    Text("验印员：箱签和数量相符。拿你在会面时核对的封印原件给我，与箱口比对。")
                    Button("提交蓝蜡 R-17 原封") { perform { try await game.cityEconomyAction { economy, _ in try economy.sealGoods(original: true, now: game.housingNow.timeIntervalSince1970) } } }
                    Button("提交匿名传闻的红蜡封") { message = "验印员：红蜡不属于这批货，原封核验未通过。" }
                } else if stage == .sealed {
                    Text("账房检查了四个箱口：货签、数量、原封都对。我现在签收，24小时后核对托管款。")
                    Button("送交四箱并取得收条 · \(item.deliveryStamina)体力") { perform { try await game.deliverMeetingGoods() } }
                } else { Text("本批手续已记录，请回会面桌查收进展与来信。") }
            } else { Text("还没有签署交货合同。") }
            if !message.isEmpty { Text(message).foregroundStyle(.orange) }
        }.buttonStyle(GameArtButtonStyle(primary: true)).disabled(busy)
    }
    private func perform(_ action: @escaping @MainActor () async throws -> Void) {
        busy = true
        Task { defer { busy = false }; do { try await action(); dismiss() } catch { message = error.localizedDescription } }
    }
}

struct CityHousingMaintenanceView: View {
    @Bindable var game: GameStore
    @State private var message = ""
    var body: some View {
        GameArtPage(title: "住处保养角", subtitle: "实物服务 · 优惠已经计入报价") {
            Text("联排／阁楼／高地每日一件普通遗落物，最多抵扣1／2／3铜且不超过实际费用一半。已经用过便按常价，不领取现金券。")
            Text("可用\(game.venueCoins)铜").font(.headline.monospacedDigit())
            ForEach(EarlyRelicShop.ids.filter { game.chapterOneCampaign.ownedRelicIDs.contains($0) }, id: \.self) { id in
                let durability = game.churchServices.ownedCondition.currentDurability(id)
                let price = game.ownedRelicRepairQuote(id)
                Text("\(EarlyRelicShop.name(id)) · 完好\(durability)%")
                Button("保养至100% · \(price)铜") {
                    do { try game.repairOwnedChurchRelic(id); message = "保养已完成，费用与今日服务已记账。" }
                    catch { message = error.localizedDescription }
                }.buttonStyle(GameArtButtonStyle()).disabled(durability == 100 || game.venueCoins < price)
            }
            if game.chapterOneCampaign.ownedRelicIDs.isDisjoint(with: EarlyRelicShop.ids) { Text("先在商人处购入遗落物。没有维修需求，就没有这笔支出或优惠。") }
            if !message.isEmpty { Text(message).foregroundStyle(.orange) }
        }.task { await game.openHousingDay() }
    }
}
