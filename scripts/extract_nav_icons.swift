import Foundation
import CoreGraphics
import ImageIO

let args = CommandLine.arguments
guard args.count == 3 else { fatalError("usage: extract_nav_icons.swift input output-dir") }
let inputURL = URL(fileURLWithPath: args[1])
let outputDir = URL(fileURLWithPath: args[2], isDirectory: true)
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { fatalError("Unable to load image") }

let width = image.width
let height = image.height
let bytesPerRow = width * 4
var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("Unable to create bitmap") }
context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

// Remove the chroma-key green while preserving a soft edge around the art.
for y in 0..<height {
    for x in 0..<width {
        let i = y * bytesPerRow + x * 4
        let r = Float(pixels[i]), g = Float(pixels[i + 1]), b = Float(pixels[i + 2])
        let greenDominance = g - max(r, b)
        if g > 70 && greenDominance > 18 {
            let strength = min(1, max(0, greenDominance / 90))
            pixels[i + 3] = UInt8(Float(pixels[i + 3]) * (1 - strength))
            if strength > 0.82 { pixels[i + 3] = 0 }
        }
    }
}

guard let keyed = context.makeImage() else { fatalError("Unable to create keyed image") }
let regions: [(String, Int, Int)] = [
    ("profile", 15, 360),
    ("conquest", 390, 740),
    ("church", 755, 1065),
    ("store", 1085, 1400),
    ("inventory", 1430, width)
]

for (name, left, right) in regions {
    // Keep the emblem artwork only; the source sheet's Chinese captions are
    // rendered by SwiftUI beneath each asset and must not be baked in twice.
    let cropRect = CGRect(x: left, y: 70, width: right - left, height: 570)
    guard let cropped = keyed.cropping(to: cropRect) else { continue }
    let outURL = outputDir.appendingPathComponent("\(name).png")
    guard let destination = CGImageDestinationCreateWithURL(outURL as CFURL, "public.png" as CFString, 1, nil) else { continue }
    CGImageDestinationAddImage(destination, cropped, nil)
    CGImageDestinationFinalize(destination)
}
