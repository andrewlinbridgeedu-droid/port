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
    @State private var confirmsExtraBatch = false

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
                        Text("皮革熟练 \(game.localWorkshop.proficiency)/20")
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
        .confirmationDialog("这单已经收满，再做的绑带暂时卖不出去。还要花 13 铜做一批吗？", isPresented: $confirmsExtraBatch) {
            Button("做一批 · 13铜") { craft() }
            Button("算了", role: .cancel) {}
        }
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
            Text("在教会塔第 1 层打败盾颚魔，可得 1 份韧皮。")
            PlateButton(title: "前往教会塔取材", plate: .workshopSecondary) { showsTower = true }
        }
    }
    private var recipe: some View {
        step("02", "皮革制作", art: "WorkshopStepCraft") {
            Text("维修绑带：1 份韧皮 + 13 铜 → 3 条")
            if !game.localWorkshop.learnedBasics {
                PlateButton(title: "学习图纸 · 免费", plate: .workshopPrimary) {
                    perform("学会了维修绑带。") { try game.learnWorkshopBasics() }
                }
            } else {
                PlateButton(title: "制作一批 · 13铜", plate: .workshopPrimary,
                            enabled: game.workshopHideCount >= 1 && game.venueCoins >= 13) {
                    if game.localWorkshop.order != .offered { confirmsExtraBatch = true }
                    else { craft() }
                }
                if game.workshopHideCount < 1 { Text("还缺 1 份韧皮。").font(.caption).foregroundStyle(.secondary) }
                else if game.venueCoins < 13 { Text("还差 \(13 - game.venueCoins) 铜。").font(.caption).foregroundStyle(.secondary) }
            }
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
    private func craft() {
        perform("做好 3 条维修绑带，皮革熟练 +1。") { try game.craftWorkshopStraps() }
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
