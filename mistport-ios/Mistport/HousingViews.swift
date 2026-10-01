import SwiftUI
import UIKit
import MistportCombatCore

private enum HousingArt {
    struct Hotspot: Decodable, Identifiable { let id, title, description: String; let at: [Double] }
    struct Home: Decodable, Identifiable { let id, name, exterior, interior: String; let hotspots: [Hotspot] }
    struct Homes: Decodable { let homes: [Home] }
    struct District: Decodable, Identifiable { let id, name: String; let at, labelAt: [Double] }
    struct Geography: Decodable { let districts, restrictedAreas: [District] }
    static func read<T: Decodable>(_ name: String, as: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "WisteriaMap"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    static let homes = read("housing-hotspots", as: Homes.self)?.homes ?? []
    static let geography = read("housing-geography", as: Geography.self)
    static let anchors = read("housing-home-anchors", as: [String: [Double]].self) ?? [:]
    static func home(_ id: String) -> Home? { homes.first { $0.id == id } }
    static func districtName(_ district: MPCHousingCatalog.District) -> String {
        geography?.districts.first { $0.id == district.rawValue }?.name ?? district.rawValue
    }
    static func history(_ id: String) -> String {
        ["shelter": "教会老侧廊的施济铺位，雾夜共用一盏灯。", "dock_bunk": "旧仓房的石拱留下来，船工在木隔间里歇脚。",
         "arcade_room": "楼下开店，楼上住人；拱廊挡住一整条街的雾雨。", "canal_house": "临水的窄屋把雾收进檐沟，铁阳台上种着香草。",
         "bell_loft": "报时钟下的斜梁阁楼，灯窗在雾中认得回家的路。", "highland_house": "旧港高处的石宅，门廊后是雾池与书房。"] [id] ?? ""
    }
}

/// Atlas cells retain the original alpha. Cache only the small cropped frames.
@MainActor
enum HousingAtlas {
    private static var cache: [String: UIImage] = [:]
    static func frame(_ asset: String, index: Int, columns: Int, rows: Int) -> UIImage {
        let key = "\(asset)-\(index)"
        if let image = cache[key] { return image }
        guard let cg = UIImage(named: asset)?.cgImage else { return UIImage() }
        let w = cg.width / columns, h = cg.height / rows
        guard let cell = cg.cropping(to: CGRect(x: index % columns * w, y: index / columns * h, width: w, height: h)) else { return UIImage() }
        let image = UIImage(cgImage: cell); cache[key] = image; return image
    }
    static func staminaCaption(_ value: Int) -> String {
        let fraction = Double(value) / Double(MPCStamina.maximum)
        if fraction <= 0 { return "灯芯黯淡，先歇一歇" }
        if fraction < 0.25 { return "灯火微弱" }
        if fraction < 0.6 { return "灯火渐暖" }
        if fraction < 0.9 { return "灯火明亮" }
        return "灯火充盈"
    }
    static func staminaFrame(_ value: Int) -> Int {
        let fraction = Double(value) / Double(MPCStamina.maximum)
        return fraction <= 0 ? 0 : fraction < 0.25 ? 1 : fraction < 0.6 ? 2 : fraction < 0.9 ? 3 : 4
    }
    static func stamina(_ value: Int) -> UIImage {
        frame("HousingStamina20260930", index: staminaFrame(value), columns: 3, rows: 2)
    }
    /// Numbers follow the wallet chips on the home page: rounded, bold, monospaced digits.
    static func digits(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded).monospacedDigit() }
    static func staminaText(_ value: Int) -> String { "\(value)／\(MPCStamina.maximum)" }
    static func refillText(_ stamina: MPCStaminaState, at now: Date) -> String {
        let seconds = stamina.secondsUntil(MPCStamina.maximum, at: now.timeIntervalSince1970)
        guard seconds > 0 else { return "每日恢复 \(stamina.recoveryPerDay) · 灯火已满" }
        let full = now.addingTimeInterval(seconds)
        let when = Calendar.current.isDate(full, inSameDayAs: now)
            ? full.formatted(date: .omitted, time: .shortened)
            : "明日 " + full.formatted(date: .omitted, time: .shortened)
        return "每日恢复 \(stamina.recoveryPerDay) · 约 \(when) 回满"
    }
}

private struct HousingPage<Content: View>: View {
    let title: String
    var backTitle = "返回港城"
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        GameArtPage(title: title, subtitle: "赁屋行 · 港城生活", closeTitle: backTitle) {
            content()
        }
    }
}

struct HousingAgencyView: View {
    @Bindable var game: GameStore
    @State private var choosing = false
    @State private var showingHome = false
    var body: some View {
        HomeCounterScene(title: "赁屋行", room: .rentalAgency, actorArt: "HousingAgencyClerk20260930") {
            Text("柜员 · 伊蕾娜").font(.headline)
            Text("先挑一条喜欢的街，再进屋看看。港区有船工的铺位，旧港那头也有安静的石宅；贵族的门牌不在这本租屋册里。")
            Text(game.housingDailyNotice).font(.footnote)
            HomeCounterAction(title: "翻开住处册 · 看区选房") { choosing = true }
            HomeCounterAction(title: "我的住处与饮食") { showingHome = true }
        }.task { await game.openHousingDay() }
            .sheet(isPresented: $choosing) { HousingSearchView(game: game) }
            .sheet(isPresented: $showingHome) { HousingResidenceView(game: game) }
    }
}

struct HousingSearchView: View {
    @Bindable var game: GameStore
    private enum Step: Equatable { case districts, cards(MPCHousingCatalog.District), interior(String), lease(String), moving(String) }
    @State private var step: Step = .districts
    @State private var rooms: [HousingRoomAvailability] = []
    @State private var message = ""
    @State private var detail = ""
    @State private var mealID = MPCHousingCatalog.basicMealID
    @State private var isSigning = false
    @State private var stampFrame = 0
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HousingPage(title: "赁屋行 · 找住处", backTitle: "返回") {
            switch step {
            case .districts: districts
            case .cards(let district): cards(district)
            case .interior(let id): interior(id)
            case .lease(let id): lease(id)
            case .moving(let id): moving(id)
            }
            if !message.isEmpty { Text(message).font(.footnote).foregroundStyle(.red) }
        }.onChange(of: step) { _, next in
            switch next {
            case .districts: recordManualView("districts")
            case .cards: recordManualView("cards")
            case .interior: recordManualView("interior")
            case .lease: recordManualView("lease")
            case .moving: recordManualView("moving")
            }
        }.onChange(of: detail) { _, _ in recordManualView("interior-detail") }
            .onChange(of: isSigning) { _, signing in if signing { recordManualView("seal-0", delay: 30) } }
            .onChange(of: stampFrame) { _, frame in recordManualView("seal-\(frame)", delay: 30) }
        .task {
            recordManualView("districts")
            await game.openHousingDay()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--housing-device-walk") {
                let screen = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--housing-screen=") }.map { String($0.dropFirst(17)) }
                switch screen {
                case "cards": step = .cards(.oldArcade)
                case "interior": step = .interior("arcade_room")
                case "lease": mealID = "bakery"; step = .lease("arcade_room")
                case "moving": try? await game.signHousing(lodgingID: "arcade_room", mealID: "bakery"); step = .moving("arcade_room")
                default: break
                }
            }
            #endif
            do { rooms = try await game.housingRooms() } catch { message = game.housingError(error) }
        }
    }
    private func recordManualView(_ name: String, delay: Int = 80) {
        #if DEBUG
        HousingManualRecorder.capture(name, delay: delay)
        #endif
    }
    private var districts: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("雾港街区").font(.title2.bold())
            HousingDistrictMap { district in step = .cards(district) }
            Text("先看看各条街的房钱，再挑一处合意的门。").font(.footnote)
            ForEach([MPCHousingCatalog.District.harbor, .oldArcade, .canal, .church, .highland], id: \.rawValue) { district in
                let homes = MPCHousingCatalog.lodgings.filter { $0.district == district }
                Button { step = .cards(district) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(HousingArt.districtName(district)).font(.headline)
                            Text("住处 \(homes.map(\.copperPerDay).min() ?? 0) 铜／日起 · \(districtAvailability(homes))").font(.caption)
                        }
                        Spacer(); Image(systemName: "chevron.right")
                    }.frame(maxWidth: .infinity)
                }.buttonStyle(GameArtButtonStyle())
            }
        }
    }
    private func districtAvailability(_ homes: [MPCHousingCatalog.Lodging]) -> String {
        homes.contains { $0.rooms == nil } ? "可登记铺位" : "向柜员问空房"
    }
    private func cards(_ district: MPCHousingCatalog.District) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Button("‹ 返回看区") { step = .districts }
            Text("\(HousingArt.districtName(district))").font(.title2.bold())
            ForEach(MPCHousingCatalog.lodgings.filter { $0.district == district }) { lodging in
                VStack(alignment: .leading, spacing: 10) {
                    if let art = HousingArt.home(lodging.id) { Image(art.exterior).resizable().aspectRatio(1.5, contentMode: .fit) }
                    Text(lodging.name).font(.system(size: 23, weight: .bold, design: .serif))
                    Text("房钱 \(lodging.copperPerDay) 铜／日")
                    Text(HousingArt.history(lodging.id)).font(.footnote)
                    Text("附近饮食：" + nearbyMeals(lodging).map(\.name).joined(separator: "、")).font(.footnote)
                    Text(availability(lodging)).font(.caption)
                    if game.housingRecord?.queuedLodgingIDs.contains(lodging.id) == true { Text("已登记等候").font(.caption) }
                    Button("进屋看看") { detail = ""; step = .interior(lodging.id) }.buttonStyle(GameArtButtonStyle(primary: true))
                    if lodging.rooms != nil {
                        Button("登记等候") { Task { do { try await game.queueHousing(lodging.id); message = "伊蕾娜记下了你的名字，有空房时会留意。" } catch { message = game.housingError(error) } } }
                    }
                }.padding(12).background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
    private func nearbyMeals(_ lodging: MPCHousingCatalog.Lodging) -> [MPCHousingCatalog.Meal] {
        MPCHousingCatalog.meals.filter { $0.requiresLodgingID == nil || $0.requiresLodgingID == lodging.id }
    }
    private func availability(_ lodging: MPCHousingCatalog.Lodging) -> String {
        if lodging.belowRecoveryLineOnly { return "教会留给一时拮据的人，不收房钱。" }
        return lodging.rooms == nil ? "可到柜台登记铺位" : "空房不多，可请伊蕾娜留意。"
    }
    private func interior(_ id: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let home = HousingArt.home(id), let lodging = MPCHousingCatalog.lodging(id) {
                Button("‹ 回住处册") { step = .cards(lodging.district) }
                Text("\(home.name)").font(.title2.bold())
                HousingInteriorArtwork(homeID: id) { detail = $0 }
                Text(detail.isEmpty ? "窗边、炉火和门楣，都藏着这间屋子的旧事。" : detail).font(.footnote)
                if lodging.belowRecoveryLineOnly {
                    Text("若钱袋已难以维持食宿，教会会替你留一处铺位。").font(.footnote)
                } else {
                    Button("选这间 · 看租约") {
                        mealID = nearbyMeals(lodging).contains { $0.id == game.housingMealID } ? game.housingMealID : MPCHousingCatalog.basicMealID
                        step = .lease(id)
                    }.buttonStyle(GameArtButtonStyle(primary: true))
                }
            }
        }
    }
    private func lease(_ id: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let lodging = MPCHousingCatalog.lodging(id) {
                Button("‹ 回屋看看") { step = .interior(id) }.disabled(isSigning)
                Text("七日租约").font(.title2.bold())
                HousingDoorplate(name: lodging.name)
                Text("选择每日饮食").font(.headline)
                ForEach(nearbyMeals(lodging)) { meal in
                    Button { mealID = meal.id } label: {
                        HStack { Text("\(meal.name) · \(meal.copperPerDay) 铜／日"); Spacer(); if mealID == meal.id { Image(systemName: "checkmark.seal.fill") } }
                    }.buttonStyle(GameArtButtonStyle(selected: mealID == meal.id))
                        .accessibilityAddTraits(mealID == meal.id ? .isSelected : [])
                }
                let meal = MPCHousingCatalog.meal(mealID)
                let perDay = lodging.copperPerDay + (meal?.copperPerDay ?? 0)
                Text("房钱与伙食每日 \(perDay) 铜 · 七日合计 \(perDay * MPCHousingCatalog.leaseDays) 铜").font(.headline)
                Text("租期七日，房钱与伙食按日收，不必一次付清。今晨的费用已经付过，新约明晨起计；若钱袋紧了，伊蕾娜会另替你安排便宜些的食宿。").font(.footnote)
                Button(isSigning ? "伊蕾娜正盖上封蜡…" : "签约并搬家") {
                    Task {
                        isSigning = true; defer { isSigning = false }
                        do {
                            try await game.signHousing(lodgingID: id, mealID: mealID)
                            for frame in 0..<4 {
                                stampFrame = frame
                                try? await Task.sleep(for: .milliseconds([140, 100, 180, 700][frame]))
                            }
                            step = .moving(id)
                        } catch { message = game.housingError(error) }
                    }
                }.buttonStyle(GameArtButtonStyle(primary: true)).disabled(isSigning)
                if isSigning {
                    Image(uiImage: HousingAtlas.frame("HousingSeal20260930", index: stampFrame, columns: 2, rows: 2))
                        .resizable().scaledToFit().frame(height: 120).accessibilityLabel("封蜡盖章")
                }
            }
        }
    }
    private func moving(_ id: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("你的新门牌").font(.title2.bold())
            if let home = HousingArt.home(id) { Image(home.exterior).resizable().aspectRatio(1.5, contentMode: .fit).transition(.opacity) }
            HousingDoorplate(name: game.housingPlayerName)
            Text("门牌已经挂好。\(MPCHousingCatalog.lodging(id)?.name ?? "住处")等你回来。").font(.headline)
            Button("收好门牌 · 返回") { dismiss() }.buttonStyle(GameArtButtonStyle(primary: true))
        }.animation(.easeInOut(duration: 0.6), value: game.housingHomeID)
    }
}

private struct HousingDistrictMap: View {
    let onSelect: (MPCHousingCatalog.District) -> Void
    var body: some View {
        GeometryReader { g in
            let h = g.size.width / HarborPainting.aspect
            ZStack {
                Image("CityAutumnDay").resizable().aspectRatio(HarborPainting.aspect, contentMode: .fit)
                ForEach(HousingArt.geography?.districts ?? []) { district in
                    if let id = MPCHousingCatalog.District(rawValue: district.id) {
                        Button { onSelect(id) } label: {
                            Text(district.name).font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                .padding(5).background(.black.opacity(0.75), in: Capsule())
                        }.position(x: district.labelAt[0] * h, y: district.labelAt[1] * h)
                    }
                }
                ForEach(HousingArt.geography?.restrictedAreas ?? []) { area in
                    Text("贵族区 · 谢绝访客").font(.system(size: 9, weight: .semibold)).foregroundStyle(.white)
                        .padding(4).background(.black.opacity(0.65), in: Capsule())
                        .position(x: area.labelAt[0] * h, y: area.labelAt[1] * h)
                }
            }
        }.aspectRatio(HarborPainting.aspect, contentMode: .fit)
    }
}

private struct HousingInteriorArtwork: View {
    let homeID: String
    let onDetail: (String) -> Void
    var body: some View {
        if let home = HousingArt.home(homeID) {
            GeometryReader { g in
                ZStack {
                    Image(home.interior).resizable().aspectRatio(1.5, contentMode: .fit)
                    ForEach(home.hotspots) { hotspot in
                        Button { onDetail(hotspot.title + "：" + hotspot.description) } label: {
                            Image(systemName: "sparkle").foregroundStyle(.white)
                                .frame(width: 44, height: 44).background(.black.opacity(0.25), in: Circle())
                        }.accessibilityLabel(hotspot.title)
                            .position(x: hotspot.at[0] * g.size.width, y: hotspot.at[1] * g.size.height)
                    }
                }
            }.aspectRatio(1.5, contentMode: .fit)
        }
    }
}

struct HousingResidenceView: View {
    @Bindable var game: GameStore
    @State private var detail = ""
    @State private var finding = false
    var body: some View {
        HousingPage(title: "我的住处", backTitle: "返回") {
            HousingDoorplate(name: game.housingPlayerName)
            Text(MPCHousingCatalog.lodging(game.housingHomeID)?.name ?? "住处").font(.title2.bold())
            HousingInteriorArtwork(homeID: game.housingHomeID) { detail = $0 }
            if !detail.isEmpty { Text(detail).font(.footnote) }
            Text(game.housingDailyNotice).font(.footnote)
            HousingMealChoices(game: game)
            Button("去赁屋行换住处") { finding = true }.buttonStyle(GameArtButtonStyle(primary: true))
        }.task { await game.openHousingDay() }.sheet(isPresented: $finding) { HousingSearchView(game: game) }
    }
}

private struct HousingMealChoices: View {
    @Bindable var game: GameStore
    @State private var busy = false
    @State private var message = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("每日饮食").font(.headline)
            Text("今晨的饭钱已经付过。换一处吃饭，明晨起安排，房期照旧。").font(.footnote)
            ForEach(MPCHousingCatalog.meals.filter { $0.requiresLodgingID == nil || $0.requiresLodgingID == game.housingHomeID }) { meal in
                Button {
                    Task {
                        busy = true; defer { busy = false }
                        do { try await game.changeHousingMeal(meal.id); message = "已登记\(meal.name)。" }
                        catch { message = game.housingError(error) }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading) { Text(meal.name); Text("\(meal.copperPerDay) 铜／日").font(.caption) }
                        Spacer(); if game.housingMealID == meal.id { Image(systemName: "checkmark.seal.fill") }
                    }
                }.buttonStyle(GameArtButtonStyle(selected: game.housingMealID == meal.id)).disabled(busy)
            }
            if !message.isEmpty { Text(message).font(.footnote) }
        }
    }
}

struct HousingMealCounterView: View {
    @Bindable var game: GameStore
    let venue: String
    var body: some View {
        HomeCounterScene(title: venue == "cafe" ? "午夜钟咖啡馆" : venue == "bakery" ? "老城面包坊" : "港区汤棚",
            room: venue == "cafe" ? .cafe : .counter(venue == "bakery" ? "oldstreet" : "harbor"),
            actorArt: venue == "cafe" ? "PortraitMollyWynn" : venue == "bakery" ? "HomeTailor20260929" : "HomeHarborClerk20260929") {
            HousingMealChoices(game: game)
        }.task { await game.openHousingDay() }
    }
}

struct HousingStaminaView: View {
    @Bindable var game: GameStore
    var body: some View {
        HousingPage(title: "体力灯罩") {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let now = max(context.date, game.housingNow)
                let stamina = game.housingRecord?.stamina ?? .init(at: now.timeIntervalSince1970)
                let value = stamina.available(at: now.timeIntervalSince1970)
                VStack(alignment: .leading, spacing: 14) {
                    HousingLanternStage(value: value,
                        fraction: stamina.current(at: now.timeIntervalSince1970) / Double(MPCStamina.maximum))
                    HStack(alignment: .firstTextBaseline) {
                        Text(HousingAtlas.staminaCaption(value)).font(.title2.bold())
                            .contentTransition(.opacity).animation(.easeInOut(duration: 0.6), value: HousingAtlas.staminaCaption(value))
                        Spacer()
                        Text("体力 ").font(.subheadline.bold()) + Text(HousingAtlas.staminaText(value)).font(HousingAtlas.digits(22))
                    }
                    Text(HousingAtlas.refillText(stamina, at: now)).font(HousingAtlas.digits(13)).foregroundStyle(.secondary)
                    Text("照顾好起居，灯火会随着歇息慢慢恢复。").font(.body)
                }
            }
        }.task { await game.openHousingDay() }
    }
}

/// The stamina lantern is alive but shows no numbers (user copy rule, H3): its light follows
/// stamina continuously, the flame flickers (unsteadily when low), the lamp sways on its chain
/// in drifting harbor mist, motes of light gather into the glass while it recovers and two
/// moths circle it once full. A tap swings the lamp and flares the flame. Reduce Motion keeps
/// a still, lit lamp that refreshes every 30 seconds.
struct HousingLanternStage: View {
    let value: Int
    /// Stamina / maximum, with fractions, so the light grows between the five art frames.
    let fraction: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pushedAt = Date.distantPast
    @State private var pushDirection = 1.0

    private static let lampHeight: CGFloat = 170
    /// Center of the glass in the atlas cell, as a share of the lamp height (from the H3 device shot).
    private static let glassY: CGFloat = 0.60
    private static let amber = Color(red: 1.0, green: 0.72, blue: 0.36)

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 30 : 1.0 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let sincePush = context.date.timeIntervalSince(pushedAt)
            let flame = flameLevel(t: t, sincePush: sincePush)
            ZStack(alignment: .top) {
                LinearGradient(colors: [Color(red: 0.05, green: 0.08, blue: 0.10), Color(red: 0.12, green: 0.17, blue: 0.18)],
                               startPoint: .top, endPoint: .bottom)
                Ellipse().fill(RadialGradient(colors: [Self.amber.opacity(0.35 * flame), .clear], center: .center, startRadius: 0, endRadius: 120))
                    .frame(width: 260, height: 46).frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 6)
                mist(t: t, layer: 0)
                lamp(flame: flame)
                    .rotationEffect(.degrees(sway(t: t, sincePush: sincePush)), anchor: .top)
                motes(t: t, flame: flame)
                mist(t: t, layer: 1)
                Text(HousingAtlas.staminaText(value)).font(HousingAtlas.digits(26))
                    .foregroundStyle(Color(red: 0.96, green: 0.83, blue: 0.57))
                    .shadow(color: Self.amber.opacity(0.6 * min(1, flame)), radius: 8)
                    .contentTransition(.numericText()).animation(.easeOut(duration: 0.4), value: value)
                    .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 14)
            }
            .frame(height: 290).frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !reduceMotion else { return }
            pushDirection = -pushDirection; pushedAt = .now
        }
        .sensoryFeedback(.impact(weight: .light), trigger: pushedAt)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("体力灯罩，\(HousingAtlas.staminaCaption(value))，体力\(value)，上限\(MPCStamina.maximum)")
    }

    private func lamp(flame: Double) -> some View {
        let h = Self.lampHeight
        return VStack(spacing: 0) {
            Rectangle().fill(LinearGradient(colors: [Color(red: 0.35, green: 0.30, blue: 0.24), Color(red: 0.55, green: 0.45, blue: 0.30)],
                                            startPoint: .top, endPoint: .bottom))
                .frame(width: 3, height: 44)
            ZStack {
                Image(uiImage: HousingAtlas.stamina(value)).resizable().scaledToFit()
                    .id(HousingAtlas.staminaFrame(value)).transition(.opacity)
            }.frame(height: h).animation(.easeInOut(duration: 0.9), value: HousingAtlas.staminaFrame(value))
                .brightness(0.10 * (flame - 0.6))
                .background {
                    Circle().fill(RadialGradient(colors: [Self.amber.opacity(0.55 * flame), Self.amber.opacity(0.12 * flame), .clear],
                                                 center: .center, startRadius: 4, endRadius: 50 + 110 * flame))
                        .frame(width: 340, height: 340).offset(y: h * (Self.glassY - 0.5))
                }
                .overlay {
                    Ellipse().fill(RadialGradient(colors: [Color(red: 1, green: 0.93, blue: 0.75).opacity(0.5 * flame), .clear],
                                                  center: .center, startRadius: 0, endRadius: h * 0.2))
                        .frame(width: h * 0.40, height: h * 0.32).offset(y: h * (Self.glassY - 0.5))
                        .blendMode(.plusLighter).allowsHitTesting(false)
                }
        }
    }

    /// 0...~1.3: stamina sets the level; the flicker is steadier when full and sputters when low.
    private func flameLevel(t: Double, sincePush: TimeInterval) -> Double {
        let level = 0.18 + 0.82 * min(1, max(0, fraction))
        guard !reduceMotion else { return level }
        let noise = 0.5 * sin(t * 7.3) + 0.3 * sin(t * 13.1 + 1.7) + 0.2 * sin(t * 23.7 + 0.4)
        let unsteady = 1 - min(1, max(0, fraction))
        var flame = level * (1 + (0.05 + 0.13 * unsteady) * noise)
        if fraction < 0.25, sin(t * 0.9) > 0.96 { flame *= 0.55 }
        if sincePush >= 0 { flame += 0.35 * exp(-sincePush / 0.5) }
        return max(0.08, flame)
    }

    private func sway(t: Double, sincePush: TimeInterval) -> Double {
        guard !reduceMotion else { return 0 }
        var angle = 1.2 * sin(2 * .pi * t / 4.2)
        if sincePush >= 0, sincePush < 6 { angle += pushDirection * 9 * exp(-sincePush / 1.6) * sin(2 * .pi * sincePush / 1.3) }
        return angle
    }

    /// Two soft mist bands, one behind and one in front of the lamp, drifting at different speeds.
    private func mist(t: Double, layer: Int) -> some View {
        Canvas { context, size in
            context.addFilter(.blur(radius: layer == 0 ? 18 : 24))
            let speed = layer == 0 ? 9.0 : 14.0
            for i in 0..<3 {
                let span = size.width + 260
                let x = (Double(i) * span / 3 + (reduceMotion ? 0 : t * speed)).truncatingRemainder(dividingBy: span) - 130
                let y = size.height * (layer == 0 ? 0.30 + 0.18 * Double(i) : 0.72 + 0.08 * Double(i % 2))
                let rect = CGRect(x: x, y: y, width: 220, height: layer == 0 ? 56 : 44)
                context.fill(Ellipse().path(in: rect), with: .color(.white.opacity(layer == 0 ? 0.10 : 0.07)))
            }
        }.allowsHitTesting(false)
    }

    /// Recovering: six motes drift in from the mist and fade into the glass. Full: two moths circle.
    private func motes(t: Double, flame: Double) -> some View {
        Canvas { context, size in
            guard !reduceMotion else { return }
            let glass = CGPoint(x: size.width / 2, y: 44 + Self.lampHeight * Self.glassY)
            if fraction < 1 {
                for i in 0..<6 {
                    let phase = (t / 3.2 + Double(i) / 6).truncatingRemainder(dividingBy: 1)
                    let angle = Double(i) * 1.047 + 0.4
                    let distance = 150 * (1 - phase)
                    let p = CGPoint(x: glass.x + cos(angle) * distance, y: glass.y + sin(angle) * distance * 0.55)
                    let r = 1.5 + 1.5 * (1 - phase)
                    let alpha = min(phase * 3, 1) * (1 - phase) * 0.9
                    context.fill(Circle().path(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)),
                                 with: .color(Self.amber.opacity(alpha)))
                }
            } else {
                for i in 0..<2 {
                    let a = t * (i == 0 ? 1.3 : -1.0) + Double(i) * 2.1
                    let p = CGPoint(x: glass.x + cos(a) * 74, y: glass.y - 10 + sin(a * 1.7) * 30)
                    let wing = 2.2 + 1.4 * abs(sin(t * 18 + Double(i)))
                    context.fill(Ellipse().path(in: CGRect(x: p.x - wing, y: p.y - 1.6, width: 2 * wing, height: 3.2)),
                                 with: .color(Color(red: 0.95, green: 0.88, blue: 0.70).opacity(0.75 * min(1, flame))))
                }
            }
        }.allowsHitTesting(false)
    }
}

/// The small lantern on the home task strip: the same art, with a faint breathing glow.
struct HousingLanternIcon: View {
    let value: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 30 : 1.0 / 15)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let level = 0.2 + 0.8 * Double(value) / Double(MPCStamina.maximum)
            let breath = reduceMotion ? 1 : 1 + 0.12 * sin(t * 2.1) + 0.05 * sin(t * 9.3)
            ZStack {
                Image(uiImage: HousingAtlas.stamina(value)).resizable().scaledToFit()
                    .id(HousingAtlas.staminaFrame(value)).transition(.opacity)
            }.animation(.easeInOut(duration: 0.9), value: HousingAtlas.staminaFrame(value))
                .background {
                    Circle().fill(RadialGradient(colors: [Color(red: 1, green: 0.72, blue: 0.36).opacity(0.45 * level * breath), .clear],
                                                 center: .center, startRadius: 0, endRadius: 22))
                        .frame(width: 44, height: 44).offset(y: 3)
                }
        }
    }
}

struct HousingHighlandBoardView: View {
    @Bindable var game: GameStore
    var body: some View {
        HousingPage(title: "高地告示处") {
            Image("HousingHighlandHouseExterior20260930").resizable().aspectRatio(1.5, contentMode: .fit)
            Text("石宅住户的告示").font(.title2.bold())
            Text(game.housingHighlandEligible ? "守门人认得你的石宅门牌。今天还没有贴出新的告示。" : "这里的告示只留给石宅住户。到伊蕾娜那里安顿好食宿，明晨登记过门牌后再来。")
        }.task { await game.openHousingDay() }
    }
}

struct HousingDoorplate: View {
    let name: String
    var body: some View {
        Image("HousingDoorplate20260930").resizable().aspectRatio(1.5, contentMode: .fit)
            .overlay { GeometryReader { g in
                Text("雾港 · 港册登记").font(.system(size: max(8, g.size.width * 0.035), design: .serif))
                    .position(x: g.size.width * 0.5, y: g.size.height * 0.39)
                Text(name).font(.system(size: max(10, g.size.width * 0.05), weight: .bold, design: .serif))
                    .lineLimit(1).minimumScaleFactor(0.5).frame(width: g.size.width * 0.65)
                    .position(x: g.size.width * 0.5, y: g.size.height * 0.66)
            }}.foregroundStyle(Color(red: 0.96, green: 0.83, blue: 0.57))
            .shadow(color: .black.opacity(0.7), radius: 0, x: 0, y: 1)
            .accessibilityLabel("\(name)的铜门牌")
    }
}

struct HousingHomeMarker: View {
    let lodgingID, playerName: String
    let painting: CGRect
    let glow: Double
    let onOpen: () -> Void
    var body: some View {
        if let point = HousingArt.anchors[lodgingID] {
            let scale = ["shelter": 0.022, "dock_bunk": 0.025, "arcade_room": 0.055,
                         "canal_house": 0.027, "bell_loft": 0.022, "highland_house": 0.019][lodgingID] ?? 0.025
            let size = max(10, painting.height * scale)
            Button(action: onOpen) {
                ZStack {
                    Image("HousingLamp20260930").resizable().scaledToFit()
                    Image("HousingLampGlow20260930").resizable().scaledToFit().opacity(glow)
                }.frame(width: size, height: size)
                    .overlay(alignment: .bottom) {
                        Text(playerName).foregroundStyle(Color(red: 0.96, green: 0.83, blue: 0.57)).font(.system(size: 9, weight: .semibold, design: .serif)).lineLimit(1).minimumScaleFactor(0.5)
                            .padding(.horizontal, 5).padding(.vertical, 3)
                            .background { Image("HousingDoorplate20260930").resizable() }
                            .offset(y: 12)
                    }
            }.buttonStyle(.plain).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()).accessibilityLabel("回到\(playerName)的住处")
                .position(x: painting.minX + point[0] * painting.height, y: painting.minY + point[1] * painting.height)
        }
    }
}

struct StaminaCostView: View {
    let activity: MPCStamina.Activity
    var body: some View {
        HStack(spacing: 3) {
            Image(uiImage: HousingAtlas.stamina(MPCStamina.maximum)).resizable().scaledToFit().frame(width: 14, height: 16)
            Text("\(MPCStamina.cost(activity))").font(HousingAtlas.digits(12))
            Text("体力").font(.caption)
        }.foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore).accessibilityLabel("花费\(MPCStamina.cost(activity))体力")
    }
}
extension MPCStamina.Activity {
    var housingTitle: String {
        switch self {
        case .post: "送信"; case .errandTwoStep: "两步委托"; case .errandThreeStep: "三步委托"; case .remnant: "余案"
        case .eventDelivery: "事件交货"; case .eventBattle: "事件战"; case .craft: "工坊制作"; case .urgentErrand: "加急委托"
        case .jointErrand: "街区难题"; case .cityCommission: "城市委托"; case .highlandShort: "高地短单"; case .highlandLong: "高地长单"
        case .storyOrChurch: "主线、塔层、通缉"
        }
    }
}
extension GameStore {
    var housingPlayerName: String { UserDefaults.standard.string(forKey: "mistport.player.display-name") ?? "愚者" }
}

struct HousingMealChoicesLink: View {
    @Bindable var game: GameStore
    let venue: String
    @State private var opened = false
    var body: some View {
        HomeCounterAction(title: venue == "soup" ? "汤棚 · 每日饮食" : venue == "bakery" ? "面包坊 · 每日饮食" : "咖啡馆 · 每日饮食") { opened = true }
            .sheet(isPresented: $opened) { HousingMealCounterView(game: game, venue: venue) }
    }
}

#if DEBUG
struct HousingDeviceReviewRoot: View {
    @Bindable var game: GameStore
    @Bindable var storefront: Storefront
    private var screen: String { ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--housing-screen=") }.map { String($0.dropFirst(17)) } ?? "agency" }
    var body: some View {
        switch screen {
        case "districts", "cards", "interior", "lease", "moving": HousingSearchView(game: game)
        case "home": ContentView(game: game, storefront: storefront)
        case "stamina": HousingStaminaView(game: game)
        case "residence": HousingResidenceView(game: game)
        case "highland": HousingHighlandBoardView(game: game)
        default: HousingAgencyView(game: game)
        }
    }
}
#endif
