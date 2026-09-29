import SwiftUI
import MistportCombatCore

/// Painted plate button in the game's flat style (ART_BRIEF_WORKSHOP_UI_20260928).
/// The plate carries no text; the label is live so prices and counts stay current.
/// Plates scale uniformly: their side ornaments sit next to the label, so they must not stretch.
struct PlateButton: View {
    enum Plate: String {
        case workshopPrimary = "ButtonArtWorkshopPrimary"
        case workshopSecondary = "ButtonArtWorkshopSecondary"
        case saltportRoute = "ButtonArtSaltportRoute"
        case saltportNews = "ButtonArtSaltportNews"
        case ritual = "ButtonArtRitualSequence8"
        case battle = "ButtonArtPublicBattle"
        case sideChoice = "ButtonArtSideChoice"

        var isDark: Bool { [.workshopSecondary, .saltportRoute, .ritual, .battle].contains(self) }
        /// The empty label band between the side ornaments, as fractions of the plate width (measured).
        var label: (center: CGFloat, width: CGFloat) {
            switch self {
            case .workshopPrimary: (0.405, 0.56)
            case .workshopSecondary: (0.424, 0.50)
            case .saltportRoute: (0.431, 0.51)
            case .saltportNews: (0.425, 0.53)
            case .ritual: (0.426, 0.51)
            case .battle: (0.432, 0.46)
            case .sideChoice: (0.467, 0.49)
            }
        }
    }

    private static let aspect: CGFloat = 866.0 / 192.0
    private static let gold = Color(red: 0.93, green: 0.78, blue: 0.48)
    private static let ink = Color(red: 0.22, green: 0.16, blue: 0.10)

    let title: String
    let plate: Plate
    /// Only for `.sideChoice`: the faction emblem laid into the empty round inset.
    var emblem: String? = nil
    var enabled = true
    var height: CGFloat = 58
    let action: () -> Void

    var body: some View {
        let width = height * Self.aspect
        Button {
            GameInterfaceSound.shared.playClick()
            action()
        } label: {
            ZStack {
                Image(decorative: plate.rawValue).resizable().scaledToFit()
                Text(title)
                    .font(.system(size: height * 0.3, weight: .bold, design: .serif))
                    .foregroundStyle(plate.isDark ? Self.gold : Self.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: width * plate.label.width)
                    .position(x: width * plate.label.center, y: height / 2)
                if let emblem {
                    Image(decorative: emblem).resizable().scaledToFit()
                        .frame(width: height * 0.56, height: height * 0.56)
                        .position(x: width * 0.884, y: height / 2)
                }
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityLabel(title)
        .frame(maxWidth: .infinity)
    }
}

/// Production save-backed workshop; never constructs an isolated playtest fixture.
struct LocalWorkshopView: View {
    @Bindable var game: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var showsTower = false
    @State private var message = ""
    @State private var selectedCraft: MPCCraftRecipe.Craft = .leather

    /// Card colour; the step illustrations fade to exactly this at their edges.
    private static let card = Color(red: 0.149, green: 0.153, blue: 0.169)

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
                    HStack {
                        stock("RewardCoin", "\(game.venueCoins) 铜")
                        Spacer()
                        Text("皮革熟练 \(game.craftingLedger.points(.leather))/20")
                    }.font(.headline).monospacedDigit()
                    HStack(spacing: 18) {
                        stock("ItemShieldJawHide", "韧皮 \(game.workshopHideCount)")
                        stock("ItemRepairStrap", "维修绑带 \(game.workshopStrapCount)")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("workshop.inventory")
                    if !game.cityServiceIsUnlocked(.workshop) {
                        Text("通过第 5 关后开放。")
                    } else if !game.workshopLedgerIsReadable {
                        Text("工坊记录读不出来，暂时不能使用。")
                    } else if !game.churchMistportFieldworkAvailable {
                        Text("你已离开雾港，这里的工坊先关着，东西都给你留着。")
                    } else {
                        gathering
                        recipe
                        dailyOrders
                        WorkshopGearCareSection(game: game)
                        order
                    }
                    if !message.isEmpty {
                        Text(message).foregroundStyle(.yellow).accessibilityIdentifier("workshop.message")
                    }
                }.padding(20)
            }
            .background(Color(red: 0.055, green: 0.08, blue: 0.12))
            .navigationTitle("百工坊")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("返回", action: { dismiss() }) } }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showsTower) { ChurchSanctuaryView(game: game) }
        .onAppear { game.openDailyWorkshopOrders() }
    }

    private func stock(_ art: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(decorative: art).resizable().scaledToFit().frame(width: 24, height: 24)
            Text(text)
        }
    }

    /// A step card: its illustration with the step name in the dark left band, then the content.
    private func step<Content: View>(_ number: String, _ title: String, art: String,
                                     @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(decorative: art).resizable().scaledToFit()
                .overlay(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(number).font(.caption.bold()).foregroundStyle(.secondary)
                        Text(title).font(.title3.bold())
                    }
                    .padding(.leading, 14)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityElement(children: .combine)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var gathering: some View {
        step("01", "取材", art: "WorkshopStepGather") {
            Text("每次封堵或重打深井，都会取得该层恶魔的材料；已封层可随时重打。")
            PlateButton(title: "前往教会塔取材", plate: .workshopSecondary) { showsTower = true }
        }
    }
    private var recipe: some View {
        step("02", "制作", art: "WorkshopStepCraft") {
            Picker("手艺", selection: $selectedCraft) {
                Text("皮革").tag(MPCCraftRecipe.Craft.leather)
                Text("药剂").tag(MPCCraftRecipe.Craft.alchemy)
                Text("金属").tag(MPCCraftRecipe.Craft.metal)
                Text("织造").tag(MPCCraftRecipe.Craft.weaving)
            }.pickerStyle(.segmented)
            Text("本门熟练 \(game.craftingLedger.points(selectedCraft))/20").font(.headline)
            Text(game.workshopProficiencyNotice).font(.caption).foregroundStyle(.secondary)
            ForEach(MPCCraftingCatalog.all.filter { $0.craft == selectedCraft }) { recipe in
                WorkshopRecipeRow(game: game, recipe: recipe) { recipeID in
                    perform("制作完成。") { try game.craftDailyWorkshop(recipeID: recipeID) }
                }
            }
        }
    }
    private var dailyOrders: some View {
        step("03", "每日订单", art: "WorkshopStepInstall") {
            Text("诊所 · 港务处 · 教会").font(.headline)
            Text("今日还可收购 \(game.workshopOrders.budget) 铜；余款最多累积 3 天。卖不掉的货可留着自用。")
            ForEach(MPCCraftingCatalog.basics) { recipe in
                HStack {
                    VStack(alignment: .leading) {
                        Text(recipe.name)
                        Text("库存 \(game.chapterOneCampaign.inventory[recipe.output, default: 0]) · 每件 \(MPCWorkshopOrderBoard.prices[recipe.output, default: 0]) 铜")
                            .font(.caption).foregroundStyle(.secondary)
                        if game.chapterOneCampaign.inventory[recipe.output, default: 0] == 0 {
                            Text("没有库存，请先制作。").font(.caption).foregroundStyle(.yellow)
                        } else if game.workshopOrders.budget < MPCWorkshopOrderBoard.prices[recipe.output, default: 0] {
                            Text("今日订单预算不足这一件的单价，明天再来。").font(.caption).foregroundStyle(.yellow)
                        }
                    }
                    Spacer()
                    Button("交 1 件") {
                        perform("已交货，铜币已到账。") { _ = try game.sellDailyWorkshop(itemID: recipe.output) }
                    }.buttonStyle(.bordered)
                        .disabled(game.chapterOneCampaign.inventory[recipe.output, default: 0] == 0 || game.workshopOrders.budget < MPCWorkshopOrderBoard.prices[recipe.output, default: 0])
                }
            }
            if game.workshopOrders.budget < 8 { Text("今天的收购预算已不足，明天再来。 ").font(.caption).foregroundStyle(.yellow) }
        }
    }
    private var order: some View {
        step("03", "工坊检修架", art: "WorkshopStepInstall") {
            switch game.localWorkshop.order {
            case .offered:
                Text("旧绑带裂了，工坊收 2 条新的，付 18 铜。")
                PlateButton(title: "交付 2 条 · 收 18 铜", plate: .workshopPrimary, enabled: game.workshopStrapCount >= 2) {
                    perform("交了 2 条，收到 18 铜。") { try game.deliverWorkshopStraps() }
                }
            case .delivered:
                Text("货已交，装上就完工。")
                PlateButton(title: "安装绑带", plate: .workshopPrimary) {
                    perform("检修架修好了。") { try game.installWorkshopStraps() }
                }
            case .installed:
                Label("检修架修好了", systemImage: "checkmark.seal.fill").foregroundStyle(.mint)
            }
        }
    }
    private func perform(_ success: String, action: () throws -> Void) {
        do { try action(); message = success }
        catch let error as MPCLocalWorkshopLedger.Failure {
            switch error {
            case .locked: message = "现在还不能做这一步。"
            case .funds: message = "铜币不够。"
            case .stock: message = "材料不够。"
            case .exhausted: message = "这单已经收满了。"
            case .conflict: message = "没有生效，请再点一次。"
            }
        } catch { message = "没能保存，请再试一次。" }
    }
}

private struct WorkshopRecipeRow: View {
    let game: GameStore
    let recipe: MPCCraftRecipe
    let craft: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(recipe.name) ×\(recipe.outputCount)").font(.headline)
            Text(recipe.inputs.sorted(by: { $0.key < $1.key }).map {
                "\(GameStore.workshopItemName($0.key)) \(game.chapterOneCampaign.inventory[$0.key, default: 0])/\($0.value)"
            }.joined(separator: " · ")).font(.caption)
            Text("底料 \(MPCCraftingCatalog.baseStock(recipe, surcharge: game.dailyCityEffects.craftSurcharge)) 铜")
            if let tier = MPCChurchGearCatalog.item(recipe.output)?.craftTier {
                Text("F\(tier) 档 · 封堵第 \(tier) 层后可穿戴；制作后需手动装备。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let reason = game.workshopRecipeLock(recipe) {
                Text(reason).font(.caption).foregroundStyle(.yellow)
            }
            PlateButton(title: "制作 · \(recipe.name)", plate: .workshopPrimary,
                        enabled: game.workshopRecipeLock(recipe) == nil) { craft(recipe.id) }
        }.padding(.vertical, 10)
    }
}

struct WorkshopGearCareSection: View {
    let game: GameStore
    @State private var message = ""
    private var pieces: [MPCChurchGearItem] {
        MPCChurchGearCatalog.all.filter { $0.craftTier != nil && game.churchServices.gear.ownedIDs.contains($0.id) }
    }
    var body: some View {
        if !pieces.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("工坊装备保养").font(.headline)
                ForEach(pieces) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name).font(.subheadline.bold())
                        Text("F\(item.craftTier ?? 0) 档 · 耐久 \(game.churchServices.gear.durability(item.id) ?? 0)/100")
                            .font(.caption)
                        let unlocked = (game.churchTowerProgress.clearedFloors.max() ?? 0) >= (item.craftTier ?? 0)
                        let kit = item.slot == .weapon ? MPCChurchGearLedger.bladeKitID : MPCChurchGearLedger.mailKitID
                        if !unlocked { Text("封堵第 \(item.craftTier ?? 0) 层后可穿戴").font(.caption).foregroundStyle(.yellow) }
                        HStack {
                            Button("穿戴") { perform { try game.equipChurchGear(item.id) } }
                                .disabled(!unlocked)
                            Button("用\(GameStore.workshopItemName(kit))修理 +25") {
                                perform { try game.repairWorkshopGear(item.id) }
                            }.disabled((game.churchServices.gear.durability(item.id) ?? 100) == 100 || game.chapterOneCampaign.inventory[kit, default: 0] == 0)
                        }.buttonStyle(.bordered)
                        Text("\(GameStore.workshopItemName(kit))库存 \(game.chapterOneCampaign.inventory[kit, default: 0])").font(.caption)
                    }
                }
                if !message.isEmpty { Text(message).font(.caption).foregroundStyle(.yellow) }
            }
        }
    }
    private func perform(_ action: () throws -> Void) {
        do { try action(); message = "已保存。" }
        catch { message = "尚未满足穿戴或修理条件。" }
    }
}
