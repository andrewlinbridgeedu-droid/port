import SwiftUI
import UIKit
import MistportCombatCore

extension Notification.Name { static let homeQuestFocus = Notification.Name("MistportHomeQuestFocus") }

struct HomeMapLayout: Decodable {
    struct Record: Decodable {
        let id: String?
        let name: String?
        let who: String?
        let at: [Double]?
        let post: [Double]?
        let points: [[Double]]?
        let polygon: [[Double]]?
        let inside: [String]?
        let holdID: String?
        let entryID: String?
        let building: String?
    }
    let zones: [Record]
    let streets: [Record]
    let entries: [Record]
    let holdSpots: [Record]
    let buildings: [Record]
    let namedPosts: [Record]
    let alwaysInteractive: [Record]
    let streetSpots: [Record]
    let approaches: [Record]
    static let current: Self = {
        let url = Bundle.main.url(forResource: "home-map-layout", withExtension: "json", subdirectory: "WisteriaMap")!
        return try! JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }()
    func point(_ value: [Double]) -> CGPoint { CGPoint(x: value[0], y: value[1]) }
    func building(_ id: String) -> Record? { buildings.first { $0.id == id } }
    func hold(for id: String) -> Record? {
        let origin = HomeCitizenCatalog.homeAnchor(for: id)
        return holdSpots.min { a, b in
            distance(a.at!, origin) < distance(b.at!, origin)
        }
    }
    func approach(for id: String) -> [[Double]] {
        let hold = hold(for: id)!
        return approaches.first { $0.holdID == hold.id }!.points!
    }
    func targetPoint(_ target: MPCStreetTaskTarget) -> [Double] {
        if let person = target.personID { return hold(for: person)!.at! }
        if let place = target.placeID, let b = building(place) { return b.at! }
        if target.placeID == "drain" { return streetSpots.first { $0.id == "drain" }!.at! }
        // Fixed scenes are stored alongside the design anchors; loaded separately below.
        return HomeCitizenCatalog.scenePoints[target.placeID ?? ""] ?? [1.03, 0.744]
    }
    private func distance(_ a: [Double], _ b: [Double]) -> Double { hypot(a[0]-b[0], a[1]-b[1]) }
}

struct HomeCitizen: Decodable, Identifiable {
    let id: String
    let name: String
    let atlasName: String
    let dialogue: String
    var post: [Double]?
    var service: String?
}

enum HomeCitizenCatalog {
    private struct Catalog: Decodable { let citizens: [HomeCitizen] }
    private struct Sites: Decodable {
        struct Site: Decodable { let at: [Double]; let caseID: String
            enum CodingKeys: String, CodingKey { case at; case caseID = "case" }
        }
        let bountySites: [Site]
    }
    static let scenePoints: [String: [Double]] = {
        let url = Bundle.main.url(forResource: "home-map-layout", withExtension: "json", subdirectory: "WisteriaMap")!
        return Dictionary(uniqueKeysWithValues: try! JSONDecoder().decode(Sites.self, from: Data(contentsOf: url)).bountySites.map { ($0.caseID, $0.at) })
    }()
    static let people: [HomeCitizen] = {
        let url = Bundle.main.url(forResource: "harbor-pedestrians", withExtension: "json", subdirectory: "WisteriaMap")!
        var citizens = try! JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url)).citizens
        let layout = HomeMapLayout.current
        for (id, name, atlas, service) in [
            ("mohr", "莫尔", "HarborResidentScholarWalkAtlas", "mohr"),
            ("old-sailor", "码头老水手", "HarborSailorWalkAtlas", "old-sailor"),
            ("odelle", "奥黛尔", "HarborResidentVisitorWalkAtlas", ""),
            ("vera", "维拉", "HarborResidentClockmakerWalkAtlas", ""),
            ("archivist", "档案员", "HarborArchiveApprenticeWalkAtlas", ""),
            ("norn", "诺恩", "HarborResidentStreetWardenWalkAtlas", ""),
            ("harbor-officer", "港务员", "HarborArchiveApprenticeWalkAtlas", ""),
            ("ilya", "伊莱", "HarborLamplighterWalkAtlas", "")
        ] {
            citizens.append(.init(id: id, name: name, atlasName: atlas, dialogue: "今天也请多关照。", post: nil, service: service.isEmpty ? nil : service))
        }
        for index in citizens.indices {
            let post = (layout.alwaysInteractive + layout.namedPosts).first { $0.who == citizens[index].name }
            citizens[index].post = post?.post
            if citizens[index].id == "merchant" || citizens[index].id == "cafe_keeper" { citizens[index].service = citizens[index].id }
        }
        return citizens
    }()
    static func homeAnchor(for id: String) -> [Double] {
        guard let index = people.firstIndex(where: { $0.id == id }) else { return [0.5, 0.7] }
        if let post = people[index].post { return post }
        let streets = ["boulevard-main", "plaza-ring", "yard-main"]
        let route = HomeMapLayout.current.streets.first { $0.id == streets[index % 3] }!.points!
        return route[(index / 3) % route.count]
    }
}

/// At most ten on-screen people. All positions are in painting-height units.
/// The clock stops while a cover is open; no save writes occur in this layer.
struct HomeStreetScene: View {
    let painting: CGRect
    let visibleRange: ClosedRange<Double>
    let active: Bool
    let targets: [MPCStreetTaskTarget]
    let trackedID: String?
    let onTarget: (MPCStreetTaskTarget) -> Void
    let onService: (String) -> Void
    @State private var epoch = Date()
    @State private var pausedAt: Date?
    @State private var pausedDuration: TimeInterval = 0
    @State private var summonStarts: [String: Double] = [:]
    @State private var greetingID: String?
    @State private var greetingPoint: [Double]?
    @State private var greetingText = ""
    @State private var greetingStarted: Double?
    @State private var personPauses: [String: Double] = [:]

    private func elapsed(_ date: Date) -> Double { max(0, (pausedAt ?? date).timeIntervalSince(epoch) - pausedDuration) }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: !active)) { timeline in
            let time = elapsed(timeline.date)
            let poses = visiblePeople(time: time)
            ZStack {
                ForEach(poses, id: \.person.id) { pose in
                    citizen(pose, date: timeline.date, time: time)
                        .position(x: painting.minX + pose.point[0] * painting.height,
                                  y: painting.minY + pose.point[1] * painting.height - pose.size * 0.5)
                        .zIndex(pose.point[1])
                }
                if let greetingID, let greetingPoint {
                    VStack(spacing: 3) {
                        Text(HomeCitizenCatalog.people.first { $0.id == greetingID }!.name).font(.caption.bold())
                        Text(greetingText).font(.caption)
                    }
                    .foregroundStyle(.black).padding(9)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10))
                    .frame(width: 180)
                    .position(x: painting.minX + greetingPoint[0] * painting.height,
                              y: painting.minY + greetingPoint[1] * painting.height - 68)
                    .allowsHitTesting(false).zIndex(2)
                }
            }
        }
        .onChange(of: active, initial: true) { _, value in
            if value, let pause = pausedAt { pausedDuration += Date().timeIntervalSince(pause); pausedAt = nil }
            if !value && pausedAt == nil { pausedAt = Date() }
        }
        .onChange(of: targets.map(\.id), initial: true) { _, _ in
            let people = Set(targets.compactMap(\.personID))
            summonStarts = summonStarts.filter { people.contains($0.key) }
            for id in people where summonStarts[id] == nil { summonStarts[id] = elapsed(Date()) }
        }
        .task(id: greetingStarted) {
            guard greetingID != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            finishGreeting()
        }
        #if DEBUG
        .task {
            guard ProcessInfo.processInfo.arguments.contains("--home-map-review-greeting") else { return }
            try? await Task.sleep(for: .seconds(6))
            let date = Date(), time = elapsed(Date())
            guard let pose = visiblePeople(time: time).first(where: { $0.tasks.isEmpty && $0.person.service == nil && $0.moving }) else { return }
            greet(pose, date: date, time: time)
            try? await Task.sleep(for: .milliseconds(400))
            HomeFrameSampler.saveScreenshot("home-greeting.png")
        }
        #endif
    }
    private struct Pose {
        let person: HomeCitizen
        let point: [Double]
        let size: Double
        let moving: Bool
        let direction: Int
        let tasks: [MPCStreetTaskTarget]
    }
    private func visiblePeople(time: Double) -> [Pose] {
        let layout = HomeMapLayout.current
        let hour = HarborClock.hour(at: Date())
        let rain = HarborWeather(gameHours: HarborClock.gameHours(at: Date())).rain
        let ambientLimit = (hour < 6 || hour > 20 || rain > 0.4) ? 4 : 7
        var poses: [Pose] = []
        // Summoned people walk to the hold spot nearest their own post, so two
        // witnesses of one case (诺恩 and 奥黛尔 both reach H6) stood on the same
        // point and only the top one could be seen or tapped (playtest
        // 2026-10-04). Stand later arrivals a step to either side.
        var holdCounts: [String: Int] = [:]
        var holdOffsets: [String: Double] = [:]
        // A fixed post right on a hold spot (the merchant at H7) counts as the
        // first occupant, so a summoned witness is not hidden behind it.
        for spot in layout.holdSpots {
            guard let holdID = spot.id, let at = spot.at else { continue }
            let posted = HomeCitizenCatalog.people.filter { person in
                guard let post = person.post, !targets.contains(where: { $0.personID == person.id }) else { return false }
                return hypot(post[0] - at[0], post[1] - at[1]) < 0.04
            }.count
            if posted > 0 { holdCounts[holdID] = posted }
        }
        for person in HomeCitizenCatalog.people where targets.contains(where: { $0.personID == person.id }) {
            let hold = layout.hold(for: person.id)?.id ?? ""
            let slot = holdCounts[hold, default: 0]
            holdCounts[hold] = slot + 1
            holdOffsets[person.id] = slot == 0 ? 0 : Double((slot + 1) / 2) * 0.035 * (slot.isMultiple(of: 2) ? -1 : 1)
        }
        for (index, person) in HomeCitizenCatalog.people.enumerated() {
            let personTime = time - (personPauses[person.id] ?? 0)
            let tasks = targets.filter { $0.personID == person.id }
            let point: [Double]
            let moving: Bool
            let direction: Int
            if greetingID == person.id, let frozen = greetingPoint {
                point = frozen; moving = false; direction = 4
            } else if !tasks.isEmpty {
                let route = layout.approach(for: person.id)
                let progress = min(1, max(0, (time - (summonStarts[person.id] ?? 0)) / 7))
                let pose = Self.interpolate(route, fraction: progress)
                point = [pose.point[0] + (holdOffsets[person.id] ?? 0), pose.point[1]]
                direction = progress < 1 ? pose.direction : 4; moving = progress < 1
            } else if person.id == "cafe_keeper" {
                guard let outing = cafeOuting(time: personTime) else { continue }
                point = outing.point; direction = outing.direction; moving = true
            } else if person.id == "mohr" {
                guard let outing = mohrOuting(time: personTime) else { continue }
                point = outing.point; direction = outing.direction; moving = true
            } else if let post = person.post {
                point = post; direction = 4; moving = false
            } else {
                let ambient = HomeCitizenCatalog.people.filter { $0.post == nil }
                let batch = Int(time / 48) * 7
                guard let slot = (0..<ambientLimit).first(where: { ambient[(batch + $0) % ambient.count].id == person.id }) else { continue }
                let routeIndex = index % 3
                var route = layout.streets.first { $0.id == ["boulevard-main", "plaza-ring", "yard-main"][routeIndex] }!.points!
                if routeIndex == 2 { route = [[1.52, 0.925], [1.465, 0.91]] + route.dropFirst() }
                route += Array(route.dropLast().reversed())
                let duration = [34.0, 23.0, 32.0][routeIndex]
                let local = personTime.truncatingRemainder(dividingBy: 48) - Double(slot) * 1.5
                guard local >= 0 && local < duration else { continue } // leave at the entry; another citizen can arrive
                let pose = Self.interpolate(route, fraction: local / duration)
                point = pose.point; direction = pose.direction; moving = true
            }
            guard visibleRange.contains(point[0]) else { continue }
            let size = Self.bodyHeight(at: point[1]) * painting.height
            poses.append(.init(person: person, point: point, size: size, moving: moving, direction: direction, tasks: tasks))
        }
        poses.sort {
            let a = !$0.tasks.isEmpty ? 0 : $0.person.service != nil ? 1 : $0.person.post != nil ? 2 : 3
            let b = !$1.tasks.isEmpty ? 0 : $1.person.service != nil ? 1 : $1.person.post != nil ? 2 : 3
            if a != b { return a < b }
            // Rotate the ambient crowd, without changing its path.
            return $0.person.id < $1.person.id
        }
        let fixedCount = poses.filter { $0.person.post != nil || !$0.tasks.isEmpty }.count
        return Array(poses.prefix(min(10, fixedCount + ambientLimit)))
    }
    static func bodyHeight(at depth: Double) -> Double {
        let anchors: [(Double, Double)] = [(0.4, 0.016), (0.55, 0.027), (0.65, 0.041), (0.75, 0.060), (0.85, 0.083), (0.99, 0.115)]
        for (a, b) in zip(anchors, anchors.dropFirst()) where depth <= b.0 {
            let t = min(1, max(0, (depth - a.0) / (b.0 - a.0)))
            return a.1 + (b.1 - a.1) * t
        }
        return anchors.last!.1
    }
    private func cafeOuting(time: Double) -> (point: [Double], direction: Int)? {
        // One short city-wide errand per twenty minutes of active home time.
        // She spends over 90% of the cycle at her counter. Street tasks override
        // this schedule, and the cafe doorway is always available.
        var cycle = (epoch.timeIntervalSince1970 + time).truncatingRemainder(dividingBy: 1200)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--home-map-review-cafe-out") {
            cycle = UserDefaults.standard.double(forKey: "MistportCafeOutingStart") + time
        } else if ProcessInfo.processInfo.arguments.contains("--home-map-review") { cycle = 200 }
        #endif
        guard cycle < 96 else { return nil }
        let leg = Int(cycle / 32), local = cycle.truncatingRemainder(dividingBy: 32)
        guard local < 28 else { return nil } // pass through an entry between districts
        var route = HomeMapLayout.current.streets.first { $0.id == ["boulevard-main", "plaza-ring", "yard-main"][leg] }!.points!
        if leg == 2 { route = [[1.52, 0.925], [1.465, 0.91]] + route.dropFirst() }
        route += Array(route.dropLast().reversed())
        return Self.interpolate(route, fraction: local / 28)
    }
    private func mohrOuting(time: Double) -> (point: [Double], direction: Int)? {
        // The errand starts at a different point in each half-hour window.
        // It lasts 48–72 seconds; otherwise Mohr is inside the tavern.
        let absolute = epoch.timeIntervalSince1970 + time
        let block = UInt64(max(0, absolute / 1800))
        let seed = block &* 1_103_515_245 &+ 12_345
        let start = 180 + Double(seed % 1280)
        let duration = 48 + Double((seed / 1280) % 25)
        var local = absolute.truncatingRemainder(dividingBy: 1800) - start
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--home-map-review-mohr-out") {
            local = UserDefaults.standard.double(forKey: "MistportMohrOutingStart") + time
        } else if ProcessInfo.processInfo.arguments.contains("--home-map-review") { local = -1 }
        #endif
        guard local >= 0 && local < duration else { return nil }
        let legDuration = duration / 3
        let leg = min(2, Int(local / legDuration))
        let within = local.truncatingRemainder(dividingBy: legDuration)
        guard within < legDuration - 2 else { return nil }
        var route = HomeMapLayout.current.streets.first { $0.id == ["plaza-ring", "yard-main", "boulevard-main"][leg] }!.points!
        if leg == 1 { route = [[1.52, 0.925], [1.465, 0.91]] + route.dropFirst() }
        route += Array(route.dropLast().reversed())
        return Self.interpolate(route, fraction: within / (legDuration - 2))
    }
    static func interpolate(_ route: [[Double]], fraction: Double) -> (point: [Double], direction: Int) {
        let lengths = zip(route, route.dropFirst()).map { hypot($0[0]-$1[0], $0[1]-$1[1]) }
        let total = lengths.reduce(0, +)
        var distance = fraction * total
        for (index, length) in lengths.enumerated() {
            if distance <= length || index == lengths.count - 1 {
                let t = min(1, distance / max(length, 0.0001))
                let dx = route[index+1][0] - route[index][0]
                let dy = route[index+1][1] - route[index][1]
                // Screen y increases toward the viewer. Row zero is the back view.
                let direction = (Int((atan2(dx, -dy) / (.pi / 4)).rounded()) + 8) % 8
                return ([route[index][0] + dx*t, route[index][1] + dy*t], direction)
            }
            distance -= length
        }
        return (route[0], 4)
    }
    private func citizen(_ pose: Pose, date: Date, time: Double) -> some View {
        // Name plates near either screen edge slide inward instead of being
        // cut in half (playtest 2026-10-05, shots 488/495/506).
        let screenX = painting.minX + pose.point[0] * painting.height
        let viewportWidth = max(1, (visibleRange.upperBound - visibleRange.lowerBound - 0.07) * painting.height)
        let plateHalfWidth = 36.0
        let plateShift = screenX < plateHalfWidth ? plateHalfWidth - screenX
            : screenX > viewportWidth - plateHalfWidth ? (viewportWidth - plateHalfWidth) - screenX : 0
        return Button {
            if let task = pose.tasks.first { onTarget(task) }
            else if pose.person.id == "cafe_keeper" {
                greet(pose, date: date, time: time)
                greetingText = "我出来办点事，买补给请进咖啡馆。"
            }
            else if pose.person.id == "mohr" {
                greet(pose, date: date, time: time)
                greetingText = "出来透口气，一会儿就回酒馆。想打牌，到牌桌找我。"
            }
            else if let service = pose.person.service { onService(service) }
            else { greet(pose, date: date, time: time) }
        } label: {
            ZStack {
                Ellipse().fill(.black.opacity(0.28)).frame(width: pose.size * 0.4, height: 4).offset(y: pose.size * 0.5)
                HomeWalkSprite(atlas: pose.person.atlasName,
                               frame: pose.moving ? Int(time * 7) % 8 : 0,
                               direction: pose.direction, size: pose.size)
                if !pose.tasks.isEmpty || pose.person.service != nil {
                    VStack(spacing: 1) {
                        if let kind = pose.tasks.first?.kind { Image(systemName: kind == .postal ? "envelope.fill" : kind == .neighbor ? "bell.fill" : "seal.fill").foregroundStyle(kind == .bounty ? .red : .yellow) }
                        Text(pose.person.name).font(.system(size: 10, weight: .semibold)).fixedSize(horizontal: true, vertical: false).foregroundStyle(.white)
                    }.padding(3).background(.black.opacity(0.55), in: Capsule()).opacity(pose.tasks.isEmpty || pose.tasks.contains { $0.id == trackedID } ? 1 : 0.55).offset(x: plateShift, y: -pose.size * 0.7)
                }
            }.frame(width: 44, height: max(44, pose.size)).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel("\(pose.person.name)\(pose.tasks.isEmpty ? "，打招呼" : "，任务互动")")
    }
    private func greet(_ pose: Pose, date: Date, time: Double) {
        finishGreeting()
        greetingID = pose.person.id; greetingPoint = pose.point; greetingStarted = time
        let hour = HarborClock.hour(at: date)
        let season = HarborSeason.state(gameHours: HarborClock.gameHours(at: date)).current
        let seasonal: String = switch season {
        case .spring: "新叶长出来了，海风也暖了。"
        case .summer: "太阳正好，路上慢慢走。"
        case .autumn: "落叶又铺满台阶了。"
        case .winter: "天冷，记得把领口拢好。"
        }
        greetingText = (hour < 6 || hour > 20) ? "夜深了，愿港灯照着你回去。" : seasonal + pose.person.dialogue
    }
    private func finishGreeting() {
        if let id = greetingID, let start = greetingStarted {
            personPauses[id, default: 0] += max(0, elapsed(Date()) - start)
        }
        greetingID = nil; greetingPoint = nil; greetingStarted = nil
    }
}

private enum HomeWalkSpriteCache {
    private struct Metrics: Decodable { let asset: String; let cellWidth: Int; let cellHeight: Int; let bounds: [[Int]] }
    static let images: [String: [CGImage]] = {
        let url = Bundle.main.url(forResource: "home-direction-atlas-metrics", withExtension: "json", subdirectory: "WisteriaMap")!
        let metrics = try! JSONDecoder().decode([String: Metrics].self, from: Data(contentsOf: url))
        return Dictionary(uniqueKeysWithValues: metrics.map { name, metric in
            let atlas = UIImage(named: metric.asset)!.cgImage!
            let frames = (0..<64).map { index in
                let direction = index / 8
                let b = metric.bounds[direction]
                return atlas.cropping(to: CGRect(x: (index % 8) * metric.cellWidth + b[0],
                                                y: direction * metric.cellHeight + b[1],
                                                width: b[2]-b[0], height: b[3]-b[1]))!
            }
            return (name, frames)
        })
    }()
}
private struct HomeWalkSprite: View {
    let atlas: String
    let frame: Int
    let direction: Int
    let size: Double
    var body: some View {
        Image(decorative: HomeWalkSpriteCache.images[atlas]![direction * 8 + frame], scale: 1)
            .resizable().interpolation(.high).scaledToFit().frame(height: size)
    }
}

struct HomeServiceGreetingView: View {
    let title: String
    let message: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HomeCounterScene(title: title, room: title == "莫尔" ? .tavern : .counter("harbor"),
                         actorArt: title == "莫尔" ? "HomeMohr20260929" : "HomeOldSailor20260929") {
            Text(message)
            HomeCounterAction(title: "返回港城") { dismiss() }
        }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}

struct HomeCafeWelcomeView: View {
    @Bindable var game: GameStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HomeCounterScene(title: "午夜钟咖啡馆", room: .cafe, actorArt: "PortraitMollyWynn") {
            Text("店主 · 莫莉·温恩").font(.headline)
            Text("今天也请多关照。补给随主线开放，你可以先坐一会儿。")
            HousingMealChoicesLink(game: game, venue: "cafe")
            HomeCounterAction(title: "离开咖啡馆") { dismiss() }
        }
    }
}

/// A room never depends on the selected person. The foreground reuses that same
/// empty painting, masked at the counter edge; no composite bitmap is created.
struct HomeSceneRoom {
    let backgroundArt: String
    var foregroundArt: String? = nil
    var aspectRatio: CGFloat = 1.5
    var counterEdge: [CGPoint] = [.init(x: 0, y: 0.70), .init(x: 1, y: 0.70)]
    var actorX: CGFloat = 0.5
    var actorTop: CGFloat = 0.12
    var actorHeight: CGFloat = 0.90

    static let rentalAgency = Self(backgroundArt: "HousingAgencyBackground20260930", foregroundArt: "HousingAgencyForeground20260930", actorTop: 0.09, actorHeight: 0.855)

    static let cafe = Self(backgroundArt: "HomeCafeEmpty20260929", aspectRatio: 944.0 / 1664.0,
                           counterEdge: [.init(x: 0, y: 0.82), .init(x: 1, y: 0.87)],
                           actorTop: 0.18, actorHeight: 0.76)
    static let restaurant = Self(backgroundArt: "SceneCopperKeyRestaurantV2", aspectRatio: 944.0 / 1664.0,
                                 counterEdge: [.init(x: 0, y: 0.63), .init(x: 1, y: 0.72)],
                                 actorTop: 0.17, actorHeight: 0.70)
    static let newspaper = Self(backgroundArt: "HomeNewspaperOfficeEmpty20260929", actorX: 0.44)
    static let tavern = Self(backgroundArt: "HomeTavernEmpty20260929", aspectRatio: 2.0 / 3.0,
                             counterEdge: [.init(x: 0, y: 0.46), .init(x: 1, y: 0.52)],
                             actorX: 0.32, actorTop: 0.10, actorHeight: 0.62)

    static func counter(_ id: String) -> Self {
        switch id {
        case "board": Self(backgroundArt: "HomeCommissionOfficeEmpty20260929")
        case "harbor": Self(backgroundArt: "HomeHarborOfficeEmpty20260929", counterEdge: [.init(x: 0, y: 0.64), .init(x: 1, y: 0.78)])
        case "cityhall": Self(backgroundArt: "HomeCityHallEmpty20260929", counterEdge: [.init(x: 0, y: 0.66), .init(x: 1, y: 0.66)])
        case "post": Self(backgroundArt: "HomePostOfficeEmpty20260929", counterEdge: [.init(x: 0, y: 0.69), .init(x: 1, y: 0.74)])
        case "police": Self(backgroundArt: "HomePoliceOfficeEmpty20260929", counterEdge: [.init(x: 0, y: 0.63), .init(x: 1, y: 0.86)])
        case "clinic": Self(backgroundArt: "HomeClinicEmpty20260929", counterEdge: [.init(x: 0, y: 0.71), .init(x: 1, y: 0.77)])
        case "oldstreet": Self(backgroundArt: "HomeOldStreetShopsEmpty20260929", counterEdge: [.init(x: 0, y: 0.64), .init(x: 0.43, y: 0.71), .init(x: 0.57, y: 0.89), .init(x: 1, y: 0.66)], actorX: 0.24)
        case "merchant": Self(backgroundArt: "HomeCopperMerchantEmpty20260929")
        default: Self.counter("cityhall")
        }
    }
}

@MainActor
private enum HomePortraitCache {
    private struct Bounds: Decodable { let bounds: [Double] }
    private static let bounds: [String: Bounds] = {
        guard let url = Bundle.main.url(forResource: "home-counter-portrait-metrics", withExtension: "json", subdirectory: "WisteriaMap"),
              let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode([String: Bounds].self, from: data) else { return [:] }
        return value
    }()
    private static let cache: NSCache<NSString, UIImage> = {
        let value = NSCache<NSString, UIImage>(); value.countLimit = 8; value.totalCostLimit = 24 * 1024 * 1024
        return value
    }()
    static func portrait(_ name: String) -> UIImage {
        if let value = cache.object(forKey: name as NSString) { return value }
        guard let original = UIImage(named: name), let cg = original.cgImage else { return UIImage() }
        let values = bounds[name]?.bounds ?? [0, 0, Double(cg.width), Double(cg.height)]
        let rect = CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
        let image = UIImage(cgImage: cg.cropping(to: rect) ?? cg)
        cache.setObject(image, forKey: name as NSString, cost: Int(rect.width * rect.height) * 4)
        return image
    }
}

struct HomeSceneArtwork: View {
    let room: HomeSceneRoom
    let actorArt: String
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(room.backgroundArt).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                Image(uiImage: HomePortraitCache.portrait(actorArt)).resizable().scaledToFit()
                    .frame(height: geometry.size.height * room.actorHeight)
                    .position(x: geometry.size.width * room.actorX,
                              y: geometry.size.height * (room.actorTop + room.actorHeight / 2))
                if let foreground = room.foregroundArt {
                    Image(foreground).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else {
                Image(room.backgroundArt).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                    .mask {
                        Path { path in
                            for (index, point) in room.counterEdge.enumerated() {
                                let scaled = CGPoint(x: geometry.size.width * point.x, y: geometry.size.height * point.y)
                                if index == 0 { path.move(to: scaled) } else { path.addLine(to: scaled) }
                            }
                            path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                            path.addLine(to: CGPoint(x: 0, y: geometry.size.height)); path.closeSubpath()
                        }
                    }
                }
            }.clipped()
        }.aspectRatio(room.aspectRatio, contentMode: .fit).accessibilityHidden(true)
    }
}

/// Names, dialogue, newspaper copy, prices and actions remain native text.
struct HomeCounterScene<Content: View>: View {
    let title: String
    let room: HomeSceneRoom
    let actorArt: String
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.title2.bold()).frame(maxWidth: .infinity, alignment: .leading)
                GameArtReturnButton { dismiss() }
            }.foregroundStyle(Color(red: 0.96, green: 0.88, blue: 0.67))
                .padding(18).background(Color(red: 0.13, green: 0.17, blue: 0.20))
            GameArtPaperScroll {
                VStack(spacing: 0) {
                    HomeSceneArtwork(room: room, actorArt: actorArt)
                    VStack(alignment: .leading, spacing: 14, content: content)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(20)
                        .environment(\.colorScheme, .light)
                }
            }
        }.background(Color(red: 0.13, green: 0.17, blue: 0.20).ignoresSafeArea(edges: .top))
            .foregroundStyle(Color(red: 0.20, green: 0.16, blue: 0.10))
            .tint(Color(red: 0.33, green: 0.24, blue: 0.12))
            .preferredColorScheme(.dark)
    }
}

struct HomeCounterAction: View {
    let title: String
    var detail: String? = nil
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.body.bold())
                    if let detail { Text(detail).font(.caption).fixedSize(horizontal: false, vertical: true) }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.caption.bold())
            }
        }.buttonStyle(GameArtButtonStyle())
    }
}

struct HomeCounterView: View {
    @Bindable var game: GameStore
    let buildingID: String
    @State private var greeting = ""
    @State private var selectedStaffName: String?
    @State private var selectedTarget: MPCStreetTaskTarget?
    @State private var neighborVisit: NeighborVisitRef?
    @State private var streetTarget: MPCStreetTaskTarget?
    private struct NeighborVisitRef: Identifiable { let id: String }
    private var localTargets: [MPCStreetTaskTarget] {
        MPCStreetTaskCatalog.bountyTargets(game.churchServices.bounties).filter { target in
            if target.placeID == buildingID { return true }
            guard let personID = target.personID,
                  let person = HomeCitizenCatalog.people.first(where: { $0.id == personID }) else { return false }
            return HomeMapLayout.current.namedPosts.contains { $0.building == buildingID && $0.who == person.name }
        }
    }
    private var staffNames: [String] {
        let inside = HomeMapLayout.current.building(buildingID)?.inside ?? []
        let posts = HomeMapLayout.current.namedPosts.filter { $0.building == buildingID }.compactMap(\.who)
            .filter { name in !inside.contains(where: { $0.contains(name) }) }
        return inside + posts + (buildingID == "post" ? ["邮务柜台"] : buildingID == "board" ? ["委托板登记员"] : [])
    }
    private var activeStaffName: String { selectedStaffName ?? staffNames.first ?? "柜台" }
    private var room: HomeSceneRoom {
        var value = HomeSceneRoom.counter(buildingID)
        if buildingID == "oldstreet", activeStaffName == "木工" { value.actorX = 0.80 }
        return value
    }
    private func staffArt(_ name: String) -> String {
        if name.contains("档案员") { return "HomeArchivist20260929" }
        if name.contains("奥黛尔") { return "HomeOdelle20260929" }
        if name.contains("诺恩") { return "HomeNorn20260929" }
        if name.contains("维拉") { return "HomeVera20260929" }
        if name.contains("伊莱") { return "HomeEli20260929" }
        switch name {
        case "公证柜台": return "HomeNotary20260929"
        case "验印台": return "HomeStampClerk20260929"
        case "雇工会": return "HomeLaborClerk20260929"
        case "市政救援站": return "HomeReliefClerk20260929"
        case "沉船档案柜": return "HomeHarborArchivist20260929"
        case "码头": return "HomeOldSailor20260929"
        case "衣铺": return "HomeTailor20260929"
        case "木工": return "HomeCarpenter20260929"
        case "相片铺": return "HomePhotographer20260929"
        case "质押所": return "HomePawnbroker20260929"
        case "染坊账房": return "HomeDyeClerk20260929"
        case "印厂旧工": return "HomeRetiredPrinter20260929"
        default:
            switch buildingID {
            case "board": return "HomeCommissionClerk20260929"
            case "harbor": return "HomeHarborClerk20260929"
            case "post": return "HomePostman20260929"
            case "police": return "HomePoliceClerk20260929"
            case "clinic": return "HomeOdelle20260929"
            default: return "HomeCivilClerk20260929"
            }
        }
    }
    private func selectStaff(_ name: String) {
        selectedStaffName = name
        greeting = "\(name)：今天也请多关照。"
    }
    var body: some View {
        let building = HomeMapLayout.current.building(buildingID)!
        HomeCounterScene(title: building.name!, room: room, actorArt: staffArt(activeStaffName)) {
                Text(greeting.isEmpty ? "\(activeStaffName) · 请问有什么事？" : greeting).font(.callout)
                if ["harbor", "oldstreet", "cafe"].contains(buildingID) {
                    let venue = buildingID == "harbor" ? "soup" : buildingID == "oldstreet" ? "bakery" : "cafe"
                    HousingMealChoicesLink(game: game, venue: venue)
                }
                ForEach(staffNames, id: \.self) { name in
                    HomeCounterAction(title: name, detail: activeStaffName == name ? "正在接待" : nil) { selectStaff(name) }
                }
                ForEach(localTargets) { target in
                    HomeCounterAction(title: target.title, detail: "通缉问话") { selectedTarget = target }
                }
                if buildingID == "board" {
                    // The board posts the day's neighbour errands (design §2.3); they can
                    // be taken here or from the neighbour on the street.
                    let offers = game.newspaperNeighborOffers.filter { !$0.done }
                    ForEach(offers) { offer in
                        let name = MPCNeighborCatalog.neighbor(offer.neighborID)?.name ?? "街坊"
                        HomeCounterAction(title: "街坊委托 · \(name)", detail: (offer.errand?.request ?? "") + "\n→ 在这里接下，或到街上找\(name)") {
                            neighborVisit = .init(id: offer.neighborID)
                        }
                    }
                    if offers.isEmpty {
                        Text("今天的街坊委托都已完成，明天会有新的。").font(.caption)
                    }
                }
                ForEach(MPCStreetTaskCatalog.streetTargets(game.streetTasks).filter { $0.placeID == buildingID }) { target in
                    if let task = MPCStreetTaskCatalog.streetTask(game.streetTasks.offers.first { $0.id == target.taskID }?.taskID ?? "") {
                        HomeCounterAction(title: StreetTaskText.kind(target.kind) + " · " + task.title,
                                          detail: target.id.hasSuffix(":post") ? task.request + "\n→ \(task.copper) 铜，\(task.steps.count) 步" : target.title) {
                            streetTarget = target
                        }
                    }
                }
        }.sheet(item: $selectedTarget) { target in HomeBountyInteractionView(game: game, target: target) }
        .sheet(item: $neighborVisit) { visit in HomeNeighborVisit(game: game, neighborID: visit.id) }
        .sheet(item: $streetTarget) { target in HomeStreetTaskView(game: game, target: target) }
        #if DEBUG
        .task {
            guard ProcessInfo.processInfo.arguments.contains("--home-map-review"),
                  let name = UserDefaults.standard.string(forKey: "MistportCounterStaff"), staffNames.contains(name) else { return }
            try? await Task.sleep(for: .milliseconds(400))
            selectStaff(name)
        }
        #endif
    }
}

struct HomeCopperShopView: View {
    @Bindable var game: GameStore
    var body: some View {
        HomeCounterScene(title: "商人 · 铜币买卖", room: .counter("merchant"), actorArt: "HomeMerchant20260929") {
                Text("铜币 \(game.venueCoins)").font(.headline.monospacedDigit())
                if game.earlyRelicShopUnlocked {
                    HomeCounterAction(title: "止痛膏", detail: "\(game.painSalvePrice) 铜") { game.purchasePainSalve() }.disabled(game.painSalveStock > 0)
                    ForEach(EarlyRelicShop.ids.filter(game.relicPurchaseUnlocked), id: \.self) { id in
                        if !game.chapterOneCampaign.ownedRelicIDs.contains(id) {
                            HomeCounterAction(title: EarlyRelicShop.name(id), detail: "\(EarlyRelicShop.price(id) ?? 0) 铜") { game.purchaseEarlyRelic(id) }
                        }
                    }
                }
                ForEach(AdvancementIngredient.allCases) { ingredient in
                    HomeCounterAction(title: ingredient.name, detail: "\(ingredient.purchaseOffer.price) 铜") { game.purchaseAdvancementIngredient(ingredient) }
                        .disabled(!game.advancementPurchaseUnlocked(ingredient) || game.advancementIngredients.contains(ingredient))
                }
        }
    }
}

struct HomeBountyInteractionView: View {
    @Bindable var game: GameStore
    let target: MPCStreetTaskTarget
    @Environment(\.dismiss) private var dismiss
    @State private var notice = ""
    @State private var suspect = ""
    @State private var supports: Set<String> = []
    @State private var battlePresented = false
    @State private var pokerPresented = false
    private var bounty: MPCChurchBounty { MPCChurchBountyCatalog.bounty(id: target.taskID)! }
    private var nodeID: String { String(target.id.split(separator: ":").last!) }
    private var node: MPCChurchBountyNode? { bounty.nodes.first { $0.id == nodeID } }
    private var progress: MPCChurchBountyProgress { game.churchServices.bounties.cases[bounty.id] ?? .init() }
    var body: some View {
        GameArtPage(title: node?.location ?? "教会柜台", subtitle: bounty.title, art: HomeSceneRoom.counter(target.placeID ?? "police").backgroundArt, closeTitle: "返回港城") {
            // After the arrest the scene page reopened on its stale interview
            // (playtest 2026-10-04); say where to go instead.
            if let node, !progress.pendingTurnIn {
                Text(node.speaker).font(.headline)
                Text(node.dialogue)
                if progress.evidenceIDs.contains(node.id) { Text(node.evidence).foregroundStyle(.secondary) }
                else {
                    Button(node.id == "compare" || node.id == "identity" ? "检查现场并记录" : "交谈、查验并记录") {
                        perform { try game.investigateChurchBounty(bounty.id, nodeID: node.id) }
                    }
                    if let challenge = MPCChurchBountyCatalog.challenge(caseID: bounty.id, nodeID: node.id) {
                        Text(challenge.question).font(.headline)
                        ForEach(challenge.choices) { choice in
                            Button(choice.text) { perform(success: choice.explanation) { try game.answerChurchBounty(bounty.id, nodeID: node.id, choiceID: choice.id) } }
                                .disabled(progress.excludedChoiceIDs.contains(choice.id))
                        }
                    }
                }
                if (bounty.id == "b03" && node.location == "码头") || (bounty.id == "b08" && node.location == "酒馆") {
                    Button("进入现有牌局") { pokerPresented = true }
                }
                if (bounty.id == "b03" && node.location == "沉船档案柜") || (bounty.id == "b08" && node.location == "港务登记处") {
                    Button("查阅公开档案") { perform { try game.inspectChurchBountyAlternative(bounty.id) } }
                }
                if node.id == "identity" {
                    ForEach(["appearance", "conduct"], id: \.self) { id in
                        Button((progress.siteFeatureIDs.contains(id) ? "✓ " : "") + (id == "appearance" ? "核对外观特征" : "核对现场行为")) {
                            perform { try game.inspectChurchBountySite(bounty.id, featureID: id) }
                        }
                    }
                    Picker("嫌疑人", selection: $suspect) {
                        Text("请选择").tag("")
                        Text(bounty.title).tag(bounty.enemyID)
                        Text("传闻中的无辜者").tag("rumour-suspect")
                    }
                    ForEach(["witness", "wound"], id: \.self) { id in
                        if let card = bounty.nodes.first(where: { $0.id == id }), progress.evidenceIDs.contains(id) {
                            Button((supports.contains(id) ? "✓ " : "") + card.evidence) {
                                if !supports.insert(id).inserted { supports.remove(id) }
                            }
                        }
                    }
                    Button("出示通缉令") { perform { try game.presentChurchBountyWarrant(bounty.id, suspectID: suspect, supportingEvidenceIDs: supports) } }
                    if progress.warrantPresented && progress.victoriousBattleID == nil { Button("进入战斗") { battlePresented = true } }
                }
            } else if progress.pendingTurnIn {
                Text("现场已收押，向教会柜台交付卷宗。")
                if target.placeID == "church" {
                    Button("交案并领取报酬") {
                        perform(success: "已结案：铜币 +\(bounty.copper)，功勋 +\(bounty.merit)。") { try game.claimChurchBounty(bounty.id) }
                    }
                }
            } else if progress.claimed {
                // Closing a five-step case used to leave a bare 已记录 (playtest 2026-10-04).
                Text(bounty.closure)
                Text("已结案 · 报酬 \(bounty.copper) 铜币 / \(bounty.merit) 功勋").foregroundStyle(.secondary)
            }
            if !notice.isEmpty { Text(notice).foregroundStyle(.secondary) }
        }
        // Arriving is not a record; the "已记录" notice used to show before the
        // player had done anything (playtest 2026-10-04).
        .onAppear { perform(success: "") { try game.visitChurchBounty(bounty.id, location: node?.location ?? "教会") } }
        .fullScreenCover(isPresented: $battlePresented) {
            ChurchBountyBattleView(game: game, bounty: bounty, onExit: { battlePresented = false })
        }
        .fullScreenCover(isPresented: $pokerPresented) { BountyPokerRound(game: game, caseID: bounty.id, onFinish: { _ in }) }
    }
    private func perform(success: String = "已记录。", _ action: () throws -> Void) {
        do { try action(); notice = success } catch { notice = "这一步尚未成立，请核对已有材料与现场特征。" }
    }
}

/// A neighbour met on the home street. The rules only accept errand actions
/// while this neighbour is the one being talked to.
struct HomeNeighborVisit: View {
    @Bindable var game: GameStore
    let neighborID: String
    var body: some View {
        NeighborConversationView(game: game, neighborID: neighborID)
            .task { try? game.talkToNeighbor(neighborID) }
            .onDisappear { game.endNeighborConversation() }
    }
}

struct HomeTaskChoicesView: View {
    @Bindable var game: GameStore
    let targets: [MPCStreetTaskTarget]
    @State private var selected: MPCStreetTaskTarget?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        if let selected {
            if selected.kind == .neighbor, let neighborID = selected.personID { HomeNeighborVisit(game: game, neighborID: neighborID) }
            else if [.urgentErrand, .jointErrand, .commission].contains(selected.kind) { HomeStreetTaskView(game: game, target: selected) }
            else { HomeBountyInteractionView(game: game, target: selected) }
        } else {
            GameArtPage(title: "选择要办的事", subtitle: "港城委托 · 来访登记", art: "HomeCommissionOfficeEmpty20260929", closeTitle: "离开") {
                Text("把要查的事情告诉柜员。").font(.callout)
                ForEach(targets) { target in
                    Button { selected = target } label: {
                        HStack { Image(systemName: "doc.text.magnifyingglass"); Text(target.title); Spacer(); Image(systemName: "chevron.right") }
                    }
                }
            }
        }
    }
}

#if DEBUG
import UIKit

/// Display-link callbacks measure main-thread scheduling, not GPU-presented frames.
@MainActor
enum HousingManualRecorder {
    private static let session = "housing-manual-" + UUID().uuidString
    private static var events: [[String: Any]] = []
    static func capture(_ name: String, delay: Int = 80) {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--housing-device-walk"), arguments.contains("--housing-manual-record") else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delay))
            guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            let folder = documents.appendingPathComponent(session)
            do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
            catch { return }
            let file = String(format: "%02d-%@.png", events.count, name)
            HomeFrameSampler.saveScreenshot(session + "/" + file)
            guard FileManager.default.fileExists(atPath: folder.appendingPathComponent(file).path) else { return }
            events.append(["view": name, "file": file, "timestamp": Date().timeIntervalSince1970])
            let report: [String: Any] = ["method": "Native window capture following manual UI changes; no automatic navigation",
                "folder": session, "isolatedFixture": true, "events": events]
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted]) {
                try? data.write(to: documents.appendingPathComponent("housing-manual-recording.json"))
            }
        }
    }
}

@MainActor
final class HomeFrameSampler: NSObject {
    static let shared = HomeFrameSampler()
    private var link: CADisplayLink?
    private var start: TimeInterval = 0
    private var previous: TimeInterval = 0
    private var intervals: [Double] = []
    static func saveScreenshot(_ name: String) {
        guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows).first(where: \.isKeyWindow),
            let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try? image.pngData()?.write(to: folder.appendingPathComponent(name))
    }
    func begin() {
        guard ProcessInfo.processInfo.arguments.contains("--home-map-review") else { return }
        link?.invalidate(); start = 0; previous = 0; intervals = []
        let display = CADisplayLink(target: self, selector: #selector(tick(_:)))
        display.add(to: .main, forMode: .common); link = display
    }
    @objc private func tick(_ sender: CADisplayLink) {
        if start == 0 { start = sender.timestamp }
        if previous != 0 { intervals.append(sender.timestamp - previous) }
        previous = sender.timestamp
        guard sender.timestamp - start >= 12 else { return }
        sender.invalidate(); link = nil
        let sorted = intervals.sorted()
        guard !sorted.isEmpty else { return }
        let report: [String: Any] = ["method": "CADisplayLink main-thread callback proxy; not GPU frame presentation",
            "seconds": sender.timestamp - start, "callbacks": sorted.count,
            "meanCallbackHz": Double(sorted.count) / intervals.reduce(0, +),
            "p95IntervalMilliseconds": sorted[Int(Double(sorted.count - 1) * 0.95)] * 1000]
        if let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
           let data = try? JSONSerialization.data(withJSONObject: report, options: .sortedKeys) {
            try? data.write(to: folder.appendingPathComponent("home-frame-scheduling.json"))
        }
        NSLog("HOME_FRAME_SCHEDULING: callbacks=%d meanHz=%.1f p95ms=%.1f", sorted.count,
              Double(sorted.count) / intervals.reduce(0, +), sorted[Int(Double(sorted.count-1)*0.95)] * 1000)
    }
}
#endif

// MARK: Street tasks (urgent errands, joint errands, city commissions)

/// Names for street-task text; the rules keep ids only.
enum StreetTaskText {
    static func kind(_ kind: MPCStreetTaskTarget.Kind) -> String {
        switch kind {
        case .commission: "市政委托"
        case .jointErrand: "联合委托"
        default: "急件"
        }
    }
    static func kind(_ kind: MPCStreetTask.Kind) -> String {
        switch kind {
        case .urgent: "急件"
        case .joint: "联合委托"
        case .commission: "市政委托"
        }
    }
    static func target(_ id: String) -> String {
        if let person = HomeCitizenCatalog.people.first(where: { $0.id == id }) { return person.name }
        if let building = HomeMapLayout.current.building(id)?.name { return building }
        return id == "drain" ? "旧排水口" : id
    }
    static func item(_ id: String) -> String {
        MPCCraftingCatalog.all.first { $0.output == id }?.name
            ?? [MPCCraftingCatalog.salveID: "止痛膏", MPCCraftingCatalog.clothID: "滤布", MPCCraftingCatalog.strapID: "维修绑带", MPCCraftingCatalog.patchID: "修甲片"][id]
            ?? id
    }
    static func action(_ action: MPCStreetStep.Action) -> String {
        switch action {
        case .talk: "交谈"
        case .handOver: "交货"
        case .answer: "回答"
        case .battle: "开打"
        }
    }
}

/// A street task met on the home street: the poster before it is taken, then the
/// current step at its person or place. The rules (MPCStreetTaskLedger) decide
/// which step is open and what it pays; this page only shows and asks.
struct HomeStreetTaskView: View {
    @Bindable var game: GameStore
    let target: MPCStreetTaskTarget
    @Environment(\.dismiss) private var dismiss
    @State private var notice = ""
    @State private var battle: BattleTicket?
    private struct BattleTicket: Identifiable { let id: String }

    private var offer: MPCStreetTaskLedger.Offer? { game.streetTasks.offers.first { $0.id == target.taskID } }
    private var task: MPCStreetTask? { offer?.task }
    private var here: String { target.personID ?? target.placeID ?? "" }

    var body: some View {
        GameArtPage(title: task?.title ?? "街头任务", subtitle: StreetTaskText.kind(target.kind) + " · " + StreetTaskText.target(here),
                    art: HomeSceneRoom.counter(target.placeID ?? "board").backgroundArt, closeTitle: "返回港城") {
            if let offer, let task {
                if offer.done {
                    Text(task.thanks)
                    Text("已完成 · 报酬 \(task.copper) 铜").foregroundStyle(.secondary)
                } else if !offer.accepted {
                    Text(task.request)
                    Text("\(task.steps.count) 步 · 完成得 \(task.copper) 铜" + (task.kind == .commission ? "" : " · 计入城市贡献")).font(.subheadline)
                    Text("体力 \(MPCStamina.cost(.errandThreeStep))，第一步时扣除；今天没做完会作废，不扣钱。").font(.footnote).foregroundStyle(.secondary)
                    Text("第一步：" + task.steps[0].goal + "（" + StreetTaskText.target(task.steps[0].target) + "）").font(.footnote)
                    Button("接下这件事") { accept { try game.acceptStreetTask(offer.id) } }
                } else if let step = offer.step {
                    Text("第 \(offer.stepIndex + 1)/\(task.steps.count) 步 · " + step.goal).font(.headline)
                    if here == step.target { stepControls(offer, step) }
                    else { Text("这一步要去找：" + StreetTaskText.target(step.target)).foregroundStyle(.secondary) }
                }
            } else {
                Text("这件事已经过期，或不在今天的委托里。")
            }
            if !notice.isEmpty { Text(notice).foregroundStyle(.orange) }
        }
        .fullScreenCover(item: $battle) { ticket in
            if let offer {
                StreetTaskBattleView(game: game, offerID: offer.id, battleID: ticket.id, onClose: { battle = nil })
            }
        }
    }

    @ViewBuilder
    private func stepControls(_ offer: MPCStreetTaskLedger.Offer, _ step: MPCStreetStep) -> some View {
        switch step.action {
        case .talk:
            Button("交谈") { run { try await game.streetTalk(offer.id, at: step.target) } }
        case .handOver:
            ForEach(step.items.sorted { $0.key < $1.key }, id: \.key) { item, count in
                Text("需要 \(StreetTaskText.item(item)) ×\(count) · 持有 \(game.chapterOneCampaign.inventory[item, default: 0])")
            }
            let stocked = step.items.allSatisfy { game.chapterOneCampaign.inventory[$0.key, default: 0] >= $0.value }
            Button("交货") { run { try await game.streetHandOver(offer.id, at: step.target) } }.disabled(!stocked)
            if !stocked { Text("货物不足，先到百工坊制作。").font(.footnote).foregroundStyle(.secondary) }
        case .answer:
            if let question = step.question { Text(question).font(.headline) }
            ForEach(step.choices) { choice in
                Button(choice.text) {
                    runAnswer(wrong: choice.explanation) { try await game.streetAnswer(offer.id, at: step.target, choiceID: choice.id) }
                }
                .disabled(offer.excludedChoiceIDs.contains(choice.id))
            }
        case .battle:
            Text("一场街头小仗：" + step.pests.map(\.name).joined(separator: "、")).font(.footnote)
            Button("开打") {
                if let active = offer.activeTicket { battle = .init(id: active) }
                else { battle = .init(id: "street-" + UUID().uuidString.lowercased()) }
            }
        }
    }

    private func accept(_ action: () throws -> Void) {
        do { try action(); notice = "已接下。先看任务条，再去找第一步的人。" }
        catch { notice = "这一步尚未成立。" }
    }
    /// Shows the step's line, and the thanks and pay when it was the last step.
    private func runAnswer(wrong: String?, _ action: @escaping () async throws -> MPCStreetTaskLedger.Progress?) {
        Task {
            do {
                guard let progress = try await action() else { notice = wrong ?? "不对，再想想。"; return }
                // The done state above already shows the thanks line.
                notice = progress.line + (progress.reward.map { "\n报酬 +\($0.copper) 铜" + ($0.neighbors.isEmpty ? "" : " · 好感 +1") } ?? "")
            } catch { notice = game.housingError(error) }
        }
    }
    private func run(_ action: @escaping () async throws -> MPCStreetTaskLedger.Progress) {
        runAnswer(wrong: nil) { try await action() }
    }
}

/// The street fight of a task step; mirrors NeighborPestBattleView.
struct StreetTaskBattleView: View {
    @Bindable var game: GameStore
    let offerID: String
    let battleID: String
    let onClose: () -> Void
    @State private var started = false
    @State private var finished = false
    @State private var won = false
    @State private var skills: [FoolSkillID] = []
    @State private var reordered = true
    @State private var configuredSession: MPCChapterOneEncounterSession?
    @State private var previewSession: MPCChapterOneEncounterSession?
    @State private var startError = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let initial = configuredSession ?? previewSession {
                ChapterOneEncounterTestView(initialSession: initial,
                    campaign: game.churchBattleCampaign, playerSequence: game.currentSequence,
                    battleIsActive: started, automatesSkillSequence: true,
                    showsStandaloneOpeningBattleButton: false,
                    onVictory: { result in
                        guard !finished else { return }
                        do {
                            _ = try game.settleStreetBattle(offerID: offerID, ticket: battleID, session: result)
                            won = true; finished = true
                        } catch { startError = "结算未完成，请保留本场并重试。" }
                    }, onExit: {
                        if started && !finished { try? game.abandonStreetBattle(offerID: offerID, ticket: battleID, defeated: false) }
                        onClose()
                    },
                    onDefeat: {
                        guard !finished else { return }
                        try? game.abandonStreetBattle(offerID: offerID, ticket: battleID, defeated: true)
                        finished = true
                    },
                    onRetrySetup: { onClose() },
                    onSequenceChanged: { skills = $0 },
                    onSelectActiveRelic: game.selectCampaignActiveRelic,
                    onSelectPassiveRelic: game.toggleCampaignRelic,
                    onUseManualMask: { game.recordManualMaskUse(encounterID: initial.encounter.id) },
                    onConsumeSupply: game.consumeCampaignSupply)
            }
            if !started && !finished {
                ChapterOneBattleSetupOverlay(
                    availableSkills: MPCChapterOneCatalog.visibleSkills.filter {
                        game.chapterOneCampaign.unlockedSkillIDs.contains($0.id) && $0.id != .maskedWhisper
                    }, relics: [], selectedSkillIDs: $skills,
                    requiresFirstReorder: false, slotCapacity: game.chapterOneLoadoutSlotCapacity,
                    hasCompletedFirstReorder: $reordered, usesEarlyTutorialLayout: true,
                    showsStartTutorialHint: false,
                    onStart: {
                        game.saveChapterOneBattleLoadout(skills)
                        Task { do {
                            configuredSession = try await game.beginStreetBattle(offerID: offerID, ticket: battleID, skills: skills)
                            started = true
                        } catch { startError = game.housingError(error) } }
                    })
                if (configuredSession ?? previewSession) == nil {
                    VStack { HStack { GameArtReturnButton(title: "返回街头") { onClose() }; Spacer() }; Spacer() }.padding()
                }
            }
            if !startError.isEmpty { Text(startError).foregroundStyle(.orange).padding().background(.black) }
            if finished {
                GameArtBattleResult(won: won, detail: won ? "这一步办妥了，报酬已到账。" : "这一场不算，可以重新准备。", title: "返回街头", action: onClose)
            }
        }
        .preferredColorScheme(.dark).buttonStyle(.plain)
        .task { if previewSession == nil { previewSession = try? game.streetBattlePreview(offerID: offerID, ticket: battleID) } }
    }
}
