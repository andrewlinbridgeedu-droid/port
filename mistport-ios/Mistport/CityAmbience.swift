import AVFoundation

/// Harbour ambience under the hub music. Loops (sea, breeze, storm wind,
/// drizzle, downpour, crickets) follow the harbour hour, season and weather;
/// one-shots are scattered over them: gulls by day, songbirds at dawn in
/// spring and summer, an owl late at night, thunder a few seconds after each
/// lightning strike (see HarborLightning), and the clock tower striking at
/// 00:00, 06:00, 12:00 and 18:00. All sounds are synthesised
/// (tools/city-daynight/make_ambience.py) and live in the "Ambience" folder.
@MainActor
final class CityAmbience {
    static let shared = CityAmbience()
    static let volumeKey = "mistport.ambience.volume"

    private static let loopNames = ["sea", "wind_soft", "wind_strong", "rain_light", "rain_heavy", "crickets"]
    private static let shotNames = ["thunder_near_1", "thunder_near_2", "thunder_far_1", "thunder_far_2",
                                    "gull_1", "gull_2", "gull_3", "songbird_1", "songbird_2", "songbird_3",
                                    "owl_1", "bell"]

    private let engine = AVAudioEngine()
    private let bus = AVAudioMixerNode()
    private var loops: [String: AVAudioPlayerNode] = [:]
    private var levels: [String: Float] = [:]
    private var shots: [AVAudioPlayerNode] = []
    private var nextShot = 0
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var timer: Timer?
    private var users = 0
    private var loading = false
    private var wired = false
    private var heardStrikes: Set<Int> = []
    private var lastHour: Int?
    private var nextGull = 0.0, nextSongbird = 0.0, nextOwl = 0.0
    /// Rain, wind and sea step back while thunder rolls: target gain and
    /// until when (reference seconds), and the smoothed gain applied.
    private var duckTarget: Float = 1, duckUntil = 0.0, duck: Float = 1

    static var volume: Float {
        Float(UserDefaults.standard.object(forKey: volumeKey) as? Double ?? 0.6)
    }

    /// The hub scene calls this when it appears; balanced by `stop()`.
    func start() {
        #if DEBUG
        // Review runs (the harbour harness, screenshots, a device launched with
        // -MistportCityMute YES) stay silent.
        if UserDefaults.standard.bool(forKey: "MistportCityMute") { return }
        #endif
        users += 1
        guard users == 1 else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch { return }
        if buffers.isEmpty && !loading {
            loading = true
            Task { @MainActor in
                // Decode one file per turn of the main actor so the hub stays smooth.
                for name in Self.loopNames + Self.shotNames {
                    self.load(name)
                    await Task.yield()
                }
                self.loading = false
                self.wire()
                if self.users > 0 { self.resume() }
            }
        } else if wired {
            resume()
        }
    }

    func stop() {
        guard users > 0 else { return }
        users -= 1
        guard users == 0 else { return }
        timer?.invalidate()
        timer = nil
        // Fade out, then pause the engine unless the hub came back meanwhile.
        bus.outputVolume = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, self.users == 0 else { return }
            self.engine.pause()
        }
    }

    func setVolume(_ value: Double) {
        UserDefaults.standard.set(min(1, max(0, value)), forKey: Self.volumeKey)
        if users > 0 { bus.outputVolume = Self.volume }
    }

    // MARK: Setup

    private func load(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf", subdirectory: "Ambience"),
              let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
        else { return }
        do { try file.read(into: buffer) } catch { return }
        buffers[name] = buffer
    }

    private func wire() {
        guard !wired, let format = buffers["sea"]?.format else { return }
        engine.attach(bus)
        engine.connect(bus, to: engine.mainMixerNode, format: nil)
        for name in Self.loopNames where buffers[name] != nil {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: bus, format: format)
            node.volume = 0
            loops[name] = node
            levels[name] = 0
        }
        for _ in 0..<6 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: bus, format: format)
            shots.append(node)
        }
        wired = true
    }

    private func resume() {
        // Without the sounds the engine has nothing attached and must not start.
        guard wired else { return }
        bus.outputVolume = Self.volume
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }
        for (name, node) in loops where !node.isPlaying {
            guard let buffer = buffers[name] else { continue }
            node.scheduleBuffer(buffer, at: nil, options: .loops)
            node.play()
        }
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { _ in
            Task { @MainActor in CityAmbience.shared.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    // MARK: Mixing

    private func tick() {
        guard users > 0 else { return }
        if !engine.isRunning {
            // Recover after an audio interruption (call, backgrounding).
            do { try engine.start() } catch { return }
        }
        let now = Date()
        let t = now.timeIntervalSinceReferenceDate
        let g = HarborClock.gameHours(at: now)
        let hour = HarborClock.hour(at: now)
        let light = HarborLight(hour: hour)
        let season = HarborSeason.state(gameHours: g).current
        let weather = HarborWeather(gameHours: g)
        let snow = season == .winter
        let wet = weather.rain
        let day = min(1, light.day + 0.7 * light.sunset)
        let dark = light.dark

        func ramp(_ v: Double, _ a: Double, _ b: Double) -> Double { HarborNoise.smooth((v - a) / (b - a)) }
        var targets: [String: Double] = [:]
        targets["sea"] = (0.55 - 0.12 * dark + 0.25 * weather.gust) * (snow ? 0.8 : 1)
        targets["wind_soft"] = 0.22 + 0.45 * weather.gust * (1 - weather.storm) + (snow ? 0.12 : 0)
        targets["wind_strong"] = ramp(weather.gust, 0.45, 0.9) * 0.9
        targets["rain_light"] = snow ? 0 : ramp(wet, 0, 0.06) * (1 - ramp(wet, 0.35, 0.7)) * 0.85
        targets["rain_heavy"] = snow ? 0 : ramp(wet, 0.25, 0.7) * 0.95
        let cricketSeason: Double = [.spring: 0.3, .summer: 1.0, .autumn: 0.6, .winter: 0][season] ?? 0
        targets["crickets"] = dark * (1 - min(1, wet * 3)) * cricketSeason * 0.8

        // Ducking: quick to drop when the thunder hits, slow to come back.
        let wantDuck: Float = t < duckUntil ? duckTarget : 1
        duck += (wantDuck - duck) * (wantDuck < duck ? 0.6 : 0.12)
        for (name, node) in loops {
            let target = Float(targets[name] ?? 0)
            let level = (levels[name] ?? 0) + (target - (levels[name] ?? 0)) * 0.08
            levels[name] = level
            node.volume = name == "crickets" ? level : level * duck
        }

        // Gulls by day, fewer in rain or snow.
        let gulls = day * (1 - wet) * (snow ? 0.6 : 1)
        if t >= nextGull {
            if gulls > 0.05 {
                play("gull_\(1 + Int.random(in: 0...2))", volume: Float(0.25 + 0.35 * Double.random(in: 0...1) * gulls),
                     pan: Float.random(in: -0.7...0.7))
            }
            nextGull = t + Double.random(in: 7...22) / max(gulls, 0.25)
        }
        // Dawn chorus, strongest in spring.
        let chorusSeason: Double = [.spring: 1.0, .summer: 0.8, .autumn: 0.35, .winter: 0.1][season] ?? 0
        let dawn = max(0, 1 - abs(hour - 7) / 2.8)
        let songbirds = (0.8 * dawn + 0.25 * day) * chorusSeason * (1 - wet)
        if t >= nextSongbird {
            if songbirds > 0.05 {
                play("songbird_\(1 + Int.random(in: 0...2))", volume: Float(0.18 + 0.3 * songbirds),
                     pan: Float.random(in: -0.8...0.8))
            }
            nextSongbird = t + Double.random(in: 3...9) / max(songbirds, 0.2)
        }
        // An owl in the deep of the night.
        let deep = hour >= 21.5 || hour < 4.5 ? dark : 0
        if t >= nextOwl {
            if deep > 0.5 && wet < 0.1 {
                play("owl_1", volume: 0.3, pan: Float.random(in: -0.6...0.6))
            }
            nextOwl = t + Double.random(in: 40...95)
        }
        // Thunder follows each lightning strike: sound travels ~340 m/s.
        let slot = Int(floor(t / HarborLightning.slot))
        for k in (slot - 1)...(slot + 1) where !heardStrikes.contains(k) {
            guard let strike = HarborLightning.strike(slot: k, storm: weather.storm) else { continue }
            let delay = strike.near ? 0.5 + 1.3 * HarborNoise.hash(k, 730) : 2.8 + 3.5 * HarborNoise.hash(k, 730)
            let wait = strike.time + delay - t
            guard wait > -0.3 else { heardStrikes.insert(k); continue }
            heardStrikes.insert(k)
            let name = strike.near ? "thunder_near_\(1 + k % 2)" : "thunder_far_\(1 + k % 2)"
            let near = strike.near
            let pan = Float((strike.x / HarborPainting.aspect - 0.5) * 1.4)
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0, wait)) { [weak self] in
                guard let self, self.users > 0 else { return }
                self.play(name, volume: near ? 1.0 : 0.85, pan: pan)
                let now = Date().timeIntervalSinceReferenceDate
                self.duckTarget = min(self.duck, near ? 0.45 : 0.65)
                self.duckUntil = now + (near ? 3.5 : 2.5)
                self.duck += (self.duckTarget - self.duck) * 0.6
            }
        }
        heardStrikes = heardStrikes.filter { $0 >= slot - 3 }
        // The clock tower strikes the hour at 00, 06, 12 and 18.
        let whole = Int(floor(hour))
        if let last = lastHour, last != whole, whole % 6 == 0 {
            let strikes = whole % 12 == 0 ? 12 : 6
            for i in 0..<strikes {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 2.3) { [weak self] in
                    guard let self, self.users > 0 else { return }
                    self.play("bell", volume: 0.42 - Float(i) * 0.012, pan: -0.1)
                }
            }
        }
        lastHour = whole
    }

    private func play(_ name: String, volume: Float, pan: Float) {
        guard let buffer = buffers[name], !shots.isEmpty, engine.isRunning else { return }
        let node = shots[nextShot % shots.count]
        nextShot += 1
        node.stop()
        node.volume = volume
        node.pan = max(-1, min(1, pan))
        node.scheduleBuffer(buffer, at: nil)
        node.play()
    }
}
