import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
// peaks <outdir> <offset-seconds> <video>...
// For each video: decode every frame, measure how much it differs from the first frame
// (sampled pixels, colour-weighted), pick the strongest frame after 0.25 s, and save the
// frame at peak + offset as <outdir>/<name>.png. Prints "name peak_seconds".
let args = CommandLine.arguments
let outDir = args[1]; let offset = Double(args[2])!
for path in args.dropFirst(3) {
    let url = URL(fileURLWithPath: path)
    let name = url.deletingPathExtension().lastPathComponent
    let asset = AVURLAsset(url: url)
    guard let track = asset.tracks(withMediaType: .video).first, let reader = try? AVAssetReader(asset: asset) else { print(name, "-1"); continue }
    let out = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    reader.add(out); reader.startReading()
    var base: [Float]? = nil
    var best: Float = -1; var bestT = 0.0
    while let sb = out.copyNextSampleBuffer() {
        let t = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sb))
        guard let pb = CMSampleBufferGetImageBuffer(sb) else { continue }
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb), bpr = CVPixelBufferGetBytesPerRow(pb)
        let p = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self)
        var v: [Float] = []
        v.reserveCapacity((w / 6) * (h / 6) * 2)
        var y = 0
        while y < h { var x = 0; while x < w {
            let o = y * bpr + x * 4
            let b = Float(p[o]), g = Float(p[o + 1]), r = Float(p[o + 2])
            let mx = max(r, g, b), mn = min(r, g, b)
            v.append((r + g + b) / 3); v.append(mx - mn)
            x += 6 }; y += 6 }
        CVPixelBufferUnlockBaseAddress(pb, .readOnly)
        if base == nil { base = v; continue }
        if t < 0.25 { continue }
        var e: Float = 0
        for i in stride(from: 0, to: v.count, by: 2) { e += abs(v[i] - base![i]) + 1.5 * abs(v[i + 1] - base![i + 1]) }
        if e > best { best = e; bestT = t }
    }
    let gen = AVAssetImageGenerator(asset: asset)
    gen.appliesPreferredTrackTransform = true
    gen.requestedTimeToleranceBefore = .zero; gen.requestedTimeToleranceAfter = .zero
    if let img = try? gen.copyCGImage(at: CMTime(seconds: bestT + offset, preferredTimescale: 600), actualTime: nil) {
        let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(outDir)/\(name).png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
    }
    print(name, String(format: "%.3f", bestT))
}
