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
    /// The workshop's five parts as tabs (2026-10-15, user: 尽量一页展示所有内容，不需要翻页):
    /// each fits a screen; stacked they took several screens of scrolling.
    private enum Section: String, CaseIterable { case gather = "取材", craft = "制作", orders = "每日订单", care = "装备保养", rack = "检修架" }
    @State private var section: Section = .craft

    /// Card colour; the step illustrations fade to exactly this at their edges.
    private static let card = Color(red: 0.149, green: 0.153, blue: 0.169)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("百工坊").font(.title2.bold()).fontDesign(.serif)
                Spacer()
                GameArtReturnButton(title: "返回") { dismiss() }
            }.foregroundStyle(GameArt.gold).padding(.horizontal, 18).padding(.vertical, 12).background(GameArt.night)
            HStack(spacing: 14) {
                stock("RewardCoin", "\(game.venueCoins) 铜")
                stock("ItemShieldJawHide", "韧皮 \(game.workshopHideCount)")
                stock("ItemRepairStrap", "绑带 \(game.workshopStrapCount)")
                Spacer(minLength: 0)
            }.font(.subheadline.bold()).monospacedDigit().foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 8)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("workshop.inventory")
            HStack(spacing: 6) {
                ForEach(Section.allCases, id: \.self) { item in
                    Button { GameInterfaceSound.shared.playClick(); section = item } label: {
                        Text(item.rawValue).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .foregroundStyle(section == item ? GameArt.gold : .white.opacity(0.72))
                            .background(section == item ? GameArt.gold.opacity(0.14) : Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(section == item ? GameArt.gold.opacity(0.6) : .white.opacity(0.08)) }
                    }.buttonStyle(.plain).accessibilityIdentifier("workshop.section.\(item.rawValue)")
                }
            }.padding(.horizontal, 12).padding(.bottom, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !game.cityServiceIsUnlocked(.workshop) {
                        Text("通过第 5 关后开放。")
                    } else if !game.workshopLedgerIsReadable {
                        Text("工坊记录读不出来，暂时不能使用。")
                    } else if !game.churchMistportFieldworkAvailable {
                        Text("你已离开雾港，这里的工坊先关着，东西都给你留着。")
                    } else {
                        switch section {
                        case .gather: gathering
                        case .craft: recipe
                        case .orders: dailyOrders
                        case .care: WorkshopGearCareSection(game: game)
                        case .rack: order
                        }
                    }
                    if !message.isEmpty {
                        Text(message).foregroundStyle(.yellow).accessibilityIdentifier("workshop.message")
                    }
                }.padding(.horizontal, 14).padding(.vertical, 10)
            }
            .background(Color(red: 0.055, green: 0.08, blue: 0.12))
        }
        .background(GameArt.night.ignoresSafeArea())
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
        VStack(alignment: .leading, spacing: 10) {
            // A short banner: the full illustration was a third of the screen.
            Image(decorative: art).resizable().scaledToFill()
                .frame(height: 96).frame(maxWidth: .infinity).clipped()
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
            // Playtest 2026-10-04: the workshop opens at Q5 but the church at
            // Q7; this button used to walk straight past the church lock.
            if game.cityServiceIsUnlocked(.church) {
                PlateButton(title: "前往教会塔取材", plate: .workshopSecondary) { showsTower = true }
            } else {
                Text(MPCChurchTowerCatalog.lockText + "；之前可先熟悉配方。")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }
    private var recipe: some View {
        step("02", "制作", art: "WorkshopStepCraft") {
            craftSelector
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(craftTitle(selectedCraft))熟练度")
                        .foregroundStyle(.white.opacity(0.88))
                    Spacer(minLength: 12)
                    Text("\(game.craftingLedger.points(selectedCraft)) / 20")
                        .foregroundStyle(GameArt.gold)
                        .monospacedDigit()
                }
                .font(.subheadline.weight(.semibold))
                ProgressView(value: Double(min(20, max(0, game.craftingLedger.points(selectedCraft)))), total: 20)
                    .tint(GameArt.gold)
                    .accessibilityLabel("\(craftTitle(selectedCraft))熟练度")
                    .accessibilityValue("\(game.craftingLedger.points(selectedCraft))，满级20")
            }
            .padding(.top, 6)
            .padding(.bottom, 4)
            StaminaCostView(activity: .craft)
                    Text(game.workshopProficiencyNotice).font(.caption).foregroundStyle(.secondary)
            // Recipes two to a row (2026-10-15: one page).
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(MPCCraftingCatalog.all.filter { $0.craft == selectedCraft }) { recipe in
                    WorkshopRecipeRow(game: game, recipe: recipe) { recipeID in
                        Task { do { try await game.craftDailyWorkshop(recipeID: recipeID); message = "制作完成。" } catch { message = game.housingError(error) } }
                    }
                }
            }
        }
    }
    private var craftSelector: some View {
        HStack(spacing: 6) {
            ForEach(MPCCraftRecipe.Craft.allCases, id: \.self) { craft in
                let isSelected = selectedCraft == craft
                Button {
                    GameInterfaceSound.shared.playClick()
                    selectedCraft = craft
                } label: {
                    VStack(spacing: 7) {
                        Text(craftTitle(craft))
                            .font(.subheadline.weight(.semibold))
                            .fontDesign(.serif)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Capsule()
                            .fill(isSelected ? GameArt.gold : .clear)
                            .frame(width: 22, height: 2)
                    }
                    .foregroundStyle(isSelected ? GameArt.gold : .white.opacity(0.72))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        isSelected ? GameArt.gold.opacity(0.12) : Color.black.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(isSelected ? GameArt.gold.opacity(0.6) : .white.opacity(0.08), lineWidth: 1)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(craftTitle(craft))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("workshop.craft.\(craft.rawValue)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("制作分类")
    }

    private func craftTitle(_ craft: MPCCraftRecipe.Craft) -> String {
        switch craft {
        case .leather: "皮革"
        case .alchemy: "药剂"
        case .metal: "金属"
        case .weaving: "织造"
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
                    }.buttonStyle(GameArtButtonStyle(compact: true))
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
        VStack(alignment: .leading, spacing: 5) {
            Text("\(recipe.name) ×\(recipe.outputCount)").font(.subheadline.bold())
            Text(recipe.inputs.sorted(by: { $0.key < $1.key }).map {
                "\(GameStore.workshopItemName($0.key)) \(game.chapterOneCampaign.inventory[$0.key, default: 0])/\($0.value)"
            }.joined(separator: " · ")).font(.caption)
            Text("底料 \(MPCCraftingCatalog.baseStock(recipe, surcharge: game.dailyCityEffects.craftSurcharge)) 铜").font(.caption)
            if let tier = MPCChurchGearCatalog.item(recipe.output)?.craftTier {
                Text("F\(tier) 档 · 封堵第\(tier)层后可穿戴").font(.caption2).foregroundStyle(.secondary)
            }
            if let reason = game.workshopRecipeLock(recipe) {
                Text(reason).font(.caption2).foregroundStyle(.yellow).lineLimit(2)
            }
            Spacer(minLength: 0)
            PlateButton(title: "制作", plate: .workshopPrimary, enabled: game.workshopRecipeLock(recipe) == nil, height: 38) { craft(recipe.id) }
        }.frame(maxWidth: .infinity, alignment: .topLeading).padding(8)
            .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
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
                        }.buttonStyle(GameArtButtonStyle(compact: true))
                        Text("\(GameStore.workshopItemName(kit))库存 \(game.chapterOneCampaign.inventory[kit, default: 0])").font(.caption)
                    }
                }
                if !message.isEmpty { Text(message).font(.caption).foregroundStyle(.yellow) }
            }
        } else {
            Text("还没有工坊制作的装备。封堵深井取得锻造配方后，在这里穿戴和修理。").foregroundStyle(.white.opacity(0.85))
        }
    }
    private func perform(_ action: () throws -> Void) {
        do { try action(); message = "已保存。" }
        catch { message = "尚未满足穿戴或修理条件。" }
    }
}
