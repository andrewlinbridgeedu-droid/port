import CoreGraphics
import UIKit

struct DistrictMapArea: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let symbol: String
    let rect: CGRect
    let tint: UIColor
    let missionNumbers: ClosedRange<Int>

    var center: CGPoint { CGPoint(x: rect.midX, y: rect.midY) }
}

struct DistrictMapDefinition {
    let id: String
    let name: String
    let worldSize: CGSize
    let chunkSize: CGFloat
    let spawnPoint: CGPoint
    let areas: [DistrictMapArea]
    let obstacles: [CGRect]
    let teamDungeonPoint: CGPoint

    var worldRect: CGRect { CGRect(origin: .zero, size: worldSize) }

    func area(containing point: CGPoint) -> DistrictMapArea {
        areas.first { $0.rect.contains(point) }
            ?? areas.min { distance(point, $0.center) < distance(point, $1.center) }
            ?? areas[0]
    }

    func objectivePoint(for mission: DistrictMission?) -> CGPoint {
        guard let mission,
              let area = areas.first(where: { $0.missionNumbers.contains(mission.number) }) else {
            return areas[0].center
        }
        if area.id == "wisteria-crossing" {
            let points = [
                CGPoint(x: 12_800, y: 12_320),
                CGPoint(x: 13_280, y: 12_800),
                CGPoint(x: 12_800, y: 13_280),
                CGPoint(x: 12_320, y: 12_800)
            ]
            return points[(mission.number - 1) % points.count]
        }
        let offset = CGFloat((mission.number - area.missionNumbers.lowerBound) % 4)
        return CGPoint(
            x: area.center.x + (offset - 1.5) * 480,
            y: area.center.y + (offset.truncatingRemainder(dividingBy: 2) == 0 ? -560 : 560)
        )
    }

    func isWalkable(_ point: CGPoint, actorRadius: CGFloat = 18) -> Bool {
        guard worldRect.insetBy(dx: 64, dy: 64).contains(point),
              !obstacles.contains(where: { $0.insetBy(dx: -actorRadius, dy: -actorRadius).contains(point) }) else {
            return false
        }

        let localX = point.x.truncatingRemainder(dividingBy: chunkSize)
        let localY = point.y.truncatingRemainder(dividingBy: chunkSize)
        let center = chunkSize * 0.5
        let roadHalfWidth = 232 - actorRadius
        let onHorizontalRoad = abs(localY - center) <= roadHalfWidth
        let onVerticalRoad = abs(localX - center) <= roadHalfWidth
        let inPlaza = hypot(localX - center, localY - center) <= 370 - actorRadius
        return onHorizontalRoad || onVerticalRoad || inPlaza
    }

    static let oldClock = DistrictMapDefinition(
        id: "old-clock-overworld",
        name: "旧城区",
        worldSize: CGSize(width: 25_600, height: 25_600),
        chunkSize: 1_024,
        spawnPoint: CGPoint(x: 12_800, y: 12_600),
        areas: [
            DistrictMapArea(
                id: "wisteria-crossing",
                name: "紫藤街口",
                subtitle: "雨夜委托 · 任务 1–5",
                symbol: "signpost.right.and.left.fill",
                rect: CGRect(x: 10_240, y: 10_240, width: 5_120, height: 5_120),
                tint: .systemYellow,
                missionNumbers: 1...5
            ),
            DistrictMapArea(
                id: "foglamp-street",
                name: "雾灯街",
                subtitle: "游荡怪群 · 任务 6–10",
                symbol: "light.beacon.max.fill",
                rect: CGRect(x: 0, y: 7_168, width: 10_240, height: 11_264),
                tint: .systemPurple,
                missionNumbers: 6...10
            ),
            DistrictMapArea(
                id: "gear-works",
                name: "齿轮工坊",
                subtitle: "机械异变 · 任务 11–13",
                symbol: "gearshape.2.fill",
                rect: CGRect(x: 15_360, y: 7_168, width: 10_240, height: 11_264),
                tint: .systemOrange,
                missionNumbers: 11...13
            ),
            DistrictMapArea(
                id: "rain-drain",
                name: "雨水排渠",
                subtitle: "潮雾巢穴 · 任务 14–15",
                symbol: "water.waves",
                rect: CGRect(x: 0, y: 0, width: 15_360, height: 7_168),
                tint: .systemCyan,
                missionNumbers: 14...15
            ),
            DistrictMapArea(
                id: "mirror-manor",
                name: "镜潮宅邸",
                subtitle: "高危封锁 · 任务 16–20",
                symbol: "theatermasks.fill",
                rect: CGRect(x: 10_240, y: 18_432, width: 15_360, height: 7_168),
                tint: .systemPink,
                missionNumbers: 16...20
            )
        ],
        obstacles: [
            CGRect(x: 12_680, y: 12_680, width: 240, height: 240)
        ],
        teamDungeonPoint: CGPoint(x: 20_992, y: 22_016)
    )
}

private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
    hypot(lhs.x - rhs.x, lhs.y - rhs.y)
}

struct DistrictGridCell: Hashable {
    let column: Int
    let row: Int
}

struct DistrictNavigationGrid {
    let definition: DistrictMapDefinition
    let cellSize: CGFloat
    private let columns: Int
    private let rows: Int

    init(definition: DistrictMapDefinition, cellSize: CGFloat = 128) {
        self.definition = definition
        self.cellSize = cellSize
        columns = Int(ceil(definition.worldSize.width / cellSize))
        rows = Int(ceil(definition.worldSize.height / cellSize))
    }

    func route(from start: CGPoint, to requestedTarget: CGPoint) -> [CGPoint] {
        let startCell = nearestWalkableCell(to: start)
        let targetCell = nearestWalkableCell(to: requestedTarget)
        guard let startCell, let targetCell else { return [] }
        if startCell == targetCell { return definition.isWalkable(requestedTarget) ? [requestedTarget] : [point(for: targetCell)] }

        var frontier = DistrictPriorityQueue()
        frontier.insert(startCell, priority: 0)
        var cameFrom: [DistrictGridCell: DistrictGridCell] = [:]
        var cost: [DistrictGridCell: CGFloat] = [startCell: 0]

        while let current = frontier.popLowest() {
            if current == targetCell { break }
            for next in neighbors(of: current) {
                let diagonal = current.column != next.column && current.row != next.row
                let newCost = cost[current, default: 0] + (diagonal ? 1.414 : 1)
                if newCost < cost[next, default: .greatestFiniteMagnitude] {
                    cost[next] = newCost
                    cameFrom[next] = current
                    frontier.insert(next, priority: newCost + heuristic(next, targetCell))
                }
            }
        }

        guard cameFrom[targetCell] != nil else { return [] }
        var cells = [targetCell]
        var cursor = targetCell
        while cursor != startCell, let previous = cameFrom[cursor] {
            cursor = previous
            cells.append(cursor)
        }
        cells.reverse()
        var points = cells.dropFirst().map(point(for:))
        if definition.isWalkable(requestedTarget) { points.append(requestedTarget) }
        return points
    }

    private func nearestWalkableCell(to point: CGPoint) -> DistrictGridCell? {
        let origin = cell(containing: point)
        if isWalkable(origin) { return origin }
        for radius in 1...8 {
            for row in (origin.row - radius)...(origin.row + radius) {
                for column in (origin.column - radius)...(origin.column + radius) {
                    guard abs(column - origin.column) == radius || abs(row - origin.row) == radius else { continue }
                    let candidate = DistrictGridCell(column: column, row: row)
                    if isWalkable(candidate) { return candidate }
                }
            }
        }
        return nil
    }

    private func neighbors(of cell: DistrictGridCell) -> [DistrictGridCell] {
        var result: [DistrictGridCell] = []
        for rowOffset in -1...1 {
            for columnOffset in -1...1 where columnOffset != 0 || rowOffset != 0 {
                let next = DistrictGridCell(column: cell.column + columnOffset, row: cell.row + rowOffset)
                guard isWalkable(next) else { continue }
                if columnOffset != 0, rowOffset != 0 {
                    let horizontal = DistrictGridCell(column: cell.column + columnOffset, row: cell.row)
                    let vertical = DistrictGridCell(column: cell.column, row: cell.row + rowOffset)
                    guard isWalkable(horizontal), isWalkable(vertical) else { continue }
                }
                result.append(next)
            }
        }
        return result
    }

    private func cell(containing point: CGPoint) -> DistrictGridCell {
        DistrictGridCell(
            column: min(max(0, Int(point.x / cellSize)), columns - 1),
            row: min(max(0, Int(point.y / cellSize)), rows - 1)
        )
    }

    private func point(for cell: DistrictGridCell) -> CGPoint {
        CGPoint(x: (CGFloat(cell.column) + 0.5) * cellSize, y: (CGFloat(cell.row) + 0.5) * cellSize)
    }

    private func isWalkable(_ cell: DistrictGridCell) -> Bool {
        guard (0..<columns).contains(cell.column), (0..<rows).contains(cell.row) else { return false }
        return definition.isWalkable(point(for: cell))
    }

    private func heuristic(_ lhs: DistrictGridCell, _ rhs: DistrictGridCell) -> CGFloat {
        let dx = abs(lhs.column - rhs.column)
        let dy = abs(lhs.row - rhs.row)
        return CGFloat(max(dx, dy)) + CGFloat(min(dx, dy)) * 0.414
    }
}

private struct DistrictPriorityQueue {
    private var values: [(cell: DistrictGridCell, priority: CGFloat)] = []

    mutating func insert(_ cell: DistrictGridCell, priority: CGFloat) {
        values.append((cell, priority))
        var index = values.count - 1
        while index > 0 {
            let parent = (index - 1) / 2
            guard values[index].priority < values[parent].priority else { break }
            values.swapAt(index, parent)
            index = parent
        }
    }

    mutating func popLowest() -> DistrictGridCell? {
        guard !values.isEmpty else { return nil }
        if values.count == 1 { return values.removeLast().cell }
        let result = values[0].cell
        values[0] = values.removeLast()
        var index = 0
        while true {
            let left = index * 2 + 1
            let right = left + 1
            var smallest = index
            if left < values.count, values[left].priority < values[smallest].priority { smallest = left }
            if right < values.count, values[right].priority < values[smallest].priority { smallest = right }
            guard smallest != index else { break }
            values.swapAt(index, smallest)
            index = smallest
        }
        return result
    }
}
