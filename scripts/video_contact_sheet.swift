// Contact sheet from a screen recording: evenly spaced frames between two
// times, optionally cropped, each labelled with its time. Used to review spell
// timing and body motion in Simulator recordings (xcrun simctl io recordVideo).
//
//   swiftc -O scripts/video_contact_sheet.swift -o /tmp/video_contact_sheet
//   /tmp/video_contact_sheet <video> <out.png> <start> <end> <count> [cols] [scale] [crop]
//   /tmp/video_contact_sheet <video> info            # prints the duration
//
// crop is either "x,y,w,h" in source pixels, or two fractions "top bottom"
// passed as separate arguments to trim the top and bottom of every frame.
import AVFoundation
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let a = CommandLine.arguments
let asset = AVURLAsset(url: URL(fileURLWithPath: a[1]))
if a[2] == "info" { print(String(format: "duration %.2f", asset.duration.seconds)); exit(0) }
let start = Double(a[3])!, end = Double(a[4])!, count = Int(a[5])!
let cols = a.count > 6 ? Int(a[6])! : 4
let scale = a.count > 7 ? Double(a[7])! : 0.25
// Either two fractions (cropTop cropBottom) or one pixel rect "x,y,w,h".
let rect: CGRect? = a.count > 8 && a[8].contains(",") ? {
    let v = a[8].split(separator: ",").map { Double($0)! }; return CGRect(x: v[0], y: v[1], width: v[2], height: v[3]) }() : nil
let cropTop = rect == nil && a.count > 8 ? Double(a[8])! : 0.0
let cropBottom = rect == nil && a.count > 9 ? Double(a[9])! : 0.0
let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero
var frames: [(Double, CGImage)] = []
for i in 0..<count {
    let t = count == 1 ? start : start + (end - start) * Double(i) / Double(count - 1)
    if let img = try? gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil) {
        let h = Double(img.height), top = Int(h * cropTop), keep = Int(h * (1 - cropTop - cropBottom))
        let cropped = img.cropping(to: rect ?? CGRect(x: 0, y: top, width: img.width, height: keep)) ?? img
        frames.append((t, cropped))
    }
}
guard let first = frames.first?.1 else { print("no frames"); exit(1) }
let w = Int(Double(first.width) * scale), h = Int(Double(first.height) * scale)
let rows = (frames.count + cols - 1) / cols, label = 22
let ctx = CGContext(data: nil, width: w * cols, height: (h + label) * rows, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.setFillColor(CGColor(gray: 0.1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w * cols, height: (h + label) * rows))
ctx.interpolationQuality = .high
let font = CTFontCreateWithName("Menlo-Bold" as CFString, 16, nil)
for (i, (t, img)) in frames.enumerated() {
    let col = i % cols, row = i / cols
    let y = (h + label) * (rows - 1 - row)
    ctx.draw(img, in: CGRect(x: col * w, y: y, width: w, height: h))
    let text = NSAttributedString(string: String(format: "%.2fs", t),
        attributes: [kCTFontAttributeName as NSAttributedString.Key: font,
                     kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(red: 1, green: 0.9, blue: 0.5, alpha: 1)])
    ctx.textPosition = CGPoint(x: col * w + 6, y: y + h + 4)
    CTLineDraw(CTLineCreateWithAttributedString(text), ctx)
}
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: a[2]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
print("wrote \(frames.count) frames \(w)x\(h) -> \(a[2])")
