import Foundation
import AVFoundation
import AppKit
let path = CommandLine.arguments[1]
let out = CommandLine.arguments[2]
let asset = AVURLAsset(url: URL(fileURLWithPath: path))
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
let duration = CMTimeGetSeconds(asset.duration)
print("duration=\(duration)")
let start = CommandLine.arguments.count > 3 ? Double(CommandLine.arguments[3])! : 0
let end = CommandLine.arguments.count > 4 ? min(duration, Double(CommandLine.arguments[4])!) : duration
for t in stride(from: start, to: end, by: 0.1) {
 do {
 let cg = try generator.copyCGImage(at: CMTime(seconds:t, preferredTimescale:600), actualTime:nil)
 let bitmap = NSBitmapImageRep(cgImage:cg)
 let data = bitmap.representation(using:.png, properties:[:])!
 try data.write(to: URL(fileURLWithPath:"\(out)/frame-\(Int((t * 10).rounded())).png"))
 } catch { print(error) }
}
