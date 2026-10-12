import AVFoundation
import ImageIO
import UniformTypeIdentifiers
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let outDir = CommandLine.arguments[2]
let asset = AVURLAsset(url: url)
let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero
let dur = CMTimeGetSeconds(asset.duration)
print("duration", dur)
var t = 0.0
var i = 0
while t < dur {
    if let img = try? gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil) {
        let p = String(format: "%@/f%03d.png", outDir, i)
        let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: p) as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
    }
    t += 0.5; i += 1
}
