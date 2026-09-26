import Observation
import SpriteKit
import UIKit

struct DistrictMapSnapshot: Equatable {
    var areaName = "紫藤街口"
    var areaSubtitle = "安全据点"
    var playerPosition = CGPoint.zero
    var objectiveDistance = 0
    var activeChunkCount = 0
    var isNearObjective = false
    var status = "点击街道移动"
    var nearbyNPCID: String?
    var nearbyNPCName: String?
    var nearbyNPCTitle: String?
    var nearbyNPCDialogue: String?
    var isNPCDialogueVisible = false
    var nearbyVenueID: String?
    var nearbyVenueName: String?
}

@MainActor
@Observable
final class DistrictMapController {
    let scene: DistrictMapScene
    private(set) var snapshot: DistrictMapSnapshot

    init(
        definition: DistrictMapDefinition = .oldClock,
        mission: DistrictMission?,
        path: Pathway?
    ) {
        scene = DistrictMapScene(definition: definition, mission: mission, path: path)
        snapshot = DistrictMapSnapshot(playerPosition: definition.spawnPoint)
        scene.onStateChange = { [weak self] state in
            guard self?.snapshot != state else { return }
            self?.snapshot = state
        }
    }

    func locateObjective() {
        scene.moveToObjective()
    }

    func interactWithNearbyNPC() {
        scene.interactWithNearbyNPC()
    }

    func dismissNPCDialogue() {
        scene.dismissNPCDialogue()
    }

    func zoomIn() {
        scene.zoomIn()
    }

    func zoomOut() {
        scene.zoomOut()
    }

    func beginPinchZoom() {
        scene.beginPinchZoom()
    }

    func updatePinchZoom(magnification: CGFloat) {
        scene.updatePinchZoom(magnification: magnification)
    }
}

private struct DistrictChunkCoordinate: Hashable {
    let column: Int
    let row: Int
}

@MainActor
final class DistrictMapScene: SKScene {
    var onStateChange: ((DistrictMapSnapshot) -> Void)?

    private let definition: DistrictMapDefinition
    private let mission: DistrictMission?
    private let path: Pathway?
    private let navigation: DistrictNavigationGrid
    private let worldNode = SKNode()
    private let sceneCamera = SKCameraNode()
    private let player = SKNode()
    private let playerVisual = SKNode()
    private let playerArtwork = SKSpriteNode()
    private let playerShadow = SKShapeNode(ellipseOf: CGSize(width: 42, height: 14))
    private let objectiveMarker = SKNode()
    private let destinationMarker = SKShapeNode()
    private let routeMarkersNode = SKNode()
    private var chunks: [DistrictChunkCoordinate: SKNode] = [:]
    private var ambientCitizens: [AmbientCitizenAgent] = []
    private var route: [CGPoint] = []
    private var lastUpdateTime: TimeInterval?
    private var publishAccumulator: TimeInterval = 0
    private var didBuild = false
    private var snapshot = DistrictMapSnapshot()
    private var animationName = ""
    private var lastFacing = "S"
    private var cameraScale: CGFloat = 1
    private var pinchStartCameraScale: CGFloat = 1
    private let cameraScaleRange: ClosedRange<CGFloat> = 0.72...1.34
    private let movementSpeed: CGFloat = 170
    private let npcInteractionDistance: CGFloat = 190
    private let npcDefinitions = GameContent.oldClockNPCs
    private let venueDefinitions = GameContent.oldClockVenues

    private var objectivePoint: CGPoint { definition.objectivePoint(for: mission) }

    init(definition: DistrictMapDefinition, mission: DistrictMission?, path: Pathway?) {
        self.definition = definition
        self.mission = mission
        self.path = path
        navigation = DistrictNavigationGrid(definition: definition)
        super.init(size: CGSize(width: 393, height: 852))
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.025, green: 0.035, blue: 0.055, alpha: 1)
        snapshot.playerPosition = definition.spawnPoint
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        guard !didBuild else { return }
        didBuild = true
        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = true
        buildWorld()
        buildCamera()
        buildAreaMarkers()
        buildNPCs()
        buildVenues()
        buildAmbientEnemies()
        buildObjective()
        buildPlayer()
        buildWeather()
        updateChunks(force: true)
        publishState(force: true)

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--preview-map-venue"),
           let venue = venueDefinitions.first {
            player.position = CGPoint(x: venue.position.x - 120, y: venue.position.y)
            sceneCamera.position = player.position
            updateChunks(force: true)
            publishState(force: true)
        }
        if ProcessInfo.processInfo.arguments.contains("--preview-map-npc") {
            run(.sequence([
                .wait(forDuration: 0.8),
                .run { [weak self] in self?.interactWithNearbyNPC() }
            ]))
        }
        if ProcessInfo.processInfo.arguments.contains("--preview-map-tour") {
            run(.sequence([
                .wait(forDuration: 0.7),
                .run { [weak self] in self?.move(to: CGPoint(x: 11_776, y: 12_800)) },
                .wait(forDuration: 4.0),
                .run { [weak self] in self?.move(to: CGPoint(x: 13_824, y: 12_800)) },
                .wait(forDuration: 7.0),
                .run { [weak self] in self?.moveToObjective() }
            ]))
        }
        if ProcessInfo.processInfo.arguments.contains("--preview-map-crowd") {
            player.isHidden = true
        }
        if ProcessInfo.processInfo.arguments.contains("--preview-map-zoom-in") {
            setCameraScale(0.76)
        }
        if ProcessInfo.processInfo.arguments.contains("--preview-map-zoom-out") {
            setCameraScale(1.28)
        }
        #endif
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        if let venue = venue(at: location) {
            move(to: venue.position)
            snapshot.status = "前往\(venue.name)"
            publishState(force: true)
            return
        }
        if let npc = npc(at: location) {
            if hypot(player.position.x - npc.position.x, player.position.y - npc.position.y) <= npcInteractionDistance {
                interact(with: npc)
            } else {
                move(to: npc.position)
                snapshot.status = "前往与\(npc.name)交谈"
            }
            publishState(force: true)
            return
        }
        move(to: location)
    }

    override func update(_ currentTime: TimeInterval) {
        let elapsed = min(1.0 / 20.0, currentTime - (lastUpdateTime ?? currentTime))
        lastUpdateTime = currentTime
        updatePlayer(deltaTime: CGFloat(elapsed))
        updateCamera()
        updateChunks(force: false)
        updateAmbientCitizens(deltaTime: CGFloat(elapsed))

        publishAccumulator += elapsed
        if publishAccumulator >= 0.12 {
            publishAccumulator = 0
            publishState(force: false)
        }
    }

    func moveToObjective() {
        move(to: objectivePoint)
        snapshot.status = "前往任务入口"
        publishState(force: true)
    }

    func interactWithNearbyNPC() {
        guard let npcID = snapshot.nearbyNPCID,
              let npc = npcDefinitions.first(where: { $0.id == npcID }) else { return }
        interact(with: npc)
        publishState(force: true)
    }

    func dismissNPCDialogue() {
        snapshot.isNPCDialogueVisible = false
        snapshot.status = "点击街道移动"
        publishState(force: true)
    }

    func zoomIn() {
        setCameraScale(cameraScale - 0.12)
    }

    func zoomOut() {
        setCameraScale(cameraScale + 0.12)
    }

    func beginPinchZoom() {
        pinchStartCameraScale = cameraScale
    }

    func updatePinchZoom(magnification: CGFloat) {
        guard magnification.isFinite, magnification > 0 else { return }
        setCameraScale(pinchStartCameraScale / magnification)
    }

    private func buildWorld() {
        worldNode.name = "district-world"
        addChild(worldNode)
    }

    private func buildCamera() {
        sceneCamera.position = definition.spawnPoint
        sceneCamera.setScale(cameraScale)
        camera = sceneCamera
        addChild(sceneCamera)
    }

    private func setCameraScale(_ requestedScale: CGFloat) {
        let clampedScale = min(max(requestedScale, cameraScaleRange.lowerBound), cameraScaleRange.upperBound)
        guard cameraScale != clampedScale else { return }
        cameraScale = clampedScale
        sceneCamera.setScale(cameraScale)
    }

    private func buildRoads() {
        let roadOutline = SKShapeNode(path: roadPath())
        roadOutline.strokeColor = UIColor.black.withAlphaComponent(0.78)
        roadOutline.lineWidth = 158
        roadOutline.lineCap = .round
        roadOutline.lineJoin = .round
        roadOutline.zPosition = -7
        worldNode.addChild(roadOutline)

        let road = SKShapeNode(path: roadPath())
        road.strokeColor = UIColor(red: 0.17, green: 0.18, blue: 0.21, alpha: 1)
        road.lineWidth = 124
        road.lineCap = .round
        road.lineJoin = .round
        road.zPosition = -6
        worldNode.addChild(road)

        let centerLine = SKShapeNode(path: roadPath())
        centerLine.strokeColor = UIColor.white.withAlphaComponent(0.055)
        centerLine.lineWidth = 2
        centerLine.zPosition = -5
        worldNode.addChild(centerLine)
    }

    private func roadPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: definition.spawnPoint)
        path.addCurve(
            to: CGPoint(x: 720, y: 1_460),
            control1: CGPoint(x: 1_400, y: 820),
            control2: CGPoint(x: 900, y: 1_020)
        )
        path.move(to: CGPoint(x: 720, y: 1_460))
        path.addCurve(
            to: CGPoint(x: 790, y: 3_040),
            control1: CGPoint(x: 780, y: 1_940),
            control2: CGPoint(x: 650, y: 2_420)
        )
        path.move(to: definition.spawnPoint)
        path.addCurve(
            to: CGPoint(x: 2_350, y: 1_480),
            control1: CGPoint(x: 1_650, y: 850),
            control2: CGPoint(x: 2_160, y: 1_020)
        )
        path.move(to: CGPoint(x: 2_350, y: 1_480))
        path.addCurve(
            to: definition.teamDungeonPoint,
            control1: CGPoint(x: 2_260, y: 1_990),
            control2: CGPoint(x: 2_440, y: 2_520)
        )
        path.move(to: CGPoint(x: 720, y: 1_460))
        path.addCurve(
            to: CGPoint(x: 2_350, y: 1_480),
            control1: CGPoint(x: 1_200, y: 1_690),
            control2: CGPoint(x: 1_850, y: 1_700)
        )
        path.move(to: CGPoint(x: 790, y: 3_040))
        path.addCurve(
            to: definition.teamDungeonPoint,
            control1: CGPoint(x: 1_230, y: 3_200),
            control2: CGPoint(x: 1_820, y: 3_040)
        )
        return path
    }

    private func buildCanal() {
        let canal = SKShapeNode(rect: CGRect(x: 0, y: 2_040, width: 1_430, height: 210), cornerRadius: 74)
        canal.fillColor = UIColor(red: 0.03, green: 0.20, blue: 0.27, alpha: 0.92)
        canal.strokeColor = UIColor.systemCyan.withAlphaComponent(0.24)
        canal.lineWidth = 10
        canal.zPosition = -4
        worldNode.addChild(canal)

        for index in 0..<12 {
            let flow = SKShapeNode(rectOf: CGSize(width: 120, height: 3), cornerRadius: 2)
            flow.position = CGPoint(x: 90 + CGFloat(index) * 118, y: 2_145 + CGFloat(index % 3) * 32 - 32)
            flow.fillColor = UIColor.systemCyan.withAlphaComponent(0.22)
            flow.strokeColor = .clear
            flow.zPosition = -3
            flow.run(.repeatForever(.sequence([
                .moveBy(x: 70, y: 0, duration: 1.2),
                .moveBy(x: -70, y: 0, duration: 0)
            ])))
            worldNode.addChild(flow)
        }
    }

    private func buildBuildings() {
        for (index, rect) in definition.obstacles.enumerated() {
            let building = SKShapeNode(rect: rect, cornerRadius: 28)
            building.fillColor = index % 3 == 0
                ? UIColor(red: 0.10, green: 0.09, blue: 0.13, alpha: 1)
                : UIColor(red: 0.075, green: 0.085, blue: 0.11, alpha: 1)
            building.strokeColor = UIColor(path?.tint ?? .purple).withAlphaComponent(0.22)
            building.lineWidth = 8
            building.zPosition = 2
            worldNode.addChild(building)

            let roof = SKShapeNode(rect: rect.insetBy(dx: 24, dy: 24), cornerRadius: 18)
            roof.fillColor = UIColor.black.withAlphaComponent(0.24)
            roof.strokeColor = UIColor.white.withAlphaComponent(0.055)
            roof.lineWidth = 3
            roof.zPosition = 3
            worldNode.addChild(roof)

            let windows = max(2, Int(rect.width / 150))
            for window in 0..<windows {
                let light = SKShapeNode(rectOf: CGSize(width: 22, height: 10), cornerRadius: 3)
                light.position = CGPoint(
                    x: rect.minX + 64 + CGFloat(window) * min(130, (rect.width - 120) / CGFloat(max(1, windows - 1))),
                    y: rect.minY + 28
                )
                light.fillColor = UIColor.systemYellow.withAlphaComponent(index % 4 == 0 ? 0.65 : 0.24)
                light.strokeColor = .clear
                light.glowWidth = 7
                light.zPosition = 4
                worldNode.addChild(light)
            }
        }
    }

    private func buildAreaMarkers() {
        let dungeon = SKNode()
        dungeon.position = definition.teamDungeonPoint
        dungeon.zPosition = 20
        let ring = SKShapeNode(circleOfRadius: 56)
        ring.fillColor = UIColor.systemPink.withAlphaComponent(0.10)
        ring.strokeColor = UIColor.systemPink.withAlphaComponent(0.85)
        ring.lineWidth = 5
        ring.glowWidth = 12
        dungeon.addChild(ring)
        let label = SKLabelNode(text: "团队副本")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 21
        label.fontColor = .white
        label.position.y = 76
        dungeon.addChild(label)
        ring.run(.repeatForever(.sequence([
            .scale(to: 1.18, duration: 0.72),
            .scale(to: 0.92, duration: 0.72)
        ])))
        worldNode.addChild(dungeon)
    }

    private func buildNPCs() {
        npcDefinitions.forEach { definition in
            let root = SKNode()
            root.name = "npc:\(definition.id)"
            root.position = definition.position
            root.zPosition = 28

            // Story NPCs should read as a person standing in the world, not as a
            // full-screen portrait. Their dialogue carries the close-up instead.
            let shadow = SKShapeNode(ellipseOf: CGSize(width: 34, height: 10))
            shadow.fillColor = UIColor.black.withAlphaComponent(0.62)
            shadow.strokeColor = .clear
            shadow.position.y = -7
            shadow.name = root.name
            root.addChild(shadow)

            let texture = SKTexture(imageNamed: definition.artName)
            texture.filteringMode = .linear
            let artwork = SKSpriteNode(texture: texture)
            artwork.anchorPoint = CGPoint(x: 0.5, y: 0)
            artwork.position.y = -8
            artwork.size = definition.id == "number-thirteen"
                ? CGSize(width: 50, height: 50)
                : CGSize(width: 32, height: 60)
            artwork.name = root.name
            root.addChild(artwork)

            let name = SKLabelNode(text: definition.name)
            name.fontName = "AvenirNext-DemiBold"
            name.fontSize = 13
            name.fontColor = .white
            name.position.y = definition.id == "number-thirteen" ? 56 : 62
            name.name = root.name
            root.addChild(name)

            let interaction = SKLabelNode(text: "…")
            interaction.fontName = "AvenirNext-Heavy"
            interaction.fontSize = 16
            interaction.fontColor = UIColor(red: 0.96, green: 0.78, blue: 0.34, alpha: 1)
            interaction.verticalAlignmentMode = .center
            interaction.position = CGPoint(x: 21, y: definition.id == "number-thirteen" ? 46 : 52)
            interaction.name = root.name
            let bubblePath = CGMutablePath()
            bubblePath.move(to: CGPoint(x: -13, y: -11))
            bubblePath.addLine(to: CGPoint(x: 11, y: -11))
            bubblePath.addLine(to: CGPoint(x: 17, y: -5))
            bubblePath.addLine(to: CGPoint(x: 17, y: 7))
            bubblePath.addLine(to: CGPoint(x: 11, y: 13))
            bubblePath.addLine(to: CGPoint(x: -11, y: 13))
            bubblePath.addLine(to: CGPoint(x: -17, y: 7))
            bubblePath.addLine(to: CGPoint(x: -17, y: -5))
            bubblePath.closeSubpath()
            let bubble = SKShapeNode(path: bubblePath)
            bubble.fillColor = UIColor.black.withAlphaComponent(0.84)
            bubble.strokeColor = UIColor(red: 0.78, green: 0.58, blue: 0.20, alpha: 0.94)
            bubble.lineWidth = 1.5
            bubble.glowWidth = 2
            bubble.zPosition = -1
            bubble.name = root.name
            interaction.addChild(bubble)

            let tail = SKShapeNode()
            let tailPath = CGMutablePath()
            tailPath.move(to: CGPoint(x: -8, y: -11))
            tailPath.addLine(to: CGPoint(x: 0, y: -20))
            tailPath.addLine(to: CGPoint(x: 4, y: -11))
            tailPath.closeSubpath()
            tail.path = tailPath
            tail.fillColor = UIColor.black.withAlphaComponent(0.84)
            tail.strokeColor = UIColor(red: 0.78, green: 0.58, blue: 0.20, alpha: 0.94)
            tail.lineWidth = 1.5
            tail.zPosition = -2
            tail.name = root.name
            interaction.addChild(tail)
            interaction.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 4, duration: 0.65),
                .moveBy(x: 0, y: -4, duration: 0.65)
            ])))
            root.addChild(interaction)

            worldNode.addChild(root)
        }
    }

    private func buildAmbientEnemies() {
        let patrols: [(name: String, textureNames: [String], position: CGPoint, size: CGSize, level: Int)] = [
            ("失秒巡猎犬", ["GearHoundRun01", "GearHoundRun02", "GearHoundRun03", "GearHoundRun04"], CGPoint(x: 7_680, y: 12_800), CGSize(width: 78, height: 78), 3),
            ("失秒巡猎犬", ["GearHoundRun01", "GearHoundRun02", "GearHoundRun03", "GearHoundRun04"], CGPoint(x: 8_704, y: 14_336), CGSize(width: 76, height: 76), 5),
            ("盐雾幽灵", ["SaltWraithIdle"], CGPoint(x: 7_680, y: 4_608), CGSize(width: 74, height: 74), 8),
            ("工坊猎犬", ["GearHoundRun01", "GearHoundRun02", "GearHoundRun03", "GearHoundRun04"], CGPoint(x: 19_968, y: 12_800), CGSize(width: 82, height: 82), 10),
            ("镜潮幽影", ["MirrorShadeIdle"], CGPoint(x: 20_992, y: 22_016), CGSize(width: 94, height: 94), 18)
        ]

        for (index, patrol) in patrols.enumerated() {
            let root = SKNode()
            root.position = patrol.position
            root.zPosition = 22

            let ring = SKShapeNode(ellipseOf: CGSize(width: patrol.size.width * 0.62, height: 26))
            ring.position.y = -10
            ring.fillColor = UIColor.systemRed.withAlphaComponent(0.10)
            ring.strokeColor = UIColor.systemRed.withAlphaComponent(0.72)
            ring.lineWidth = 3
            ring.glowWidth = 7
            root.addChild(ring)

            let textures = patrol.textureNames.map {
                let texture = SKTexture(imageNamed: $0)
                texture.filteringMode = .linear
                return texture
            }
            let artwork = SKSpriteNode(texture: textures[0])
            artwork.anchorPoint = CGPoint(x: 0.5, y: 0)
            artwork.position.y = -12
            artwork.size = patrol.size
            root.addChild(artwork)
            if textures.count > 1 {
                artwork.run(.repeatForever(.animate(with: textures, timePerFrame: 0.12)), withKey: "patrol")
            } else {
                artwork.run(.repeatForever(.sequence([
                    .moveBy(x: 0, y: 5, duration: 0.55),
                    .moveBy(x: 0, y: -5, duration: 0.55)
                ])))
            }

            let label = SKLabelNode(text: "Lv.\(patrol.level) · \(patrol.name)")
            label.fontName = "AvenirNext-DemiBold"
            label.fontSize = 13
            label.fontColor = .white
            label.position.y = patrol.size.height * 0.78
            root.addChild(label)

            let horizontal: CGFloat = index.isMultiple(of: 2) ? 26 : -26
            root.run(.repeatForever(.sequence([
                .moveBy(x: horizontal, y: 0, duration: 1.8),
                .run { artwork.xScale *= -1 },
                .moveBy(x: -horizontal, y: 0, duration: 1.8),
                .run { artwork.xScale *= -1 }
            ])))
            worldNode.addChild(root)
        }
    }

    private func buildVenues() {
        venueDefinitions.forEach { venue in
            let root = SKNode()
            root.name = "venue:\(venue.id)"
            root.position = venue.position
            root.zPosition = 24

            // A street-level sign and threshold belong in the plaza better than a
            // freestanding oversized door. The actual interior appears on entry.
            let threshold = SKShapeNode(rectOf: CGSize(width: 46, height: 12), cornerRadius: 3)
            threshold.fillColor = UIColor(red: 0.13, green: 0.09, blue: 0.06, alpha: 0.94)
            threshold.strokeColor = UIColor(red: 0.72, green: 0.49, blue: 0.15, alpha: 0.76)
            threshold.lineWidth = 1.4
            threshold.position.y = -4
            threshold.name = root.name
            root.addChild(threshold)

            let post = SKShapeNode(rectOf: CGSize(width: 3, height: 40), cornerRadius: 1.5)
            post.fillColor = UIColor(red: 0.29, green: 0.18, blue: 0.10, alpha: 1)
            post.strokeColor = UIColor(red: 0.76, green: 0.54, blue: 0.18, alpha: 0.46)
            post.lineWidth = 1
            post.position = CGPoint(x: 0, y: 27)
            post.name = root.name
            root.addChild(post)

            let sign = SKShapeNode(rectOf: CGSize(width: 42, height: 22), cornerRadius: 5)
            sign.fillColor = UIColor.black.withAlphaComponent(0.86)
            sign.strokeColor = UIColor(red: 0.78, green: 0.56, blue: 0.20, alpha: 0.9)
            sign.lineWidth = 1.8
            sign.glowWidth = 1
            sign.position.y = 48
            sign.name = root.name
            root.addChild(sign)

            let lamp = SKShapeNode(circleOfRadius: 5)
            lamp.position = CGPoint(x: 0, y: 48)
            lamp.fillColor = .systemYellow
            lamp.strokeColor = UIColor.white.withAlphaComponent(0.62)
            lamp.glowWidth = 7
            lamp.name = root.name
            root.addChild(lamp)

            let label = SKLabelNode(text: venue.name)
            label.fontName = "AvenirNext-DemiBold"
            label.fontSize = 12
            label.fontColor = UIColor(red: 0.98, green: 0.86, blue: 0.62, alpha: 1)
            label.position.y = 70
            label.name = root.name
            root.addChild(label)

            let subtitle = SKLabelNode(text: venue.kind == .cafe ? "咖啡 · 传闻" : "餐食 · 秘密菜单")
            subtitle.fontName = "AvenirNext-Regular"
            subtitle.fontSize = 10
            subtitle.fontColor = UIColor.white.withAlphaComponent(0.58)
            subtitle.position.y = 58
            subtitle.name = root.name
            root.addChild(subtitle)

            lamp.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.52, duration: 0.8),
                .fadeAlpha(to: 1, duration: 0.8)
            ])))
            worldNode.addChild(root)
        }
    }

    private func buildObjective() {
        objectiveMarker.position = objectivePoint
        objectiveMarker.zPosition = 24

        let ring = SKShapeNode(circleOfRadius: 24)
        ring.fillColor = UIColor(red: 0.18, green: 0.12, blue: 0.05, alpha: 0.72)
        ring.strokeColor = UIColor(red: 0.88, green: 0.67, blue: 0.18, alpha: 0.92)
        ring.lineWidth = 2
        ring.glowWidth = 0
        objectiveMarker.addChild(ring)

        let pin = SKLabelNode(text: "◆")
        pin.fontName = "AvenirNext-Heavy"
        pin.fontSize = 14
        pin.fontColor = UIColor(red: 0.98, green: 0.80, blue: 0.26, alpha: 1)
        pin.verticalAlignmentMode = .center
        pin.position.y = 1
        objectiveMarker.addChild(pin)

        let title = SKLabelNode(text: mission?.title ?? "任务入口")
        title.fontName = "AvenirNext-DemiBold"
        title.fontSize = 16
        title.fontColor = .white
        title.position.y = 38
        objectiveMarker.addChild(title)
        worldNode.addChild(objectiveMarker)

        let destinationPath = CGMutablePath()
        destinationPath.move(to: CGPoint(x: 0, y: 20))
        destinationPath.addLine(to: CGPoint(x: 20, y: 0))
        destinationPath.addLine(to: CGPoint(x: 0, y: -20))
        destinationPath.addLine(to: CGPoint(x: -20, y: 0))
        destinationPath.closeSubpath()
        destinationMarker.path = destinationPath
        destinationMarker.strokeColor = UIColor(red: 0.86, green: 0.66, blue: 0.22, alpha: 0.82)
        destinationMarker.fillColor = UIColor.black.withAlphaComponent(0.38)
        destinationMarker.lineWidth = 2
        destinationMarker.glowWidth = 3
        destinationMarker.zPosition = 16
        destinationMarker.isHidden = true
        worldNode.addChild(destinationMarker)

        routeMarkersNode.zPosition = 14
        worldNode.addChild(routeMarkersNode)
    }

    private func buildPlayer() {
        player.position = definition.spawnPoint
        player.zPosition = 30

        playerShadow.fillColor = UIColor.black.withAlphaComponent(0.58)
        playerShadow.strokeColor = .clear
        playerShadow.position.y = -8
        player.addChild(playerShadow)

        let texture = SKTexture(imageNamed: "FoolCombatTopDownV3")
        texture.filteringMode = .linear
        playerArtwork.texture = texture
        playerArtwork.anchorPoint = CGPoint(x: 0.5, y: 0)
        playerArtwork.position.y = -10
        playerArtwork.size = CGSize(width: 82, height: 82)
        playerVisual.addChild(playerArtwork)
        player.addChild(playerVisual)
        worldNode.addChild(player)
        playPlayerAnimation(moving: false, facing: "N")
    }

    private func buildWeather() {
        let rain = SKEmitterNode()
        rain.particleBirthRate = 42
        rain.particleLifetime = 2.1
        rain.particlePositionRange = CGVector(dx: size.width * 1.4, dy: 20)
        rain.position = CGPoint(x: 0, y: size.height * 0.58)
        rain.emissionAngle = -.pi * 0.56
        rain.emissionAngleRange = 0.05
        rain.particleSpeed = 430
        rain.particleSpeedRange = 80
        rain.particleAlpha = 0.28
        rain.particleColor = UIColor(red: 0.66, green: 0.82, blue: 1, alpha: 1)
        rain.particleSize = CGSize(width: 1.2, height: 14)
        rain.zPosition = 100
        rain.targetNode = sceneCamera
        sceneCamera.addChild(rain)
    }

    private func move(to requestedPoint: CGPoint) {
        snapshot.isNPCDialogueVisible = false
        let nextRoute = navigation.route(from: player.position, to: requestedPoint)
        guard !nextRoute.isEmpty else {
            snapshot.status = "道路被封锁"
            publishState(force: true)
            return
        }
        route = nextRoute
        drawRoute()
        destinationMarker.position = nextRoute.last ?? requestedPoint
        destinationMarker.isHidden = false
        destinationMarker.removeAllActions()
        destinationMarker.run(.repeatForever(.sequence([
            .scale(to: 1.12, duration: 0.5),
            .scale(to: 0.72, duration: 0.5)
        ])))
        snapshot.status = "穿行旧城区"
        publishState(force: true)
    }

    private func updatePlayer(deltaTime: CGFloat) {
        guard let waypoint = route.first else {
            stopPlayerAnimation()
            return
        }
        let dx = waypoint.x - player.position.x
        let dy = waypoint.y - player.position.y
        let waypointDistance = hypot(dx, dy)
        guard waypointDistance > 0.01 else {
            route.removeFirst()
            drawRoute()
            return
        }

        updatePlayerDirection(dx: dx, dy: dy)
        let travel = movementSpeed * deltaTime
        if travel >= waypointDistance {
            player.position = waypoint
            route.removeFirst()
            drawRoute()
            if route.isEmpty {
                destinationMarker.removeAllActions()
                destinationMarker.run(.sequence([.fadeOut(withDuration: 0.22), .hide()]))
                snapshot.status = hypot(player.position.x - objectivePoint.x, player.position.y - objectivePoint.y) < 140
                    ? "已抵达任务入口"
                    : "点击街道继续移动"
            }
        } else {
            player.position.x += dx / waypointDistance * travel
            player.position.y += dy / waypointDistance * travel
        }
        player.zPosition = 30 + (definition.worldSize.height - player.position.y) / definition.worldSize.height
    }

    private func updatePlayerDirection(dx: CGFloat, dy: CGFloat) {
        if abs(dx) > abs(dy) {
            lastFacing = dx >= 0 ? "E" : "W"
        } else {
            lastFacing = dy >= 0 ? "N" : "S"
        }
        playPlayerAnimation(moving: true, facing: lastFacing)
    }

    private func playPlayerAnimation(moving: Bool, facing: String) {
        let name = "\(moving ? "Run" : "Idle")-\(facing)"
        guard name != animationName else { return }
        animationName = name
        playerArtwork.removeAction(forKey: "frames")

        // A stopped map avatar stays still. Replaying a pose sheet here made the
        // protagonist look as if they were fidgeting without any player input.
        guard moving else {
            GroundedSpriteGait.stop(artwork: playerArtwork, shadow: playerShadow)
            let idleAsset = switch facing {
            case "N": "FoolIdleN"
            case "S": "FoolIdleS"
            default: "FoolIdle01"
            }
            let texture = SKTexture(imageNamed: idleAsset)
            texture.filteringMode = .linear
            playerArtwork.texture = texture
            playerArtwork.xScale = facing == "W" ? -1 : 1
            playerVisual.removeAllActions()
            playerVisual.position = .zero
            playerVisual.zRotation = 0
            playerVisual.xScale = 1
            playerVisual.yScale = 1
            return
        }

        let frameCount = 6
        var textures: [SKTexture] = []
        for frame in 1...frameCount {
            let assetName: String
            switch facing {
            case "N": assetName = String(format: "FoolRunN%02d", frame)
            case "S": assetName = String(format: "FoolRunS%02d", frame)
            default: assetName = String(format: "FoolRun%02d", frame)
            }
            guard let image = UIImage(named: assetName) else {
                textures.removeAll()
                break
            }
            let texture = SKTexture(image: image)
            texture.filteringMode = .linear
            textures.append(texture)
        }

        if textures.count == frameCount {
            GroundedSpriteGait.stop(artwork: playerArtwork, shadow: playerShadow)
            // The generated strip's source orientation leads screen-right.
            // Mirror it only when travelling west so the face leads the motion.
            playerArtwork.xScale = facing == "W" ? -1 : 1
            playerArtwork.texture = textures[0]
            playerArtwork.run(.repeatForever(.animate(with: textures, timePerFrame: 0.09)), withKey: "frames")
        } else {
            let fallbackNames = ["FoolIdle01", "FoolIdle02", "FoolIdle03", "FoolIdle04", "FoolIdle03", "FoolIdle02"]
            let fallbackTextures = fallbackNames.map { assetName -> SKTexture in
                let texture = SKTexture(imageNamed: assetName)
                texture.filteringMode = .linear
                return texture
            }
            playerArtwork.texture = fallbackTextures[0]
            playerArtwork.xScale = facing == "W" ? -1 : 1
            GroundedSpriteGait.start(
                artwork: playerArtwork,
                shadow: playerShadow,
                cadence: 0.34,
                stride: 1.8
            )
            playerArtwork.run(
                .repeatForever(.animate(with: fallbackTextures, timePerFrame: 0.105)),
                withKey: "frames"
            )
        }

        playerVisual.removeAction(forKey: "body-motion")
        playerVisual.position = .zero
        playerVisual.zRotation = 0
        playerVisual.xScale = 1
        playerVisual.yScale = 1
    }

    private func stopPlayerAnimation() {
        let facing = animationName.split(separator: "-").last.map(String.init) ?? "N"
        playPlayerAnimation(moving: false, facing: facing)
    }

    private func updateCamera() {
        let halfWidth = size.width * cameraScale * 0.5
        let halfHeight = size.height * cameraScale * 0.5
        let target = CGPoint(
            x: min(max(halfWidth, player.position.x), definition.worldSize.width - halfWidth),
            y: min(max(halfHeight, player.position.y), definition.worldSize.height - halfHeight)
        )
        sceneCamera.position.x += (target.x - sceneCamera.position.x) * 0.13
        sceneCamera.position.y += (target.y - sceneCamera.position.y) * 0.13
    }

    private func updateChunks(force: Bool) {
        let center = DistrictChunkCoordinate(
            column: Int(player.position.x / definition.chunkSize),
            row: Int(player.position.y / definition.chunkSize)
        )
        let columns = Int(ceil(definition.worldSize.width / definition.chunkSize))
        let rows = Int(ceil(definition.worldSize.height / definition.chunkSize))
        var required: Set<DistrictChunkCoordinate> = []
        for row in (center.row - 1)...(center.row + 1) {
            for column in (center.column - 1)...(center.column + 1)
            where (0..<columns).contains(column) && (0..<rows).contains(row) {
                required.insert(DistrictChunkCoordinate(column: column, row: row))
            }
        }
        guard force || Set(chunks.keys) != required else { return }

        for coordinate in Set(chunks.keys).subtracting(required) {
            chunks.removeValue(forKey: coordinate)?.removeFromParent()
        }
        ambientCitizens.removeAll { $0.root.parent == nil }
        for coordinate in required where chunks[coordinate] == nil {
            let chunk = makeChunk(coordinate)
            chunks[coordinate] = chunk
            worldNode.addChild(chunk)
        }
    }

    private func makeChunk(_ coordinate: DistrictChunkCoordinate) -> SKNode {
        let node = SKNode()
        node.name = "chunk-\(coordinate.column)-\(coordinate.row)"
        node.position = CGPoint(
            x: CGFloat(coordinate.column) * definition.chunkSize,
            y: CGFloat(coordinate.row) * definition.chunkSize
        )
        node.zPosition = -10

        let center = CGPoint(x: node.position.x + definition.chunkSize / 2, y: node.position.y + definition.chunkSize / 2)
        let area = definition.area(containing: center)
        let base = SKShapeNode(rect: CGRect(origin: .zero, size: CGSize(width: definition.chunkSize, height: definition.chunkSize)))
        base.fillColor = UIColor(red: 0.052, green: 0.058, blue: 0.073, alpha: 1)
        base.strokeColor = UIColor.white.withAlphaComponent(0.045)
        base.lineWidth = 5
        node.addChild(base)

        let zoneWash = SKShapeNode(rect: CGRect(origin: .zero, size: CGSize(width: definition.chunkSize, height: definition.chunkSize)))
        zoneWash.fillColor = area.tint.withAlphaComponent(0.035)
        zoneWash.strokeColor = .clear
        zoneWash.zPosition = 0.1
        node.addChild(zoneWash)

        if let assetName = environmentAssetName(for: area, coordinate: coordinate) {
            let texture = SKTexture(imageNamed: assetName)
            texture.filteringMode = .linear
            let artwork = SKSpriteNode(texture: texture)
            artwork.position = CGPoint(x: definition.chunkSize / 2, y: definition.chunkSize / 2)
            artwork.size = CGSize(width: definition.chunkSize + 2, height: definition.chunkSize + 2)
            artwork.zPosition = 4
            if area.id != "clock-square" {
                artwork.zRotation = CGFloat((coordinate.column + coordinate.row) % 4) * .pi / 2
            }
            node.addChild(artwork)
            addAmbientCitizens(to: node, coordinate: coordinate)
            return node
        }

        var random = DistrictSeededRandom(seed: UInt64((coordinate.row + 7) * 1_009 + (coordinate.column + 11) * 9_173))
        for _ in 0..<64 {
            let width = CGFloat(random.next(in: 32...104))
            let stone = SKShapeNode(rectOf: CGSize(width: width, height: CGFloat(random.next(in: 12...28))), cornerRadius: 7)
            stone.position = CGPoint(
                x: CGFloat(random.next(in: 20...1_004)),
                y: CGFloat(random.next(in: 20...1_004))
            )
            stone.zRotation = CGFloat(random.next(in: -12...12)) * .pi / 180
            stone.fillColor = UIColor.white.withAlphaComponent(CGFloat(random.next(in: 3...9)) / 100)
            stone.strokeColor = UIColor.black.withAlphaComponent(0.12)
            stone.lineWidth = 1
            node.addChild(stone)
        }

        for propIndex in 0..<9 {
            let prop = SKShapeNode(circleOfRadius: CGFloat(random.next(in: 8...18)))
            prop.position = CGPoint(
                x: CGFloat(random.next(in: 40...984)),
                y: CGFloat(random.next(in: 40...984))
            )
            prop.fillColor = area.tint.withAlphaComponent(0.10)
            prop.strokeColor = area.tint.withAlphaComponent(0.22)
            prop.lineWidth = 2
            node.addChild(prop)

            if propIndex < 3 {
                let lamp = SKShapeNode(circleOfRadius: 7)
                lamp.position = prop.position
                lamp.fillColor = UIColor.systemYellow.withAlphaComponent(0.72)
                lamp.strokeColor = UIColor.white.withAlphaComponent(0.38)
                lamp.lineWidth = 2
                lamp.glowWidth = 13
                lamp.zPosition = 1
                node.addChild(lamp)
            }
        }
        addAmbientCitizens(to: node, coordinate: coordinate)
        return node
    }

    private func environmentAssetName(
        for area: DistrictMapArea,
        coordinate: DistrictChunkCoordinate
    ) -> String? {
        switch area.id {
        case "clock-square":
            "OldClockSquareTileV1"
        case "foglamp-street": "FoglampStreetTileV1"
        case "gear-works": "GearWorksTileV1"
        case "rain-drain": "RainwaterDrainsTileV1"
        case "mirror-manor": "MirrorTideManorTileV1"
        default: nil
        }
    }

    private func addAmbientCitizens(
        to chunk: SKNode,
        coordinate: DistrictChunkCoordinate
    ) {
        let chunkCenter = CGPoint(
            x: chunk.position.x + definition.chunkSize * 0.5,
            y: chunk.position.y + definition.chunkSize * 0.5
        )
        let area = definition.area(containing: chunkCenter)
        let walkLanes = ambientWalkLanes(for: area)
        let palette = [
            UIColor(red: 0.27, green: 0.25, blue: 0.29, alpha: 1),
            UIColor(red: 0.22, green: 0.28, blue: 0.34, alpha: 1),
            UIColor(red: 0.33, green: 0.24, blue: 0.20, alpha: 1),
            UIColor(red: 0.25, green: 0.20, blue: 0.31, alpha: 1)
        ]
        var random = DistrictSeededRandom(
            seed: UInt64((coordinate.row + 31) * 7_919 + (coordinate.column + 47) * 10_007)
        )
        let citizenCount = random.next(in: 4...7)
        for index in 0..<citizenCount {
            // These atlases are side-facing walk cycles. Keep them on horizontal
            // lanes until dedicated north/south cycles are available.
            let lane = walkLanes[index % walkLanes.count]
            let laneY = lane.y + CGFloat(random.next(in: -8...8))
            let axisPosition = CGFloat(random.next(in: Int(lane.minX)...Int(lane.maxX)))

            let root = SKNode()
            root.name = "ambient-citizen"
            root.zPosition = 27
            root.position = CGPoint(x: axisPosition, y: laneY)

            let shadow = SKShapeNode(ellipseOf: CGSize(width: 19, height: 6))
            shadow.fillColor = UIColor.black.withAlphaComponent(0.48)
            shadow.strokeColor = .clear
            shadow.position.y = -4
            root.addChild(shadow)

            let archetype = AmbientCitizenArchetype.pick(using: &random)
            let baseWalkTextures = ambientWalkTextures(atlasName: archetype.atlasName)
            let startingFrame = random.next(in: 0...(baseWalkTextures.count - 1))
            let walkTextures = Array(baseWalkTextures[startingFrame...])
                + Array(baseWalkTextures[..<startingFrame])
            let artwork = SKSpriteNode(texture: walkTextures[0])
            artwork.anchorPoint = CGPoint(x: 0.5, y: 0)
            artwork.position.y = -5
            let artworkHeight = CGFloat(random.next(in: 39...47))
            artwork.size = CGSize(width: artworkHeight, height: artworkHeight)
            artwork.alpha = CGFloat(random.next(in: 86...98)) / 100
            artwork.color = palette[random.next(in: 0...(palette.count - 1))]
            artwork.colorBlendFactor = 0.10
            // The agent sets the initial orientation from its actual route below.
            artwork.xScale = 1
            root.addChild(artwork)

            chunk.addChild(root)

            let endpointA = CGPoint(x: lane.minX, y: laneY)
            let endpointB = CGPoint(x: lane.maxX, y: laneY)
            ambientCitizens.append(AmbientCitizenAgent(
                root: root,
                artwork: artwork,
                shadow: shadow,
                walkTextures: walkTextures,
                endpointA: endpointA,
                endpointB: endpointB,
                walksTowardB: random.next(in: 0...1) == 1,
                speed: CGFloat(random.next(in: archetype.speedRange)),
                walkFrameDuration: archetype.frameDuration,
                pauseDuration: TimeInterval(random.next(in: 8...22)) / 10,
                initialPause: TimeInterval(random.next(in: 0...14)) / 10,
                priority: random.next(in: 0...10_000),
                radius: artworkHeight * 0.43
            ))
        }
    }

    /// Horizontal pedestrian corridors matched to the visible paving in each
    /// environment tile. Keeping these separate from the navigation grid makes
    /// the decorative building silhouettes act like real solid scenery.
    private func ambientWalkLanes(for area: DistrictMapArea) -> [AmbientWalkLane] {
        switch area.id {
        case "clock-square":
            // The middle is occupied by the clock fountain.
            [
                AmbientWalkLane(minX: 250, maxX: 774, y: 330),
                AmbientWalkLane(minX: 220, maxX: 804, y: 388),
                AmbientWalkLane(minX: 220, maxX: 804, y: 650),
                AmbientWalkLane(minX: 250, maxX: 774, y: 708)
            ]
        case "foglamp-street":
            [
                AmbientWalkLane(minX: 300, maxX: 724, y: 360),
                AmbientWalkLane(minX: 270, maxX: 754, y: 505),
                AmbientWalkLane(minX: 300, maxX: 724, y: 650)
            ]
        case "gear-works":
            [
                AmbientWalkLane(minX: 190, maxX: 834, y: 360),
                AmbientWalkLane(minX: 165, maxX: 859, y: 510),
                AmbientWalkLane(minX: 190, maxX: 834, y: 660)
            ]
        case "rain-drain":
            [
                AmbientWalkLane(minX: 210, maxX: 814, y: 430),
                AmbientWalkLane(minX: 165, maxX: 859, y: 515),
                AmbientWalkLane(minX: 210, maxX: 814, y: 600)
            ]
        case "mirror-manor":
            [
                AmbientWalkLane(minX: 250, maxX: 774, y: 390),
                AmbientWalkLane(minX: 205, maxX: 819, y: 510),
                AmbientWalkLane(minX: 250, maxX: 774, y: 625)
            ]
        default:
            [AmbientWalkLane(minX: 260, maxX: 764, y: definition.chunkSize * 0.5)]
        }
    }

    private func ambientWalkTextures(atlasName: String) -> [SKTexture] {
        let atlas = SKTexture(imageNamed: atlasName)
        atlas.filteringMode = .linear
        return (0..<8).map { frame in
            let texture = SKTexture(
                rect: CGRect(x: CGFloat(frame) / 8, y: 0, width: 1 / 8, height: 1),
                in: atlas
            )
            texture.filteringMode = .linear
            return texture
        }
    }

    private func updateAmbientCitizens(deltaTime: CGFloat) {
        ambientCitizens.removeAll { $0.root.parent == nil }
        guard !ambientCitizens.isEmpty else { return }

        var blocked = Array(repeating: false, count: ambientCitizens.count)
        let positions: [CGPoint] = ambientCitizens.map {
            $0.root.convert(CGPoint.zero, to: worldNode)
        }

        for firstIndex in ambientCitizens.indices {
            let first = ambientCitizens[firstIndex]
            for secondIndex in ambientCitizens.indices where secondIndex > firstIndex {
                let second = ambientCitizens[secondIndex]

                var dx = positions[secondIndex].x - positions[firstIndex].x
                var dy = positions[secondIndex].y - positions[firstIndex].y
                var distance = hypot(dx, dy)
                let minimumDistance = first.radius + second.radius

                if distance < 0.01 {
                    dx = first.priority <= second.priority ? -1 : 1
                    dy = 0
                    distance = 1
                }

                if distance < minimumDistance {
                    let correction: CGFloat = (minimumDistance - distance) * 0.5 + 0.5
                    let normalX: CGFloat = dx / distance
                    let normalY: CGFloat = dy / distance
                    first.root.position.x -= normalX * correction
                    first.root.position.y -= normalY * correction
                    second.root.position.x += normalX * correction
                    second.root.position.y += normalY * correction
                    first.constrainToLane()
                    second.constrainToLane()
                }

                guard distance < minimumDistance * 3.4 else { continue }
                let firstDirection = first.pauseRemaining > 0 ? CGVector.zero : first.directionToTarget
                let secondDirection = second.pauseRemaining > 0 ? CGVector.zero : second.directionToTarget
                let predictionTime: CGFloat = 0.62
                let firstFuture = CGPoint(
                    x: positions[firstIndex].x + firstDirection.dx * first.speed * predictionTime,
                    y: positions[firstIndex].y + firstDirection.dy * first.speed * predictionTime
                )
                let secondFuture = CGPoint(
                    x: positions[secondIndex].x + secondDirection.dx * second.speed * predictionTime,
                    y: positions[secondIndex].y + secondDirection.dy * second.speed * predictionTime
                )
                let futureDistance = hypot(secondFuture.x - firstFuture.x, secondFuture.y - firstFuture.y)
                guard futureDistance < minimumDistance + 10 else { continue }

                if first.pauseRemaining > 0, second.pauseRemaining <= 0 {
                    blocked[secondIndex] = true
                } else if second.pauseRemaining > 0, first.pauseRemaining <= 0 {
                    blocked[firstIndex] = true
                } else if first.priority == second.priority {
                    blocked[secondIndex] = true
                } else if first.priority < second.priority {
                    blocked[firstIndex] = true
                } else {
                    blocked[secondIndex] = true
                }
            }
        }

        let playerPosition = player.position
        for index in ambientCitizens.indices {
            let citizen = ambientCitizens[index]
            if citizen.pauseRemaining > 0 {
                citizen.pauseRemaining = max(0, citizen.pauseRemaining - TimeInterval(deltaTime))
                citizen.setWalking(false)
                continue
            }

            if !player.isHidden {
                let worldPosition = citizen.root.convert(CGPoint.zero, to: worldNode)
                var playerDX = worldPosition.x - playerPosition.x
                var playerDY = worldPosition.y - playerPosition.y
                var distanceToPlayer = hypot(playerDX, playerDY)
                let playerClearance = citizen.radius + 36
                if distanceToPlayer < playerClearance {
                    if distanceToPlayer < 0.01 {
                        playerDX = citizen.priority.isMultiple(of: 2) ? -1 : 1
                        playerDY = 0
                        distanceToPlayer = 1
                    }
                    let pushDistance = playerClearance - distanceToPlayer + 0.5
                    citizen.root.position.x += playerDX / distanceToPlayer * pushDistance
                    citizen.root.position.y += playerDY / distanceToPlayer * pushDistance
                    citizen.constrainToLane()
                    blocked[index] = true
                }
            }

            if blocked[index] {
                citizen.setWalking(false)
                continue
            }

            let direction = citizen.directionToTarget
            let distanceToTarget = citizen.distanceToTarget
            if distanceToTarget < 4 {
                citizen.reachEndpoint()
                citizen.setWalking(false)
                continue
            }

            let travel = min(citizen.speed * deltaTime, distanceToTarget)
            citizen.root.position.x += direction.dx * travel
            citizen.root.position.y += direction.dy * travel
            citizen.constrainToLane()
            citizen.root.zPosition = 27 + (definition.chunkSize - citizen.root.position.y) / 10_000
            citizen.face(direction: direction)
            citizen.setWalking(true)
        }

        resolveAmbientCitizenOverlaps()
    }

    private func resolveAmbientCitizenOverlaps() {
        guard ambientCitizens.count > 1 else { return }

        for _ in 0..<2 {
            for firstIndex in ambientCitizens.indices {
                for secondIndex in ambientCitizens.indices where secondIndex > firstIndex {
                    let first = ambientCitizens[firstIndex]
                    let second = ambientCitizens[secondIndex]
                    let firstPosition = first.root.convert(CGPoint.zero, to: worldNode)
                    let secondPosition = second.root.convert(CGPoint.zero, to: worldNode)
                    var dx = secondPosition.x - firstPosition.x
                    var dy = secondPosition.y - firstPosition.y
                    var distance = hypot(dx, dy)
                    let minimumDistance = first.radius + second.radius
                    guard distance < minimumDistance else { continue }

                    if distance < 0.01 {
                        dx = first.priority <= second.priority ? -1 : 1
                        dy = 0
                        distance = 1
                    }
                    let correction: CGFloat = (minimumDistance - distance) * 0.5 + 0.25
                    let normalX: CGFloat = dx / distance
                    let normalY: CGFloat = dy / distance
                    first.root.position.x -= normalX * correction
                    first.root.position.y -= normalY * correction
                    second.root.position.x += normalX * correction
                    second.root.position.y += normalY * correction
                    first.constrainToLane()
                    second.constrainToLane()
                }
            }
        }
    }

    private func drawRoute() {
        routeMarkersNode.removeAllChildren()
        guard route.count > 2 else { return }

        let visibleCount = min(route.count - 1, 22)
        for index in stride(from: 1, to: visibleCount, by: 2) {
            let current = route[index]
            let next = route[min(index + 1, route.count - 1)]
            let markerPath = CGMutablePath()
            markerPath.move(to: CGPoint(x: -7, y: -5))
            markerPath.addLine(to: CGPoint(x: 8, y: 0))
            markerPath.addLine(to: CGPoint(x: -7, y: 5))
            markerPath.addLine(to: CGPoint(x: -2, y: 0))
            markerPath.closeSubpath()

            let marker = SKShapeNode(path: markerPath)
            marker.position = current
            marker.zRotation = atan2(next.y - current.y, next.x - current.x)
            marker.fillColor = UIColor(red: 0.88, green: 0.68, blue: 0.24, alpha: 0.52)
            marker.strokeColor = UIColor.white.withAlphaComponent(0.10)
            marker.lineWidth = 0.6
            marker.glowWidth = 1.5
            marker.setScale(0.84)
            marker.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.34, duration: 0.62),
                .fadeAlpha(to: 0.78, duration: 0.62)
            ])))
            routeMarkersNode.addChild(marker)
        }
    }

    private func npc(at location: CGPoint) -> DistrictNPCDefinition? {
        var node: SKNode? = atPoint(location)
        while let current = node {
            if let name = current.name, name.hasPrefix("npc:") {
                let id = String(name.dropFirst(4))
                return npcDefinitions.first(where: { $0.id == id })
            }
            node = current.parent
        }
        return nil
    }

    private func venue(at location: CGPoint) -> VenueDefinition? {
        var node: SKNode? = atPoint(location)
        while let current = node {
            if let name = current.name, name.hasPrefix("venue:") {
                let id = String(name.dropFirst(6))
                return venueDefinitions.first(where: { $0.id == id })
            }
            node = current.parent
        }
        return nil
    }

    private func interact(with npc: DistrictNPCDefinition) {
        route.removeAll()
        drawRoute()
        stopPlayerAnimation()
        snapshot.nearbyNPCID = npc.id
        snapshot.nearbyNPCName = npc.name
        snapshot.nearbyNPCTitle = npc.title
        snapshot.nearbyNPCDialogue = npc.dialogue
        snapshot.isNPCDialogueVisible = true
        snapshot.status = "正在与\(npc.name)交谈"
    }

    private func publishState(force: Bool) {
        let area = definition.area(containing: player.position)
        let objectiveDistance = Int(hypot(player.position.x - objectivePoint.x, player.position.y - objectivePoint.y))
        snapshot.areaName = area.name
        snapshot.areaSubtitle = area.subtitle
        snapshot.playerPosition = player.position
        snapshot.objectiveDistance = objectiveDistance
        snapshot.activeChunkCount = chunks.count
        snapshot.isNearObjective = objectiveDistance < 140
        let nearbyNPC = npcDefinitions.min { lhs, rhs in
            hypot(player.position.x - lhs.position.x, player.position.y - lhs.position.y)
                < hypot(player.position.x - rhs.position.x, player.position.y - rhs.position.y)
        }
        if let nearbyNPC,
           hypot(player.position.x - nearbyNPC.position.x, player.position.y - nearbyNPC.position.y) <= npcInteractionDistance {
            if snapshot.nearbyNPCID != nearbyNPC.id {
                snapshot.isNPCDialogueVisible = false
            }
            snapshot.nearbyNPCID = nearbyNPC.id
            snapshot.nearbyNPCName = nearbyNPC.name
            snapshot.nearbyNPCTitle = nearbyNPC.title
            snapshot.nearbyNPCDialogue = nearbyNPC.dialogue
        } else {
            snapshot.nearbyNPCID = nil
            snapshot.nearbyNPCName = nil
            snapshot.nearbyNPCTitle = nil
            snapshot.nearbyNPCDialogue = nil
            snapshot.isNPCDialogueVisible = false
        }
        let nearbyVenue = venueDefinitions.min { lhs, rhs in
            hypot(player.position.x - lhs.position.x, player.position.y - lhs.position.y)
                < hypot(player.position.x - rhs.position.x, player.position.y - rhs.position.y)
        }
        if let nearbyVenue,
           hypot(player.position.x - nearbyVenue.position.x, player.position.y - nearbyVenue.position.y) <= 175 {
            snapshot.nearbyVenueID = nearbyVenue.id
            snapshot.nearbyVenueName = nearbyVenue.name
        } else {
            snapshot.nearbyVenueID = nil
            snapshot.nearbyVenueName = nil
        }
        if force || onStateChange != nil { onStateChange?(snapshot) }
    }
}

@MainActor
private struct AmbientWalkLane {
    let minX: CGFloat
    let maxX: CGFloat
    let y: CGFloat
}

private enum AmbientCitizenArchetype {
    case man
    case woman
    case elder

    var atlasName: String {
        switch self {
        case .man: "AmbientMaleWalkAtlas"
        case .woman: "AmbientFemaleWalkAtlas"
        case .elder: "AmbientElderWalkAtlas"
        }
    }

    var speedRange: ClosedRange<Int> {
        switch self {
        case .man: 28...38
        case .woman: 27...37
        case .elder: 19...27
        }
    }

    var frameDuration: TimeInterval {
        switch self {
        case .man: 0.17
        case .woman: 0.18
        case .elder: 0.24
        }
    }

    static func pick(using random: inout DistrictSeededRandom) -> Self {
        switch random.next(in: 0...9) {
        case 0...3: .man
        case 4...7: .woman
        default: .elder
        }
    }
}

@MainActor
private final class AmbientCitizenAgent {
    let root: SKNode
    let artwork: SKSpriteNode
    let shadow: SKShapeNode
    let walkTextures: [SKTexture]
    let endpointA: CGPoint
    let endpointB: CGPoint
    let speed: CGFloat
    let walkFrameDuration: TimeInterval
    let pauseDuration: TimeInterval
    let priority: Int
    let radius: CGFloat

    var pauseRemaining: TimeInterval
    private var walksTowardB: Bool
    private var isWalking = false

    init(
        root: SKNode,
        artwork: SKSpriteNode,
        shadow: SKShapeNode,
        walkTextures: [SKTexture],
        endpointA: CGPoint,
        endpointB: CGPoint,
        walksTowardB: Bool,
        speed: CGFloat,
        walkFrameDuration: TimeInterval,
        pauseDuration: TimeInterval,
        initialPause: TimeInterval,
        priority: Int,
        radius: CGFloat
    ) {
        self.root = root
        self.artwork = artwork
        self.shadow = shadow
        self.walkTextures = walkTextures
        self.endpointA = endpointA
        self.endpointB = endpointB
        self.walksTowardB = walksTowardB
        self.speed = speed
        self.walkFrameDuration = walkFrameDuration
        self.pauseDuration = pauseDuration
        pauseRemaining = initialPause
        self.priority = priority
        self.radius = radius
        face(direction: directionToTarget)
    }

    var target: CGPoint { walksTowardB ? endpointB : endpointA }

    var distanceToTarget: CGFloat {
        hypot(target.x - root.position.x, target.y - root.position.y)
    }

    var directionToTarget: CGVector {
        let dx = target.x - root.position.x
        let dy = target.y - root.position.y
        let distance = hypot(dx, dy)
        guard distance > 0.01 else { return .zero }
        return CGVector(dx: dx / distance, dy: dy / distance)
    }

    func face(direction: CGVector) {
        guard abs(direction.dx) > 0.08 else { return }
        // Generated atlas art faces screen-left in its unmirrored form.
        artwork.xScale = direction.dx < 0 ? abs(artwork.xScale) : -abs(artwork.xScale)
    }

    func reachEndpoint() {
        root.position = target
        walksTowardB.toggle()
        pauseRemaining = pauseDuration
    }

    func constrainToLane() {
        root.position.x = min(max(root.position.x, endpointA.x), endpointB.x)
        root.position.y = endpointA.y
    }

    func setWalking(_ shouldWalk: Bool) {
        guard shouldWalk != isWalking else { return }
        isWalking = shouldWalk
        artwork.removeAction(forKey: "ambient-walk-frames")
        artwork.warpGeometry = nil
        shadow.removeAction(forKey: "grounded-shadow-gait")
        shadow.setScale(1)
        shadow.alpha = 1
        if shouldWalk {
            artwork.run(.repeatForever(.animate(
                with: walkTextures,
                timePerFrame: walkFrameDuration,
                resize: false,
                restore: false
            )), withKey: "ambient-walk-frames")
        } else {
            artwork.texture = walkTextures[0]
        }
    }
}

@MainActor
private enum GroundedSpriteGait {
    private static let actionKey = "grounded-leg-gait"
    private static let shadowActionKey = "grounded-shadow-gait"

    static func start(
        artwork: SKSpriteNode,
        shadow: SKShapeNode,
        cadence: TimeInterval,
        stride: CGFloat
    ) {
        artwork.removeAction(forKey: actionKey)
        shadow.removeAction(forKey: shadowActionKey)

        let neutral = warp(leftStep: 0, lift: 0, stride: stride)
        let leftContact = warp(leftStep: 1, lift: 1, stride: stride)
        let passingLeft = warp(leftStep: 0.34, lift: 0.52, stride: stride)
        let rightContact = warp(leftStep: -1, lift: -1, stride: stride)
        let passingRight = warp(leftStep: -0.34, lift: -0.52, stride: stride)
        artwork.warpGeometry = neutral

        let quarter = cadence * 0.25
        let times = [0, quarter, quarter * 2, quarter * 3, cadence].map(NSNumber.init(value:))
        if let step = SKAction.animate(
            withWarps: [leftContact, passingLeft, rightContact, passingRight, leftContact],
            times: times
        ) {
            artwork.run(.repeatForever(step), withKey: actionKey)
        }

        let halfStep = cadence * 0.5
        shadow.run(.repeatForever(.sequence([
            .group([
                .scaleX(to: 1.08, y: 0.88, duration: halfStep * 0.5),
                .fadeAlpha(to: 0.68, duration: halfStep * 0.5)
            ]),
            .group([
                .scaleX(to: 0.94, y: 1.06, duration: halfStep * 0.5),
                .fadeAlpha(to: 0.46, duration: halfStep * 0.5)
            ]),
            .group([
                .scaleX(to: 1.08, y: 0.88, duration: halfStep * 0.5),
                .fadeAlpha(to: 0.68, duration: halfStep * 0.5)
            ]),
            .group([
                .scaleX(to: 0.94, y: 1.06, duration: halfStep * 0.5),
                .fadeAlpha(to: 0.46, duration: halfStep * 0.5)
            ])
        ])), withKey: shadowActionKey)
    }

    static func stop(artwork: SKSpriteNode, shadow: SKShapeNode) {
        artwork.removeAction(forKey: actionKey)
        artwork.warpGeometry = warp(leftStep: 0, lift: 0, stride: 1)
        shadow.removeAction(forKey: shadowActionKey)
        shadow.setScale(1)
        shadow.alpha = 1
    }

    private static func warp(
        leftStep: CGFloat,
        lift: CGFloat,
        stride: CGFloat
    ) -> SKWarpGeometryGrid {
        let columns = 4
        let rows = 4
        var source: [SIMD2<Float>] = []
        var destination: [SIMD2<Float>] = []
        source.reserveCapacity((columns + 1) * (rows + 1))
        destination.reserveCapacity((columns + 1) * (rows + 1))

        for row in 0...rows {
            let y = CGFloat(row) / CGFloat(rows)
            for column in 0...columns {
                let x = CGFloat(column) / CGFloat(columns)
                source.append(SIMD2<Float>(Float(x), Float(y)))

                let lowerBodyInfluence = max(0, 1 - y / 0.64)
                let side: CGFloat = x < 0.5 ? -1 : (x > 0.5 ? 1 : 0)
                let strideInfluence = stride * lowerBodyInfluence
                let stepPhase = side * leftStep
                let stepOffset = stepPhase * 0.042 * strideInfluence
                let trailingSide: CGFloat = side * lift > 0 ? 1 : 0
                let liftAmount: CGFloat = Swift.abs(lift) * 0.045
                let footLift = trailingSide * liftAmount * strideInfluence
                let upperBodyInfluence = min(1, y / 0.55)
                let hipSway = leftStep * 0.012 * stride * upperBodyInfluence
                let compressionAmount: CGFloat = Swift.abs(leftStep) * 0.012
                let kneeCompression = compressionAmount * strideInfluence
                destination.append(SIMD2<Float>(
                    Float(x + stepOffset + hipSway),
                    Float(y + footLift + kneeCompression)
                ))
            }
        }

        return SKWarpGeometryGrid(
            columns: columns,
            rows: rows,
            sourcePositions: source,
            destinationPositions: destination
        )
    }
}

private struct DistrictSeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 1 : seed
    }

    mutating func next(in range: ClosedRange<Int>) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int((state >> 33) % span)
    }
}
