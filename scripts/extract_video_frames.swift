import AppKit
import AVFoundation
import Foundation

guard CommandLine.arguments.count >= 4 else {
    fputs("usage: extract_video_frames <video> <output-dir> <frame-count>\n", stderr)
    exit(2)
}

let videoURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let frameCount = max(2, Int(CommandLine.arguments[3]) ?? 12)

try FileManager.default.createDirectory(
    at: outputURL,
    withIntermediateDirectories: true
)

let asset = AVURLAsset(url: videoURL)
let duration = CMTimeGetSeconds(asset.duration)
guard duration.isFinite, duration > 0 else {
    fputs("invalid video duration\n", stderr)
    exit(3)
}

let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero

for index in 0..<frameCount {
    let fraction = Double(index) / Double(frameCount - 1)
    let seconds = min(duration - 0.001, duration * fraction)
    let time = CMTime(seconds: seconds, preferredTimescale: 600)
    let image = try generator.copyCGImage(at: time, actualTime: nil)
    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let data = bitmap.representation(
        using: .jpeg,
        properties: [.compressionFactor: 0.9]
    ) else {
        continue
    }
    let filename = String(format: "frame-%02d-%.3f.jpg", index, seconds)
    try data.write(to: outputURL.appendingPathComponent(filename))
}

print(String(format: "extracted %d frames from %.3f seconds", frameCount, duration))
