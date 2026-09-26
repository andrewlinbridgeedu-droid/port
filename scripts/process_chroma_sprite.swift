#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct RGBAImage {
    let width: Int
    let height: Int
    var pixels: [UInt8]

    init(url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw PipelineError.cannotDecode(url.path) }

        width = image.width
        height = image.height
        pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw PipelineError.cannotCreateContext }
        // `CGContext` already writes the decoded `CGImage` into this byte buffer
        // in the same top-to-bottom order that `writePNG` later encodes. Applying
        // an extra UIKit-style coordinate flip here makes every exported frame
        // vertically inverted (characters appear on their backs).
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        pixels = [UInt8](repeating: 0, count: width * height * 4)
    }

    func offset(x: Int, y: Int) -> Int { (y * width + x) * 4 }
}

enum PipelineError: Error, CustomStringConvertible {
    case invalidArguments
    case cannotDecode(String)
    case cannotCreateContext
    case cannotEncode(String)
    case emptyFrame(Int)

    var description: String {
        switch self {
        case .invalidArguments:
            "usage: process_chroma_sprite.swift INPUT OUTPUT_DIRECTORY FRAME_COUNT [OUTPUT_PREFIX] [COLUMNS]"
        case let .cannotDecode(path): "cannot decode image: \(path)"
        case .cannotCreateContext: "cannot create RGBA context"
        case let .cannotEncode(path): "cannot encode PNG: \(path)"
        case let .emptyFrame(index): "frame \(index) contains no foreground pixels"
        }
    }
}

struct FrameSample {
    let index: Int
    let cell: CGRect
    let bounds: CGRect
    let touchesCellEdge: Bool
}

func foregroundAlpha(r: UInt8, g: UInt8, b: UInt8) -> UInt8 {
    let red = Int(r)
    let green = Int(g)
    let blue = Int(b)
    let dominance = green - max(red, blue)

    // Preserve cyan cores and blue armor: true chroma green must dominate both
    // other channels, not merely contain a high green component.
    guard green > 115, dominance > 24, green > red * 6 / 5, green > blue * 6 / 5 else {
        return 255
    }
    if dominance >= 92 { return 0 }
    let transition = 1 - Double(dominance - 24) / Double(92 - 24)
    return UInt8(max(0, min(255, Int(transition * 255))))
}

func scanFrames(_ image: RGBAImage, count: Int, columns: Int) throws -> [FrameSample] {
    let rows = Int(ceil(Double(count) / Double(columns)))
    return try (0..<count).map { frameIndex in
        let column = frameIndex % columns
        let row = frameIndex / columns
        let minCellX = image.width * column / columns
        let maxCellX = image.width * (column + 1) / columns
        let minCellY = image.height * row / rows
        let maxCellY = image.height * (row + 1) / rows
        var minX = maxCellX
        var minY = maxCellY
        var maxX = minCellX - 1
        var maxY = minCellY - 1

        for y in minCellY..<maxCellY {
            for x in minCellX..<maxCellX {
                let offset = image.offset(x: x, y: y)
                let chromaAlpha = foregroundAlpha(
                    r: image.pixels[offset],
                    g: image.pixels[offset + 1],
                    b: image.pixels[offset + 2]
                )
                let alpha = min(chromaAlpha, image.pixels[offset + 3])
                if alpha > 18 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard maxX >= minX, maxY >= minY else { throw PipelineError.emptyFrame(frameIndex + 1) }
        let edgeTolerance = 3
        let touchesEdge = minX <= minCellX + edgeTolerance
            || maxX >= maxCellX - 1 - edgeTolerance
            || minY <= minCellY + edgeTolerance
            || maxY >= maxCellY - 1 - edgeTolerance
        return FrameSample(
            index: frameIndex,
            cell: CGRect(
                x: minCellX,
                y: minCellY,
                width: maxCellX - minCellX,
                height: maxCellY - minCellY
            ),
            bounds: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1),
            touchesCellEdge: touchesEdge
        )
    }
}

func renderFrame(
    source: RGBAImage,
    sample: FrameSample,
    canvasSide: Int,
    padding: Int,
    sharedScale: Double
) -> RGBAImage {
    var output = RGBAImage(width: canvasSide, height: canvasSide)
    let bounds = sample.bounds.integral
    let sourceWidth = Int(bounds.width)
    let sourceHeight = Int(bounds.height)
    let scale = sharedScale
    let targetWidth = max(1, Int((Double(sourceWidth) * scale).rounded()))
    let targetHeight = max(1, Int((Double(sourceHeight) * scale).rounded()))
    let targetX = (canvasSide - targetWidth) / 2
    let targetY = canvasSide - padding - targetHeight

    for targetPixelY in 0..<targetHeight {
        let sourceY = Int(bounds.minY) + min(sourceHeight - 1, Int(Double(targetPixelY) / scale))
        for targetPixelX in 0..<targetWidth {
            let sourceX = Int(bounds.minX) + min(sourceWidth - 1, Int(Double(targetPixelX) / scale))
            let sourceOffset = source.offset(x: sourceX, y: sourceY)
            let outputOffset = output.offset(x: targetX + targetPixelX, y: targetY + targetPixelY)
            let r = source.pixels[sourceOffset]
            let g = source.pixels[sourceOffset + 1]
            let b = source.pixels[sourceOffset + 2]
            let chromaAlpha = foregroundAlpha(r: r, g: g, b: b)
            let alpha = min(chromaAlpha, source.pixels[sourceOffset + 3])
            // Source bytes are already premultiplied by their stored alpha.
            // Apply only the additional chroma matte here to avoid darkening
            // antialiased edges twice after the Python despill pass.
            output.pixels[outputOffset] = UInt8(Int(r) * Int(chromaAlpha) / 255)
            output.pixels[outputOffset + 1] = UInt8(Int(g) * Int(chromaAlpha) / 255)
            output.pixels[outputOffset + 2] = UInt8(Int(b) * Int(chromaAlpha) / 255)
            output.pixels[outputOffset + 3] = alpha
        }
    }
    return output
}

func writePNG(_ image: RGBAImage, to url: URL) throws {
    var mutablePixels = image.pixels
    guard let context = CGContext(
        data: &mutablePixels,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: image.width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let cgImage = context.makeImage(),
       let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
       )
    else { throw PipelineError.cannotEncode(url.path) }
    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else { throw PipelineError.cannotEncode(url.path) }
}

do {
    let arguments = CommandLine.arguments
    guard arguments.count >= 4, let frameCount = Int(arguments[3]), frameCount > 0 else {
        throw PipelineError.invalidArguments
    }
    let inputURL = URL(fileURLWithPath: arguments[1])
    let outputDirectory = URL(fileURLWithPath: arguments[2], isDirectory: true)
    let prefix = arguments.count >= 5 ? arguments[4] : "Frame"
    let columns = arguments.count >= 6 ? (Int(arguments[5]) ?? frameCount) : frameCount
    guard columns > 0, columns <= frameCount else { throw PipelineError.invalidArguments }
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    let source = try RGBAImage(url: inputURL)
    let samples = try scanFrames(source, count: frameCount, columns: columns)
    let maxContentWidth = samples.map { Int($0.bounds.width) }.max() ?? 1
    let maxContentHeight = samples.map { Int($0.bounds.height) }.max() ?? 1
    let maxDimension = max(maxContentWidth, maxContentHeight)
    let canvasSide = max(512, Int(ceil(Double(maxDimension) * 1.18)))
    let padding = max(20, Int(Double(canvasSide) * 0.055))
    let sharedScale = min(
        Double(canvasSide - padding * 2) / Double(maxContentWidth),
        Double(canvasSide - padding * 2) / Double(maxContentHeight)
    )

    for sample in samples {
        let frame = renderFrame(
            source: source,
            sample: sample,
            canvasSide: canvasSide,
            padding: padding,
            sharedScale: sharedScale
        )
        let filename = String(format: "%@%02d.png", prefix, sample.index + 1)
        try writePNG(frame, to: outputDirectory.appendingPathComponent(filename))
        let edgeStatus = sample.touchesCellEdge ? "EDGE_CONTACT" : "ok"
        print(String(
            format: "frame %02d cell=(%.0f,%.0f %.0fx%.0f) bounds=(%.0f,%.0f %.0fx%.0f) %@",
            sample.index + 1,
            sample.cell.minX,
            sample.cell.minY,
            sample.cell.width,
            sample.cell.height,
            sample.bounds.minX,
            sample.bounds.minY,
            sample.bounds.width,
            sample.bounds.height,
            edgeStatus
        ))
    }
    print(String(
        format: "output_canvas=%dx%d frames=%d columns=%d shared_scale=%.4f",
        canvasSide,
        canvasSide,
        samples.count,
        columns,
        sharedScale
    ))
    if samples.contains(where: \.touchesCellEdge) {
        print("REJECT: one or more characters touch a generated cell boundary")
        exit(2)
    }
} catch {
    FileHandle.standardError.write(Data("ERROR: \(error)\n".utf8))
    exit(1)
}
