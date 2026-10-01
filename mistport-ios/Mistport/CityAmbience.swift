import AVFoundation

/// Harbour ambience under the hub music. Loops (sea, breeze, storm wind,
/// drizzle, downpour, crickets) follow the harbour hour, season and weather;
/// one-shots are scattered over them: gulls by day, songbirds at dawn in
/// spring and summer, an owl late at night, waves slapping the quay, gusts,
/// ships' timber and ropes creaking, a ship's bell across the water by day,
/// thunder a few seconds after each lightning strike (see HarborLightning),
/// and the clock tower striking at 00:00, 06:00, 12:00 and 18:00.
///
/// So that it never sounds like a loop: every loop has two takes of
/// different length (41 s and 53 s for the sea, …) streamed from disk side by
/// side and cross-faded slowly, each drifting a little in pitch and across the
/// stereo field; every one-shot picks one of several takes and plays it at a
/// slightly different pitch, level and place. All sounds are synthesised
/// (tools/city-daynight/make_ambience.py) and live in the "Ambience" folder.
///
/// Audio output can stall under the hub without the engine noticing: iPhone
/// Mirroring, AirPlay, a headset or a call moves the route, and a player told
/// to play then throws "player did not see an IO cycle" (an Objective-C
/// exception Swift cannot catch; seen on device 2026-09-30, 169.12). So no
/// player starts until the output clock is seen advancing between two ticks;
/// a route or configuration change, an interruption or a stall of two seconds
/// drops every voice and waits for the clock again, and a media-services reset
/// rebuilds the whole graph.
@MainActor
final class CityAmbience {
    static let shared = CityAmbience()
    static let volumeKey = "mistport.ambience.volume"

    private static let loopNames = ["sea", "wind_soft", "wind_strong", "rain_light", "rain_heavy", "crickets"]
    /// One-shot families and how many takes each has (<family>_1 … <family>_n).
    private static let shotTakes: [String: Int] = [
        "thunder_near": 3, "thunder_far": 3, "gull": 6, "songbird": 6, "owl": 2,
        "splash": 3, "gust": 3, "creak": 3, "shipbell": 2]
    /// Per loop: pitch drift (± share of speed), stereo spread of the two
    /// takes, and how far each take wanders from its side.
    private static let character: [String: (depth: Double, spread: Double, swing: Double)] = [
        "sea": (0.05, 0.25, 0.15), "wind_soft": (0.07, 0.35, 0.40), "wind_strong": (0.06, 0.30, 0.40),
        "rain_light": (0.03, 0.20, 0.10), "rain_heavy": (0.03, 0.20, 0.10), "crickets": (0.015, 0.50, 0.10)]

    /// One sound path: player → varispeed (pitch) → its own mixer (level and
    /// pan at the bus; effects cannot pan, so the pan sits after them).
    private final class Voice {
        let player = AVAudioPlayerNode()
        let speed = AVAudioUnitVarispeed()
        let mix = AVAudioMixerNode()
        var busyUntil = 0.0
    }

    /// A loop take streamed from disk, re-queued whenever a copy is consumed.
    private struct Take {
        let voice: Voice
        let file: AVAudioFile
        var queued = 0
    }

    /// Slow random motions of one loop: periods (seconds) and phases.
    private struct Drift {
        let periods: [Double]
        let phases: [Double]
        init() {
            periods = (0..<9).map { _ in Double.random(in: 40...140) }
            phases = (0..<9).map { _ in Double.random(in: 0..<(2 * .pi)) }
        }
        func wave(_ i: Int, _ t: Double) -> Double { sin(2 * .pi * t / periods[i] + phases[i]) }
    }

    private var engine = AVAudioEngine()
    private var bus = AVAudioMixerNode()
    private var takes: [String: [Take]] = [:]
    private var drifts: [String: Drift] = [:]
    private var levels: [String: Float] = [:]
    private var shots: [Voice] = []
    private var urls: [String: URL] = [:]
    private var timer: Timer?
    private var users = 0
    private var wired = false
    private var heardStrikes: Set<Int> = []
    private var lastHour: Int?
    private var nextGull = 0.0, nextSongbird = 0.0, nextOwl = 0.0
    private var nextSplash = 0.0, nextGust = 0.0, nextCreak = 0.0, nextShipBell = 0.0
    /// Rain, wind and sea step back while thunder rolls: target gain and
    /// until when (reference seconds), and the smoothed gain applied.
    private var duckTarget: Float = 1, duckUntil = 0.0, duck: Float = 1
    /// True only while the output clock was seen advancing at the last tick.
    private var ioReady = false
    private var lastSample: AVAudioFramePosition?
    private var stalledTicks = 0
    /// Bumped whenever the voices are dropped, so completions of buffers
    /// scheduled before that cannot miscount the loop queues.
    private var generation = 0
    #if DEBUG
    private let reviewSession = UUID().uuidString
    private var reviewEvents: [[String: Any]] = []
    private var reviewSnapshotAt = 0.0
    private func reviewEvent(_ event: String, detail: Int? = nil) {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--housing-device-walk"), arguments.contains("--housing-audio-review") else { return }
        var entry: [String: Any] = ["event": event, "at": Date().timeIntervalSince1970,
            "users": users, "engineRunning": engine.isRunning, "outputReady": ioReady,
            "busVolume": bus.outputVolume,
            "route": AVAudioSession.sharedInstance().currentRoute.outputs.map { $0.portType.rawValue },
            "playingLoops": takes.values.flatMap { $0 }.filter { $0.voice.player.isPlaying }.count,
            "audibleLoopGains": takes.values.flatMap { $0 }.filter { $0.voice.mix.volume > 0.001 }.count]
        if let detail { entry["notificationDetail"] = detail }
        if let time = engine.outputNode.lastRenderTime, time.isSampleTimeValid { entry["outputSampleTime"] = time.sampleTime }
        reviewEvents.append(entry)
        let report: [String: Any] = ["session": reviewSession, "isolatedFixture": true,
            "environmentMuted": UserDefaults.standard.bool(forKey: "MistportCityMute"),
            "launchArguments": arguments, "events": reviewEvents]
        if let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
           let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted]) {
            try? data.write(to: folder.appendingPathComponent("housing-audio-review.json"))
        }
    }
    #endif

    private init() {
        let center = NotificationCenter.default
        _ = center.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { note in
            let source = (note.object as AnyObject?).map { ObjectIdentifier($0) }
            Task { @MainActor in CityAmbience.shared.outputChanged(engine: source) }
        }
        _ = center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { note in
            let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? Int
            Task { @MainActor in
                #if DEBUG
                CityAmbience.shared.reviewEvent("route-change", detail: reason)
                #endif
                CityAmbience.shared.outputChanged(engine: nil)
            }
        }
        _ = center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in CityAmbience.shared.outputChanged(engine: nil) }
        }
        _ = center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in CityAmbience.shared.rebuild() }
        }
    }

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
        #if DEBUG
        reviewEvent("home-start")
        #endif
        guard users == 1 else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch { return }
        if !wired { wire() }
        resume()
    }

    func stop() {
        guard users > 0 else { return }
        users -= 1
        #if DEBUG
        reviewEvent("home-stop")
        #endif
        guard users == 0 else { return }
        timer?.invalidate()
        timer = nil
        // Fade out, then pause the engine unless the hub came back meanwhile.
        bus.outputVolume = 0
        ioReady = false; lastSample = nil
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

    private func url(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "caf", subdirectory: "Ambience")
    }

    private func wire() {
        guard let first = url("sea_a"), let probe = try? AVAudioFile(forReading: first) else { return }
        let format = probe.processingFormat
        engine.attach(bus)
        engine.connect(bus, to: engine.mainMixerNode, format: nil)
        func voice() -> Voice {
            let v = Voice()
            engine.attach(v.player)
            engine.attach(v.speed)
            engine.attach(v.mix)
            engine.connect(v.player, to: v.speed, format: format)
            engine.connect(v.speed, to: v.mix, format: format)
            engine.connect(v.mix, to: bus, format: format)
            v.mix.volume = 0
            return v
        }
        for name in Self.loopNames {
            let pair = ["a", "b"].compactMap { take -> Take? in
                guard let u = url("\(name)_\(take)"), let file = try? AVAudioFile(forReading: u) else { return nil }
                return Take(voice: voice(), file: file)
            }
            guard !pair.isEmpty else { continue }
            takes[name] = pair
            drifts[name] = Drift()
            levels[name] = 0
        }
        for _ in 0..<10 { shots.append(voice()) }
        for (family, count) in Self.shotTakes {
            for k in 1...count { urls["\(family)_\(k)"] = url("\(family)_\(k)") }
        }
        urls["bell"] = url("bell")
        wired = true
    }

    private func resume() {
        // Without the sounds the engine has nothing attached and must not start.
        guard wired else { return }
        bus.outputVolume = Self.volume
        ioReady = false; lastSample = nil; stalledTicks = 0
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }
        // The loops start from tick() once the output clock is seen moving.
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { _ in
            Task { @MainActor in CityAmbience.shared.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    /// Two copies of every take stay queued; the player streams them from disk.
    private func keepLoopsPlaying() {
        guard ioReady else { return }
        for (name, pair) in takes {
            for index in pair.indices {
                while (takes[name]?[index].queued ?? 2) < 2 { queue(name, index) }
                if let player = takes[name]?[index].voice.player, !player.isPlaying { player.play() }
            }
        }
    }

    private func queue(_ name: String, _ index: Int) {
        guard let take = takes[name]?[index] else { return }
        let generation = generation
        take.voice.player.scheduleFile(take.file, at: nil, completionCallbackType: .dataConsumed) { [weak self] _ in
            Task { @MainActor in self?.consumed(name, index, generation) }
        }
        takes[name]?[index].queued += 1
    }

    private func consumed(_ name: String, _ index: Int, _ scheduledIn: Int) {
        guard scheduledIn == generation, takes[name] != nil else { return }
        takes[name]?[index].queued -= 1
        if users > 0, (takes[name]?[index].queued ?? 2) < 2 { queue(name, index) }
    }

    // MARK: Output health

    /// Whether the output node rendered since the previous tick. A stopped,
    /// interrupted or re-routing engine has no valid or no advancing time.
    private func outputAdvancing() -> Bool {
        guard engine.isRunning, let time = engine.outputNode.lastRenderTime, time.isSampleTimeValid else {
            lastSample = nil
            return false
        }
        defer { lastSample = time.sampleTime }
        guard let previous = lastSample else { return false }
        return time.sampleTime > previous
    }

    /// Stops every voice and forgets the queued loop buffers. Stopping a
    /// player is always safe; only starting one needs a live output.
    private func dropVoices() {
        generation += 1
        for (name, pair) in takes {
            for index in pair.indices {
                pair[index].voice.player.stop()
                takes[name]?[index].queued = 0
            }
        }
        for voice in shots { voice.player.stop(); voice.busyUntil = 0 }
    }

    /// Route or configuration change, or an interruption. Nothing plays until
    /// tick() sees the output clock moving again.
    fileprivate func outputChanged(engine source: ObjectIdentifier?) {
        if let source, source != ObjectIdentifier(engine) { return }
        ioReady = false; lastSample = nil; stalledTicks = 0
        guard wired else { return }
        dropVoices()
        #if DEBUG
        reviewEvent("output-reset")
        #endif
    }

    /// Media services were reset: every node is invalid, build a new graph.
    fileprivate func rebuild() {
        timer?.invalidate(); timer = nil
        ioReady = false; lastSample = nil; stalledTicks = 0
        generation += 1
        engine = AVAudioEngine(); bus = AVAudioMixerNode()
        takes = [:]; drifts = [:]; levels = [:]; shots = []; urls = [:]
        wired = false
        guard users > 0 else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch { return }
        wire()
        resume()
    }

    // MARK: Mixing

    private func tick() {
        guard users > 0 else { return }
        if !engine.isRunning {
            // Recover after an audio interruption (call, backgrounding, a new route).
            ioReady = false; lastSample = nil
            do { try engine.start() } catch { return }
            return
        }
        guard outputAdvancing() else {
            // Running but silent: wait, and after two seconds restart it.
            if ioReady { dropVoices() }
            ioReady = false
            stalledTicks += 1
            if stalledTicks >= 8 { stalledTicks = 0; engine.stop() }
            return
        }
        #if DEBUG
        let recovered = !ioReady
        #endif
        stalledTicks = 0
        ioReady = true
        keepLoopsPlaying()
        #if DEBUG
        if recovered { reviewEvent("output-recovered") }
        #endif
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
        for (name, pair) in takes {
            guard let drift = drifts[name], let look = Self.character[name] else { continue }
            let target = Float(targets[name] ?? 0)
            let level = (levels[name] ?? 0) + (target - (levels[name] ?? 0)) * 0.08
            levels[name] = level
            // Equal-power cross-fade between the two takes, and a slow swell.
            let theta = .pi / 4 + .pi / 4 * (0.7 * drift.wave(0, t) + 0.3 * drift.wave(1, t))
            let swell = 0.85 + 0.15 * drift.wave(2, t)
            let gain = level * (name == "crickets" ? 1 : duck) * Float(swell)
            for (i, take) in pair.enumerated() {
                let weight = i == 0 ? cos(theta) : sin(theta)
                take.voice.mix.volume = gain * Float(weight)
                take.voice.speed.rate = Float(1 + look.depth * (0.6 * drift.wave(3 + i, t) + 0.4 * drift.wave(5 + i, t)))
                let side = i == 0 ? -look.spread : look.spread
                take.voice.mix.pan = Float(max(-1, min(1, side + look.swing * drift.wave(7 + i, t))))
            }
        }

        // Gulls by day, fewer in rain or snow.
        let gulls = day * (1 - wet) * (snow ? 0.6 : 1)
        if t >= nextGull {
            if gulls > 0.05 {
                play("gull", volume: Float(0.25 + 0.35 * Double.random(in: 0...1) * gulls),
                     pan: Float.random(in: -0.7...0.7), rate: 0.9...1.12)
            }
            nextGull = t + Double.random(in: 7...22) / max(gulls, 0.25)
        }
        // Dawn chorus, strongest in spring.
        let chorusSeason: Double = [.spring: 1.0, .summer: 0.8, .autumn: 0.35, .winter: 0.1][season] ?? 0
        let dawn = max(0, 1 - abs(hour - 7) / 2.8)
        let songbirds = (0.8 * dawn + 0.25 * day) * chorusSeason * (1 - wet)
        if t >= nextSongbird {
            if songbirds > 0.05 {
                play("songbird", volume: Float(0.18 + 0.3 * songbirds), pan: Float.random(in: -0.8...0.8), rate: 0.92...1.1)
            }
            nextSongbird = t + Double.random(in: 3...9) / max(songbirds, 0.2)
        }
        // An owl in the deep of the night.
        let deep = hour >= 21.5 || hour < 4.5 ? dark : 0
        if t >= nextOwl {
            if deep > 0.5 && wet < 0.1 {
                play("owl", volume: Float.random(in: 0.22...0.34), pan: Float.random(in: -0.6...0.6), rate: 0.95...1.05)
            }
            nextOwl = t + Double.random(in: 40...95)
        }
        // Waves slapping the quay, more when the wind is up.
        let waves = targets["sea"] ?? 0.4
        if t >= nextSplash {
            play("splash", volume: Float(0.14 + 0.22 * Double.random(in: 0...1) * min(1, waves + 0.3 * weather.gust)),
                 pan: Float.random(in: -0.8...0.8), rate: 0.85...1.15)
            nextSplash = t + Double.random(in: 4...12) / max(0.5, waves + weather.gust)
        }
        // Single gusts passing through, when there is wind.
        if t >= nextGust {
            let wind = max(weather.gust, snow ? 0.35 : 0)
            if wind > 0.2 {
                play("gust", volume: Float(0.10 + 0.30 * wind), pan: Float.random(in: -0.8...0.8), rate: 0.8...1.2)
            }
            nextGust = t + Double.random(in: 6...18) / max(0.3, wind)
        }
        // Ships' timber and mooring ropes working, out in the harbour (right).
        if t >= nextCreak {
            play("creak", volume: Float.random(in: 0.10...0.24), pan: Float.random(in: 0.0...0.9), rate: 0.8...1.25)
            nextCreak = t + Double.random(in: 10...30)
        }
        // Now and then a ship's bell across the water by day.
        if t >= nextShipBell {
            if hour >= 7 && hour < 20 && wet < 0.5 {
                play("shipbell", volume: Float.random(in: 0.12...0.2), pan: Float.random(in: 0.3...0.9), rate: 0.97...1.03)
            }
            nextShipBell = t + Double.random(in: 70...160)
        }
        // Thunder follows each lightning strike: sound travels ~340 m/s.
        let slot = Int(floor(t / HarborLightning.slot))
        for k in (slot - 1)...(slot + 1) where !heardStrikes.contains(k) {
            guard let strike = HarborLightning.strike(slot: k, storm: weather.storm) else { continue }
            let delay = strike.near ? 0.5 + 1.3 * HarborNoise.hash(k, 730) : 2.8 + 3.5 * HarborNoise.hash(k, 730)
            let wait = strike.time + delay - t
            guard wait > -0.3 else { heardStrikes.insert(k); continue }
            heardStrikes.insert(k)
            let near = strike.near
            let pan = Float((strike.x / HarborPainting.aspect - 0.5) * 1.4)
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0, wait)) { [weak self] in
                guard let self, self.users > 0 else { return }
                self.play(near ? "thunder_near" : "thunder_far", volume: near ? 1.0 : 0.85, pan: pan,
                          rate: 0.9...1.05, priority: true)
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
                    self.play("bell", volume: 0.42 - Float(i) * 0.012, pan: -0.1, rate: 1...1, priority: true)
                }
            }
        }
        lastHour = whole
        #if DEBUG
        if t - reviewSnapshotAt >= 2 { reviewSnapshotAt = t; reviewEvent("output-snapshot") }
        #endif
    }

    /// Plays a random take of a family on a free voice, at a random speed in
    /// `rate`. With every voice busy, ordinary sounds are skipped; thunder and
    /// the clock take over the voice that frees soonest.
    private func play(_ family: String, volume: Float, pan: Float, rate: ClosedRange<Float>, priority: Bool = false) {
        let count = Self.shotTakes[family] ?? 0
        let name = count > 0 ? "\(family)_\(Int.random(in: 1...count))" : family
        guard ioReady, engine.isRunning, let u = urls[name], let file = try? AVAudioFile(forReading: u) else { return }
        let now = Date().timeIntervalSinceReferenceDate
        let voice: Voice
        if let free = shots.first(where: { $0.busyUntil <= now }) {
            voice = free
        } else if priority, let soonest = shots.min(by: { $0.busyUntil < $1.busyUntil }) {
            voice = soonest
        } else {
            return
        }
        let speed = Float.random(in: rate)
        voice.player.stop()
        voice.speed.rate = speed
        voice.mix.volume = volume
        voice.mix.pan = max(-1, min(1, pan))
        voice.player.scheduleFile(file, at: nil)
        voice.player.play()
        voice.busyUntil = now + Double(file.length) / file.fileFormat.sampleRate / Double(speed) + 0.1
    }
}
