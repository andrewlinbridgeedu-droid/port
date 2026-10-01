import SpriteKit
import SwiftUI

struct DistrictMapView: View {
    private let mission: DistrictMission?
    private let onExit: () -> Void
    private let onMissionBoard: () -> Void
    private let onBeginMission: () -> Void
    private let onEnterVenue: (String) -> Void
    @State private var controller: DistrictMapController
    @State private var isPinching = false

    init(
        path: Pathway?,
        mission: DistrictMission?,
        onExit: @escaping () -> Void,
        onMissionBoard: @escaping () -> Void,
        onBeginMission: @escaping () -> Void,
        onEnterVenue: @escaping (String) -> Void
    ) {
        self.mission = mission
        self.onExit = onExit
        self.onMissionBoard = onMissionBoard
        self.onBeginMission = onBeginMission
        self.onEnterVenue = onEnterVenue
        _controller = State(initialValue: DistrictMapController(mission: mission, path: path))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                SpriteView(
                    scene: controller.scene,
                    preferredFramesPerSecond: 60,
                    options: [.ignoresSiblingOrder]
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .ignoresSafeArea()
                .simultaneousGesture(
                    MagnifyGesture()
                        .onChanged { value in
                            if !isPinching {
                                isPinching = true
                                controller.beginPinchZoom()
                            }
                            controller.updatePinchZoom(magnification: value.magnification)
                        }
                        .onEnded { _ in
                            isPinching = false
                        }
                )

                LinearGradient(
                    colors: [.black.opacity(0.34), .clear, .black.opacity(0.26)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    MapAreaHUD(
                        areaName: controller.snapshot.areaName,
                        areaSubtitle: controller.snapshot.areaSubtitle,
                        playerPosition: controller.snapshot.playerPosition,
                        objectivePosition: DistrictMapDefinition.oldClock.objectivePoint(for: mission),
                        onExit: onExit
                    )

                    Spacer(minLength: 80)

                    VStack(spacing: 8) {
                        if controller.snapshot.isNPCDialogueVisible,
                           let npc = nearbyNPC {
                            MapDialogueHUD(npc: npc)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            MapObjectiveHUD(
                                mission: mission,
                                distance: controller.snapshot.objectiveDistance,
                                isNearObjective: controller.snapshot.isNearObjective
                            )
                            .transition(.opacity)
                        }

                        MapActionDock(
                            isDialogueVisible: controller.snapshot.isNPCDialogueVisible,
                            nearbyNPCName: controller.snapshot.nearbyNPCName,
                            enterTitle: controller.snapshot.nearbyVenueID == nil ? "进入" : "入店",
                            canEnter: controller.snapshot.nearbyVenueID != nil
                                || (controller.snapshot.isNearObjective && mission != nil),
                            showsEnterTutorial: mission?.number == 1,
                            onMissions: onMissionBoard,
                            onContext: handleContextAction,
                            onEnter: handleEnterAction
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 8)
                .animation(.easeOut(duration: 0.22), value: controller.snapshot.isNPCDialogueVisible)

                MapZoomControls(
                    onZoomIn: controller.zoomIn,
                    onZoomOut: controller.zoomOut
                )
                .padding(.trailing, 14)
                .padding(.top, 104)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: controller.snapshot.isNPCDialogueVisible)
    }

    private var nearbyNPC: DistrictNPCDefinition? {
        guard let id = controller.snapshot.nearbyNPCID else { return nil }
        return GameContent.oldClockNPCs.first { $0.id == id }
    }

    private func handleContextAction() {
        if controller.snapshot.isNPCDialogueVisible {
            controller.dismissNPCDialogue()
        } else if controller.snapshot.nearbyNPCID != nil {
            controller.interactWithNearbyNPC()
        } else {
            controller.locateObjective()
        }
    }

    private func handleEnterAction() {
        if let venueID = controller.snapshot.nearbyVenueID {
            onEnterVenue(venueID)
        } else {
            onBeginMission()
        }
    }
}

private struct MapZoomControls: View {
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void

    var body: some View {
        VStack(spacing: 7) {
            zoomButton(symbol: "plus.magnifyingglass", label: "放大地图", action: onZoomIn)
            zoomButton(symbol: "minus.magnifyingglass", label: "缩小地图", action: onZoomOut)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("地图缩放")
    }

    private func zoomButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.black.opacity(0.76), in: CutCornerShape(cut: 9))
                .overlay { CutCornerShape(cut: 9).stroke(.cyan.opacity(0.36), lineWidth: 1) }
        }
        .buttonStyle(RunePressStyle())
        .accessibilityLabel(label)
    }
}

private struct MapAreaHUD: View {
    let areaName: String
    let areaSubtitle: String
    let playerPosition: CGPoint
    let objectivePosition: CGPoint
    let onExit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            GameArtReturnButton(title: "返回城区", action: onExit)

            VStack(alignment: .leading, spacing: 1) {
                Text(areaName)
                    .font(.headline.bold())
                Text(areaSubtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.62))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            DistrictMiniMap(
                definition: .oldClock,
                playerPosition: playerPosition,
                objectivePosition: objectivePosition
            )
            .frame(width: 82, height: 86)
        }
        .foregroundStyle(.white)
        .padding(.leading, 9)
        .padding(.trailing, 7)
        .padding(.vertical, 7)
        .background {
            CutCornerShape(cut: 18)
                .fill(
                    LinearGradient(
                        colors: [.black.opacity(0.82), .black.opacity(0.48)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .overlay {
            CutCornerShape(cut: 18)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.25), .cyan.opacity(0.36)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

private struct MapObjectiveHUD: View {
    let mission: DistrictMission?
    let distance: Int
    let isNearObjective: Bool

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                DiamondShape()
                    .fill(isNearObjective ? Color.green.opacity(0.82) : Color.yellow.opacity(0.88))
                Image(systemName: isNearObjective ? "checkmark" : "location.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.black)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(mission.map { "任务 \($0.number) · \($0.title)" } ?? "旧城区自由巡游")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(isNearObjective ? "战斗入口已开启" : "目标距离 \(distance) · 点击街道移动")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.60))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background {
            CutCornerShape(cut: 13)
                .fill(.black.opacity(0.74))
        }
        .overlay {
            CutCornerShape(cut: 13)
                .stroke(isNearObjective ? .green.opacity(0.72) : .yellow.opacity(0.40), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct MapDialogueHUD: View {
    let npc: DistrictNPCDefinition

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack(alignment: .bottom) {
                CutCornerShape(cut: 11)
                    .fill(.black.opacity(0.86))
                Image(npc.portraitArtName)
                    .resizable()
                    .scaledToFit()
                    .padding(.top, 5)
                    .padding(.horizontal, 5)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color(uiColor: npc.tint).opacity(0.55)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 20)
            }
            .frame(width: 62, height: 82)
            .clipShape(CutCornerShape(cut: 11))
            .overlay { CutCornerShape(cut: 11).stroke(Color(uiColor: npc.tint).opacity(0.72), lineWidth: 1) }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(npc.name)
                        .font(.subheadline.bold())
                    Text(npc.title)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(uiColor: npc.tint))
                        .lineLimit(1)
                }
                Text(npc.dialogue)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            CutCornerShape(cut: 17)
                .fill(
                    LinearGradient(
                        colors: [.black.opacity(0.92), Color(uiColor: npc.tint).opacity(0.20), .black.opacity(0.88)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .overlay {
            CutCornerShape(cut: 17)
                .stroke(Color(uiColor: npc.tint).opacity(0.72), lineWidth: 1.2)
        }
        .overlay(alignment: .topLeading) {
            DialogueTailShape()
                .fill(Color(uiColor: npc.tint).opacity(0.78))
                .frame(width: 20, height: 12)
                .offset(x: 28, y: -10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(npc.name)，\(npc.title)，\(npc.dialogue)")
    }
}

private struct MapActionDock: View {
    let isDialogueVisible: Bool
    let nearbyNPCName: String?
    let enterTitle: String
    let canEnter: Bool
    let showsEnterTutorial: Bool
    let onMissions: () -> Void
    let onContext: () -> Void
    let onEnter: () -> Void

    private var contextTitle: String {
        if isDialogueVisible { return "收起" }
        if nearbyNPCName != nil { return "交谈" }
        return "寻路"
    }

    private var contextKind: MapEmblemKind {
        if isDialogueVisible { return .dismiss }
        if nearbyNPCName != nil { return .talk }
        return .route
    }

    var body: some View {
        HStack(alignment: .bottom) {
            MapRuneButton(title: "任务", artName: "ButtonArt16MapRunesMissions", tint: .purple, action: onMissions)
            Spacer()
            MapRuneButton(title: contextTitle, artName: "ButtonArt16MapRunesContext", tint: .yellow, isPrimary: true, action: onContext)
            Spacer()
            MapRuneButton(
                title: enterTitle,
                artName: "ButtonArt16MapRunesEnter",
                tint: .orange,
                isTutorialEmphasis: showsEnterTutorial && canEnter,
                action: onEnter
            )
            .disabled(!canEnter)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("地图动作")
    }
}

private struct MapRuneButton: View {
    let title: String
    let artName: String
    let tint: Color
    var isPrimary = false
    var isTutorialEmphasis = false
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Image(artName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: isPrimary ? 62 : 56, height: isPrimary ? 70 : 64)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(isEnabled ? .white : .white.opacity(0.32))
                    .shadow(color: .black, radius: 2)
            }
            .frame(minWidth: 76)
        }
        .buttonStyle(RunePressStyle())
        .tutorialButtonEmphasis(isTutorialEmphasis, tint: tint)
        .accessibilityLabel(title)
    }
}

private enum MapEmblemKind {
    case quest
    case talk
    case route
    case dismiss
    case enter
}

private struct MapEmblemView: View {
    let kind: MapEmblemKind
    let tint: Color
    let isEnabled: Bool

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.39
            let strength = isEnabled ? 1.0 : 0.28

            for index in 0..<10 {
                let angle = CGFloat(index) * .pi / 5
                var tooth = Path(roundedRect: CGRect(x: -3, y: -6, width: 6, height: 12), cornerRadius: 1)
                let transform = CGAffineTransform(translationX: center.x, y: center.y)
                    .rotated(by: angle)
                    .translatedBy(x: 0, y: -radius - 4)
                tooth = tooth.applying(transform)
                context.fill(tooth, with: .color(Color(red: 0.53, green: 0.37, blue: 0.14).opacity(strength)))
            }

            let outer = Path(ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            context.fill(
                outer,
                with: .radialGradient(
                    Gradient(colors: [tint.opacity(0.80 * strength), .black.opacity(0.96)]),
                    center: center,
                    startRadius: 2,
                    endRadius: radius
                )
            )
            context.stroke(outer, with: .color(Color(red: 0.78, green: 0.58, blue: 0.22).opacity(strength)), lineWidth: 2)

            let innerRadius = radius * 0.76
            let inner = Path(ellipseIn: CGRect(
                x: center.x - innerRadius,
                y: center.y - innerRadius,
                width: innerRadius * 2,
                height: innerRadius * 2
            ))
            context.stroke(inner, with: .color(.white.opacity(0.16 * strength)), lineWidth: 1)
            drawSymbol(in: &context, center: center, radius: radius * 0.62, strength: strength)
        }
        .accessibilityHidden(true)
    }

    private func drawSymbol(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        strength: Double
    ) {
        let ivory = Color(red: 0.95, green: 0.88, blue: 0.70).opacity(strength)
        let brass = Color(red: 0.93, green: 0.68, blue: 0.22).opacity(strength)
        switch kind {
        case .quest:
            let scroll = Path(roundedRect: CGRect(
                x: center.x - radius * 0.58,
                y: center.y - radius * 0.62,
                width: radius * 1.02,
                height: radius * 1.18
            ), cornerRadius: 3)
            context.fill(scroll, with: .color(ivory))
            context.stroke(scroll, with: .color(brass), lineWidth: 1.4)
            var lineOne = Path()
            lineOne.move(to: CGPoint(x: center.x - radius * 0.33, y: center.y - radius * 0.22))
            lineOne.addLine(to: CGPoint(x: center.x + radius * 0.22, y: center.y - radius * 0.22))
            lineOne.move(to: CGPoint(x: center.x - radius * 0.33, y: center.y + radius * 0.04))
            lineOne.addLine(to: CGPoint(x: center.x + radius * 0.08, y: center.y + radius * 0.04))
            context.stroke(lineOne, with: .color(.black.opacity(0.58 * strength)), lineWidth: 1.5)
            let seal = Path(ellipseIn: CGRect(x: center.x + radius * 0.10, y: center.y + radius * 0.10, width: radius * 0.50, height: radius * 0.50))
            context.fill(seal, with: .color(tint.opacity(0.95 * strength)))

        case .talk:
            let leftMask = Path(ellipseIn: CGRect(x: center.x - radius * 0.78, y: center.y - radius * 0.48, width: radius, height: radius * 1.08))
            let rightMask = Path(ellipseIn: CGRect(x: center.x - radius * 0.14, y: center.y - radius * 0.48, width: radius, height: radius * 1.08))
            context.fill(leftMask, with: .color(ivory))
            context.fill(rightMask, with: .color(tint.opacity(0.92 * strength)))
            let eyeSize = radius * 0.20
            for eyeCenter in [
                CGPoint(x: center.x - radius * 0.42, y: center.y - radius * 0.08),
                CGPoint(x: center.x + radius * 0.36, y: center.y - radius * 0.08)
            ] {
                context.fill(Path(ellipseIn: CGRect(x: eyeCenter.x - eyeSize / 2, y: eyeCenter.y - eyeSize / 2, width: eyeSize, height: eyeSize * 0.62)), with: .color(.black.opacity(0.78 * strength)))
            }

        case .route:
            var compass = Path()
            compass.move(to: CGPoint(x: center.x, y: center.y - radius))
            compass.addLine(to: CGPoint(x: center.x + radius * 0.30, y: center.y - radius * 0.12))
            compass.addLine(to: CGPoint(x: center.x + radius, y: center.y))
            compass.addLine(to: CGPoint(x: center.x + radius * 0.24, y: center.y + radius * 0.18))
            compass.addLine(to: CGPoint(x: center.x, y: center.y + radius))
            compass.addLine(to: CGPoint(x: center.x - radius * 0.26, y: center.y + radius * 0.14))
            compass.addLine(to: CGPoint(x: center.x - radius, y: center.y))
            compass.addLine(to: CGPoint(x: center.x - radius * 0.24, y: center.y - radius * 0.16))
            compass.closeSubpath()
            context.fill(compass, with: .color(brass))
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius * 0.18, y: center.y - radius * 0.18, width: radius * 0.36, height: radius * 0.36)), with: .color(tint.opacity(strength)))

        case .dismiss:
            var curtain = Path()
            curtain.move(to: CGPoint(x: center.x - radius * 0.72, y: center.y - radius * 0.72))
            curtain.addCurve(to: CGPoint(x: center.x, y: center.y + radius * 0.24), control1: CGPoint(x: center.x - radius * 0.62, y: center.y), control2: CGPoint(x: center.x - radius * 0.18, y: center.y + radius * 0.28))
            curtain.addCurve(to: CGPoint(x: center.x + radius * 0.72, y: center.y - radius * 0.72), control1: CGPoint(x: center.x + radius * 0.18, y: center.y + radius * 0.28), control2: CGPoint(x: center.x + radius * 0.62, y: center.y))
            curtain.closeSubpath()
            context.fill(curtain, with: .color(tint.opacity(0.92 * strength)))
            var chevron = Path()
            chevron.move(to: CGPoint(x: center.x - radius * 0.42, y: center.y + radius * 0.18))
            chevron.addLine(to: CGPoint(x: center.x, y: center.y + radius * 0.60))
            chevron.addLine(to: CGPoint(x: center.x + radius * 0.42, y: center.y + radius * 0.18))
            context.stroke(chevron, with: .color(brass), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

        case .enter:
            var arch = Path()
            arch.move(to: CGPoint(x: center.x - radius * 0.62, y: center.y + radius * 0.72))
            arch.addLine(to: CGPoint(x: center.x - radius * 0.62, y: center.y - radius * 0.12))
            arch.addCurve(to: CGPoint(x: center.x + radius * 0.62, y: center.y - radius * 0.12), control1: CGPoint(x: center.x - radius * 0.48, y: center.y - radius), control2: CGPoint(x: center.x + radius * 0.48, y: center.y - radius))
            arch.addLine(to: CGPoint(x: center.x + radius * 0.62, y: center.y + radius * 0.72))
            arch.closeSubpath()
            context.fill(arch, with: .color(brass))
            let doorway = Path(roundedRect: CGRect(x: center.x - radius * 0.34, y: center.y - radius * 0.20, width: radius * 0.68, height: radius * 0.88), cornerRadius: radius * 0.22)
            context.fill(doorway, with: .color(.black.opacity(0.88 * strength)))
            context.fill(Path(ellipseIn: CGRect(x: center.x + radius * 0.10, y: center.y + radius * 0.18, width: 3, height: 3)), with: .color(ivory))
        }
    }
}

private struct RunePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
    }
}

private struct DistrictMiniMap: View {
    let definition: DistrictMapDefinition
    let playerPosition: CGPoint
    let objectivePosition: CGPoint

    var body: some View {
        GeometryReader { geometry in
            let scaleX = geometry.size.width / definition.worldSize.width
            let scaleY = geometry.size.height / definition.worldSize.height
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.78)
                ForEach(definition.areas) { area in
                    Rectangle()
                        .fill(Color(uiColor: area.tint).opacity(0.20))
                        .frame(width: area.rect.width * scaleX, height: area.rect.height * scaleY)
                        .position(
                            x: area.rect.midX * scaleX,
                            y: geometry.size.height - area.rect.midY * scaleY
                        )
                }
                DiamondShape()
                    .fill(.yellow)
                    .frame(width: 8, height: 8)
                    .position(
                        x: objectivePosition.x * scaleX,
                        y: geometry.size.height - objectivePosition.y * scaleY
                    )
                Circle()
                    .fill(.cyan)
                    .frame(width: 9, height: 9)
                    .overlay { Circle().stroke(.white, lineWidth: 1) }
                    .position(
                        x: playerPosition.x * scaleX,
                        y: geometry.size.height - playerPosition.y * scaleY
                    )
            }
            .clipShape(OctagonShape())
            .overlay { OctagonShape().stroke(.cyan.opacity(0.48), lineWidth: 1.2) }
        }
        .accessibilityLabel("区域小地图")
    }
}

private struct CutCornerShape: Shape {
    let cut: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        path.closeSubpath()
        return path
    }
}

private struct HexagonShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let side = insetRect.width * 0.24
        var path = Path()
        path.move(to: CGPoint(x: insetRect.minX + side, y: insetRect.minY))
        path.addLine(to: CGPoint(x: insetRect.maxX - side, y: insetRect.minY))
        path.addLine(to: CGPoint(x: insetRect.maxX, y: insetRect.midY))
        path.addLine(to: CGPoint(x: insetRect.maxX - side, y: insetRect.maxY))
        path.addLine(to: CGPoint(x: insetRect.minX + side, y: insetRect.maxY))
        path.addLine(to: CGPoint(x: insetRect.minX, y: insetRect.midY))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> HexagonShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

private struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct OctagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        CutCornerShape(cut: min(rect.width, rect.height) * 0.18).path(in: rect)
    }
}

private struct DialogueTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#if DEBUG
#Preview {
    DistrictMapView(
        path: GameContent.pathways[0],
        mission: GameContent.chapterOneDistricts[0].missions[0],
        onExit: {},
        onMissionBoard: {},
        onBeginMission: {},
        onEnterVenue: { _ in }
    )
}
#endif
