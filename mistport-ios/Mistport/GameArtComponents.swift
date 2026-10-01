import SwiftUI

/// Shared game chrome. Labels remain live text; decoration never handles input.
enum GameArt {
    static let ink = Color(red: 0.22, green: 0.16, blue: 0.11)
    static let gold = Color(red: 0.87, green: 0.72, blue: 0.45)
    static let night = Color(red: 0.065, green: 0.085, blue: 0.105)
    static let paper = Color(red: 0.94, green: 0.88, blue: 0.74)
}

struct GameArtCutout: Shape {
    func path(in r: CGRect) -> Path {
        let c = min(7.0, r.height / 4)
        return Path { p in
            p.move(to: CGPoint(x: c, y: 0)); p.addLine(to: CGPoint(x: r.width-c, y: 0))
            p.addLine(to: CGPoint(x: r.width, y: c)); p.addLine(to: CGPoint(x: r.width, y: r.height-c))
            p.addLine(to: CGPoint(x: r.width-c, y: r.height)); p.addLine(to: CGPoint(x: c, y: r.height))
            p.addLine(to: CGPoint(x: 0, y: r.height-c)); p.addLine(to: CGPoint(x: 0, y: c)); p.closeSubpath()
        }
    }
}

struct GameArtButtonStyle: ButtonStyle {
    var primary = false
    var compact = false
    var selected = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? .subheadline.weight(.semibold) : .headline)
            .fontDesign(.serif)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, compact ? 14 : 24)
            .padding(.top, primary ? 22 : 12)
            .padding(.bottom, 12)
            .frame(maxWidth: compact ? nil : .infinity, minHeight: 44)
            .foregroundStyle(primary ? GameArt.ink : Color(red: 0.98, green: 0.91, blue: 0.74))
            .background {
                if primary {
                    Image("ButtonArt25MainAction")
                        .resizable()
                        .accessibilityHidden(true)
                } else {
                    GameArtCutout().fill(LinearGradient(colors: [selected ? Color(red: 0.34, green: 0.26, blue: 0.13) : Color(red: 0.22, green: 0.26, blue: 0.28), GameArt.night], startPoint: .topLeading, endPoint: .bottomTrailing))
                    GameArtCutout().stroke(GameArt.gold.opacity(selected ? 1 : 0.7), lineWidth: selected ? 2 : 1)
                    GameArtCutout().stroke(GameArt.gold.opacity(0.22), lineWidth: 0.5).padding(4)
                }
            }
            .accessibilityAddTraits(selected ? .isSelected : [])
            .contentShape(Rectangle())
            .brightness(configuration.isPressed ? -0.10 : 0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.42)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Shared page-return control, matching the approved harbor-counter button.
/// Callers retain their navigation action and name the actual destination.
struct GameArtReturnButton: View {
    var title = "返回港城"
    let action: () -> Void
    var body: some View {
        Button(title, action: action)
            .buttonStyle(GameArtButtonStyle(compact: true))
            .fixedSize(horizontal: true, vertical: false)
    }
}

/// Fixed-height card-table controls keep their existing layout and hit actions.
struct GameArtControlSurface: ViewModifier {
    var primary = false
    var selected = false
    func body(content: Content) -> some View {
        content.offset(y: primary ? 4 : 0).background {
            if primary {
                Image("ButtonArt25MainAction")
                    .resizable()
                    .accessibilityHidden(true)
            } else {
                GameArtCutout().fill(LinearGradient(colors: [selected ? Color(red: 0.34, green: 0.26, blue: 0.13) : Color(red: 0.22, green: 0.26, blue: 0.28), GameArt.night], startPoint: .topLeading, endPoint: .bottomTrailing))
                GameArtCutout().stroke(GameArt.gold.opacity(selected ? 1 : 0.7), lineWidth: selected ? 2 : 1)
                GameArtCutout().stroke(GameArt.gold.opacity(0.22), lineWidth: 0.5).padding(4)
            }
        }.accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct GameArtPaper: View {
    var body: some View {
        GameArtCutout().fill(LinearGradient(colors: [Color(red: 0.98, green: 0.94, blue: 0.83), GameArt.paper, Color(red: 0.86, green: 0.77, blue: 0.59)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay { GameArtCutout().stroke(GameArt.gold.opacity(0.6), lineWidth: 1) }
            .overlay { GameArtCutout().stroke(GameArt.ink.opacity(0.15), lineWidth: 0.5).padding(5) }
            .allowsHitTesting(false)
    }
}

/// The paper fills the viewport even when there are only a few counter actions.
/// Its bottom safe-area backing remains paper when the content scrolls or bounces.
struct GameArtPaperScroll<Content: View>: View {
    var newsprint = false
    @ViewBuilder let content: () -> Content
    private let bottomID = "game-art-paper-bottom"
    private var backing: Color {
        newsprint ? Color(red: 0.93, green: 0.86, blue: 0.70) : GameArt.paper
    }
    var body: some View {
        GeometryReader { viewport in
            ScrollViewReader { reader in
                ScrollView {
                    VStack(spacing: 0) {
                        content()
                        Color.clear.frame(height: 0).id(bottomID)
                    }
                    .frame(maxWidth: .infinity, minHeight: viewport.size.height, alignment: .top)
                    .background {
                        if newsprint {
                            backing.overlay {
                                LinearGradient(colors: [.brown.opacity(0.14), .clear, .brown.opacity(0.10)], startPoint: .leading, endPoint: .trailing)
                            }
                        } else {
                            GameArtPaper()
                        }
                    }
                }
                .background(backing.ignoresSafeArea(edges: .bottom))
                #if DEBUG
                .task {
                    let args = ProcessInfo.processInfo.arguments
                    guard (args.contains("--daily-pacing-device-walk") || args.contains("--housing-device-walk")),
                          args.contains("--daily-ui-review-bottom") else { return }
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    reader.scrollTo(bottomID, anchor: .bottom)
                }
                #endif
            }
        }
    }
}

struct GameArtGroupStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            configuration.label.font(.headline).fontDesign(.serif)
            Rectangle().fill(GameArt.gold).frame(height: 1).accessibilityHidden(true)
            configuration.content.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(18).foregroundStyle(GameArt.ink).background { GameArtPaper() }
    }
}

struct GameArtPage<Content: View>: View {
    let title: String
    var subtitle = "雾港 · 港城纪事"
    var art: String? = nil
    var closeTitle = "返回"
    var onClose: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subtitle).font(.caption).tracking(1).foregroundStyle(GameArt.gold)
                    Text(title).font(.title2.bold()).fontDesign(.serif).foregroundStyle(.white)
                }.frame(maxWidth: .infinity, alignment: .leading)
                GameArtReturnButton(title: closeTitle) { onClose?(); dismiss() }
            }.padding(18).background(GameArt.night)
            GameArtPaperScroll {
                VStack(spacing: 0) {
                    if let art {
                        GeometryReader { g in
                            Image(art).resizable().scaledToFill().frame(width: g.size.width, height: g.size.height).clipped()
                                .overlay(alignment: .bottom) { LinearGradient(colors: [.clear, GameArt.night.opacity(0.6)], startPoint: .top, endPoint: .bottom).frame(height: 60) }
                        }.frame(height: 180).accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 18, content: content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20).foregroundStyle(GameArt.ink)
                        .environment(\.colorScheme, .light)
                        .padding(.horizontal, 12).padding(.top, art == nil ? 14 : -12).padding(.bottom, 24)
                }
            }
        }.background(GameArt.night.ignoresSafeArea())
            .tint(GameArt.ink).preferredColorScheme(.dark)
            .buttonStyle(GameArtButtonStyle())
            .groupBoxStyle(GameArtGroupStyle())
    }
}

struct GameArtBattleResult: View {
    let won: Bool
    let detail: String
    let title: String
    let action: () -> Void
    var body: some View {
        ZStack {
            GameArt.night.opacity(0.92).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    Image(won ? "BattleVictoryCrest" : "BattleDefeatEmblem").resizable().scaledToFit().frame(height: 150).accessibilityHidden(true)
                    Text(won ? "阻碍已解除" : "行动未完成").font(.largeTitle.bold()).fontDesign(.serif).foregroundStyle(GameArt.gold)
                    Text(detail).font(.body).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.85))
                    Button(title, action: action).buttonStyle(GameArtButtonStyle(primary: true))
                }.padding(28).frame(maxWidth: 520).frame(maxWidth: .infinity)
            }.defaultScrollAnchor(.center)
        }
    }
}

#if DEBUG
import MistportCombatCore

/// Reachable only from the existing isolated daily-review host, never a player route.
struct GameArtReviewPage: View {
    @Bindable var game: GameStore
    let page: String
    private var targets: [MPCStreetTaskTarget] {
        MPCChurchBountyCatalog.all.prefix(2).compactMap { bounty in
            guard let node = bounty.nodes.first else { return nil }
            return MPCStreetTaskTarget(id: bounty.id + ":" + node.id, taskID: bounty.id,
                kind: .bounty, placeID: "church", title: bounty.title + " · " + node.location)
        }
    }
    var body: some View {
        Group {
            switch page {
            case "newspaper": DailyNewspaperView(game: game, onSelect: { _ in })
            case "supplement": RemnantCasesView(game: game)
            case "police", "cityhall", "harbor", "board", "post", "clinic", "oldstreet": HomeCounterView(game: game, buildingID: page)
            case "cafe": HomeCafeWelcomeView(game: game)
            case "agency": HousingAgencyView(game: game)
            case "inventory": HubFeatureView(kind: .inventory, game: game)
            case "build": HubFeatureView(kind: .build, game: game)
            case "chapter-map": ChapterStageMapView(game: game, onExit: {}, onEnterVenue: { _ in })
            case "district-map": DistrictMapView(path: nil, mission: nil, onExit: {}, onMissionBoard: {}, onBeginMission: {}, onEnterVenue: { _ in })
            case "church": ChurchSanctuaryView(game: game)
            case "battle-hud":
                if let mission = game.selectedChapterDistrict.missions.first(where: { $0.number == 4 }) {
                    ChapterOneEncounterTestView(initialSession: game.chapterOneSession(for: mission),
                        campaign: game.chapterOneCampaign, battleIsActive: false,
                        onVictory: { _ in }, onExit: {})
                }
            case "tower": ChurchTowerView(game: game)
            case "settings": GameSettingsView()
            case "skill": ChapterSkillDetailSheet(skill: MPCChapterOneCatalog.visibleSkills.first!)
            case "tavern", "poker": TavernInteriorView(game: game, onBack: {}).task { game.prepareTavernPreview() }
            case "poker-help": BountyPokerRound(game: game, caseID: "tavern", onFinish: { _ in }).returnButtonHelpReview
            case "profile": CharacterProfileView(game: game)
            case "shop": HomeCopperShopView(game: game)
            case "offers": VenueOfferArtReview()
            case "tasks": HomeTaskChoicesView(game: game, targets: targets)
            case "bounty": HomeBountyInteractionView(game: game, target: targets[0])
            case "victory", "defeat": GameArtBattleResult(won: page == "victory", detail: page == "victory" ? "现场已恢复平静。回到委托人身边，完成后续交付。" : "本次行动尚未完成。整理技能和装备后可以重试。", title: "返回港城", action: {})
            default: Text("Unknown UI review page")
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(3))
            HomeFrameSampler.saveScreenshot("ui-art-\(page).png")
        }
    }
}
#endif
