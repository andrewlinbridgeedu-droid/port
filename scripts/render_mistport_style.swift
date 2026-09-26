import AppKit
import Foundation

// Render a deterministic, review-only portrait style board from Mistport's
// current runtime art. This is deliberately kept outside the App target: it
// lets art direction be approved before the same composition is authored as a
// Unity prefab/VFX graph.

let canvasWidth: CGFloat = 946
let canvasHeight: CGFloat = 2048
let outputDirectory = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "/Users/andrewlin/Downloads/DEV_Projects/mindstone-game/output/mistport-style"

let projectRoot = "/Users/andrewlin/Downloads/DEV_Projects/mindstone-game"
let backgroundPath = projectRoot + "/output/imagegen/old-clock-district/gear-works-v1.png"
let houndIdlePath = projectRoot + "/mistport-ios/Mistport/Assets.xcassets/ClockHoundLostSecondIdleV301.imageset/ClockHoundLostSecondIdleV301.png"
let houndAttackPath = projectRoot + "/mistport-ios/Mistport/Assets.xcassets/ClockHoundSouthAttackV506.imageset/ClockHoundSouthAttackV506.png"
let foolPath = projectRoot + "/mistport-ios/Mistport/Assets.xcassets/FoolCombatTopDownV3.imageset/fool-combat-topdown-v3.png"

func loadImage(_ path: String) -> NSImage {
    guard let image = NSImage(contentsOfFile: path) else {
        fatalError("Unable to load image: \(path)")
    }
    return image
}

let background = loadImage(backgroundPath)
let houndIdle = loadImage(houndIdlePath)
let houndAttack = loadImage(houndAttackPath)
let fool = loadImage(foolPath)

try FileManager.default.createDirectory(
    at: URL(fileURLWithPath: outputDirectory, isDirectory: true),
    withIntermediateDirectories: true
)

let ink = NSColor(calibratedRed: 0.025, green: 0.035, blue: 0.060, alpha: 0.94)
let panel = NSColor(calibratedRed: 0.018, green: 0.023, blue: 0.043, alpha: 0.88)
let brass = NSColor(calibratedRed: 0.83, green: 0.58, blue: 0.24, alpha: 1)
let brassSoft = NSColor(calibratedRed: 0.90, green: 0.72, blue: 0.42, alpha: 1)
let paper = NSColor(calibratedRed: 0.94, green: 0.92, blue: 0.84, alpha: 1)
let blue = NSColor(calibratedRed: 0.22, green: 0.74, blue: 0.94, alpha: 1)
let violet = NSColor(calibratedRed: 0.66, green: 0.24, blue: 0.98, alpha: 1)
let signalRed = NSColor(calibratedRed: 0.96, green: 0.18, blue: 0.16, alpha: 1)
let ember = NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.18, alpha: 1)

func topRect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
    NSRect(x: x, y: canvasHeight - y - height, width: width, height: height)
}

func topPoint(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
    NSPoint(x: x, y: canvasHeight - y)
}

func color(_ source: NSColor, alpha: CGFloat) -> NSColor {
    source.withAlphaComponent(alpha)
}

func font(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
    NSFont(name: weight == .bold ? "PingFangSC-Semibold" : "PingFangSC-Regular", size: size)
        ?? NSFont.systemFont(ofSize: size, weight: weight)
}

func drawText(
    _ text: String,
    x: CGFloat,
    y: CGFloat,
    size: CGFloat,
    color textColor: NSColor = paper,
    weight: NSFont.Weight = .regular,
    alignment: NSTextAlignment = .left
) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font(size, weight: weight),
        .foregroundColor: textColor
    ]
    let measured = (text as NSString).size(withAttributes: attributes)
    let drawX: CGFloat
    switch alignment {
    case .center:
        drawX = x - measured.width / 2
    case .right:
        drawX = x - measured.width
    default:
        drawX = x
    }
    (text as NSString).draw(
        at: NSPoint(x: drawX, y: canvasHeight - y - measured.height),
        withAttributes: attributes
    )
}

func drawImage(_ image: NSImage, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, alpha: CGFloat = 1) {
    image.draw(
        in: topRect(x, y, width, height),
        from: NSRect(origin: .zero, size: image.size),
        operation: .sourceOver,
        fraction: alpha,
        respectFlipped: false,
        hints: nil
    )
}

func roundedPanel(_ rect: NSRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil, lineWidth: CGFloat = 1) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
}

func fillEllipse(_ rect: NSRect, _ fill: NSColor) {
    fill.setFill()
    NSBezierPath(ovalIn: rect).fill()
}

func strokeEllipse(_ rect: NSRect, _ stroke: NSColor, width: CGFloat) {
    stroke.setStroke()
    let path = NSBezierPath(ovalIn: rect)
    path.lineWidth = width
    path.stroke()
}

func line(_ start: NSPoint, _ end: NSPoint, _ stroke: NSColor, width: CGFloat) {
    stroke.setStroke()
    let path = NSBezierPath()
    path.move(to: start)
    path.line(to: end)
    path.lineWidth = width
    path.lineCapStyle = .round
    path.stroke()
}

func diamond(center: NSPoint, radius: CGFloat, fill: NSColor? = nil, stroke: NSColor? = nil, width: CGFloat = 1) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: center.x, y: center.y + radius))
    path.line(to: NSPoint(x: center.x + radius, y: center.y))
    path.line(to: NSPoint(x: center.x, y: center.y - radius))
    path.line(to: NSPoint(x: center.x - radius, y: center.y))
    path.close()
    if let fill {
        fill.setFill()
        path.fill()
    }
    if let stroke {
        stroke.setStroke()
        path.lineWidth = width
        path.stroke()
    }
}

func makeCanvas() -> (NSBitmapImageRep, NSGraphicsContext) {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasWidth),
        pixelsHigh: Int(canvasHeight),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Unable to create bitmap")
    }
    guard let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Unable to create graphics context")
    }
    return (bitmap, graphics)
}

func save(_ bitmap: NSBitmapImageRep, as fileName: String) throws {
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Unable to encode PNG")
    }
    try data.write(to: URL(fileURLWithPath: outputDirectory).appendingPathComponent(fileName))
}

func drawBackground() {
    let scale = max(canvasWidth / background.size.width, canvasHeight / background.size.height)
    let width = background.size.width * scale
    let height = background.size.height * scale
    background.draw(
        in: NSRect(x: (canvasWidth - width) / 2, y: (canvasHeight - height) / 2, width: width, height: height),
        from: NSRect(origin: .zero, size: background.size),
        operation: .copy,
        fraction: 1,
        respectFlipped: false,
        hints: nil
    )

    // Push the background toward Mistport's ink-blue night while keeping the
    // warm lamps available as a contrast anchor for the spell.
    NSColor(calibratedRed: 0.01, green: 0.025, blue: 0.08, alpha: 0.27).setFill()
    NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight).fill()
    NSColor(calibratedWhite: 0, alpha: 0.16).setFill()
    NSRect(x: 0, y: 0, width: canvasWidth, height: 300).fill()
    NSColor(calibratedWhite: 0, alpha: 0.18).setFill()
    NSRect(x: 0, y: canvasHeight - 460, width: canvasWidth, height: 460).fill()

    // Rain is part of the Old Clock district identity, but remains a quiet
    // layer so the combat read belongs to the actor and spell.
    for index in 0..<56 {
        let seed = CGFloat((index * 37) % 113) / 113
        let x = 24 + seed * (canvasWidth - 48)
        let y = CGFloat((index * 97) % 1640) + 88
        line(
            topPoint(x, y),
            topPoint(x - 5, y + 28 + CGFloat(index % 4) * 8),
            NSColor(calibratedRed: 0.64, green: 0.78, blue: 0.88, alpha: 0.18),
            width: index % 5 == 0 ? 2 : 1
        )
    }
}

func drawStatusBar() {
    NSColor(calibratedWhite: 0, alpha: 0.44).setFill()
    NSRect(x: 0, y: canvasHeight - 58, width: canvasWidth, height: 58).fill()
    drawText("9:41", x: 54, y: 24, size: 24, color: paper, weight: .bold)
    roundedPanel(topRect(393, 16, 160, 32), radius: 17, fill: NSColor.black)
    drawText("•••", x: 822, y: 22, size: 20, color: paper, weight: .bold)
    drawText("▰", x: 880, y: 23, size: 17, color: paper)
}

func drawHeader(phase: String, phaseColor: NSColor) {
    let header = topRect(28, 78, canvasWidth - 56, 132)
    roundedPanel(header, radius: 32, fill: color(panel, alpha: 0.90), stroke: color(brassSoft, alpha: 0.34), lineWidth: 1)
    strokeEllipse(topRect(60, 103, 74, 74), color(brassSoft, alpha: 0.58), width: 2)
    strokeEllipse(topRect(70, 113, 54, 54), color(violet, alpha: 0.56), width: 2)
    line(topPoint(97, 126), topPoint(97, 146), brassSoft, width: 2)
    line(topPoint(97, 146), topPoint(111, 155), brassSoft, width: 2)
    drawText("旧钟区", x: 158, y: 99, size: 30, color: paper, weight: .bold)
    drawText("失秒巡猎犬 · 逆潮咬合", x: 158, y: 140, size: 18, color: color(paper, alpha: 0.70))
    drawText(phase, x: 866, y: 114, size: 20, color: phaseColor, weight: .bold, alignment: .right)
    drawText("TURN 04", x: 866, y: 149, size: 14, color: color(brassSoft, alpha: 0.76), alignment: .right)
}

func drawArena() {
    let arenaRect = topRect(106, 610, 734, 672)
    fillEllipse(arenaRect, NSColor(calibratedRed: 0.015, green: 0.025, blue: 0.055, alpha: 0.24))
    strokeEllipse(topRect(126, 636, 694, 620), color(blue, alpha: 0.18), width: 2)
    strokeEllipse(topRect(156, 674, 634, 544), color(brassSoft, alpha: 0.19), width: 1)
    strokeEllipse(topRect(215, 752, 516, 386), color(violet, alpha: 0.12), width: 2)
    line(topPoint(160, 970), topPoint(786, 970), color(brassSoft, alpha: 0.13), width: 1)
    line(topPoint(473, 694), topPoint(473, 1245), color(brassSoft, alpha: 0.10), width: 1)
}

func drawGroundSeal(centerX: CGFloat, topY: CGFloat, radius: CGFloat, tint: NSColor, alpha: CGFloat, broken: Bool = false) {
    let outer = topRect(centerX - radius, topY - radius * 0.28, radius * 2, radius * 0.56)
    fillEllipse(topRect(centerX - radius * 0.88, topY - radius * 0.20, radius * 1.76, radius * 0.40), color(tint, alpha: alpha * 0.16))
    strokeEllipse(outer, color(tint, alpha: alpha * 0.44), width: 3)
    if broken {
        line(topPoint(centerX - radius * 0.52, topY), topPoint(centerX - radius * 0.12, topY - 3), color(paper, alpha: alpha * 0.72), width: 3)
        line(topPoint(centerX + radius * 0.12, topY + 3), topPoint(centerX + radius * 0.55, topY), color(paper, alpha: alpha * 0.42), width: 3)
    }
}

func drawClockSigil(center: NSPoint, radius: CGFloat, tint: NSColor, alpha: CGFloat, rotation: CGFloat = 0, broken: Bool = false) {
    fillEllipse(
        NSRect(x: center.x - radius * 1.15, y: center.y - radius * 1.15, width: radius * 2.3, height: radius * 2.3),
        color(tint, alpha: alpha * 0.07)
    )
    strokeEllipse(
        NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2),
        color(tint, alpha: alpha * 0.72),
        width: 4
    )
    strokeEllipse(
        NSRect(x: center.x - radius * 0.73, y: center.y - radius * 0.73, width: radius * 1.46, height: radius * 1.46),
        color(brassSoft, alpha: alpha * 0.58),
        width: 2
    )
    for index in 0..<12 {
        if broken && index == 5 { continue }
        let angle = rotation + CGFloat(index) * .pi / 6
        let inner = radius * 0.84
        let outer = radius * 1.16
        let start = NSPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner)
        let end = NSPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer)
        line(start, end, color(tint, alpha: alpha * 0.78), width: index % 3 == 0 ? 6 : 3)
    }
    diamond(center: center, radius: radius * 0.28, fill: color(tint, alpha: alpha * 0.78), stroke: paper, width: 1)
    line(
        NSPoint(x: center.x, y: center.y + radius * 0.12),
        NSPoint(x: center.x + cos(rotation - .pi / 3) * radius * 0.52, y: center.y + sin(rotation - .pi / 3) * radius * 0.52),
        paper,
        width: 3
    )
    line(
        NSPoint(x: center.x, y: center.y),
        NSPoint(x: center.x + cos(rotation + .pi / 2) * radius * 0.64, y: center.y + sin(rotation + .pi / 2) * radius * 0.64),
        brassSoft,
        width: 2
    )
}

func drawParticles(center: NSPoint, radius: CGFloat, tint: NSColor, count: Int, alpha: CGFloat, phase: Int) {
    for index in 0..<count {
        let seedA = CGFloat((index * 47 + phase * 19) % 127) / 127
        let seedB = CGFloat((index * 71 + phase * 11) % 131) / 131
        let angle = seedA * CGFloat.pi * 2
        let distance = radius * (0.35 + seedB * 0.85)
        let point = NSPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)
        let size = 2 + CGFloat(index % 4) * 1.4
        if index % 3 == 0 {
            diamond(center: point, radius: size, fill: color(tint, alpha: alpha * 0.82), stroke: color(paper, alpha: alpha * 0.35), width: 1)
        } else {
            line(
                NSPoint(x: point.x - size * 1.8, y: point.y - size * 0.5),
                NSPoint(x: point.x + size * 1.8, y: point.y + size * 0.5),
                color(tint, alpha: alpha * 0.72),
                width: index % 2 == 0 ? 2 : 1
            )
        }
    }
}

func crescentPath(center: NSPoint, scale: CGFloat, offset: CGFloat = 0) -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: center.x - 360 * scale, y: center.y - 136 * scale + offset))
    path.curve(
        to: NSPoint(x: center.x + 362 * scale, y: center.y + 122 * scale + offset),
        controlPoint1: NSPoint(x: center.x - 148 * scale, y: center.y + 42 * scale + offset),
        controlPoint2: NSPoint(x: center.x + 132 * scale, y: center.y + 222 * scale + offset)
    )
    path.curve(
        to: NSPoint(x: center.x + 305 * scale, y: center.y + 50 * scale + offset),
        controlPoint1: NSPoint(x: center.x + 328 * scale, y: center.y + 122 * scale + offset),
        controlPoint2: NSPoint(x: center.x + 320 * scale, y: center.y + 82 * scale + offset)
    )
    path.curve(
        to: NSPoint(x: center.x - 344 * scale, y: center.y - 183 * scale + offset),
        controlPoint1: NSPoint(x: center.x + 74 * scale, y: center.y - 22 * scale + offset),
        controlPoint2: NSPoint(x: center.x - 120 * scale, y: center.y - 126 * scale + offset)
    )
    path.close()
    return path
}

func drawCrescentImpact(center: NSPoint, intensity: CGFloat) {
    let layers: [(NSColor, CGFloat, CGFloat)] = [
        (signalRed, 84, 0.14),
        (ember, 48, 0.32),
        (brassSoft, 22, 0.68),
        (paper, 7, 0.96)
    ]
    for (tint, width, alpha) in layers {
        // Keep the body translucent so the actor and its hit reaction remain
        // legible. The readable silhouette comes from stacked directional
        // strokes, not from a full opaque polygon.
        tint.withAlphaComponent(alpha * intensity).setStroke()
        let stroke = crescentPath(center: center, scale: 0.95 * intensity)
        stroke.lineWidth = CGFloat(width)
        stroke.lineCapStyle = .round
        stroke.stroke()
    }
    fillEllipse(
        NSRect(x: center.x - 82 * intensity, y: center.y - 82 * intensity, width: 164 * intensity, height: 164 * intensity),
        color(paper, alpha: 0.62 * intensity)
    )
    fillEllipse(
        NSRect(x: center.x - 48 * intensity, y: center.y - 48 * intensity, width: 96 * intensity, height: 96 * intensity),
        color(ember, alpha: 0.94 * intensity)
    )
    drawParticles(center: center, radius: 300 * intensity, tint: ember, count: 32, alpha: 0.92 * intensity, phase: 4)
    drawParticles(center: center, radius: 420 * intensity, tint: blue, count: 20, alpha: 0.72 * intensity, phase: 8)
}

func drawChargeAttack(enemyCenter: NSPoint, playerCenter: NSPoint) {
    // Three offset arcs establish a moving spell body; the center remains
    // readable instead of becoming a flat beam.
    for index in 0..<3 {
        let path = NSBezierPath()
        let yOffset = CGFloat(index - 1) * 22
        path.move(to: NSPoint(x: enemyCenter.x - 40, y: enemyCenter.y - 40 + yOffset))
        path.curve(
            to: NSPoint(x: playerCenter.x + 18, y: playerCenter.y + 18 + yOffset),
            controlPoint1: NSPoint(x: enemyCenter.x + 86, y: enemyCenter.y + 180 + yOffset),
            controlPoint2: NSPoint(x: playerCenter.x - 156, y: playerCenter.y - 182 + yOffset)
        )
        path.lineWidth = index == 1 ? 10 : 4
        path.lineCapStyle = .round
        (index == 1 ? blue : violet).withAlphaComponent(index == 1 ? 0.66 : 0.36).setStroke()
        path.stroke()
    }
    drawParticles(center: NSPoint(x: (enemyCenter.x + playerCenter.x) / 2, y: (enemyCenter.y + playerCenter.y) / 2), radius: 260, tint: blue, count: 16, alpha: 0.68, phase: 2)
}

func drawBottomHUD(playerHealth: CGFloat, caption: String, captionColor: NSColor) {
    let hud = topRect(26, 1660, canvasWidth - 52, 356)
    roundedPanel(hud, radius: 34, fill: color(panel, alpha: 0.96), stroke: color(brassSoft, alpha: 0.46), lineWidth: 1.5)
    drawText("雾港仪式记录", x: 64, y: 1690, size: 16, color: color(brassSoft, alpha: 0.78), weight: .bold)
    drawText("愚者 · 序列 9", x: 64, y: 1720, size: 24, color: paper, weight: .bold)
    let hpBackground = topRect(64, 1773, 580, 18)
    roundedPanel(hpBackground, radius: 9, fill: NSColor(calibratedWhite: 1, alpha: 0.12))
    let hpWidth = 580 * max(0, min(playerHealth, 1))
    roundedPanel(topRect(64, 1773, hpWidth, 18), radius: 9, fill: playerHealth > 0.45 ? ember : signalRed)
    drawText("HP", x: 662, y: 1768, size: 14, color: color(paper, alpha: 0.68), weight: .bold)
    drawText("\(Int(playerHealth * 100))", x: 744, y: 1760, size: 30, color: paper, weight: .bold, alignment: .right)

    roundedPanel(topRect(64, 1833, 202, 118), radius: 22, fill: color(violet, alpha: 0.22), stroke: color(violet, alpha: 0.68), lineWidth: 1.5)
    drawText("✦", x: 114, y: 1850, size: 34, color: brassSoft, weight: .bold)
    drawText("假面低语", x: 160, y: 1850, size: 20, color: paper, weight: .bold)
    drawText("技能 01", x: 160, y: 1883, size: 14, color: color(paper, alpha: 0.62))

    roundedPanel(topRect(290, 1833, 202, 118), radius: 22, fill: color(blue, alpha: 0.13), stroke: color(blue, alpha: 0.48), lineWidth: 1.5)
    drawText("◇", x: 340, y: 1850, size: 34, color: blue, weight: .bold)
    drawText("错步穿幕", x: 386, y: 1850, size: 20, color: paper, weight: .bold)
    drawText("技能 02", x: 386, y: 1883, size: 14, color: color(paper, alpha: 0.62))

    roundedPanel(topRect(716, 1816, 164, 144), radius: 72, fill: color(signalRed, alpha: 0.92), stroke: color(ember, alpha: 0.86), lineWidth: 3)
    drawText("✦", x: 798, y: 1844, size: 46, color: paper, weight: .bold, alignment: .center)
    drawText("行动", x: 798, y: 1903, size: 16, color: paper, weight: .bold, alignment: .center)
    drawText(caption, x: 473, y: 1979, size: 16, color: captionColor, weight: .bold, alignment: .center)
}

func drawEnemyLabel() {
    drawText("失秒巡猎犬", x: 473, y: 442, size: 22, color: paper, weight: .bold, alignment: .center)
    drawText("CLOCK HOUND · LOST SECOND", x: 473, y: 474, size: 11, color: color(brassSoft, alpha: 0.72), weight: .bold, alignment: .center)
    roundedPanel(topRect(257, 510, 432, 12), radius: 6, fill: NSColor(calibratedWhite: 1, alpha: 0.14))
    roundedPanel(topRect(257, 510, 324, 12), radius: 6, fill: signalRed)
    drawText("78 / 100", x: 706, y: 500, size: 14, color: color(paper, alpha: 0.82), alignment: .right)
}

func drawFrame(_ phase: Int) throws -> NSBitmapImageRep {
    let (bitmap, graphics) = makeCanvas()
    NSGraphicsContext.current = graphics
    graphics.saveGraphicsState()
    NSColor.black.setFill()
    NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight).fill()
    drawBackground()
    drawStatusBar()
    let phaseText: String
    let phaseColor: NSColor
    switch phase {
    case 1:
        phaseText = "预警 · 0.34s"
        phaseColor = ember
    case 2:
        phaseText = "命中 · 0.56s"
        phaseColor = signalRed
    default:
        phaseText = "残留 · 0.92s"
        phaseColor = blue
    }
    drawHeader(phase: phaseText, phaseColor: phaseColor)
    drawArena()

    let enemyCenter = topPoint(473, 690)
    let playerCenter = topPoint(473, 1270)
    drawGroundSeal(centerX: 473, topY: 760, radius: 154, tint: phase == 2 ? signalRed : violet, alpha: phase == 3 ? 0.48 : 0.82, broken: phase == 3)
    drawGroundSeal(centerX: 473, topY: 1370, radius: 124, tint: phase == 2 ? ember : blue, alpha: phase == 3 ? 0.46 : 0.72, broken: phase == 3)

    if phase == 1 {
        drawImage(houndIdle, x: 318, y: 498, width: 310, height: 310)
        drawClockSigil(center: topPoint(473, 750), radius: 98, tint: violet, alpha: 0.92, rotation: -0.18)
        drawChargeAttack(enemyCenter: topPoint(473, 790), playerCenter: topPoint(473, 1260))
        drawImage(fool, x: 332, y: 1170, width: 282, height: 282)
        drawEnemyLabel()
        drawText("预警：逆潮咬合", x: 473, y: 1042, size: 24, color: ember, weight: .bold, alignment: .center)
        drawText("不要让第十三格闭合", x: 473, y: 1081, size: 16, color: color(paper, alpha: 0.72), alignment: .center)
        drawBottomHUD(playerHealth: 1, caption: "蓄力完成前可打断", captionColor: ember)
    } else if phase == 2 {
        drawImage(houndAttack, x: 300, y: 500, width: 346, height: 346)
        drawImage(fool, x: 328, y: 1166, width: 290, height: 290)
        drawClockSigil(center: topPoint(473, 760), radius: 92, tint: signalRed, alpha: 0.54, rotation: 0.42)
        drawCrescentImpact(center: topPoint(473, 1260), intensity: 1)
        drawText("-18", x: 626, y: 1163, size: 48, color: paper, weight: .bold, alignment: .center)
        drawText("受击硬直", x: 626, y: 1222, size: 15, color: color(ember, alpha: 0.90), weight: .bold, alignment: .center)
        drawEnemyLabel()
        drawText("接触帧 · 金属裂响", x: 473, y: 1016, size: 18, color: color(brassSoft, alpha: 0.86), weight: .bold, alignment: .center)
        drawBottomHUD(playerHealth: 0.82, caption: "伤害在亮核接触帧结算", captionColor: signalRed)
    } else {
        drawImage(houndIdle, x: 324, y: 510, width: 298, height: 298, alpha: 0.88)
        drawImage(fool, x: 334, y: 1184, width: 278, height: 278, alpha: 0.90)
        drawClockSigil(center: topPoint(473, 1264), radius: 78, tint: blue, alpha: 0.48, rotation: 0.80, broken: true)
        drawParticles(center: playerCenter, radius: 220, tint: blue, count: 24, alpha: 0.62, phase: 12)
        drawParticles(center: enemyCenter, radius: 168, tint: violet, count: 16, alpha: 0.50, phase: 15)
        let residue = NSBezierPath()
        residue.move(to: topPoint(188, 1226))
        residue.curve(to: topPoint(756, 1350), controlPoint1: topPoint(374, 1160), controlPoint2: topPoint(560, 1432))
        residue.lineWidth = 6
        residue.lineCapStyle = .round
        color(blue, alpha: 0.28).setStroke()
        residue.stroke()
        drawEnemyLabel()
        drawText("残留 0.92s", x: 473, y: 1008, size: 20, color: color(blue, alpha: 0.88), weight: .bold, alignment: .center)
        drawText("断续刻度正在回收 · 目标仍可读", x: 473, y: 1044, size: 16, color: color(paper, alpha: 0.70), alignment: .center)
        drawBottomHUD(playerHealth: 0.82, caption: "尾迹在下一行动前清理", captionColor: blue)
    }
    graphics.restoreGraphicsState()
    return bitmap
}

for phase in 1...3 {
    let bitmap = try drawFrame(phase)
    try save(bitmap, as: String(format: "reverse-tide-%02d.png", phase))
}

print("Rendered 3 Mistport style frames to \(outputDirectory)")
