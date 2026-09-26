import Foundation
import AVFoundation
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let asset = AVURLAsset(url: input)
guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else { fatalError("No video exporter") }
exporter.shouldOptimizeForNetworkUse = true
Task {
    do { try await exporter.export(to: output, as: .mp4); print(output.path); exit(0) }
    catch { print(error); exit(1) }
}
dispatchMain()
