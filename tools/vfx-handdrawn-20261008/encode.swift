// encode <frames_dir> <fps> <out.mp4> [width]
// Encodes the dir's PNGs (sorted by name) into an H.264 mp4 with AVFoundation, so
// review clips need no ffmpeg (the old /tmp encoder is gone and downloads need asking).
import AVFoundation
import CoreGraphics
import ImageIO

let a = CommandLine.arguments
let dir = URL(fileURLWithPath: a[1])
let fps = Int32(a[2])!
let out = URL(fileURLWithPath: a[3])
let names = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".png") }.sorted()
guard let first = names.first,
      let src0 = CGImageSourceCreateWithURL(dir.appendingPathComponent(first) as CFURL, nil),
      let img0 = CGImageSourceCreateImageAtIndex(src0, 0, nil) else { fatalError("no frames") }
var w = img0.width, h = img0.height
if a.count > 4, let tw = Int(a[4]) { h = Int(Double(h) * Double(tw) / Double(w)) / 2 * 2; w = tw / 2 * 2 }
try? FileManager.default.removeItem(at: out)
let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 8_000_000]])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)
for (i, n) in names.enumerated() {
    guard let src = CGImageSourceCreateWithURL(dir.appendingPathComponent(n) as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { continue }
    while !input.isReadyForMoreMediaData { usleep(2000) }
    var pb: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
    guard let buf = pb else { continue }
    CVPixelBufferLockBaseAddress(buf, [])
    let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: w, height: h, bitsPerComponent: 8,
                        bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    CVPixelBufferUnlockBaseAddress(buf, [])
    adaptor.append(buf, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps))
}
input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
print("wrote", names.count, "frames", w, "x", h, writer.status == .completed ? "ok" : "failed \(String(describing: writer.error))")
