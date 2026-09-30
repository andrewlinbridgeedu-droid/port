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
         "bell_loft": "报时钟下的斜梁阁楼，灯窗在雾中认得回家的路。", "highland_house": "左侧高级住宅区的石宅，门廊后是雾池与书房。"] [id] ?? ""
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
    static func stamina(_ value: Int) -> UIImage {
        let fraction = Double(value) / Double(MPCStamina.maximum)
        let frame = fraction <= 0 ? 0 : fraction < 0.25 ? 1 : fraction < 0.6 ? 2 : fraction < 0.9 ? 3 : 4
        return self.frame("HousingStamina20260930", index: frame, columns: 3, rows: 2)
    }
}

private struct HousingPage<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.system(size: 22, weight: .bold, design: .serif))
                Spacer(); Button("返回港城") { dismiss() }.font(.subheadline.bold())
            }.padding(18).foregroundStyle(Color(red: 0.9, green: 0.8, blue: 0.55))
                .background(Color(red: 0.12, green: 0.18, blue: 0.19))
            ScrollView { VStack(alignment: .leading, spacing: 18, content: content).padding(18).frame(maxWidth: .infinity, alignment: .leading) }
                .background(Color(red: 0.94, green: 0.87, blue: 0.70))
        }.foregroundStyle(Color(red: 0.19, green: 0.15, blue: 0.10)).tint(Color(red: 0.14, green: 0.31, blue: 0.29))
            .background(Color(red: 0.12, green: 0.18, blue: 0.19)).preferredColorScheme(.light)
    }
}

struct HousingAgencyView: View {
    @Bindable var game: GameStore
    @State private var choosing = false
    @State private var showingHome = false
    var body: some View {
        HomeCounterScene(title: "赁屋行", room: .rentalAgency, actorArt: "HousingAgencyClerk20260930") {
            Text("柜员 · 伊蕾娜").font(.headline)
            Text("从港区的铺位到左侧高级住宅区，先看看，再定下来。右侧贵族区很少开放，不在普通租屋册里。")
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
    private enum Step { case districts, cards(MPCHousingCatalog.District), interior(String), lease(String), moving(String) }
    @State private var step: Step = .districts
    @State private var rooms: [HousingRoomAvailability] = []
    @State private var message = ""
    @State private var detail = ""
    @State private var mealID = MPCHousingCatalog.basicMealID
    @State private var isSigning = false
    @State private var stampFrame = 0
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HousingPage(title: "赁屋行 · 找住处") {
            switch step {
            case .districts: districts
            case .cards(let district): cards(district)
            case .interior(let id): interior(id)
            case .lease(let id): lease(id)
            case .moving(let id): moving(id)
            }
            if !message.isEmpty { Text(message).font(.footnote).foregroundStyle(.red) }
        }.task {
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
    private var districts: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("一 · 先看区").font(.title2.bold())
            HousingDistrictMap { district in step = .cards(district) }
            Text("左侧是高级住宅区；右侧贵族区极少开放。").font(.footnote)
            ForEach([MPCHousingCatalog.District.harbor, .oldArcade, .canal, .church, .highland], id: \.rawValue) { district in
                let homes = MPCHousingCatalog.lodgings.filter { $0.district == district }
                Button { step = .cards(district) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(HousingArt.districtName(district)).font(.headline)
                            Text("住处 \(homes.map(\.copperPerDay).min() ?? 0) 铜／日起 · \(districtAvailability(homes))").font(.caption)
                        }
                        Spacer(); Image(systemName: "chevron.right")
                    }.padding(14).frame(maxWidth: .infinity).background(.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain)
            }
        }
    }
    private func districtAvailability(_ homes: [MPCHousingCatalog.Lodging]) -> String {
        homes.contains { $0.rooms == nil } ? "铺位不设总量" : "房量待共享服确认"
    }
    private func cards(_ district: MPCHousingCatalog.District) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Button("‹ 返回看区") { step = .districts }
            Text("二 · \(HousingArt.districtName(district))").font(.title2.bold())
            ForEach(MPCHousingCatalog.lodgings.filter { $0.district == district }) { lodging in
                VStack(alignment: .leading, spacing: 10) {
                    if let art = HousingArt.home(lodging.id) { Image(art.exterior).resizable().aspectRatio(1.5, contentMode: .fit) }
                    Text(lodging.name).font(.system(size: 23, weight: .bold, design: .serif))
                    Text("住处 \(lodging.copperPerDay) 铜／日 · 恢复 +\(lodging.staminaBonus)／日")
                    Text(HousingArt.history(lodging.id)).font(.footnote)
                    Text("附近饮食：" + nearbyMeals(lodging).map(\.name).joined(separator: "、")).font(.footnote)
                    Text(availability(lodging)).font(.caption)
                    if game.housingRecord?.queuedLodgingIDs.contains(lodging.id) == true { Text("已登记等候").font(.caption) }
                    Button("进屋看看") { detail = ""; step = .interior(lodging.id) }.buttonStyle(.borderedProminent).foregroundStyle(.white)
                    if lodging.rooms != nil {
                        Button("登记等候") { Task { do { try await game.queueHousing(lodging.id); message = "已登记，房间消息以共享服为准。" } catch { message = game.housingError(error) } } }
                    }
                }.padding(12).background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
    private func nearbyMeals(_ lodging: MPCHousingCatalog.Lodging) -> [MPCHousingCatalog.Meal] {
        MPCHousingCatalog.meals.filter { $0.requiresLodgingID == nil || $0.requiresLodgingID == lodging.id }
    }
    private func availability(_ lodging: MPCHousingCatalog.Lodging) -> String {
        if lodging.belowRecoveryLineOnly { return "按恢复线施济登记，不签租约。" }
        return lodging.rooms == nil ? "不设房间总量" : "房间限量 · 剩余房间待共享服确认"
    }
    private func interior(_ id: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let home = HousingArt.home(id), let lodging = MPCHousingCatalog.lodging(id) {
                Button("‹ 返回房子卡片") { step = .cards(lodging.district) }
                Text("三 · \(home.name)").font(.title2.bold())
                HousingInteriorArtwork(homeID: id) { detail = $0 }
                Text(detail.isEmpty ? "点亮的细节点可以看看窗、灯和屋子的来历。" : detail).font(.footnote)
                if lodging.belowRecoveryLineOnly {
                    Text("今天余额低于恢复线时，日结会按规则安排这里。").font(.footnote)
                } else {
                    Button("选这间 · 看七天约") {
                        mealID = nearbyMeals(lodging).contains { $0.id == game.housingMealID } ? game.housingMealID : MPCHousingCatalog.basicMealID
                        step = .lease(id)
                    }.buttonStyle(.borderedProminent).foregroundStyle(.white)
                }
            }
        }
    }
    private func lease(_ id: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let lodging = MPCHousingCatalog.lodging(id) {
                Button("‹ 回屋看看") { step = .interior(id) }.disabled(isSigning)
                Text("四 · 七天租约").font(.title2.bold())
                HousingDoorplate(name: lodging.name)
                Picker("日常饮食", selection: $mealID) { ForEach(nearbyMeals(lodging)) { meal in Text("\(meal.name) · \(meal.copperPerDay) 铜／日").tag(meal.id) } }
                    .pickerStyle(.menu)
                let meal = MPCHousingCatalog.meal(mealID)
                let perDay = lodging.copperPerDay + (meal?.copperPerDay ?? 0)
                Text("每天 \(perDay) 铜 · \(MPCHousingCatalog.leaseDays) 天预计 \(perDay * MPCHousingCatalog.leaseDays) 铜").font(.headline)
                Text("签约不预付七天；每天第一次打开时付生活费，余额不足会降档。今天已付的费用与恢复速度不变，新选择从下一次日结生效。").font(.footnote)
                Text("恢复 \(MPCHousingCatalog.recoveryPerDay(lodgingID: id, mealID: mealID))／日 · 体力上限 \(MPCStamina.maximum)").font(.footnote)
                Button(isSigning ? "封蜡登记中…" : "签约并搬家") {
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
                }.buttonStyle(.borderedProminent).foregroundStyle(.white).disabled(isSigning)
                if isSigning {
                    Image(uiImage: HousingAtlas.frame("HousingSeal20260930", index: stampFrame, columns: 2, rows: 2))
                        .resizable().scaledToFit().frame(height: 120).accessibilityLabel("封蜡盖章")
                }
            }
        }
    }
    private func moving(_ id: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("五 · 搬到新住处").font(.title2.bold())
            if let home = HousingArt.home(id) { Image(home.exterior).resizable().aspectRatio(1.5, contentMode: .fit).transition(.opacity) }
            HousingDoorplate(name: game.housingPlayerName)
            Text("门牌已经挂好。\(MPCHousingCatalog.lodging(id)?.name ?? "住处")等你回来。").font(.headline)
            Button("回港城") { dismiss() }.buttonStyle(.borderedProminent).foregroundStyle(.white)
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
                    Text("贵族区 · 极少开放").font(.system(size: 9, weight: .semibold)).foregroundStyle(.white)
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
        HousingPage(title: "我的住处") {
            HousingDoorplate(name: game.housingPlayerName)
            Text(MPCHousingCatalog.lodging(game.housingHomeID)?.name ?? "住处").font(.title2.bold())
            HousingInteriorArtwork(homeID: game.housingHomeID) { detail = $0 }
            if !detail.isEmpty { Text(detail).font(.footnote) }
            Text(game.housingDailyNotice).font(.footnote)
            HousingMealChoices(game: game)
            Button("去赁屋行换住处") { finding = true }.buttonStyle(.borderedProminent).foregroundStyle(.white)
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
            Text("今天已付不重扣，换餐从下一次日结生效；租约日期不延长。").font(.footnote)
            ForEach(MPCHousingCatalog.meals.filter { $0.requiresLodgingID == nil || $0.requiresLodgingID == game.housingHomeID }) { meal in
                Button {
                    Task {
                        busy = true; defer { busy = false }
                        do { try await game.changeHousingMeal(meal.id); message = "已登记\(meal.name)。" }
                        catch { message = game.housingError(error) }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading) { Text(meal.name); Text("\(meal.copperPerDay) 铜／日 · 恢复 +\(meal.staminaBonus)").font(.caption) }
                        Spacer(); if game.housingMealID == meal.id { Image(systemName: "checkmark.seal.fill") }
                    }.padding(12).background(.white.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain).disabled(busy)
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
                    Image(uiImage: HousingAtlas.stamina(value)).resizable().scaledToFit().frame(height: 170).frame(maxWidth: .infinity)
                    Text("体力 \(value)／\(MPCStamina.maximum)").font(.title2.bold())
                    Text("恢复 \(stamina.recoveryPerDay)／日 · 预计 \(now.addingTimeInterval(stamina.secondsUntil(MPCStamina.maximum, at: now.timeIntervalSince1970)).formatted(date: .abbreviated, time: .shortened)) 回满").font(.footnote)
                    Text(game.housingDailyNotice).font(.footnote)
                    ForEach(MPCStamina.Activity.allCases, id: \.rawValue) { activity in
                        HStack { Text(activity.housingTitle); Spacer(); Text("\(MPCStamina.cost(activity)) 体力") }.font(.subheadline)
                    }
                }
            }
        }.task { await game.openHousingDay() }
    }
}

struct HousingHighlandBoardView: View {
    @Bindable var game: GameStore
    var body: some View {
        HousingPage(title: "高地告示处") {
            Image("HousingHighlandHouseExterior20260930").resizable().aspectRatio(1.5, contentMode: .fit)
            Text("左侧高级住宅区 · 住高地石宅才能接").font(.title2.bold())
            Text(game.housingHighlandEligible ? "今天石宅的生活费已付，住户资格有效。具体告示尚未开放。" : "需要实际住在高地石宅，并付过今天的石宅生活费。搬家后下一次日结生效。")
            StaminaCostView(activity: .highlandShort); StaminaCostView(activity: .highlandLong)
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
    var body: some View { Label("\(MPCStamina.cost(activity)) 体力", systemImage: "lamp.desk.fill").font(.caption).foregroundStyle(.secondary) }
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
