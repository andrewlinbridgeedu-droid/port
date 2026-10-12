import AVFoundation
import ImageIO
import UniformTypeIdentifiers
// extract_range <video> <outdir> <start> <end> <fps> <x> <y> <w> <h> <startIndex>
let a = CommandLine.arguments
let asset = AVURLAsset(url: URL(fileURLWithPath: a[1]))
let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = .zero; gen.requestedTimeToleranceAfter = .zero
let t0 = Double(a[3])!, t1 = Double(a[4])!, fps = Double(a[5])!
let crop = CGRect(x: Double(a[6])!, y: Double(a[7])!, width: Double(a[8])!, height: Double(a[9])!)
var i = Int(a[10])!
var t = t0
while t <= t1 {
    if let img = try? gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil), let c = img.cropping(to: crop) {
        let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: String(format: "%@/r%05d.png", a[2], i)) as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(d, c, nil); CGImageDestinationFinalize(d)
    }
    i += 1; t += 1.0 / fps
}
print(i)
