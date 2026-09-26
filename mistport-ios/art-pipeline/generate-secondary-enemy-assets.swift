import AppKit
import CoreGraphics
import ImageIO

let outputRoot = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "ArtSource/Enemies")
let runtimeRoot = CommandLine.arguments.count > 2
    ? URL(fileURLWithPath: CommandLine.arguments[2])
    : nil
let frameSize = CGSize(width: 256, height: 256)

struct EnemySpec {
    let id: String
    let primary: NSColor
    let accent: NSColor
    let family: String
}

let specs = [
    EnemySpec(id: "SaltCrystalDeacon", primary: NSColor(calibratedRed: 0.08, green: 0.24, blue: 0.29, alpha: 1), accent: NSColor(calibratedRed: 0.45, green: 0.92, blue: 0.98, alpha: 1), family: "salt-warehouse"),
    EnemySpec(id: "StageAfterimage", primary: NSColor(calibratedRed: 0.22, green: 0.04, blue: 0.34, alpha: 1), accent: NSColor(calibratedRed: 0.95, green: 0.30, blue: 0.98, alpha: 1), family: "mirror-theater"),
    EnemySpec(id: "DrownedMemoryGhost", primary: NSColor(calibratedRed: 0.03, green: 0.18, blue: 0.31, alpha: 1), accent: NSColor(calibratedRed: 0.32, green: 0.84, blue: 0.98, alpha: 1), family: "tide-gate"),
    EnemySpec(id: "FacelessAttendant", primary: NSColor(calibratedRed: 0.10, green: 0.09, blue: 0.19, alpha: 1), accent: NSColor(calibratedRed: 0.72, green: 0.64, blue: 0.98, alpha: 1), family: "mist-crown")
]

func point(_ x: CGFloat, _ y: CGFloat, frame: Int, cast: Bool) -> CGPoint {
    let sway = CGFloat(frame - 1) * 1.6 + (cast ? 3 : 0)
    return CGPoint(x: 128 + x + sway, y: 128 + y)
}

func drawPath(_ points: [CGPoint], fill: NSColor, stroke: NSColor, width: CGFloat = 3) {
    let path = NSBezierPath()
    guard let first = points.first else { return }
    path.move(to: first)
    for point in points.dropFirst() { path.line(to: point) }
    path.close()
    fill.setFill()
    path.fill()
    stroke.setStroke()
    path.lineWidth = width
    path.stroke()
}

func drawEllipse(_ rect: CGRect, fill: NSColor, stroke: NSColor, width: CGFloat = 2) {
    let path = NSBezierPath(ovalIn: rect)
    fill.setFill()
    path.fill()
    stroke.setStroke()
    path.lineWidth = width
    path.stroke()
}

func drawEnemy(_ spec: EnemySpec, frame: Int, cast: Bool) -> CGImage? {
    let image = NSImage(size: frameSize)
    image.lockFocus()
    NSColor.clear.setFill()
    NSBezierPath(rect: CGRect(origin: .zero, size: frameSize)).fill()

    let alpha = cast ? 0.94 : 0.84
    let body = spec.primary.withAlphaComponent(alpha)
    let edge = spec.accent.withAlphaComponent(0.92)

    if spec.id == "SaltCrystalDeacon" {
        for index in 0..<7 {
            let angle = CGFloat(index) / 7 * .pi * 2
            let radius: CGFloat = cast ? 76 : 68
            let x = cos(angle) * radius
            let y = 26 + sin(angle) * radius * 0.60
            drawPath([
                point(x, y + 16, frame: frame, cast: cast),
                point(x + 9, y, frame: frame, cast: cast),
                point(x, y - 16, frame: frame, cast: cast),
                point(x - 9, y, frame: frame, cast: cast)
            ], fill: edge.withAlphaComponent(cast ? 0.82 : 0.56), stroke: NSColor.white.withAlphaComponent(0.65), width: 1)
        }
        drawPath([point(-26, -64, frame: frame, cast: cast), point(-12, 40, frame: frame, cast: cast), point(12, 40, frame: frame, cast: cast), point(28, -64, frame: frame, cast: cast)], fill: body, stroke: edge)
        drawEllipse(CGRect(x: 113, y: 157, width: 30, height: 38), fill: NSColor(calibratedWhite: 0.92, alpha: 1), stroke: edge)
        if cast {
            drawEllipse(CGRect(x: 69, y: 70, width: 118, height: 54), fill: edge.withAlphaComponent(0.16), stroke: edge.withAlphaComponent(0.82), width: 2)
        }
    } else if spec.id == "StageAfterimage" {
        for offset in [-18.0, -7.0, 5.0] {
            let ghost = NSColor(calibratedRed: 0.38, green: 0.08, blue: 0.50, alpha: offset == 5 ? 0.78 : 0.30)
            drawPath([point(-23 + offset, -64, frame: frame, cast: cast), point(-10 + offset, 38, frame: frame, cast: cast), point(12 + offset, 38, frame: frame, cast: cast), point(25 + offset, -64, frame: frame, cast: cast)], fill: ghost, stroke: edge.withAlphaComponent(offset == 5 ? 0.92 : 0.35), width: 2)
        }
        drawEllipse(CGRect(x: 113, y: 157, width: 30, height: 38), fill: NSColor(calibratedRed: 0.12, green: 0.04, blue: 0.18, alpha: 0.96), stroke: edge)
        let line = NSBezierPath()
        line.move(to: point(-43, 0, frame: frame, cast: cast)); line.line(to: point(43, 0, frame: frame, cast: cast))
        edge.withAlphaComponent(cast ? 0.95 : 0.55).setStroke(); line.lineWidth = 3; line.stroke()
    } else if spec.id == "DrownedMemoryGhost" {
        drawEllipse(CGRect(x: 78, y: 70, width: 100, height: 100), fill: spec.accent.withAlphaComponent(0.12), stroke: edge, width: 3)
        drawPath([point(-25, -62, frame: frame, cast: cast), point(-11, 35, frame: frame, cast: cast), point(11, 35, frame: frame, cast: cast), point(26, -62, frame: frame, cast: cast)], fill: body.withAlphaComponent(0.72), stroke: edge.withAlphaComponent(0.72), width: 2)
        drawEllipse(CGRect(x: 113, y: 157, width: 30, height: 38), fill: edge.withAlphaComponent(0.48), stroke: edge)
        for index in 0..<5 {
            let x = CGFloat(index * 17 - 34)
            let y = CGFloat((index % 3) * 18 - 8)
            drawEllipse(CGRect(x: 128 + x - 3, y: 128 + y - 3, width: 6, height: 6), fill: NSColor.white.withAlphaComponent(0.72), stroke: .clear, width: 0)
        }
    } else {
        drawPath([point(-24, -64, frame: frame, cast: cast), point(-10, 40, frame: frame, cast: cast), point(10, 40, frame: frame, cast: cast), point(24, -64, frame: frame, cast: cast)], fill: body, stroke: edge)
        drawEllipse(CGRect(x: 113, y: 157, width: 30, height: 38), fill: NSColor(calibratedWhite: 0.93, alpha: 1), stroke: edge)
        for index in 0..<3 {
            let angle = CGFloat(index) / 3 * .pi * 2
            let x = cos(angle) * 64
            let y = 25 + sin(angle) * 72
            drawPath([point(x - 8, y + 12, frame: frame, cast: cast), point(x + 8, y + 12, frame: frame, cast: cast), point(x + 8, y - 12, frame: frame, cast: cast), point(x - 8, y - 12, frame: frame, cast: cast)], fill: NSColor(calibratedWhite: 0.92, alpha: 0.78), stroke: edge, width: 1)
        }
    }

    if cast {
        let flash = NSBezierPath(ovalIn: CGRect(x: 94, y: 82, width: 68, height: 28))
        edge.withAlphaComponent(0.14).setFill(); flash.fill()
    }
    image.unlockFocus()
    guard let rep = NSBitmapImageRep(data: image.tiffRepresentation ?? Data()) else { return nil }
    return rep.cgImage
}

func writePNG(_ image: CGImage, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { throw NSError(domain: "asset", code: 1) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "asset", code: 2) }
}

func writeJSON(_ object: Any, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url)
}

for spec in specs {
    for (action, cast) in [("Idle", false), ("Cast", true)] {
        for frame in 1...4 {
            let asset = "\(spec.id)\(action)V1\(String(format: "%02d", frame))"
            let url = outputRoot.appendingPathComponent(spec.family).appendingPathComponent(spec.id).appendingPathComponent(action.lowercased()).appendingPathComponent("\(asset).png")
            if let image = drawEnemy(spec, frame: frame, cast: cast) {
                try writePNG(image, to: url)
                if let runtimeRoot {
                    let imageset = runtimeRoot.appendingPathComponent("\(asset).imageset")
                    let runtimeFile = "\(asset).png"
                    try writePNG(image, to: imageset.appendingPathComponent(runtimeFile))
                    try writeJSON([
                        "images": [["filename": runtimeFile, "idiom": "universal", "scale": "1x"]],
                        "info": ["author": "xcode", "version": 1]
                    ], to: imageset.appendingPathComponent("Contents.json"))
                }
            }
        }
    }
    let manifestURL = outputRoot
        .appendingPathComponent(spec.family)
        .appendingPathComponent(spec.id)
        .appendingPathComponent("manifest.json")
    try writeJSON([
        "assetID": spec.id,
        "district": spec.family,
        "version": "v1",
        "canvas": ["width": 512, "height": 512],
        "anchor": "bottom-center",
        "actions": ["idle": 4, "cast": 4],
        "source": "deterministic CoreGraphics generator",
        "generator": "art-pipeline/generate-secondary-enemy-assets.swift",
        "commercialStatus": "project-original technical art; pending final illustration pass"
    ], to: manifestURL)
}
