import AppKit
import SwiftUI

/// Offline renderer for the home harbour: draws CityLivingScene (the app's own
/// code) at chosen moments and writes PNGs, for checking walkers, ships,
/// rain, clouds and lightning without a phone or simulator.
///
/// usage: HarborRender <out_dir> <height_pt> <x0> <x1> <t> [<t> ...]
///   x0, x1: painting units (0 … 1.777) of the strip to keep; t: real seconds
///   (reference date) pinned for each frame. Hour, season, weather: the
///   usual -MistportCity* arguments.
@main
struct HarborRender {
    @MainActor static func main() {
        let a = CommandLine.arguments.filter { !$0.hasPrefix("-") && Double($0) != nil || $0.contains("/") }
        let positional = Array(CommandLine.arguments.dropFirst().prefix { !$0.hasPrefix("-") })
        _ = a
        guard positional.count >= 5 else { print("usage: HarborRender out height x0 x1 t..."); return }
        let out = positional[0]
        let height = CGFloat(Double(positional[1]) ?? 744)
        let x0 = Double(positional[2]) ?? 0, x1 = Double(positional[3]) ?? HarborPainting.aspect
        let width = height * HarborPainting.aspect
        try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
        for text in positional.dropFirst(4) {
            guard let t = Double(text) else { continue }
            HarborRenderClock.now = Date(timeIntervalSinceReferenceDate: t)
            let view = CityLivingScene()
                .frame(width: width, height: height)
                .background(Color.black)
                .environment(\.colorScheme, .dark)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.cgImage else { print("render failed"); continue }
            let crop = image.cropping(to: CGRect(x: x0 * height * 2, y: 0, width: (x1 - x0) * height * 2,
                                                 height: height * 2)) ?? image
            let url = URL(fileURLWithPath: "\(out)/t\(text).png")
            guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { continue }
            CGImageDestinationAddImage(dest, crop, nil)
            CGImageDestinationFinalize(dest)
            print("wrote", url.path)
        }
    }
}

/// The app's ambience needs AVAudioSession (iOS only); renders are silent.
@MainActor final class CityAmbience {
    static let shared = CityAmbience()
    func start() {}
    func stop() {}
}
