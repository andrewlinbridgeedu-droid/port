import SwiftUI
import AVFoundation

enum GameSettingsKeys {
    static let displayName = "mistport.player.display-name"
    static let musicVolume = "mistport.music.volume"
    static let interfaceSoundVolume = "mistport.interface-sound.volume"
    static let combatSoundVolume = "mistport.combat-sound.volume"
    static let reduceMotion = "mistport.interface.reduce-motion"
    static let hapticsEnabled = "mistport.haptics.enabled"
}

struct GameSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(GameSettingsKeys.displayName, store: .standard) private var displayName = "愚者"
    @AppStorage(HomeMusicController.isEnabledKey, store: .standard) private var musicEnabled = true
    @AppStorage(GameSettingsKeys.musicVolume, store: .standard) private var musicVolume = 0.7
    @AppStorage(GameSettingsKeys.interfaceSoundVolume, store: .standard) private var soundVolume = 0.6
    @AppStorage(GameSettingsKeys.combatSoundVolume, store: .standard) private var combatSoundVolume = 0.6
    @AppStorage(CityAmbience.volumeKey, store: .standard) private var ambienceVolume = 0.6
    @AppStorage(GameSettingsKeys.reduceMotion, store: .standard) private var reduceMotion = false
    @AppStorage(GameSettingsKeys.hapticsEnabled, store: .standard) private var hapticsEnabled = true
    @State private var nameDraft = ""
    @FocusState private var editingName: Bool

    var body: some View {
        GameArtPage(title: "设置", subtitle: "旅人手册 · 声音与体验", closeTitle: "完成", onClose: { saveName(); GameInterfaceSound.shared.playClick() }) {
                GroupBox("旅人") {
                    VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("名字")
                        TextField("愚者", text: $nameDraft)
                            .multilineTextAlignment(.trailing)
                            .focused($editingName)
                            .submitLabel(.done)
                            .onSubmit { saveName() }
                            .onChange(of: nameDraft) { _, value in
                                if value.count > 12 { nameDraft = String(value.prefix(12)) }
                            }
                    }
                    Text("最多 12 个字，作为主界面显示名字。")
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }
                GroupBox("声音") {
                    VStack(alignment: .leading, spacing: 14) {
                    Toggle("背景音乐", isOn: $musicEnabled)
                    volumeRow("音乐音量", value: $musicVolume)
                        .disabled(!musicEnabled)
                    volumeRow("界面音效", value: $soundVolume)
                    Button("试听界面音效") { GameInterfaceSound.shared.playClick() }
                    volumeRow("战斗法术音效", value: $combatSoundVolume)
                    volumeRow("港城环境音", value: $ambienceVolume)
                    Text("界面按钮、战斗法术与主页的海浪、风雨、鸟叫分别调节；调至 0 即静音。")
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }
                GroupBox("效果") {
                    VStack(alignment: .leading, spacing: 14) {
                    Toggle("减少界面动态", isOn: $reduceMotion)
                    Text("减弱界面旋转、悬浮及卡牌光效，保留战斗演出与技能提示。")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("战斗振动", isOn: $hapticsEnabled)
                        .onChange(of: hapticsEnabled) { _, enabled in
                            if !enabled { CombatHaptics.shared.cancel() }
                        }
                    Button("体验震动：轻击 · 重击 · 格挡") { CombatHaptics.shared.preview() }
                        .disabled(!hapticsEnabled)
                }
            }
            }
            .tint(Color(red: 0.50, green: 0.32, blue: 0.12))
            .onAppear { nameDraft = displayName }
            .onDisappear { saveName(); CombatHaptics.shared.cancel() }
            .onChange(of: musicEnabled) { _, enabled in
                HomeMusicController.shared.setEnabled(enabled)
            }
            .onChange(of: musicVolume) { _, volume in
                HomeMusicController.shared.setVolume(volume)
            }
            .onChange(of: ambienceVolume) { _, volume in
                CityAmbience.shared.setVolume(volume)
            }
    }

    private func volumeRow(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded()))%")
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...1)
                .accessibilityLabel(title)
        }.padding(.vertical, 4)
    }

    private func saveName() {
        let name = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        displayName = name.isEmpty ? "愚者" : String(name.prefix(12))
        editingName = false
    }
}

/// Short, locally synthesized two-tone UI cue; independent from the music player.
@MainActor
final class GameInterfaceSound {
    static let shared = GameInterfaceSound()
    private var player: AVAudioPlayer?

    func playClick() {
        let volume = UserDefaults.standard.object(forKey: GameSettingsKeys.interfaceSoundVolume) as? Double ?? 0.6
        guard volume > 0 else { return }
        do {
            if player == nil { player = try AVAudioPlayer(data: Self.clickWave()) }
            player?.volume = Float(min(1, max(0, volume)))
            player?.currentTime = 0
            player?.play()
        } catch { player = nil }
    }

    private static func clickWave() -> Data {
        let rate = 22_050
        let count = Int(Double(rate) * 0.085)
        var pcm = Data()
        for index in 0..<count {
            let t = Double(index) / Double(rate)
            let envelope = min(1, t / 0.004) * exp(-t * 60)
            let sample = (sin(t * 2 * .pi * 880) + 0.3 * sin(t * 2 * .pi * 1320)) * envelope * 0.17
            var word = Int16(sample * Double(Int16.max)).littleEndian
            withUnsafeBytes(of: &word) { pcm.append(contentsOf: $0) }
        }
        var wave = Data()
        func tag(_ text: String) { wave.append(contentsOf: text.utf8) }
        func u32(_ value: UInt32) { var value = value.littleEndian; withUnsafeBytes(of: &value) { wave.append(contentsOf: $0) } }
        func u16(_ value: UInt16) { var value = value.littleEndian; withUnsafeBytes(of: &value) { wave.append(contentsOf: $0) } }
        tag("RIFF"); u32(UInt32(36 + pcm.count)); tag("WAVEfmt "); u32(16)
        u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
        tag("data"); u32(UInt32(pcm.count)); wave.append(pcm)
        return wave
    }
}
