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

/// A home-street citizen. Their look on the street comes from home-walkers-v2.json by id.
struct HomeCitizen: Decodable, Identifiable {
    let id: String
    let name: String
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
        for (id, name, service) in [
            ("mohr", "莫尔", "mohr"), ("old-sailor", "码头老水手", "old-sailor"),
            ("odelle", "奥黛尔", ""), ("vera", "维拉", ""), ("archivist", "档案员", ""),
            ("norn", "诺恩", ""), ("harbor-officer", "港务员", ""), ("ilya", "伊莱", "")
        ] {
            citizens.append(.init(id: id, name: name, dialogue: "今天也请多关照。", post: nil, service: service.isEmpty ? nil : service))
        }
        // The three faction leaders a plot can expose (2026-10-17); on the street only while exposed.
        for side in MPCCityFaction.allCases {
            citizens.append(.init(id: side.leaderID, name: side.leaderLabel, dialogue: "", post: nil, service: nil))
        }
        for index in citizens.indices {
            let post = (layout.alwaysInteractive + layout.namedPosts).first { $0.who == citizens[index].name }
            citizens[index].post = post?.post
            if citizens[index].id == "merchant" || citizens[index].id == "cafe_keeper" { citizens[index].service = citizens[index].id }
        }
        return citizens
    }()
    /// Where the faction leaders come to be seen: the docks, the plaza arch, the works lane.
    static let leaderAnchors: [String: [Double]] = [
        MPCCityFaction.neighbours.leaderID: [1.39, 0.875], MPCCityFaction.offices.leaderID: [0.985, 0.705],
        MPCCityFaction.compacts.leaderID: [1.515, 0.817],
    ]
    static func homeAnchor(for id: String) -> [Double] {
        if let anchor = leaderAnchors[id] { return anchor }
        guard let index = people.firstIndex(where: { $0.id == id }) else { return [0.5, 0.7] }
        if let post = people[index].post { return post }
        let streets = ["boulevard-main", "plaza-ring", "yard-main"]
        let route = HomeMapLayout.current.streets.first { $0.id == streets[index % 3] }!.points!
        return route[(index / 3) % route.count]
    }
}

/// The home street's people (user 2026-10-17): each player sees only the NPCs of their own
/// tasks, plus the shopkeepers everyone shares (the merchant and the old sailor at their
/// stalls); there is no ambient crowd. A task NPC walks in from the street entry nearest their
/// post, waits at a hold spot standing (idle frames, now and then a glance aside) and walks back
/// out once the task no longer needs them. Positions are in painting-height units.
/// The clock stops while a cover is open; no save writes occur in this layer.
struct HomeStreetScene: View {
    let painting: CGRect
    let visibleRange: ClosedRange<Double>
    let active: Bool
    let targets: [MPCStreetTaskTarget]
    let trackedID: String?
    let onTarget: (MPCStreetTaskTarget) -> Void
    let onService: (String) -> Void
    /// Shopkeepers standing at their stalls. The cafe keeper and Mohr stay inside their venues
    /// (their doors are on the map) unless a task brings them out.
    static let streetShopkeepers: Set<String> = ["merchant", "old-sailor"]
    @State private var epoch = Date()
    @State private var pausedAt: Date?
    @State private var pausedDuration: TimeInterval = 0
    /// When each task NPC set off towards their hold spot. People already needed when the
    /// street first appears are standing there, not all walking in at every launch.
    @State private var summonStarts: [String: Double] = [:]
    @State private var seeded = false
    /// Task NPCs on their way out: when they left, and from where.
    @State private var departureStarts: [String: Double] = [:]
    @State private var departurePoints: [String: [Double]] = [:]
    /// People sharing a hold spot stand apart, and later arrivals lift their plate a row, so names
    /// and bells do not print over one another ("钟楼广场水手账员", playtest 2026-10-17). Both
    /// depend only on who is needed, so they are worked out when the targets change.
    @State private var holdOffsets: [String: Double] = [:]
    @State private var plateRows: [String: Int] = [:]

    private func elapsed(_ date: Date) -> Double { max(0, (pausedAt ?? date).timeIntervalSince(epoch) - pausedDuration) }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: !active)) { timeline in
            let time = elapsed(timeline.date)
            ZStack {
                ForEach(visiblePeople(time: time), id: \.person.id) { pose in
                    citizen(pose)
                        .opacity(pose.opacity)
                        .position(x: painting.minX + pose.point[0] * painting.height,
                                  y: painting.minY + pose.point[1] * painting.height - pose.size * 0.5)
                        .zIndex(pose.point[1])
                }
            }
        }
        .onChange(of: active, initial: true) { _, value in
            if value, let pause = pausedAt { pausedDuration += Date().timeIntervalSince(pause); pausedAt = nil }
            if !value && pausedAt == nil { pausedAt = Date() }
        }
        .onChange(of: targets.map(\.id), initial: true) { _, _ in
            let people = Set(targets.compactMap(\.personID))
            let now = elapsed(Date())
            for id in Set(summonStarts.keys).subtracting(people) {
                let path = arrivalPath(id)
                let age = now - (summonStarts[id] ?? now)
                let offset = (holdOffsets[id] ?? 0) * min(1, max(0, age) / max(path.duration, 0.01))
                var from = path.pose(at: age).point
                from[0] += offset
                departurePoints[id] = from
                departureStarts[id] = now
            }
            for id in people { departureStarts[id] = nil; departurePoints[id] = nil }
            summonStarts = summonStarts.filter { people.contains($0.key) }
            for id in people where summonStarts[id] == nil { summonStarts[id] = seeded ? now : -10_000 }
            seeded = true
            (holdOffsets, plateRows) = holdLayout()
        }
    }
    private struct Pose {
        let person: HomeCitizen
        let point: [Double]
        let size: Double
        let motion: HomeWalkPath.Pose
        let tasks: [MPCStreetTaskTarget]
        var opacity = 1.0
        var plateRow = 0
    }
    /// A person's pace in metres a second, a little different for everyone.
    private static func pace(_ id: String) -> Double {
        1.15 + Double(id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xffff } % 100) / 400
    }
    /// The walk in: the approach from the street entry to the hold spot.
    private func arrivalPath(_ id: String) -> HomeWalkPath {
        HomeWalkPath(HomeMapLayout.current.approach(for: id), pace: Self.pace(id))
    }
    /// Waiting at a spot: the idle loop facing the street, now and then a glance to one side.
    private static func standing(_ seconds: Double, _ index: Int) -> HomeWalkPath.Pose {
        let cycle = (seconds + Double(index) * 3.7).truncatingRemainder(dividingBy: 16)
        let direction = cycle < 11 ? 4 : (index.isMultiple(of: 2) ? 3 : 5)
        return .init(point: [], direction: direction, frame: Int((seconds + Double(index)) * 4) % 8, walking: false)
    }
    private func holdLayout() -> ([String: Double], [String: Int]) {
        let layout = HomeMapLayout.current
        var counts: [String: Int] = [:], offsets: [String: Double] = [:], rows: [String: Int] = [:]
        // A shopkeeper standing right on a hold spot (the merchant at H7) is its first occupant,
        // so a summoned witness is not hidden behind them.
        for spot in layout.holdSpots {
            guard let holdID = spot.id, let at = spot.at else { continue }
            let standing = HomeCitizenCatalog.people.filter { person in
                guard Self.streetShopkeepers.contains(person.id), let post = person.post,
                      !targets.contains(where: { $0.personID == person.id }) else { return false }
                return hypot(post[0] - at[0], post[1] - at[1]) < 0.04
            }.count
            if standing > 0 { counts[holdID] = standing }
        }
        var taken: [String: [Double]] = [:]
        for spot in layout.holdSpots where counts[spot.id ?? ""] != nil { taken[spot.id!] = [0] }
        for person in HomeCitizenCatalog.people where targets.contains(where: { $0.personID == person.id }) {
            guard let hold = layout.hold(for: person.id), let holdID = hold.id, let at = hold.at else { continue }
            let slot = counts[holdID, default: 0]
            counts[holdID] = slot + 1
            rows[person.id] = slot
            // 0.05 painting heights (about 44 points on a phone) keeps neighbouring tap areas apart.
            // Take the nearest free place to either side that is still on the pavement: the
            // merchant's spot H7 has a foreground pillar on its right (playtest 2026-10-17).
            let candidates = [0.0] + (1...4).flatMap { [Double($0) * 0.05, -Double($0) * 0.05] }
            let free = candidates.filter { !(taken[holdID] ?? []).contains($0) }
            // The authored spot itself is always fine for the first to arrive.
            let offset = free.first == 0 ? 0 : free.first { Self.onPavement([at[0] + $0, at[1]], layout) } ?? free.first ?? 0
            taken[holdID, default: []].append(offset)
            offsets[person.id] = offset
        }
        return (offsets, rows)
    }
    /// Inside one of the layout's walkable zones (boulevard, plaza, yard).
    private static func onPavement(_ point: [Double], _ layout: HomeMapLayout) -> Bool {
        layout.zones.contains { zone in
            guard let polygon = zone.polygon, polygon.count > 2 else { return false }
            var inside = false
            for (a, b) in zip(polygon, polygon.dropFirst() + [polygon[0]])
            where (a[1] > point[1]) != (b[1] > point[1]) && point[0] < a[0] + (point[1] - a[1]) * (b[0] - a[0]) / (b[1] - a[1]) {
                inside.toggle()
            }
            return inside
        }
    }
    private func visiblePeople(time: Double) -> [Pose] {
        var poses: [Pose] = []
        for (index, person) in HomeCitizenCatalog.people.enumerated() {
            let tasks = targets.filter { $0.personID == person.id }
            var motion: HomeWalkPath.Pose
            var opacity = 1.0
            if !tasks.isEmpty {
                let path = arrivalPath(person.id)
                let age = time - (summonStarts[person.id] ?? -10_000)
                let offset = holdOffsets[person.id] ?? 0
                if age < path.duration {
                    motion = path.pose(at: age)
                    motion.point[0] += offset * max(0, age) / max(path.duration, 0.01)
                    opacity = min(1, max(0, age) / 0.6)
                } else {
                    motion = Self.standing(age - path.duration, index)
                    motion.point = [path.end[0] + offset, path.end[1]]
                }
            } else if let start = departureStarts[person.id], let from = departurePoints[person.id] {
                let path = HomeWalkPath([from] + Array(HomeMapLayout.current.approach(for: person.id).dropLast().reversed()),
                                        pace: Self.pace(person.id))
                let age = time - start
                guard age < path.duration else { continue }
                motion = path.pose(at: age)
                opacity = min(1, (path.duration - age) / 0.6)
            } else if Self.streetShopkeepers.contains(person.id), let post = person.post {
                motion = Self.standing(time, index)
                motion.point = post
            } else {
                continue
            }
            guard visibleRange.contains(motion.point[0]) else { continue }
            poses.append(.init(person: person, point: motion.point, size: Self.bodyHeight(at: motion.point[1]) * painting.height,
                               motion: motion, tasks: tasks, opacity: opacity,
                               plateRow: tasks.isEmpty ? 0 : plateRows[person.id] ?? 0))
        }
        return poses
    }
    static func bodyHeight(at depth: Double) -> Double {
        let anchors: [(Double, Double)] = [(0.4, 0.016), (0.55, 0.027), (0.65, 0.041), (0.75, 0.060), (0.85, 0.083), (0.99, 0.115)]
        for (a, b) in zip(anchors, anchors.dropFirst()) where depth <= b.0 {
            let t = min(1, max(0, (depth - a.0) / (b.0 - a.0)))
            return a.1 + (b.1 - a.1) * t
        }
        return anchors.last!.1
    }
    private func citizen(_ pose: Pose) -> some View {
        // Name plates near either screen edge slide inward instead of being
        // cut in half (playtest 2026-10-05, shots 488/495/506).
        // On-screen x, from the visible strip's left edge. This used the panorama x, so every
        // person beyond the first screen width had their plate pushed far off to one spot and
        // the people the map lit for errands showed no name or bell (2026-10-17).
        let screenX = (pose.point[0] - (visibleRange.lowerBound + 0.035)) * painting.height
        let viewportWidth = max(1, (visibleRange.upperBound - visibleRange.lowerBound - 0.07) * painting.height)
        let plateHalfWidth = 36.0
        let plateShift = screenX < plateHalfWidth ? plateHalfWidth - screenX
            : screenX > viewportWidth - plateHalfWidth ? (viewportWidth - plateHalfWidth) - screenX : 0
        return Button {
            if let task = pose.tasks.first { onTarget(task) }
            else if let service = pose.person.service { onService(service) }
        } label: {
            ZStack {
                // The body's tap area; the plate below adds its own, so a name can be tapped
                // too when people share a hold spot (it was outside the hit shape, 2026-10-17).
                Color.clear.frame(width: 44, height: max(44, pose.size)).contentShape(Rectangle())
                Ellipse().fill(.black.opacity(0.28)).frame(width: pose.size * 0.4, height: 4).offset(y: pose.size * 0.5)
                HomeWalkSprite(citizen: pose.person.id, motion: pose.motion, size: pose.size)
                VStack(spacing: 1) {
                    if let kind = pose.tasks.first?.kind { Image(systemName: kind == .postal ? "envelope.fill" : kind == .neighbor ? "bell.fill" : kind == .plot ? "scope" : "seal.fill").foregroundStyle(kind == .bounty || kind == .plot ? .red : .yellow) }
                    Text(pose.person.name).font(.system(size: 10, weight: .semibold)).fixedSize(horizontal: true, vertical: false).foregroundStyle(.white)
                }.padding(3).background(.black.opacity(0.55), in: Capsule()).opacity(pose.tasks.isEmpty || pose.tasks.contains { $0.id == trackedID } ? 1 : 0.55).offset(x: plateShift, y: -pose.size * 0.7 - Double(pose.plateRow) * 28)
            }.frame(width: 44, height: max(44, pose.size))
        }.buttonStyle(.plain).accessibilityLabel("\(pose.person.name)\(pose.tasks.isEmpty ? "，店铺" : "，任务互动")")
    }
}

/// A walk along a street polyline at a person's pace (2026-10-17): corners are rounded, and
/// speed and stride are in metres, with a body 1.7 m tall at the painting's depth scale, so a
/// far walker covers less of the painting a second and the feet keep step with the ground.
struct HomeWalkPath {
    struct Pose {
        var point: [Double]
        var direction: Int
        var frame: Int
        var walking: Bool
    }
    private let points: [[Double]]
    private let times: [Double]
    private let metres: [Double]
    var duration: Double { times.last ?? 0 }
    var end: [Double] { points.last ?? [0.5, 0.7] }

    init(_ route: [[Double]], pace: Double) {
        var p = route
        for _ in 0..<2 where p.count > 2 {   // Chaikin corner cutting; the ends stay put
            var cut = [p[0]]
            for (a, b) in zip(p, p.dropFirst()) {
                cut.append([a[0] * 0.75 + b[0] * 0.25, a[1] * 0.75 + b[1] * 0.25])
                cut.append([a[0] * 0.25 + b[0] * 0.75, a[1] * 0.25 + b[1] * 0.75])
            }
            cut.append(p[p.count - 1])
            p = cut
        }
        points = p
        var t = [0.0], m = [0.0]
        for (a, b) in zip(p, p.dropFirst()) {
            let unitsPerMetre = HomeStreetScene.bodyHeight(at: (a[1] + b[1]) / 2) / 1.7
            let dm = hypot(b[0] - a[0], b[1] - a[1]) / max(unitsPerMetre, 0.0001)
            m.append(m.last! + dm)
            t.append(t.last! + dm / pace)
        }
        times = t; metres = m
    }
    func pose(at time: Double) -> Pose {
        guard points.count > 1 else { return .init(point: end, direction: 4, frame: 0, walking: false) }
        let time = min(max(0, time), duration)
        var i = 0
        while i < times.count - 2 && times[i + 1] < time { i += 1 }
        let f = (time - times[i]) / max(times[i + 1] - times[i], 0.000001)
        let a = points[i], b = points[i + 1]
        let dx = b[0] - a[0], dy = b[1] - a[1]
        // Screen y increases toward the viewer. Row zero is the back view.
        let direction = (Int((atan2(dx, -dy) / (.pi / 4)).rounded()) + 8) % 8
        let walked = metres[i] + (metres[i + 1] - metres[i]) * f
        // One gait cycle (both steps, eight frames) every 1.5 m.
        return .init(point: [a[0] + dx * f, a[1] + dy * f], direction: direction, frame: Int(walked / 1.5 * 8) % 8, walking: true)
    }
}

/// Second-pass walkers (tools/harbor/package_home_walkers_v2.py): for each look, strips W0-W4
/// walk (directions 5-7 draw 3-1 mirrored) and I3/I4 stand. A strip is decoded the first time
/// a person on screen needs it, and may be dropped again under memory pressure.
@MainActor
enum HomeWalkerArt {
    private struct Strip: Decodable { let asset: String; let cellWidth: Int; let cellHeight: Int }
    private struct Look: Decodable { let citizens: [String]; let strips: [String: Strip] }
    private struct File: Decodable { let looks: [String: Look] }
    private static let strips: [String: [String: Strip]] = {
        let url = Bundle.main.url(forResource: "home-walkers-v2", withExtension: "json", subdirectory: "WisteriaMap")!
        let file = try! JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        var byCitizen: [String: [String: Strip]] = [:]
        for look in file.looks.values { for id in look.citizens { byCitizen[id] = look.strips } }
        return byCitizen
    }()
    private final class Frames {
        let images: [CGImage]
        init(_ images: [CGImage]) { self.images = images }
    }
    private static let cache: NSCache<NSString, Frames> = {
        let cache = NSCache<NSString, Frames>()
        cache.countLimit = 40
        return cache
    }()
    static func hasLook(_ citizen: String) -> Bool { strips[citizen] != nil }
    /// The frame to draw, and whether to mirror it.
    static func frame(_ citizen: String, direction: Int, walking: Bool, index: Int) -> (image: CGImage, mirrored: Bool)? {
        let mirrored = direction >= 5
        let base = mirrored ? 8 - direction : direction
        let key = walking ? "W\(base)" : (base == 3 || base == 4 ? "I\(base)" : "I4")
        guard let strip = strips[citizen]?[key] else { return nil }
        let frames: Frames
        if let cached = cache.object(forKey: strip.asset as NSString) {
            frames = cached
        } else {
            guard let sheet = UIImage(named: strip.asset)?.cgImage else { return nil }
            let images = (0..<8).compactMap {
                sheet.cropping(to: CGRect(x: $0 * strip.cellWidth, y: 0, width: strip.cellWidth, height: strip.cellHeight))
            }
            guard images.count == 8 else { return nil }
            frames = Frames(images)
            cache.setObject(frames, forKey: strip.asset as NSString)
        }
        return (frames.images[index % 8], mirrored)
    }
}
private struct HomeWalkSprite: View {
    let citizen: String
    let motion: HomeWalkPath.Pose
    let size: Double
    var body: some View {
        if let art = HomeWalkerArt.frame(citizen, direction: motion.direction, walking: motion.walking, index: motion.frame) {
            Image(decorative: art.image, scale: 1)
                .resizable().interpolation(.high).scaledToFit().frame(height: size)
                .scaleEffect(x: art.mirrored ? -1 : 1, y: 1)
        }
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
    var illustrationArt: String? = nil
    var returnTitle = "返回港城"
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        GeometryReader { screen in
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.title2.bold()).frame(maxWidth: .infinity, alignment: .leading)
                GameArtReturnButton(title: returnTitle) { dismiss() }
            }.foregroundStyle(Color(red: 0.96, green: 0.88, blue: 0.67))
                .padding(.horizontal, 18).padding(.vertical, 12).background(Color(red: 0.13, green: 0.17, blue: 0.20))
            GameArtPaperScroll {
                VStack(spacing: 0) {
                    banner(width: screen.size.width, screenHeight: screen.size.height)
                    VStack(alignment: .leading, spacing: 10, content: content)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.vertical, 14)
                        .environment(\.colorScheme, .light)
                }
            }
        }
        }.background(Color(red: 0.13, green: 0.17, blue: 0.20).ignoresSafeArea(edges: .top))
            .foregroundStyle(Color(red: 0.20, green: 0.16, blue: 0.10))
            .tint(Color(red: 0.33, green: 0.24, blue: 0.12))
            .preferredColorScheme(.dark)
    }
}

extension HomeCounterScene {
    /// The scene as a banner a fifth of the screen tall (2026-10-15, user: 尽量一页展示所有内容，
    /// 不需要翻页): the room is drawn full width and only the band round the person's head and
    /// shoulders shows, so the counter's business fits below without scrolling.
    @ViewBuilder fileprivate func banner(width: CGFloat, screenHeight: CGFloat) -> some View {
        let height = min(width / max(room.aspectRatio, 0.3), max(150, screenHeight * 0.21))
        if let illustrationArt {
            Image(illustrationArt).resizable().scaledToFill()
                .frame(width: width, height: height, alignment: .top).clipped().accessibilityHidden(true)
        } else {
            HomeSceneBanner(room: room, actorArt: actorArt, height: height, width: width)
        }
    }
}

/// A counter room cut down to a banner: drawn full width, showing the band from just above
/// the person's head down (their face and hands, then the counter).
struct HomeSceneBanner: View {
    let room: HomeSceneRoom
    let actorArt: String
    let height: CGFloat
    var width: CGFloat? = nil
    var body: some View {
        if let width { cut(width) } else { GeometryReader { g in cut(g.size.width) }.frame(height: height) }
    }
    private func cut(_ width: CGFloat) -> some View {
        let full = width / room.aspectRatio
        let shown = min(height, full)
        let top = min(max(0, (room.actorTop - 0.03) * full), max(0, full - shown))
        return HomeSceneArtwork(room: room, actorArt: actorArt)
            .frame(width: width, height: full)
            .offset(y: -top)
            .frame(width: width, height: shown, alignment: .top).clipped()
    }
}

/// Counter actions two to a row, so a long list of people and errands fits on one page.
struct HomeCounterActionGrid<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], alignment: .leading, spacing: 8, content: content)
    }
}

struct HomeCounterAction: View {
    let title: String
    var detail: String? = nil
    var detailLines = 3
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.bold()).lineLimit(2).minimumScaleFactor(0.85)
                    if let detail { Text(detail).font(.caption2).lineLimit(detailLines).fixedSize(horizontal: false, vertical: true) }
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
    @State private var meetingPresented = false
    @State private var postalPresented = false
    @State private var contractWorkPresented = false
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
        // A destination that is not a building on the map (an unmapped id from a list) shows
        // an empty counter instead of crashing (办事册 "赁屋行" passed "housing-agency", 2026-10-17).
        let building = HomeMapLayout.current.building(buildingID)
        HomeCounterScene(title: building?.name ?? "柜台", room: room, actorArt: staffArt(activeStaffName)) {
                Text(greeting.isEmpty ? "\(activeStaffName) · 请问有什么事？" : greeting).font(.callout)
                if ["harbor", "oldstreet", "cafe"].contains(buildingID) {
                    let venue = buildingID == "harbor" ? "soup" : buildingID == "oldstreet" ? "bakery" : "cafe"
                    HousingMealChoicesLink(game: game, venue: venue)
                }
                if buildingID == "post" { HomeCounterAction(title: "承接邮务核对", detail: "第4关后；40铜／单，10体力") { postalPresented = true } }
                if buildingID == "cityhall" || (buildingID == "oldstreet" && activeStaffName == "染坊账房") {
                    HomeCounterAction(title: "雨夜的交货单 · 公开会面", detail: "第13关后；核验证据、谈条款与履约") { meetingPresented = true }
                }
                if (buildingID == "cityhall" && game.cityEconomy.meeting?.stage == .collected) || (buildingID == "oldstreet" && game.cityEconomy.meeting?.stage == .sealed) {
                    HomeCounterAction(title: "办理当前交货合同", detail: "核对原封／取得收条") { contractWorkPresented = true }
                }
                HomeCounterActionGrid {
                    ForEach(staffNames, id: \.self) { name in
                        HomeCounterAction(title: name, detail: activeStaffName == name ? "正在接待" : nil) { selectStaff(name) }
                    }
                    ForEach(localTargets) { target in
                        HomeCounterAction(title: target.title, detail: "通缉问话") { selectedTarget = target }
                    }
                }
                if buildingID == "board" {
                    // A poster is not a conversation with its absent author.
                    let offers = game.newspaperNeighborOffers.filter { !$0.done }
                    ForEach(offers) { offer in
                        let name = MPCNeighborCatalog.neighbor(offer.neighborID)?.name ?? "街坊"
                        HomeCounterAction(title: "街坊委托 · \(name)", detail: (offer.errand?.request ?? "") + "\n→ 查看委托，再到街上找\(name)") {
                            neighborVisit = .init(id: offer.neighborID)
                        }
                    }
                    if offers.isEmpty {
                        Text("今天的街坊委托都已完成，明天会有新的。").font(.caption)
                    }
                }
                ForEach(MPCStreetTaskCatalog.streetTargets(game.streetTasks, today: game.pacingDay).filter { $0.placeID == buildingID }) { target in
                    if let task = MPCStreetTaskCatalog.streetTask(game.streetTasks.offers.first { $0.id == target.taskID }?.taskID ?? "") {
                        HomeCounterAction(title: StreetTaskText.kind(target.kind) + " · " + task.title,
                                          detail: target.id.hasSuffix(":post") ? task.request + "\n→ \(task.copper) 铜，\(task.steps.count) 步" : target.title) {
                            streetTarget = target
                        }
                    }
                }
        }.fullScreenCover(item: $selectedTarget) { target in HomeBountyInteractionView(game: game, target: target) }
            .fullScreenCover(isPresented: $meetingPresented) { CityPrivateMeetingView(game: game) }
            .fullScreenCover(isPresented: $postalPresented) { CityPostalWorkView(game: game) }
            .fullScreenCover(isPresented: $contractWorkPresented) { CityContractWorkView(game: game) }
        .fullScreenCover(item: $neighborVisit) { visit in HomeNeighborPosterView(game: game, neighborID: visit.id) }
        .fullScreenCover(item: $streetTarget) { target in HomeStreetTaskView(game: game, target: target) }
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
                if !game.featureMessage.isEmpty { Text(game.featureMessage).foregroundStyle(.orange) }
                HomeCounterActionGrid {
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

/// Board-only information. Opening it never establishes a conversation or pays an offer.
struct HomeNeighborPosterView: View {
    @Bindable var game: GameStore
    let neighborID: String
    var body: some View {
        GameArtPage(title: "街坊委托", subtitle: "委托板 · 来访登记", closeTitle: "返回委托板") {
            ForEach(game.neighbors.offers.filter { $0.neighborID == neighborID && $0.day == game.pacingDay }) { offer in
                if let errand = offer.errand {
                    Text(MPCNeighborCatalog.neighbor(neighborID)?.name ?? "街坊").font(.headline)
                    Text(errand.request)
                    if offer.done {
                        Text("已完成").foregroundStyle(.secondary)
                    } else {
                        if offer.replayWithoutReward == true { Text("这次是重试，原报酬已领取。").font(.footnote) }
                        let target = MPCStreetTaskCatalog.neighborTargets(game.neighbors, heardMessages: game.neighborHeardMessages, today: game.pacingDay).first { $0.taskID == offer.id }
                        let person = target?.personID ?? neighborID
                        let name = MPCNeighborCatalog.neighbor(person)?.name ?? "委托人"
                        Text("请到\(name)面前交谈；委托板不能代为交货或传话。").font(.footnote)
                        Button("前往 · \(name)") {
                            NotificationCenter.default.post(name: .homeQuestFocus, object: target?.id ?? person)
                        }
                    }
                }
            }
        }
        .task(id: game.pacingDay) { try? game.openNeighborDay() }
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
            else if selected.kind == .plot { HomePlotView(game: game) }
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
                    if let way = offer.chosenWay { Text(way.reply + " · 帮了\(way.side.name)").font(.footnote) }
                    Text("已完成 · 报酬 \(task.copper) 铜").foregroundStyle(.secondary)
                } else if !offer.accepted {
                    Text(task.request)
                    Text("\(task.steps.count) 步 · 完成得 \(task.copper) 铜" + (task.kind == .commission ? "" : " · 计入城市贡献")).font(.subheadline)
                    Text("体力 \(MPCStamina.cost(.errandThreeStep))，第一步时扣除。").font(.footnote).foregroundStyle(.secondary)
                    timeLeft(offer)
                    Text("第一步：" + task.steps[0].goal + "（" + StreetTaskText.target(task.steps[0].target) + "）").font(.footnote)
                    let ways = MPCStreetTaskCatalog.ways(task.id)
                    if ways.isEmpty {
                        Button("接下这件事") { accept { try game.acceptStreetTask(offer.id) } }
                    } else {
                        // Two ways (2026-10-17): the same steps and pay, a different side of the city helped.
                        Text("怎么办：报酬一样，帮到的人不同。接下时选定。").font(.footnote).foregroundStyle(.secondary)
                        ForEach(ways) { way in
                            Button { accept { try game.acceptStreetTask(offer.id, way: way.side) } } label: {
                                VStack(spacing: 2) {
                                    Text("接下 · " + way.label).font(.subheadline.bold())
                                    Text("帮\(way.side.name) · \(way.side.motto)").font(.caption2)
                                }.frame(maxWidth: .infinity)
                            }.buttonStyle(GameArtButtonStyle())
                        }
                    }
                } else if let step = offer.step {
                    Text("第 \(offer.stepIndex + 1)/\(task.steps.count) 步 · " + step.goal).font(.headline)
                    if let way = offer.chosenWay { Text("办法：\(way.label) · 帮\(way.side.name)").font(.footnote).foregroundStyle(.secondary) }
                    timeLeft(offer)
                    if here == step.target { stepControls(offer, step) }
                    else {
                        // A task often takes a few trips; one tap walks the map to the next person or place.
                        Text("这一步要去找：" + StreetTaskText.target(step.target)).foregroundStyle(.secondary)
                        Button("前往 · " + StreetTaskText.target(step.target)) {
                            NotificationCenter.default.post(name: .homeQuestFocus, object: offer.id + ":\(offer.stepIndex)")
                        }
                    }
                }
            } else {
                // Replaced by a new day's tasks while open; the page closes itself (below).
                Text("今天的委托已换新，回街上看看新的。")
            }
            if !notice.isEmpty { Text(notice).foregroundStyle(.orange) }
        }
        .onChange(of: offer == nil, initial: true) { _, gone in if gone { dismiss() } }
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

    /// The countdown to the end of the offer's last day (user 2026-10-17, instead of "作废").
    private func timeLeft(_ offer: MPCStreetTaskLedger.Offer) -> some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            Text((offer.lastDay == game.pacingDay ? "今天午夜换新 · " : "第 \(offer.lastDay) 天午夜前完成 · ") + game.errandTimeLeft(lastDay: offer.lastDay))
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
    private func accept(_ action: () throws -> Void) {
        do { try action(); notice = "已接下。" }
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
                    battleIsActive: started,
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

// MARK: The plot (city trend, days 21–27)


/// The plot (2026-10-17, CITY_TREND_TASKS_PROPOSAL_20261017.md): from day 21 the leader of the
/// side out in front is seen in public, and the city decides whether they live. Each account
/// has one try, to strike or to guard; a death needs four more strikes than guards across the
/// whole city, and what it does to the side cannot be known beforehand.
struct HomePlotView: View {
    @Bindable var game: GameStore
    @State private var battle: PlotTicket?
    private struct PlotTicket: Identifiable { let id: String; let assassin: Bool }

    var body: some View {
        let trend = game.cityTrend
        GameArtPage(title: trend.plot?.target.leaderLabel ?? "风声", subtitle: "城势 · 第 21–27 天", art: "HomePoliceOfficeEmpty20260929", closeTitle: "返回港城") {
            if let plot = trend.plot {
                let side = plot.target
                Text("\(side.leaderTitle)\(side.leaderName)这几天在\(side.leaderPlace)公开露面。\(side.name)这一章走得太前，全城都在传：有人要他的命。")
                Text("风声：刺客已得手 \(plot.struck) 次，护卫挡下 \(plot.held) 次。" + (plot.killedDay == nil
                    ? "再净得手 \(max(0, MPCCityTrendWorld.killMargin - plot.net)) 次，他就活不过这几天。" : ""))
                    .font(.callout)
                Text("他若死了，\(side.name)可能树倒猢狲散，也可能全城为他举哀、反倒更齐心——谁也说不准。")
                    .font(.footnote).foregroundStyle(.secondary)
                if let killed = plot.killedDay {
                    Text("第 \(killed) 天，\(side.leaderLabel)遇刺身亡。" + (plot.aftermath == .collapse ? "\(side.name)树倒猢狲散。" : "全城为他举哀。"))
                        .font(.headline)
                } else if let mine = game.cityTrendLedger.plotTry {
                    Text(mine.assassin ? (mine.success ? "你那一刀得手了。" : "你去刺杀，没能得手。")
                         : (mine.success ? "你替他挡下了一次刺杀。" : "你去护卫，没能挡住。")).font(.headline)
                    Text("每人只有一次机会。剩下的，看全城的人。").font(.footnote).foregroundStyle(.secondary)
                } else if MPCCityTrendWorld.plotDays.contains(game.pacingDay) {
                    if let leaning = game.cityTrendLedger.leaning(through: game.pacingDay) {
                        Text("你这周多替\(leaning.name)办事。").font(.footnote)
                    }
                    StaminaCostView(activity: .errandThreeStep)
                    Button("刺杀\(side.leaderLabel)") { battle = .init(id: "plot-strike-" + UUID().uuidString.lowercased(), assassin: true) }
                        .buttonStyle(GameArtButtonStyle(primary: true))
                    Button("护卫\(side.leaderLabel)") { battle = .init(id: "plot-guard-" + UUID().uuidString.lowercased(), assassin: false) }
                        .buttonStyle(GameArtButtonStyle())
                    Text("只有一次机会：打赢算一次得手或一次挡下，赢了得 \(GameStore.plotPay) 铜；打输或中途撤退也算用掉。")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text("露面的日子已经过去。").font(.footnote)
                }
            } else {
                Text("城里暂时没有人露面。")
            }
        }
        .fullScreenCover(item: $battle) { ticket in
            CityPlotBattleView(game: game, assassin: ticket.assassin, battleID: ticket.id, onClose: { battle = nil })
        }
        .onAppear { if battle == nil { game.closeStalePlotTicket() } }
    }
}

/// The plot fight; mirrors StreetTaskBattleView. Starting it uses the account's one try.
struct CityPlotBattleView: View {
    @Bindable var game: GameStore
    let assassin: Bool
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
                    battleIsActive: started,
                    showsStandaloneOpeningBattleButton: false,
                    onVictory: { _ in
                        guard !finished else { return }
                        do { won = try game.settleCityPlot(assassin: assassin, ticket: battleID, won: true); finished = true }
                        catch { startError = "结算未完成，请保留本场并重试。" }
                    }, onExit: {
                        if started && !finished { try? game.settleCityPlot(assassin: assassin, ticket: battleID, won: false, retreated: true) }
                        onClose()
                    },
                    onDefeat: {
                        guard !finished else { return }
                        try? game.settleCityPlot(assassin: assassin, ticket: battleID, won: false)
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
                            configuredSession = try await game.beginCityPlot(assassin: assassin, ticket: battleID, skills: skills)
                            started = true
                        } catch { startError = game.housingError(error) } }
                    })
                if (configuredSession ?? previewSession) == nil {
                    VStack { HStack { GameArtReturnButton(title: "返回") { onClose() }; Spacer() }; Spacer() }.padding()
                }
            }
            if !startError.isEmpty { Text(startError).foregroundStyle(.orange).padding().background(.black) }
            if finished {
                GameArtBattleResult(won: won,
                    detail: won ? (assassin ? "得手了。剩下的看全城。" : "挡下了这一次。") + "报酬 \(GameStore.plotPay) 铜已到账。"
                        : "没成。每人只有一次机会，这次已经用掉。",
                    title: "返回港城", action: onClose)
            }
        }
        .preferredColorScheme(.dark).buttonStyle(.plain)
        .task { if previewSession == nil { previewSession = try? game.cityPlotPreview(assassin: assassin, ticket: battleID) } }
    }
}
