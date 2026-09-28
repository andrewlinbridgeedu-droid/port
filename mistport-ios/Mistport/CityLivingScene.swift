import SwiftUI

// MARK: - Harbour clock

/// Home-harbour time. One game day (24 game hours) lasts 48 real minutes, so a
/// game hour is two real minutes. The day is aligned to local midnight: the
/// same wall-clock minute always shows the same harbour hour.
enum HarborClock {
    static let realSecondsPerGameHour: TimeInterval = 120

    /// Game hours elapsed since the reference day; used for weather, which
    /// must carry on across midnight.
    static func gameHours(at date: Date) -> Double {
        #if DEBUG
        if let debug = HarborClockDebug.override {
            return debug.startHour + date.timeIntervalSince(debug.launch) * debug.scale / realSecondsPerGameHour
        }
        #endif
        // Local seconds, so the harbour day starts at local midnight
        // (86 400 s is exactly thirty game days).
        let local = date.timeIntervalSinceReferenceDate + Double(TimeZone.current.secondsFromGMT(for: date))
        return local / realSecondsPerGameHour
    }

    static func hour(at date: Date) -> Double { wrap(gameHours(at: date)) }

    static func wrap(_ hour: Double) -> Double {
        let h = hour.truncatingRemainder(dividingBy: 24)
        return h < 0 ? h + 24 : h
    }
}

#if DEBUG
/// Review-only launch arguments: `-MistportCityHour 18.2` pins the starting
/// hour, `-MistportCityTimeScale 20` speeds the day up, `-MistportCityRain 0.8`
/// forces rain, `-MistportCitySeason summer` pins the season,
/// `-MistportCityNightCloud 0.9` forces an overcast night, `-MistportCityStorm 1`
/// forces a thunderstorm (with `-MistportCityRain`). Walkers, birds, ships and raindrops keep their real speed.
private struct HarborClockDebug {
    let startHour: Double
    let scale: Double
    let launch: Date

    static let override: HarborClockDebug? = {
        let defaults = UserDefaults.standard
        guard let text = defaults.string(forKey: "MistportCityHour"), let start = Double(text) else { return nil }
        let scale = defaults.string(forKey: "MistportCityTimeScale").flatMap(Double.init) ?? 1
        return HarborClockDebug(startHour: start, scale: scale, launch: Date())
    }()

    static let rain: Double? = UserDefaults.standard.string(forKey: "MistportCityRain").flatMap(Double.init)
    static let season: HarborSeason? = UserDefaults.standard.string(forKey: "MistportCitySeason").flatMap(HarborSeason.init(rawValue:))
    static let nightCloud: Double? = UserDefaults.standard.string(forKey: "MistportCityNightCloud").flatMap(Double.init)
    static let storm: Double? = UserDefaults.standard.string(forKey: "MistportCityStorm").flatMap(Double.init)
    static let gust: Double? = UserDefaults.standard.string(forKey: "MistportCityGust").flatMap(Double.init)
    /// `-MistportCitySnowCover 0.6`: snow lying in the town (winter only).
    static let snowCover: Double? = UserDefaults.standard.string(forKey: "MistportCitySnowCover").flatMap(Double.init)
    static let nearLightning = UserDefaults.standard.string(forKey: "MistportCityLightning") == "near"
    /// Freeze a strike at this many seconds after it began (screenshots).
    static let lightningFrozen: Double? = UserDefaults.standard.string(forKey: "MistportCityLightningAt").flatMap(Double.init)
}

/// Offline frame renders (tools/city-daynight/render) pin the real clock, so
/// walkers, ships, rain and lightning can be drawn at any chosen moment.
enum HarborRenderClock {
    nonisolated(unsafe) static var now: Date?
}
#endif

// MARK: - Painting

/// The hub paintings are 16:9 (4096 × 2305). Everything drawn over them uses
/// painting units: y down from the top edge and x across from the left edge,
/// both as fractions of the painting's height, so x runs 0 … `aspect`.
enum HarborPainting {
    static let aspect = 4096.0 / 2305.0

    /// Where the painting sits in a view it fills (as `scaledToFill` places it).
    static func rect(in size: CGSize) -> CGRect {
        let unit = max(size.height, size.width / aspect)
        let width = unit * aspect
        return CGRect(x: (size.width - width) / 2, y: (size.height - unit) / 2, width: width, height: unit)
    }
}

// MARK: - Seasons

/// One set of paintings in the hub's composition: day, sunset and the unlit
/// night (deep night reuses it, with the last lamps and windows still burning
/// in the light layer), plus the switchable light layer and its order map.
struct HarborPlateSet: Equatable {
    let prefix: String

    var plates: [String] { ["Day", "Sunset", "Night", "Night"].map { prefix + $0 } }
    var lights: String { prefix + "Lights" }
    var lightOrder: String { prefix + "LightOrder" }

    /// Winter with snow lying, revealed over the bare winter set as it settles.
    static let winterSnow = HarborPlateSet(prefix: "CityWinterSnow")
}

/// Seasons follow each other every seven game days (5.6 real hours) and turn
/// at 02:30 in the deep of the night, cross-fading over a quarter of a game
/// hour. Each has its own paintings, and sets the weather (rain,
/// thunderstorms, snow, falling leaves).
enum HarborSeason: String, CaseIterable {
    case spring, summer, autumn, winter

    /// Calendar order.
    static let cycle: [HarborSeason] = [.spring, .summer, .autumn, .winter]
    static let gameDaysPerSeason = 7.0
    static let turnHour = 2.5
    static let turnLength = 0.25

    var plateSet: HarborPlateSet {
        switch self {
        case .spring: return HarborPlateSet(prefix: "CitySpring")
        case .summer: return HarborPlateSet(prefix: "CitySummer")
        case .autumn: return HarborPlateSet(prefix: "CityAutumn")
        case .winter: return HarborPlateSet(prefix: "CityWinter")
        }
    }

    /// Where the sun meets the sea (painting x): the afterglow of the sunset
    /// painting, beside the lighthouse at the right end of the harbour.
    var sunsetX: Double { 1.72 }

    struct State {
        let current: HarborSeason
        let previous: HarborSeason
        let mix: Double              // 0 → previous only, 1 → current only
        let next: HarborSeason?      // set when the next turn is under half a game hour away
    }

    static func state(gameHours g: Double) -> State {
        #if DEBUG
        if let forced = HarborClockDebug.season { return State(current: forced, previous: forced, mix: 1, next: nil) }
        #endif
        let period = gameDaysPerSeason * 24
        let since = g - turnHour
        let k = Int(floor(since / period))
        let within = since - Double(k) * period
        func at(_ i: Int) -> HarborSeason { cycle[((i % cycle.count) + cycle.count) % cycle.count] }
        let mix = within < turnLength ? smooth(within / turnLength) : 1
        let next: HarborSeason? = period - within < 0.5 && at(k + 1) != at(k) ? at(k + 1) : nil
        return State(current: at(k), previous: at(k - 1), mix: mix, next: next)
    }
}

// MARK: - Weather

/// Occasional rain: about half of the harbour days have one or two showers of
/// 1.5–4.5 game hours, from drizzle to downpour, fading in and out.
struct HarborWeather {
    /// Rain, or snow in winter: 0 dry … 1 downpour / heavy snow. Varies
    /// within a shower: it picks up, eases off and comes in bursts.
    let rain: Double
    let wind: Double     // slant of rain and snow, -1 … 1
    let gust: Double     // wind strength 0 … 1 (drives rain curtains, blizzards, the wind sound)
    /// Summer thunderstorm, 0 … 1: dark sky, downpour, lightning and thunder.
    let storm: Double
    /// Dark cloud over the night sky (0 clear … 1 the moon is gone). About
    /// four nights in ten are overcast; thinner cover lets the moon look
    /// through now and then.
    let nightCloud: Double

    /// One shower, snowfall or storm.
    struct Spell {
        let start: Double      // game hours
        let length: Double
        let strength: Double
        let slant: Double
        let gust: Double
        let storm: Bool
        let seed: Int
    }

    /// Precipitation of one harbour day, by season:
    /// spring — showers on half the days, mostly light, sometimes heavy;
    /// summer — a thunderstorm on a third of the days (afternoon or evening), otherwise the odd short shower;
    /// autumn — long drizzle or steady rain on over half the days;
    /// winter — snow on half the days, from flurries to a heavy, wind-driven fall.
    static func spells(day d: Int) -> [Spell] {
        let season = HarborSeason.state(gameHours: Double(d) * 24 + 12).current
        let base = Double(d) * 24
        func h(_ k: Int) -> Double { hash01(d, 900 + k) }
        func tier(_ r: Double, _ light: ClosedRange<Double>, _ mid: ClosedRange<Double>, _ heavy: ClosedRange<Double>,
                  _ pLight: Double, _ pMid: Double, _ u: Double) -> Double {
            let band = r < pLight ? light : (r < pLight + pMid ? mid : heavy)
            return band.lowerBound + (band.upperBound - band.lowerBound) * u
        }
        var list: [Spell] = []
        switch season {
        case .spring:
            let count = h(0) < 0.5 ? 0 : (h(0) < 0.85 ? 1 : 2)
            for k in 0..<count {
                let strength = tier(h(10 + k), 0.15...0.35, 0.40...0.70, 0.75...1.0, 0.55, 0.30, h(20 + k))
                list.append(Spell(start: base + 24 * h(1 + k), length: 1 + 3 * h(30 + k), strength: strength,
                                  slant: (h(40 + k) - 0.5) * 1.2, gust: 0.15 + 0.4 * strength, storm: false, seed: d * 10 + k))
            }
        case .summer:
            if h(0) < 0.35 {
                list.append(Spell(start: base + 13 + 6 * h(1), length: 1.2 + 1.3 * h(2), strength: 0.85 + 0.15 * h(3),
                                  slant: (h(4) < 0.5 ? -1 : 1) * (0.5 + 0.4 * h(5)), gust: 0.7 + 0.3 * h(6), storm: true, seed: d * 10))
            } else if h(0) < 0.55 {
                let strength = 0.25 + 0.45 * h(3)
                list.append(Spell(start: base + 24 * h(1), length: 0.5 + 1.0 * h(2), strength: strength,
                                  slant: (h(4) - 0.5) * 1.0, gust: 0.2 + 0.3 * strength, storm: false, seed: d * 10))
            }
        case .autumn:
            let count = h(0) < 0.45 ? 0 : (h(0) < 0.85 ? 1 : 2)
            for k in 0..<count {
                let strength = tier(h(10 + k), 0.15...0.30, 0.35...0.60, 0.65...0.90, 0.5, 0.35, h(20 + k))
                list.append(Spell(start: base + 24 * h(1 + k), length: 2 + 4 * h(30 + k), strength: strength,
                                  slant: (h(40 + k) - 0.5) * 1.4, gust: 0.25 + 0.45 * strength, storm: false, seed: d * 10 + k))
            }
        case .winter:
            let count = h(0) < 0.5 ? 0 : (h(0) < 0.85 ? 1 : 2)
            for k in 0..<count {
                let strength = tier(h(10 + k), 0.10...0.30, 0.35...0.65, 0.70...1.0, 0.45, 0.35, h(20 + k))
                let blizzard = strength > 0.7 && h(50 + k) < 0.6
                list.append(Spell(start: base + 24 * h(1 + k), length: 2 + 4 * h(30 + k), strength: strength,
                                  slant: (h(40 + k) < 0.5 ? -1 : 1) * (blizzard ? 0.8 + 0.2 * h(41 + k) : 0.1 + 0.4 * h(41 + k)),
                                  gust: blizzard ? 0.8 + 0.2 * h(42 + k) : 0.1 + 0.3 * strength, storm: false, seed: d * 10 + k))
            }
        }
        return list
    }

    init(gameHours g: Double) {
        nightCloud = HarborWeather.nightCloud(g)
        #if DEBUG
        if let forced = HarborClockDebug.rain {
            storm = HarborClockDebug.storm ?? 0
            gust = HarborClockDebug.gust ?? min(1, 0.15 + 0.5 * forced + 0.4 * storm)
            rain = forced; wind = storm > 0 || gust > 0.6 ? 0.8 : 0.35
            return
        }
        #endif
        let day = Int(floor(g / 24))
        var amount = 0.0, slant = 0.3, windAmount = 0.12, stormAmount = 0.0
        for d in (day - 1)...day {
            for spell in HarborWeather.spells(day: d) {
                let envelope = smooth((g - spell.start) / min(0.5, spell.length * 0.3))
                    * (1 - smooth((g - (spell.start + spell.length - 0.5)) / 0.5))
                guard envelope > 0 else { continue }
                // Rain comes and goes inside a shower: slow swells plus short bursts.
                let seed = Double(spell.seed)
                let swell = 0.5 + 0.5 * sin(g * 9.1 + seed * 1.7) * sin(g * 3.7 + seed)
                let burst = pow(max(0, sin(g * 23 + seed * 2.3)), 6)
                let level = spell.strength * envelope * (0.55 + 0.35 * swell + 0.25 * burst)
                if level > amount {
                    amount = min(1, level)
                    slant = spell.slant
                    windAmount = spell.gust * envelope * (0.75 + 0.25 * swell)
                    stormAmount = spell.storm ? envelope : 0
                }
            }
        }
        rain = amount; wind = slant; storm = stormAmount
        gust = max(windAmount, 0.12)
    }

    static func nightCloud(_ g: Double) -> Double {
        #if DEBUG
        if let forced = HarborClockDebug.nightCloud { return forced }
        #endif
        // A night belongs to the day it begins on (noon to noon).
        let night = Int(floor((g - 12) / 24))
        guard hash01(night, 950) < 0.4 else { return 0 }
        let h = g - Double(night) * 24 - 12          // 0 at noon, 12 at midnight
        let cover = 0.6 + 0.4 * hash01(night, 951)
        let envelope = smooth((h - 5.8) / 1.6) * (1 - smooth((h - 17.2) / 1.6))
        // Slow breaks in the cloud (a few per night) unless it is thick.
        let breaks = 0.5 + 0.5 * sin(g * 1.3 + 6.28 * hash01(night, 952))
        return envelope * min(1, cover + (1 - cover) * 0.3 + 0.25 * (1 - breaks) * (1 - cover) * 4)
    }
}

// MARK: - Lightning

/// Lightning during a thunderstorm, as a function of real time so the flash,
/// the bolt and the thunder (see CityAmbience) all agree. Slots of seven
/// real seconds; in a full storm most slots carry one strike, near or far.
/// Snow lying in the town, 0 … 1. While it snows the cover grows toward what
/// the fall can build (a flurry only dusts the roofs, a heavy fall whitens
/// everything within about three game hours); once it stops it melts over
/// about a game day and a half. Worked out from the weather of the last
/// three game days, once per game hour.
enum HarborSnowCover {
    nonisolated(unsafe) private static var cache: (hour: Int, value: Double)?

    static func at(gameHours g: Double) -> Double {
        #if DEBUG
        if let forced = HarborClockDebug.snowCover { return forced }
        #endif
        let hour = Int(floor(g))
        if let cached = cache, cached.hour == hour { return cached.value }
        var cover = 0.0
        for h in (hour - 72)...hour {
            let at = Double(h) + 0.5
            let winter = HarborSeason.state(gameHours: at).current == .winter
            let fall = winter ? HarborWeather(gameHours: at).rain : 0
            if fall > 0.03 {
                let reach = 0.25 + 0.75 * fall
                if reach > cover { cover += (reach - cover) * (0.25 + 0.3 * fall) }
            } else {
                cover = max(0, cover - (winter ? 1.0 / 36 : 0.25))
            }
        }
        cache = (hour, cover)
        return cover
    }
}

enum HarborLightning {
    static let slot = 7.0

    struct Strike {
        let time: Double       // real seconds (reference date)
        let x: Double          // painting x of the bolt
        let near: Bool         // near strikes show a bolt and a loud crack
        let seed: Int
    }

    static func strike(slot k: Int, storm: Double) -> Strike? {
        guard storm > 0.05, hash01(k, 700) < 0.9 * storm else { return nil }
        var near = hash01(k, 701) < 0.55
        #if DEBUG
        if HarborClockDebug.nearLightning { near = true }
        #endif
        return Strike(time: (Double(k) + 0.1 + 0.7 * hash01(k, 702)) * slot,
                      x: 0.40 + 1.00 * hash01(k, 703), near: near, seed: k)
    }

    /// The most recent strike still lit at time t, with its flicker level 0 … 1.
    static func current(at t: Double, storm: Double) -> (Strike, Double)? {
        #if DEBUG
        if let dt = HarborClockDebug.lightningFrozen {
            let s = Strike(time: 0, x: 0.95, near: true, seed: 11)
            return (s, flicker(dt, seed: s.seed))
        }
        #endif
        let k = Int(floor(t / slot))
        for j in [k, k - 1] {
            guard let s = strike(slot: j, storm: storm) else { continue }
            let dt = t - s.time
            if dt >= 0 && dt < 1.4 { return (s, flicker(dt, seed: s.seed)) }
        }
        return nil
    }

    /// A main stroke, a dark gap, often a re-strike, then the afterglow.
    /// Long enough to be seen at 30 frames a second: the main stroke, a dark
    /// gap, usually one or two re-strikes, then a fading afterglow.
    static func flicker(_ dt: Double, seed: Int) -> Double {
        let restrikes = hash01(seed, 704) < 0.35 ? 2 : (hash01(seed, 704) < 0.85 ? 1 : 0)
        if dt < 0.10 { return 1 }
        if dt < 0.16 { return 0.22 }
        if restrikes >= 1 && dt < 0.26 { return 0.9 }
        if restrikes >= 1 && dt < 0.31 { return 0.25 }
        if restrikes == 2 && dt < 0.40 { return 0.75 }
        let from = restrikes == 2 ? 0.40 : (restrikes == 1 ? 0.31 : 0.16)
        return 0.55 * exp(-(dt - from) / 0.28)
    }
}

// MARK: - Light of the hour

/// Which painting is showing and how added figures should be lit.
struct HarborLight {
    let from: Int
    let to: Int
    let mix: Double
    let weights: [Double]   // day, sunset, night, deep night

    init(hour h: Double) {
        // Holds: day 6.2–16.2, sunset 17.6–18.8, night 19.9–23.2, deep night 0–4.5.
        let fades: [(Double, Double, Int, Int)] = [
            (4.5, 6.2, 3, 0), (16.2, 17.6, 0, 1), (18.8, 19.9, 1, 2), (23.2, 24.0, 2, 3)]
        var from = 3, to = 3, mix = 0.0
        if let fade = fades.first(where: { h >= $0.0 && h < $0.1 }) {
            from = fade.2; to = fade.3; mix = smooth((h - fade.0) / (fade.1 - fade.0))
        } else if h >= 6.2 && h < 16.2 {
            from = 0; to = 0
        } else if h >= 17.6 && h < 18.8 {
            from = 1; to = 1
        } else if h >= 19.9 && h < 23.2 {
            from = 2; to = 2
        }
        var w = [0.0, 0, 0, 0]
        w[from] += 1 - mix
        w[to] += mix
        self.from = from; self.to = to; self.mix = mix; weights = w
    }

    var day: Double { weights[0] }
    var sunset: Double { weights[1] }
    var dark: Double { weights[2] + weights[3] }

    /// Multiplier applied to added figures so they sit in the painting's light.
    var ambient: RGB {
        RGB(1, 1, 1) * weights[0] + RGB(1.0, 0.80, 0.64) * weights[1]
            + RGB(0.34, 0.36, 0.52) * weights[2] + RGB(0.23, 0.25, 0.39) * weights[3]
    }

    /// Strength of direct sunlight (drives lit sides and cast shadows).
    var sun: Double { weights[0] + weights[1] * 0.85 }

    /// Share of the city's lamps and windows switched on (dusk, 17:54–21:00).
    static func lampsOn(_ h: Double) -> Double {
        if h >= 6.2 && h < 17.9 { return 0 }
        if h >= 17.9 && h < 21.0 { return (h - 17.9) / 3.1 }
        return 1
    }

    /// Progress along the switch-off ramp: most windows go dark between 22:00
    /// and 01:30 (0 … 0.8); street lamps, the lighthouse and the last windows
    /// go out at dawn, 04:30–06:06 (0.8 … 1).
    static func lampsOff(_ h: Double) -> Double {
        if h >= 6.2 && h < 22.0 { return 0 }
        let late = h < 12 ? h + 24 : h
        if late < 28.5 { return 0.8 * clamp((late - 22.0) / 3.5) }
        return 0.8 + 0.2 * clamp((late - 28.5) / 1.6)
    }

    /// Plate that will be needed within the next half hour (decoded ahead).
    static func upcoming(after hour: Double) -> Int {
        let next = HarborLight(hour: HarborClock.wrap(hour + 0.5))
        return next.mix > 0 ? next.to : next.from
    }
}

// MARK: - Scene

/// The home harbour through a day: the four paintings cross-fade with the
/// hour; the sun, the blood moon, gulls, ships and people are drawn on top in
/// the painting's own coordinates (the paintings share one composition).
struct CityLivingScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 5 : 1.0 / 30.0)) { timeline in
            let now = Self.pinned(timeline.date)
            let hour = HarborClock.hour(at: now)
            let light = HarborLight(hour: hour)
            let seasons = HarborSeason.state(gameHours: HarborClock.gameHours(at: now))
            let weather = HarborWeather(gameHours: HarborClock.gameHours(at: now))
            let season = seasons.current
            let upcoming = HarborLight.upcoming(after: hour)
            let t = reduceMotion ? 0 : now.timeIntervalSinceReferenceDate
            let lampsOn = (HarborLight.lampsOn(hour) * 400).rounded() / 400
            let lampsOff = (HarborLight.lampsOff(hour) * 400).rounded() / 400
            let snow = (HarborSnowCover.at(gameHours: HarborClock.gameHours(at: now)) * 100).rounded() / 100

            GeometryReader { geometry in
                let rain = weather.rain
                let storm = weather.storm
                // Even drizzle comes from a grey sky: cover rises faster than the rain.
                let cover = smooth(rain / 0.08) * (0.45 + 0.55 * rain)
                let snowing = season == .winter
                // Snow cloud is pale; storm cloud is heavy and dark.
                let overcast = (snowing ? RGB(0.80, 0.82, 0.87) : RGB(0.60, 0.63, 0.68))
                    .mix(RGB(0.20, 0.22, 0.28), storm).mix(RGB(0.10, 0.11, 0.15), light.dark)
                let lightning = reduceMotion ? nil : HarborLightning.current(at: t, storm: storm)
                let flash = lightning?.1 ?? 0
                ZStack {
                    ZStack {
                        if seasons.mix < 1 {
                            scenery(seasons.previous, light: light, upcoming: upcoming, lamps: (lampsOn, lampsOff),
                                    snow: snow, in: geometry.size)
                        }
                        scenery(season, light: light, upcoming: upcoming, lamps: (lampsOn, lampsOff),
                                snow: snow, in: geometry.size)
                            .opacity(seasons.mix)
                        if let next = seasons.next {
                            // Decode the coming season's night painting before the turn.
                            plate(next.plateSet, 3, in: geometry.size).opacity(0.001)
                        }
                        Canvas { context, size in
                            var painter = HarborPainter(size: size, hour: hour, t: t, light: light, rain: cover,
                                                        nightCloud: weather.nightCloud * light.dark, wind: weather.wind,
                                                        snow: season == .winter, lightning: lightning,
                                                        sunsetX: season.sunsetX, still: reduceMotion,
                                                        moon: context.resolve(Image("CityBloodMoon")))
                            painter.cloudImage = context.resolve(Image("CityCloudNight"))
                            painter.draw(in: &context)
                        }
                        let autumn = (season == .autumn ? seasons.mix : 0) + (seasons.previous == .autumn ? 1 - seasons.mix : 0)
                        if autumn > 0.01 && !reduceMotion {
                            Canvas { context, size in
                                HarborLeaves(size: size, t: t, wind: weather.wind, rain: rain, light: light)
                                    .draw(in: context)
                            }
                            .opacity(autumn)
                        }
                    }
                    .compositingGroup()
                    // Under cloud the hard sunlight goes: flatter, greyer, darker.
                    .saturation(1 - 0.45 * cover - 0.20 * storm)
                    .contrast(1 - 0.30 * cover + 0.08 * storm)
                    .brightness(-0.07 * cover - 0.16 * storm)

                    if rain > 0.01 {
                        Rectangle()
                            .fill(RGB(0.62, 0.66, 0.74).mix(RGB(0.42, 0.45, 0.55), max(light.dark, storm * 0.8)).color())
                            .opacity(0.45 * cover + 0.2 * storm)
                            .blendMode(.multiply)
                        if snowing {
                            // Pale snow cloud; mist swallows the far shore.
                            LinearGradient(stops: [.init(color: overcast.color(0.88 * cover), location: 0.0),
                                                   .init(color: overcast.color(0.72 * cover), location: 0.17),
                                                   .init(color: overcast.color(0.45 * cover), location: 0.26),
                                                   .init(color: overcast.color(0.14 * cover), location: 0.36),
                                                   .init(color: .clear, location: 0.5)],
                                           startPoint: .top, endPoint: .bottom)
                        } else {
                            Canvas { context, size in
                                HarborOvercast(size: size, t: t, cover: cover, storm: storm, wind: weather.wind, light: light)
                                    .draw(in: context)
                            }
                        }
                        Canvas { context, size in
                            if snowing {
                                HarborSnow(size: size, t: t, amount: rain, wind: weather.wind, gust: weather.gust, light: light)
                                    .draw(in: context)
                            } else {
                                var shower = HarborRain(size: size, t: t, rain: rain, wind: weather.wind, gust: weather.gust, light: light)
                                shower.textures = ["CityRainFar", "CityRainMid", "CityRainNear"].map { context.resolve(Image($0)) }
                                shower.draw(in: context)
                            }
                        }
                    }
                    if let lightning, lightning.1 > 0.01 {
                        // The bolt and its cloud glow, above the storm cloud and the rain.
                        Canvas { context, size in
                            HarborPainter(size: size, hour: hour, t: t, light: light, rain: cover, nightCloud: 0, wind: 0,
                                          snow: false, lightning: lightning, sunsetX: season.sunsetX, still: reduceMotion,
                                          moon: context.resolve(Image("CityBloodMoon")))
                                .drawLightning(context)
                        }
                    }
                    if flash > 0.01 {
                        // The whole harbour lights up for an instant, bluish white.
                        Rectangle()
                            .fill(RGB(0.80, 0.84, 1.0).color())
                            .opacity(flash * (lightning!.0.near ? 0.55 : 0.30))
                            .blendMode(.screen)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { CityAmbience.shared.start() }
        .onDisappear { CityAmbience.shared.stop() }
    }

    /// The moment to draw: the timeline's, unless an offline render pins it.
    static func pinned(_ date: Date) -> Date {
        #if DEBUG
        if let pinned = HarborRenderClock.now { return pinned }
        #endif
        return date
    }

    /// A season's paintings with their lamps. In winter the snowy paintings
    /// (and their own lamplight on the snow) are revealed over the bare ones
    /// as the snow settles, and taken away again as it melts.
    @ViewBuilder
    private func scenery(_ season: HarborSeason, light: HarborLight, upcoming: Int, lamps: (on: Double, off: Double),
                         snow: Double, in size: CGSize) -> some View {
        ZStack {
            lit(season.plateSet, light: light, upcoming: upcoming, lamps: lamps, in: size)
            if season == .winter && snow > 0.005 {
                lit(.winterSnow, light: light, upcoming: upcoming, lamps: lamps, in: size)
                    .mask { HarborSnowMask(cover: snow).equatable() }
            }
        }
    }

    private func lit(_ set: HarborPlateSet, light: HarborLight, upcoming: Int, lamps: (on: Double, off: Double),
                     in size: CGSize) -> some View {
        ZStack {
            plates(set, light: light, upcoming: upcoming, in: size)
            if lamps.on > 0 && lamps.off < 1 {
                HarborLampsLayer(on: lamps.on, off: lamps.off, lights: set.lights, order: set.lightOrder)
                    .equatable()
                    .opacity(0.6 + 0.4 * light.dark)
                    .blendMode(.plusLighter)
            }
        }
        .compositingGroup()
    }

    @ViewBuilder
    private func plates(_ set: HarborPlateSet, light: HarborLight, upcoming: Int, in size: CGSize) -> some View {
        ZStack {
            plate(set, light.from, in: size)
            if light.to != light.from {
                plate(set, light.to, in: size).opacity(light.mix)
            }
            if upcoming != light.from && upcoming != light.to {
                // Keep the next painting decoded before its fade begins.
                plate(set, upcoming, in: size).opacity(0.001)
            }
        }
    }

    private func plate(_ set: HarborPlateSet, _ index: Int, in size: CGSize) -> some View {
        Image(decorative: set.plates[index])
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
    }
}

// MARK: - Snow cover

/// Where snow lies at a given cover: each spot of the snow order map turns
/// white once the cover passes its time (red channel, stored as 1 - time) —
/// roofs, branches and ledges first, open paving last, in soft patches.
private struct HarborSnowMask: View, Equatable {
    let cover: Double

    var body: some View {
        Canvas { context, size in
            let order = context.resolve(Image("CityWinterSnowOrder").interpolation(.high))
            context.addFilter(.alphaThreshold(min: max(0.002, 1 - cover), color: .white))
            context.addFilter(.colorMatrix(HarborLampsLayer.channelToAlpha(red: true)))
            context.draw(order, in: HarborPainting.rect(in: size))
        }
        .blur(radius: 1.2)
        .allowsHitTesting(false)
    }
}

// MARK: - City lamps

/// The lit night painting's lamps and windows over the unlit one, switched
/// one by one: every light has its own switch-on time at dusk (red channel of
/// the order map, stored as 1 - time) and switch-off time (green channel,
/// see `HarborLight.lampsOff`). Street lamps come on first and go out at
/// dawn; most windows go dark after midnight.
private struct HarborLampsLayer: View, Equatable {
    let on: Double
    let off: Double
    let lights: String
    let order: String

    var body: some View {
        Canvas { context, size in
            let rect = HarborPainting.rect(in: size)
            let order = context.resolve(Image(self.order).interpolation(.none))
            context.clipToLayer { layer in
                layer.addFilter(.alphaThreshold(min: max(0.002, 1 - on), color: .white))
                layer.addFilter(.colorMatrix(Self.channelToAlpha(red: true)))
                layer.draw(order, in: rect)
            }
            if off > 0 {
                context.clipToLayer { layer in
                    layer.addFilter(.alphaThreshold(min: min(1, off + 0.002), color: .white))
                    layer.addFilter(.colorMatrix(Self.channelToAlpha(red: false)))
                    layer.draw(order, in: rect)
                }
            }
            context.draw(context.resolve(Image(lights)), in: rect)
        }
        .allowsHitTesting(false)
    }

    static func channelToAlpha(red: Bool) -> ColorMatrix {
        var m = ColorMatrix()
        m.r1 = 0; m.g2 = 0; m.b3 = 0; m.a4 = 0
        m.r5 = 1; m.g5 = 1; m.b5 = 1
        if red { m.a1 = 1 } else { m.a2 = 1 }
        return m
    }
}

// MARK: - Rain

/// Rain between the viewer and the harbour: three depths of falling
/// streaks, each a tiled texture of tapered streaks (faint tail, brighter
/// head — tools/city-daynight/textures), slanted by the wind. Drizzle shows
/// mostly the fine far layer; a downpour doubles the layers and adds the
/// long, soft near streaks and grey curtains sweeping across in the gusts.
private struct HarborRain {
    let size: CGSize
    let t: Double
    let rain: Double
    let wind: Double
    let gust: Double
    let light: HarborLight
    /// Far, middle and near streak textures.
    var textures: [GraphicsContext.ResolvedImage] = []

    func draw(in context: GraphicsContext) {
        let r = rain
        let colour = RGB(0.92, 0.94, 0.98).mix(RGB(0.60, 0.64, 0.76), light.dark)
        let unit = size.height
        // Horizontal drift per unit of fall: the wind leans the rain.
        let shear = CGFloat(wind * (0.10 + 0.32 * gust))
        // (tile size in view heights, fall in tiles per second, opacity)
        let layers: [(CGFloat, Double, Double)] = [
            (0.30, 2.6, 0.30 + 0.45 * r),
            (0.52, 2.1, r < 0.08 ? 0 : 0.12 + 0.62 * r),
            (0.95, 1.6, 0.80 * pow(r, 1.2))]
        let reach = abs(shear) * size.height
        for (i, layer) in layers.enumerated() where i < textures.count {
            let (scale, speed, alpha) = layer
            guard alpha > 0.01 else { continue }
            let h = unit * scale, w = h
            var g = context
            g.addFilter(.colorMultiply(colour.color()))
            g.concatenate(CGAffineTransform(a: 1, b: 0, c: shear, d: 1, tx: 0, ty: 0))
            let passes = i < 2 && r > 0.45 ? 2 : 1
            for pass in 0..<passes {
                var sheet = g
                sheet.opacity = min(1, alpha) * (pass == 0 ? 1 : min(1, (r - 0.45) * 1.8))
                let fall = fract(t * speed * (pass == 0 ? 1 : 1.09) + (pass == 0 ? 0 : 0.37)) * h
                let dx = pass == 0 ? 0 : w * 0.5
                var y = -h + fall
                while y < size.height {
                    var x = floor((-reach - dx) / w) * w + dx
                    while x < size.width + reach {
                        sheet.draw(textures[i], in: CGRect(x: x, y: y, width: w, height: h))
                        x += w
                    }
                    y += h
                }
            }
        }
        // Curtains of rain in heavy downpours, driven across by the wind.
        let curtains = clamp((r - 0.55) / 0.45) * (0.5 + 0.5 * gust)
        guard curtains > 0.01 else { return }
        let wide = max(1, Double(size.width / size.height))
        let slant = wind * (0.12 + 0.35 * gust) / wide
        var g = context
        g.addFilter(.blur(radius: size.width * 0.02))
        let dir: Double = wind >= 0 ? 1 : -1
        for k in 0..<Int(3 * wide) {
            let speed = (0.035 + 0.03 * hash01(k, 30)) / wide
            let x = fract(hash01(k, 31) + dir * t * speed) * 1.6 - 0.3
            let w = (0.12 + 0.12 * hash01(k, 32)) / wide
            var band = Path()
            band.move(to: CGPoint(x: (x - w / 2) * size.width, y: -0.05 * size.height))
            band.addLine(to: CGPoint(x: (x + w / 2) * size.width, y: -0.05 * size.height))
            band.addLine(to: CGPoint(x: (x + w / 2 + slant * 0.5) * size.width, y: 1.05 * size.height))
            band.addLine(to: CGPoint(x: (x - w / 2 + slant * 0.5) * size.width, y: 1.05 * size.height))
            band.closeSubpath()
            g.fill(band, with: .color(colour.mix(RGB(0.6, 0.63, 0.7), 0.4).color(0.16 * curtains)))
        }
    }
}

// MARK: - Rain cloud

/// The deck of rain cloud over the harbour: the painting's own clouds turned
/// grey (CityStormSky, made from the day painting's sky, so it keeps the
/// painting's brushwork), and over it a thin sheet of drifting cloud so the
/// sky moves. Grey by day, darker in a storm, warm at sunset, dark at night.
private struct HarborOvercast {
    let size: CGSize
    let t: Double
    let cover: Double
    let storm: Double
    let wind: Double
    let light: HarborLight

    func draw(in context: GraphicsContext) {
        let rect = HarborPainting.rect(in: size)
        let unit = rect.height
        let tint = RGB(1, 1, 1).mix(RGB(0.70, 0.72, 0.78), storm)
            .mix(RGB(1.0, 0.80, 0.68), 0.5 * light.sunset)
            .mix(RGB(0.22, 0.24, 0.32), light.dark)
        var deck = context
        deck.opacity = min(1, cover * 1.25)
        deck.addFilter(.colorMultiply(tint.color()))
        deck.draw(context.resolve(Image("CityStormSky")),
                  in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: unit * 0.30))
        let mist = context.resolve(Image("CityCloudStorm"))
        let h = unit * 0.40, w = h * 3.2
        let drift = fract(t * (0.006 + 0.012 * abs(wind)) * unit / w) * w
        var sheet = context
        sheet.opacity = min(1, cover) * (0.28 + 0.27 * storm)
        sheet.addFilter(.colorMultiply(tint.color()))
        var x = rect.minX - drift
        while x < rect.maxX {
            sheet.draw(mist, in: CGRect(x: x, y: rect.minY - unit * 0.03, width: w, height: h))
            x += w
        }
    }
}

// MARK: - Snow

/// Winter's precipitation. A few big, slow flakes in flurries; a steady fall
/// of many; in a heavy, wind-driven fall the flakes stream sideways, blur
/// into short streaks and the far shore whitens out.
private struct HarborSnow {
    let size: CGSize
    let t: Double
    let amount: Double
    let wind: Double
    let gust: Double
    let light: HarborLight

    func draw(in context: GraphicsContext) {
        let a = amount
        let unit = size.height / 900
        let colour = RGB(0.97, 0.98, 1.0).mix(RGB(0.70, 0.74, 0.86), light.dark)
        // Whiteout: the distance dissolves in falling snow.
        let whiteout = clamp((a - 0.45) / 0.55) * (0.4 + 0.6 * gust)
        if whiteout > 0.01 {
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(stops: [.init(color: colour.color(0.10 * whiteout), location: 0),
                                 .init(color: colour.color(0.42 * whiteout), location: 0.25),
                                 .init(color: colour.color(0.22 * whiteout), location: 0.45),
                                 .init(color: colour.color(0.06 * whiteout), location: 0.75)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        }
        let wide = max(1, Double(size.width / size.height))
        let drive = wind * (0.05 + 0.45 * gust) / wide
        let streaky = clamp((gust - 0.55) / 0.35) * clamp((a - 0.5) / 0.3)
        // (count, radius, seconds to fall, sway, blur, alpha)
        let layers: [(Double, Double, Double, Double, CGFloat, Double)] = [
            (360 * wide * pow(a, 0.9), 1.5, 16, 0.010 / wide, 0, 0.70),
            (190 * wide * pow(a, 0.8), 2.8, 10, 0.018 / wide, 0, 0.85),
            ((28 + 36 * a) * wide, 5.6 - 1.4 * a, 6, 0.030 / wide, 1.4, 0.92)]
        for (index, layer) in layers.enumerated() {
            let (countValue, radius, fallTime, sway, blur, alpha) = layer
            let count = Int(countValue)
            guard count > 0 else { continue }
            var flakes = Path()
            var streaks = Path()
            let speedUp = 1 + 1.2 * gust
            for i in 0..<count {
                let fall = fract(t * speedUp / (fallTime * (0.8 + 0.5 * hash01(i, index, 61))) + hash01(i, index, 62))
                let y = -0.03 + fall * 1.06
                let swing = sway * (1 - 0.6 * gust) * sin(t * (0.6 + 0.8 * hash01(i, index, 63)) + 6.28 * hash01(i, index, 64))
                let x = fract(hash01(i, index, 65) + (0.04 / wide + drive) * fall * 1.5 + swing)
                let r = CGFloat(radius * (0.7 + 0.6 * hash01(i, index, 66))) * unit
                let c = CGPoint(x: CGFloat(x) * size.width, y: CGFloat(y) * size.height)
                if index < 2 && hash01(i, index, 67) < streaky * 0.5 {
                    let stretch = CGFloat(3 + 6 * hash01(i, index, 68))
                    let dx = CGFloat(drive * wide) * r * stretch * 2.5, dy = r * stretch * 0.6
                    streaks.move(to: CGPoint(x: c.x - dx, y: c.y - dy))
                    streaks.addLine(to: c)
                } else {
                    flakes.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                }
            }
            var g = context
            if blur > 0 { g.addFilter(.blur(radius: blur * unit)) }
            g.fill(flakes, with: .color(colour.color(alpha * (0.6 + 0.4 * a))))
            var soft = context
            soft.addFilter(.blur(radius: 0.8 * unit))
            soft.stroke(streaks, with: .color(colour.color(alpha * 0.7)), style: StrokeStyle(lineWidth: radius * 1.6 * unit, lineCap: .round))
        }
    }
}

// MARK: - Falling leaves

/// Autumn: leaves come down all over the town, not only in front of the
/// viewer. Three depths in painting coordinates: many tiny leaves drifting
/// down over the far streets and canals, some over the middle distance, and
/// only a few large ones passing close to the viewer.
private struct HarborLeaves {
    let size: CGSize
    let t: Double
    let wind: Double
    let rain: Double
    let light: HarborLight

    func draw(in context: GraphicsContext) {
        let rect = HarborPainting.rect(in: size)
        let side = rect.height
        let origin = rect.origin
        let aspect = HarborPainting.aspect
        let colours = [RGB(0.86, 0.36, 0.08), RGB(0.74, 0.18, 0.07), RGB(0.95, 0.64, 0.16),
                       RGB(0.62, 0.30, 0.10), RGB(0.90, 0.48, 0.12)]
        let ambient = light.ambient.mix(RGB(1, 1, 1), 0.15)
        let air = RGB(0.72, 0.74, 0.82).mix(RGB(0.2, 0.22, 0.34), light.dark)
        // (count, top y, bottom y, x range, fall height, size, fall seconds, haze)
        let layers: [(Int, Double, Double, Double, Double, Double, Double, Double)] = [
            (46, 0.26, 0.50, aspect, 0.035, 0.0022, 7, 0.45),   // far streets and the harbour front
            (22, 0.44, 0.78, aspect, 0.070, 0.0045, 8, 0.2),    // plaza, market and the walk
            (7, -0.05, 1.05, aspect, 1.10, 0.012, 14, 0)]       // close to the viewer
        for (layer, spec) in layers.enumerated() {
            let (count, top, bottom, width, fallHeight, leafSize, fallTime, haze) = spec
            for i in 0..<count {
                let seed = layer * 100 + i
                let duration = fallTime * (0.8 + 0.5 * hash01(seed, 81)) * (1 + 0.6 * rain)
                let cycle = floor(t / duration + hash01(seed, 82))
                let progress = fract(t / duration + hash01(seed, 82))
                // Each fall starts from a new spot in its band.
                let startX = width * hash01(seed, Int(cycle), 83)
                let startY = top + (bottom - top) * hash01(seed, Int(cycle), 84)
                let y = startY + fallHeight * progress
                let sway = fallHeight * 0.35 * sin(t * (0.8 + 0.6 * hash01(seed, 85)) + Double(i) * 1.7)
                let x = startX + (0.04 + wind * 0.05) * fallHeight / 0.1 * progress + sway
                let s = CGFloat(leafSize * (0.7 + 0.6 * hash01(seed, 86))) * side
                guard s > 0.6 else { continue }
                let fadeInOut = min(1, min(progress, 1 - progress) * 8)
                let spin = t * (1.2 + 2.4 * hash01(seed, 87)) * (hash01(seed, 88) < 0.5 ? 1 : -1)
                let flip = CGFloat(cos(t * (1.6 + 1.8 * hash01(seed, 89)) + Double(i)))
                var g = context
                g.opacity = fadeInOut * 0.95
                g.translateBy(x: origin.x + CGFloat(x) * side, y: origin.y + CGFloat(y) * side)
                g.rotate(by: .radians(spin))
                g.scaleBy(x: max(0.18, abs(flip)), y: 1)
                if layer == 2 { g.addFilter(.blur(radius: s * 0.06)) }
                let base = (colours[Int(hash01(seed, 90) * Double(colours.count)) % colours.count] * ambient).mix(air, haze)
                var leaf = Path()
                leaf.move(to: CGPoint(x: 0, y: -s))
                leaf.addQuadCurve(to: CGPoint(x: 0, y: s), control: CGPoint(x: s * 0.9, y: -s * 0.1))
                leaf.addQuadCurve(to: CGPoint(x: 0, y: -s), control: CGPoint(x: -s * 0.9, y: -s * 0.1))
                leaf.closeSubpath()
                g.fill(leaf, with: .color((flip > 0 ? base : base * 0.72).color()))
                if s > 4 {
                    var rib = Path()
                    rib.move(to: CGPoint(x: 0, y: -s * 0.8)); rib.addLine(to: CGPoint(x: 0, y: s * 1.25))
                    g.stroke(rib, with: .color((base * 0.55).color(0.8)), lineWidth: max(0.5, s * 0.07))
                }
            }
        }
    }
}

// MARK: - Painter

private struct HarborPainter {
    let origin: CGPoint
    /// Painting height in points: one painting unit.
    let side: CGFloat
    let aspect = HarborPainting.aspect
    let hour: Double
    let t: Double
    let light: HarborLight
    let rain: Double
    let nightCloud: Double
    let wind: Double
    let snow: Bool
    let lightning: (HarborLightning.Strike, Double)?
    let sunsetX: Double
    let still: Bool
    let moon: GraphicsContext.ResolvedImage
    /// Drifting night cloud texture (CityCloudNight).
    var cloudImage: GraphicsContext.ResolvedImage?

    init(size: CGSize, hour: Double, t: Double, light: HarborLight, rain: Double, nightCloud: Double, wind: Double,
         snow: Bool, lightning: (HarborLightning.Strike, Double)?, sunsetX: Double, still: Bool,
         moon: GraphicsContext.ResolvedImage) {
        let rect = HarborPainting.rect(in: size)
        side = rect.height
        origin = rect.origin
        self.hour = hour; self.t = t; self.light = light; self.rain = rain; self.nightCloud = nightCloud
        self.wind = wind; self.snow = snow; self.lightning = lightning; self.sunsetX = sunsetX
        self.still = still; self.moon = moon
    }

    func p(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: origin.x + CGFloat(x) * side, y: origin.y + CGFloat(y) * side)
    }

    func len(_ v: Double) -> CGFloat { CGFloat(v) * side }

    mutating func draw(in context: inout GraphicsContext) {
        // Cloud cover hides the sun and moon and their light on the water.
        let clear = clamp(1 - 1.4 * rain)
        var sky = context
        sky.opacity = clear
        drawDawn(sky)
        sky.clip(to: skyPath())
        drawSun(sky)
        drawMoon(sky)
        drawNightClouds(sky)
        var water = context
        water.opacity = (1 - rain) * (1 - nightCloud)
        drawReflections(water)
        if !snow { splashWater(context) }
        drawFlocks(context)
        drawShips(context)
        drawHarborGulls(context)
        drawPeople(context)
        drawNearGull(context)
    }

    // MARK: Sky

    /// Land/sky boundary traced from the paintings: 256 columns across the
    /// width (tools/city-daynight/newplates/skyline.py with
    /// skyline-prior-seasons.json). Mountains, the bell tower, the castle and
    /// the far islands count as land; the sun and moon go down behind them.
    static let skyline: [Double] = [
        0.1158, 0.101, 0.1112, 0.1095, 0.1059, 0.1032, 0.1046, 0.1105, 0.1169, 0.1265, 0.1296, 0.1296, 0.1275, 0.1275, 0.1275, 0.1254,
        0.1246, 0.1176, 0.1103, 0.1165, 0.1137, 0.1133, 0.1083, 0.11, 0.1126, 0.1137, 0.118, 0.1193, 0.1266, 0.1296, 0.1318, 0.1357,
        0.1371, 0.135, 0.1339, 0.1403, 0.1445, 0.1509, 0.1535, 0.1594, 0.1668, 0.1658, 0.1668, 0.169, 0.1707, 0.1722, 0.1761, 0.1732,
        0.186, 0.1764, 0.1764, 0.1764, 0.1775, 0.1779, 0.1775, 0.1945, 0.1807, 0.1817, 0.1817, 0.1817, 0.1838, 0.1924, 0.1847, 0.1838,
        0.1838, 0.1966, 0.1949, 0.1067, 0.0718, 0.0723, 0.068, 0.0574, 0.0521, 0.0298, 0.0542, 0.0554, 0.067, 0.0809, 0.085, 0.114,
        0.1892, 0.1892, 0.1881, 0.187, 0.1838, 0.1828, 0.1828, 0.1791, 0.1764, 0.1652, 0.1669, 0.17, 0.1734, 0.1782, 0.1807, 0.1785,
        0.1764, 0.1743, 0.1753, 0.1743, 0.1732, 0.1701, 0.1685, 0.1892, 0.1742, 0.1679, 0.1624, 0.1518, 0.1492, 0.138, 0.126, 0.123,
        0.1222, 0.1184, 0.1169, 0.1123, 0.1104, 0.112, 0.1179, 0.1217, 0.1265, 0.1286, 0.1296, 0.1314, 0.1383, 0.1403, 0.1471, 0.1509,
        0.1541, 0.1541, 0.153, 0.152, 0.1509, 0.1561, 0.1583, 0.1615, 0.1631, 0.1625, 0.1632, 0.1646, 0.163, 0.1594, 0.1544, 0.1522,
        0.1541, 0.152, 0.153, 0.152, 0.15, 0.1456, 0.1403, 0.1371, 0.1339, 0.1312, 0.1296, 0.1339, 0.135, 0.1399, 0.1424, 0.1453,
        0.1615, 0.1518, 0.152, 0.152, 0.1509, 0.1477, 0.1413, 0.1413, 0.1525, 0.1233, 0.1233, 0.1449, 0.1447, 0.1562, 0.1498, 0.1498,
        0.153, 0.1481, 0.1373, 0.1197, 0.1126, 0.1322, 0.136, 0.1477, 0.169, 0.1711, 0.1668, 0.1658, 0.1668, 0.164, 0.1637, 0.1637,
        0.1612, 0.1583, 0.1541, 0.1511, 0.1462, 0.1424, 0.1413, 0.1392, 0.1429, 0.1446, 0.1483, 0.15, 0.152, 0.1521, 0.1573, 0.1562,
        0.1554, 0.1509, 0.1571, 0.1662, 0.1731, 0.1732, 0.1838, 0.187, 0.186, 0.1892, 0.1881, 0.186, 0.1848, 0.1807, 0.183, 0.1899,
        0.1969, 0.2115, 0.2115, 0.22, 0.22, 0.221, 0.2226, 0.2253, 0.2333, 0.2359, 0.2418, 0.203, 0.1987, 0.1985, 0.1955, 0.1968,
        0.1966, 0.1917, 0.1913, 0.1913, 0.1934, 0.1955, 0.1977, 0.1987, 0.1987, 0.1977, 0.1999, 0.2019, 0.203, 0.2069, 0.2104, 0.2125
    ]

    /// Where the open sea meets the far islands (right of the harbour).
    static let horizon = 0.248

    func skyPath() -> Path {
        var path = Path()
        path.move(to: p(0, -0.8))
        path.addLine(to: p(aspect, -0.8))
        let line = Self.skyline
        path.addLine(to: p(aspect, line[line.count - 1]))
        for i in stride(from: line.count - 1, through: 0, by: -1) {
            path.addLine(to: p((Double(i) + 0.5) / Double(line.count) * aspect, line[i]))
        }
        path.addLine(to: p(0, line[0]))
        path.closeSubpath()
        return path
    }

    func drawDawn(_ context: GraphicsContext) {
        // Warm light spreads from behind the eastern (left) mountains before sunrise,
        // and a rose afterglow lingers where the sun set.
        let dawn = bell(hour, 5.7, 1.15)
        let dusk = bell(hour, 18.95, 0.7)
        guard dawn > 0.01 || dusk > 0.01 else { return }
        var g = context
        g.blendMode = .screen
        // Soft oval glows: a round gradient squashed vertically, so the glow
        // fades out everywhere instead of stopping at an oval edge.
        func glow(at c: CGPoint, radius: CGFloat, squash: CGFloat, _ stops: [Color]) {
            var e = g
            e.translateBy(x: c.x, y: c.y)
            e.scaleBy(x: 1, y: squash)
            e.fill(circle(.zero, radius), with: .radialGradient(Gradient(colors: stops + [.clear]),
                                                                center: .zero, startRadius: 0, endRadius: radius))
        }
        if dawn > 0.01 {
            glow(at: p(0.22, 0.16), radius: len(0.62), squash: 0.64,
                 [RGB(1, 0.62, 0.36).color(0.55 * dawn), RGB(0.95, 0.46, 0.48).color(0.22 * dawn)])
        }
        if dusk > 0.01 {
            glow(at: p(sunsetX, 0.22), radius: len(0.42), squash: 0.6, [RGB(1, 0.5, 0.35).color(0.35 * dusk)])
        }
    }

    /// Sun rises behind the eastern (left) mountains around 06:20, passes
    /// high over the town and sets behind the far islands right of the
    /// lighthouse around 18:35, where the sunset painting glows.
    static func sunPosition(_ h: Double, sunsetX: Double) -> (x: Double, y: Double)? {
        guard h > 5.6 && h < 18.95 else { return nil }
        let s = (h - 5.8) / 12.9
        let base = 0.19 + (horizon - 0.19) * s
        return (0.17 + (sunsetX - 0.17) * s, base - 0.66 * sin(.pi * s))
    }

    func drawSun(_ context: GraphicsContext) {
        guard let s = Self.sunPosition(hour, sunsetX: sunsetX), s.y > -0.1 else { return }
        let c = p(s.x, s.y)
        let r = len(0.0085)
        let alt = clamp((Self.horizon - s.y) / 0.22)
        let core = RGB(1.0, 0.56, 0.24).mix(RGB(1.0, 0.98, 0.93), alt * alt)
        let glow = RGB(1.0, 0.40, 0.12).mix(RGB(1.0, 0.92, 0.76), alt)
        var g = context
        g.blendMode = .screen
        g.fill(circle(c, r * 46), with: .radialGradient(
            Gradient(colors: [glow.color(0.26 + 0.2 * (1 - alt)), glow.color(0.07), .clear]),
            center: c, startRadius: 0, endRadius: r * 46))
        g.fill(circle(c, r * 11), with: .radialGradient(
            Gradient(colors: [core.color(0.85), glow.color(0.35), .clear]),
            center: c, startRadius: r * 0.6, endRadius: r * 11))
        // Low sun: flattened by refraction, with a thin haze streak.
        var d = context
        d.translateBy(x: c.x, y: c.y)
        d.scaleBy(x: 1, y: 1 - 0.14 * (1 - alt))
        // The disk is far brighter than any sky: a pale core, colour only at the rim.
        let rim = RGB(1.0, 0.78, 0.46).mix(RGB(1.0, 0.95, 0.86), alt)
        d.fill(circle(.zero, r), with: .radialGradient(
            Gradient(stops: [.init(color: RGB(1, 1, 0.95).color(), location: 0),
                             .init(color: RGB(1, 0.96, 0.80).mix(core, 0.15).color(), location: 0.7),
                             .init(color: rim.color(), location: 1)]),
            center: .zero, startRadius: 0, endRadius: r))
        if alt < 0.35 {
            var streak = context
            streak.blendMode = .screen
            let k = (0.35 - alt) / 0.35
            streak.translateBy(x: c.x, y: c.y)
            streak.scaleBy(x: 1, y: 0.03)
            streak.fill(circle(.zero, r * 9), with: .radialGradient(Gradient(colors: [glow.color(0.45 * k), .clear]),
                                                                  center: .zero, startRadius: 0, endRadius: r * 9))
        }
    }

    /// Blood moon: rises from behind the tall peak above the town after dusk,
    /// hangs over the castle hill through the night (inside the hub's default
    /// view) and pales away at dawn.
    static let moonPath: [(h: Double, x: Double, y: Double)] = [
        (19.2, 0.842, 0.165), (19.9, 0.852, 0.118), (20.8, 0.872, 0.086), (22.0, 0.900, 0.064),
        (24.0, 0.940, 0.050), (26.5, 0.990, 0.047), (28.8, 1.040, 0.053), (30.6, 1.080, 0.062)]

    static func moonPosition(_ hour: Double) -> (x: Double, y: Double, fade: Double)? {
        let h = hour < 12 ? hour + 24 : hour
        guard h >= moonPath.first!.h, h <= moonPath.last!.h else { return nil }
        let (x, y) = catmullRom(moonPath.map { ($0.h, $0.x, $0.y) }, h)
        return (x, y, 1 - smooth((h - 29.2) / 1.2))
    }

    func drawMoon(_ context: GraphicsContext) {
        guard let (x, y, clearFade) = Self.moonPosition(hour) else { return }
        let fade = clearFade * (1 - 0.85 * nightCloud)
        guard fade > 0.01 else { return }
        let low = clamp((y - 0.07) / 0.09)
        let r = len(0.0462) * (1 + 0.07 * low)
        let c = p(x, y)
        var g = context
        g.blendMode = .screen
        g.fill(circle(c, r * 2.8), with: .radialGradient(
            Gradient(colors: [RGB(0.95, 0.32, 0.18).color(0.34 * fade), RGB(0.6, 0.12, 0.1).color(0.12 * fade), .clear]),
            center: c, startRadius: r * 0.9, endRadius: r * 2.8))
        var m = context
        m.opacity *= fade
        m.translateBy(x: c.x, y: c.y)
        m.scaleBy(x: 1, y: 1 - 0.06 * low)
        m.draw(moon, in: CGRect(x: -r * 1.05, y: -r * 1.05, width: r * 2.1, height: r * 2.1))
        if low > 0.02 {
            // Near the horizon the moon is seen through more air: darker, redder.
            m.blendMode = .multiply
            m.fill(circle(.zero, r), with: .color(RGB(0.55, 0.16, 0.10).mix(RGB(1, 1, 1), 1 - 0.6 * low).color()))
        }
    }

    /// Heavy night cloud drifting over the sky: a veil darkens the whole sky
    /// (lighter toward the horizon, where the town's lamps glow on the cloud
    /// base), and two sheets of cloud texture drift across it, a high far one
    /// and a lower, nearer, faster one. Where they cross the moon it goes out.
    func drawNightClouds(_ context: GraphicsContext) {
        guard nightCloud > 0.01 else { return }
        let top = RGB(0.07, 0.08, 0.13)
        let base = RGB(0.24, 0.20, 0.22)
        let c = nightCloud
        context.fill(Path(CGRect(x: p(0, -0.2).x, y: p(0, -0.2).y, width: len(aspect), height: len(0.46))),
                     with: .linearGradient(Gradient(stops: [.init(color: top.color(0.55 * c), location: 0),
                                                            .init(color: top.mix(base, 0.4).color(0.42 * c), location: 0.72),
                                                            .init(color: base.color(0.30 * c), location: 1)]),
                                           startPoint: p(0, -0.2), endPoint: p(0, 0.26)))
        guard let cloud = cloudImage else { return }
        // (height, top, drift in painting units per second, opacity)
        let sheets: [(Double, Double, Double, Double)] = [(0.22, -0.02, 0.0016, 0.85), (0.30, 0.01, 0.0030, 0.80)]
        for (height, top, speed, alpha) in sheets {
            let w = height * 3.2
            let drift = fract(t * speed * (0.6 + wind) / w) * w
            var g = context
            g.opacity = c * alpha
            var x = -drift
            while x < aspect {
                g.draw(cloud, in: CGRect(x: p(x, top).x, y: p(x, top).y, width: len(w), height: len(height)))
                x += w
            }
        }
    }

    /// The bolt of a near strike, from the cloud base down behind the far
    /// shore, and the glow of the cloud it came from. Far strikes only light
    /// the cloud.
    func drawLightning(_ base: GraphicsContext) {
        guard let (strike, level) = lightning, level > 0.01 else { return }
        var context = base
        context.clip(to: skyPath())
        // The storm cloud lights up from inside in uneven cells.
        var glow = context
        glow.blendMode = .screen
        glow.addFilter(.blur(radius: len(0.02)))
        let skyRect = CGRect(x: p(0, -0.2).x, y: p(0, -0.2).y, width: len(aspect), height: len(0.45))
        for cell in 0..<7 {
            let c = p(strike.x + (hash01(strike.seed, cell, 720) - 0.5) * 0.34, 0.01 + 0.13 * hash01(strike.seed, cell, 721))
            let r = len(0.08 + 0.14 * hash01(strike.seed, cell, 722))
            glow.fill(Path(skyRect), with: .radialGradient(
                Gradient(colors: [RGB(0.88, 0.90, 1.0).color(0.55 * level), RGB(0.75, 0.8, 1.0).color(0.16 * level), .clear]),
                center: c, startRadius: 0, endRadius: r))
        }
        guard strike.near else { return }
        var points: [CGPoint] = []
        var x = strike.x
        var y = -0.02
        var i = 0
        while y < 0.235 {
            points.append(p(x, y))
            y += 0.012 + 0.02 * hash01(strike.seed, i, 710)
            x += (hash01(strike.seed, i, 711) - 0.5) * 0.028
            i += 1
        }
        var bolt = Path()
        bolt.addLines(points)
        for b in 0..<5 {
            let from = Int(Double(points.count) * (0.15 + 0.6 * hash01(strike.seed, b, 712)))
            guard from < points.count else { continue }
            var bx = Double((points[from].x - origin.x) / side), by = Double((points[from].y - origin.y) / side)
            let dir = hash01(strike.seed, b, 713) < 0.5 ? -1.0 : 1.0
            bolt.move(to: points[from])
            for j in 0..<5 {
                bx += dir * (0.006 + 0.012 * hash01(strike.seed, b * 10 + j, 714))
                by += 0.008 + 0.012 * hash01(strike.seed, b * 10 + j, 715)
                bolt.addLine(to: p(bx, by))
            }
        }
        // A wide blue halo, a white-hot glow, then the thin core.
        var halo = context
        halo.blendMode = .screen
        halo.addFilter(.blur(radius: len(0.009)))
        halo.stroke(bolt, with: .color(RGB(0.62, 0.70, 1.0).color(0.9 * level)),
                    style: StrokeStyle(lineWidth: len(0.018), lineCap: .round, lineJoin: .round))
        var inner = context
        inner.addFilter(.blur(radius: len(0.0025)))
        inner.stroke(bolt, with: .color(RGB(0.90, 0.93, 1.0).color(0.95 * level)),
                     style: StrokeStyle(lineWidth: len(0.006), lineCap: .round, lineJoin: .round))
        context.stroke(bolt, with: .color(RGB(1, 1, 1).color(level)),
                       style: StrokeStyle(lineWidth: max(1.5, len(0.0024)), lineCap: .round, lineJoin: .round))
    }

    /// Open water, traced from the spring day painting: the bay either side
    /// of the bell tower, the inner harbour below the quay, the open sea and
    /// outer harbour right of the castle hill, and the canal by the bridge.
    static let waters: [[(Double, Double)]] = [
        [(0.280, 0.202), (0.470, 0.202), (0.470, 0.270), (0.400, 0.275), (0.300, 0.262), (0.270, 0.240)],
        [(0.555, 0.202), (0.660, 0.202), (0.660, 0.215), (0.620, 0.225), (0.600, 0.238), (0.560, 0.240)],
        [(0.930, 0.318), (1.360, 0.318), (1.360, 0.372), (1.290, 0.372), (1.285, 0.330), (1.220, 0.330),
         (1.215, 0.370), (1.200, 0.345), (1.175, 0.345), (1.170, 0.385), (1.100, 0.385), (1.080, 0.360),
         (1.020, 0.370), (0.990, 0.375), (0.930, 0.375)],
        [(1.440, 0.249), (1.777, 0.249), (1.777, 0.490), (1.735, 0.490), (1.730, 0.465), (1.700, 0.465),
         (1.680, 0.500), (1.620, 0.500), (1.620, 0.440), (1.668, 0.440), (1.668, 0.345), (1.509, 0.345),
         (1.509, 0.410), (1.345, 0.410), (1.345, 0.310), (1.400, 0.280), (1.440, 0.265)],
        [(0.385, 0.407), (0.465, 0.407), (0.478, 0.425), (0.460, 0.440), (0.390, 0.437)],
        [(0.388, 0.455), (0.440, 0.458), (0.440, 0.486), (0.388, 0.486)]]
    /// Rain rings per water at full rain, roughly by area.
    static let waterDrops = [12, 5, 18, 50, 5, 4]

    /// Things standing in front of the water: ships pass behind them and no
    /// reflection falls on them.
    static let bellTower: [(Double, Double)] = [
        (0.510, 0.018), (0.513, 0.050), (0.530, 0.060), (0.545, 0.075), (0.548, 0.090), (0.552, 0.140),
        (0.555, 0.200), (0.565, 0.215), (0.568, 0.260), (0.570, 0.400), (0.440, 0.400), (0.443, 0.260),
        (0.448, 0.225), (0.465, 0.200), (0.468, 0.140), (0.472, 0.090), (0.475, 0.075), (0.490, 0.060),
        (0.507, 0.050)]
    static let lighthouse: [(Double, Double)] = [
        (1.738, 0.251), (1.745, 0.256), (1.750, 0.268), (1.750, 0.340), (1.777, 0.340), (1.777, 0.376),
        (1.673, 0.376), (1.673, 0.350), (1.700, 0.342), (1.726, 0.340), (1.726, 0.268), (1.731, 0.256)]
    static let chimneys: [[(Double, Double)]] = [
        [(1.485, 0.427), (1.509, 0.427), (1.512, 0.560), (1.482, 0.560)],
        [(1.590, 0.413), (1.615, 0.413), (1.618, 0.560), (1.587, 0.560)],
        [(1.704, 0.468), (1.730, 0.468), (1.733, 0.560), (1.701, 0.560)]]

    func occluders() -> Path {
        var path = polygon(Self.bellTower)
        path.addPath(polygon(Self.lighthouse))
        for chimney in Self.chimneys { path.addPath(polygon(chimney)) }
        return path
    }

    /// A broken column of light on the water under a low sun or the moon.
    func drawReflections(_ context: GraphicsContext) {
        var water = context
        var mask = Path()
        for outline in Self.waters { mask.addPath(polygon(outline)) }
        water.clip(to: mask)
        water.clip(to: occluders(), options: .inverse)
        water.blendMode = .screen
        if let m = Self.moonPosition(hour), m.y < Self.horizon {
            let strength = m.fade * light.dark * clamp((Self.horizon - m.y) / 0.03)
            glitter(water, x: m.x, colour: RGB(0.95, 0.30, 0.18), strength: strength * 0.8, width: 0.028, seed: 3)
        }
        if let s = Self.sunPosition(hour, sunsetX: sunsetX), s.y < Self.horizon {
            let low = 1 - clamp((Self.horizon - s.y) / 0.16)
            let strength = low * clamp((Self.horizon - s.y) / 0.01) * (0.6 + 0.4 * light.sunset)
            glitter(water, x: s.x, colour: RGB(1.0, 0.78, 0.45), strength: strength, width: 0.022, seed: 7)
        }
    }

    func glitter(_ context: GraphicsContext, x: Double, colour: RGB, strength: Double, width: Double, seed: Int) {
        guard strength > 0.01 else { return }
        var y = 0.197
        var row = 0
        while y < 0.52 {
            // Rows get thicker and the column wider toward the viewer; only
            // the rows that fall on water show.
            let depth = (y - 0.197) / 0.32
            let rowH = 0.0012 + 0.0026 * depth
            let jitter = sin(t * (1.3 + hash01(seed, row) * 1.4) + Double(row) * 2.1)
            let halfW = width * (0.35 + 0.9 * depth) * (0.55 + 0.45 * hash01(seed, row, 2)) * (0.8 + 0.2 * jitter)
            let cx = x + width * 0.25 * (hash01(seed, row, 3) - 0.5) + 0.002 * sin(t * 0.7 + Double(row))
            let a = strength * (0.75 - 0.45 * depth) * (0.55 + 0.45 * jitter)
            if a > 0.01 {
                let rect = CGRect(x: p(cx - halfW, y).x, y: p(0, y).y, width: len(halfW * 2), height: len(rowH))
                context.fill(Path(ellipseIn: rect), with: .linearGradient(
                    Gradient(colors: [.clear, colour.color(a), .clear]),
                    startPoint: CGPoint(x: rect.minX, y: rect.midY), endPoint: CGPoint(x: rect.maxX, y: rect.midY)))
            }
            y += rowH * 1.9
            row += 1
        }
    }

    /// Paved ground where rain bursts into crowns: outline, and the height of
    /// a standing person at its top and bottom edge.
    static let pavements: [(outline: [(Double, Double)], h0: Double, h1: Double)] = [
        ([(0.35, 0.60), (0.58, 0.60), (0.64, 0.66), (0.70, 0.76), (0.76, 0.90), (0.85, 1.0), (0.0, 1.0),
          (0.0, 0.86), (0.10, 0.76), (0.20, 0.68), (0.30, 0.63)], 0.045, 0.16),          // the walk
        ([(1.30, 0.72), (1.60, 0.70), (1.66, 0.80), (1.60, 0.95), (1.28, 0.95)], 0.040, 0.050), // market square
        ([(0.92, 0.66), (1.15, 0.66), (1.15, 0.74), (0.92, 0.745)], 0.024, 0.027)]       // lower courtyard

    /// Rings on the bay, the harbour and the canal, and drops bursting on the
    /// walk, the market street and the courtyard.
    func splashWater(_ context: GraphicsContext) {
        guard rain > 0.02 else { return }
        let colour = RGB(0.86, 0.90, 0.95).mix(RGB(0.7, 0.72, 0.8), light.dark)
        var rings = Path()
        for (w, water) in Self.waters.enumerated() {
            let (x0, x1, y0, y1) = bounds(water)
            for i in 0..<Int(Double(Self.waterDrops[w]) * rain) {
                let cycle = 0.7 + 0.5 * hash01(i, w, 5)
                let k = floor(t / cycle + hash01(i, w, 6))
                let phase = fract(t / cycle + hash01(i, w, 6))
                let x = x0 + (x1 - x0) * hash01(i, Int(k), w * 7 + 1)
                let y = y0 + (y1 - y0) * hash01(i, Int(k), w * 7 + 2)
                guard Self.inside(water, x, y) else { continue }
                let size = 0.003 + 0.010 * clamp((y - 0.2) / 0.3)
                let r = size * (0.2 + 0.8 * phase) * (0.5 + 0.8 * hash01(i, Int(k), w * 7 + 3))
                let c = p(x, y)
                rings.addEllipse(in: CGRect(x: c.x - len(r), y: c.y - len(r * 0.3), width: len(r * 2), height: len(r * 0.6)))
            }
        }
        context.stroke(rings, with: .color(colour.color(0.16 * rain)), lineWidth: 0.5)
        var crowns = Path()
        for (g, ground) in Self.pavements.enumerated() {
            let (x0, x1, y0, y1) = bounds(ground.outline)
            for i in 0..<Int(40 * rain) {
                let cycle = 0.35 + 0.25 * hash01(i, g, 40)
                let k = floor(t / cycle + hash01(i, g, 41))
                let phase = fract(t / cycle + hash01(i, g, 41))
                guard phase < 0.45 else { continue }
                let x = x0 + (x1 - x0) * hash01(i, Int(k), g * 5 + 42)
                let y = y0 + (y1 - y0) * hash01(i, Int(k), g * 5 + 43)
                guard Self.inside(ground.outline, x, y) else { continue }
                let person = ground.h0 + (ground.h1 - ground.h0) * clamp((y - y0) / max(y1 - y0, 0.001))
                let h = person * 0.10 * (0.5 + phase)
                let c = p(x, y)
                for spoke in [-1.0, 0.0, 1.0] {
                    crowns.move(to: CGPoint(x: c.x + len(h * 0.2 * spoke), y: c.y))
                    crowns.addLine(to: CGPoint(x: c.x + len(h * 0.7 * spoke), y: c.y - len(h * (1 - 0.3 * abs(spoke)))))
                }
            }
        }
        context.stroke(crowns, with: .color(colour.color(0.45 * rain)), lineWidth: 0.7)
    }

    func bounds(_ outline: [(Double, Double)]) -> (Double, Double, Double, Double) {
        let xs = outline.map { $0.0 }, ys = outline.map { $0.1 }
        return (xs.min()!, xs.max()!, ys.min()!, ys.max()!)
    }

    /// Point in polygon (even–odd rule), in painting units.
    static func inside(_ outline: [(Double, Double)], _ x: Double, _ y: Double) -> Bool {
        var result = false
        var j = outline.count - 1
        for i in 0..<outline.count {
            let (xi, yi) = outline[i], (xj, yj) = outline[j]
            if (yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi { result.toggle() }
            j = i
        }
        return result
    }

    // MARK: Birds

    static func birdDensity(_ h: Double) -> Double {
        piecewise(h, [(0, 0), (5.2, 0), (6.2, 0.7), (7.5, 1), (17.0, 1), (18.6, 0.7), (19.6, 0.1), (20.2, 0), (24, 0)])
    }

    func birdTone(backlit: Bool) -> (body: RGB, tips: RGB) {
        let ambient = light.ambient
        if backlit {
            let dark = RGB(0.16, 0.17, 0.21).mix(RGB(0.14, 0.08, 0.07), light.sunset)
            return (dark, dark * 0.8)
        }
        return (RGB(0.94, 0.94, 0.91) * ambient, RGB(0.22, 0.22, 0.25) * ambient)
    }

    /// A gull seen at a distance: the M of the wings changes with the beat.
    func drawGull(_ context: GraphicsContext, at c: CGPoint, span: CGFloat, up: Double, heading: Double,
                  tone: (body: RGB, tips: RGB), alpha: Double) {
        guard alpha > 0.01 else { return }
        let w = span / 2
        let u = CGFloat(up)
        let wristY = -(0.12 + 0.34 * u) * w
        let tipY = wristY + (0.14 + 0.2 * max(0, -u) - 0.08 * max(0, u)) * w
        var g = context
        g.opacity *= alpha
        if span < 5 {
            var path = Path()
            path.move(to: CGPoint(x: c.x - w, y: c.y + tipY))
            path.addQuadCurve(to: c, control: CGPoint(x: c.x - 0.42 * w, y: c.y + wristY - 0.08 * w))
            path.addQuadCurve(to: CGPoint(x: c.x + w, y: c.y + tipY), control: CGPoint(x: c.x + 0.42 * w, y: c.y + wristY - 0.08 * w))
            g.stroke(path, with: .color(tone.body.color()), style: StrokeStyle(lineWidth: max(0.7, span * 0.11), lineCap: .round, lineJoin: .round))
            return
        }
        for s in [-1.0, 1.0] as [CGFloat] {
            func q(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: c.x + s * x * w, y: c.y + y) }
            var wing = Path()
            wing.move(to: q(0.05, -0.03 * w))
            wing.addQuadCurve(to: q(0.46, wristY), control: q(0.22, wristY - 0.12 * w))
            wing.addLine(to: q(1.0, tipY))
            wing.addQuadCurve(to: q(0.46, wristY + 0.13 * w), control: q(0.74, (wristY + tipY) / 2 + 0.12 * w))
            wing.addQuadCurve(to: q(0.05, 0.05 * w), control: q(0.22, wristY * 0.4 + 0.11 * w))
            wing.closeSubpath()
            g.fill(wing, with: .color(tone.body.color()))
            var tip = Path()
            tip.move(to: q(0.74, wristY + (tipY - wristY) * 0.5 - 0.02 * w))
            tip.addLine(to: q(1.0, tipY))
            tip.addLine(to: q(0.70, wristY + (tipY - wristY) * 0.55 + 0.09 * w))
            tip.closeSubpath()
            g.fill(tip, with: .color(tone.tips.color()))
        }
        let hx = CGFloat(heading)
        g.fill(Path(ellipseIn: CGRect(x: c.x - 0.16 * w + hx * 0.03 * w, y: c.y - 0.045 * w, width: 0.32 * w, height: 0.1 * w)),
               with: .color(tone.body.color()))
        g.fill(circle(CGPoint(x: c.x + hx * 0.17 * w, y: c.y - 0.02 * w), 0.055 * w), with: .color(tone.body.color()))
    }

    func wingBeat(_ seed: Int, rate: Double = 3.1) -> Double {
        let burst = fract(t / (5 + 4 * hash01(seed, 71)) + hash01(seed, 72))
        return burst < 0.45 ? sin(2 * .pi * (t * rate + hash01(seed, 73))) : 0.24
    }

    /// Gulls circling on slow, tilted loops: most over the harbour below the
    /// castle hill, a few over the bay left of the bell tower.
    func drawHarborGulls(_ context: GraphicsContext) {
        let density = Self.birdDensity(hour) * (1 - rain)
        guard density > 0.01 else { return }
        for i in 0..<10 {
            let appear = smooth((density - hash01(i, 8) * 0.85) / 0.15)
            guard appear > 0.01 else { continue }
            let overHarbour = i < 7
            let cx = overHarbour ? 0.92 + 0.42 * hash01(i, 1) : 0.28 + 0.14 * hash01(i, 1)
            let cy = overHarbour ? 0.215 + 0.075 * hash01(i, 2) : 0.150 + 0.040 * hash01(i, 2)
            let rx = 0.018 + 0.032 * hash01(i, 3), ry = rx * 0.32
            let period = 16 + 18 * hash01(i, 4)
            let dir = hash01(i, 5) < 0.5 ? 1.0 : -1.0
            let a = dir * 2 * .pi * t / period + 6.28 * hash01(i, 6)
            let x = cx + rx * cos(a), y = cy + ry * sin(a) + 0.004 * sin(t * 0.3 + Double(i))
            let near = 0.85 + 0.15 * sin(a)
            let span = len((0.0068 + 0.004 * hash01(i, 7)) * near)
            drawGull(context, at: p(x, y), span: span, up: wingBeat(i), heading: -sin(a) * dir >= 0 ? 1 : -1,
                     tone: birdTone(backlit: light.sunset > 0.5), alpha: appear)
        }
    }

    /// Loose V-flocks crossing high over the bay.
    func drawFlocks(_ context: GraphicsContext) {
        for slot in 0..<3 {
            let period = 110 + 50 * hash01(slot, 11), duration = (36 + 14 * hash01(slot, 12)) * 1.6
            for run in runs(period: period, duration: duration, slot: slot + 100) {
                let startHour = HarborClock.hour(at: Date(timeIntervalSinceReferenceDate: run.start))
                guard Self.birdDensity(startHour) * (1 - rain) > hash01(slot, run.k, 6) else { continue }
                let d = hash01(slot, run.k, 3) < 0.5 ? 1.0 : -1.0
                let y0 = 0.05 + 0.10 * hash01(slot, run.k, 4)
                let x = d > 0 ? -0.08 + (aspect + 0.16) * run.progress : aspect + 0.08 - (aspect + 0.16) * run.progress
                let y = y0 + 0.02 * sin(run.progress * 3 + Double(run.k))
                let count = 4 + Int(6 * hash01(slot, run.k, 5))
                let edge = min(1, min(run.progress, 1 - run.progress) * 12)
                for j in 0..<count {
                    let row = Double((j + 1) / 2), side = j % 2 == 0 ? 1.0 : -1.0
                    let seed = slot * 97 + run.k * 13 + j
                    let bx = x - d * row * 0.012 + 0.004 * (hash01(seed, 1) - 0.5)
                    let by = y + side * row * 0.006 + 0.003 * sin(t * 0.8 + Double(j))
                    drawGull(context, at: p(bx, by), span: len(0.0058 + 0.0024 * hash01(seed, 2)),
                             up: wingBeat(seed, rate: 2.8), heading: d, tone: birdTone(backlit: true), alpha: 0.85 * edge)
                }
            }
        }
    }

    /// Now and then a gull passes close over the city.
    func drawNearGull(_ context: GraphicsContext) {
        for run in runs(period: 130, duration: 15, slot: 200) {
            let startHour = HarborClock.hour(at: Date(timeIntervalSinceReferenceDate: run.start))
            guard Self.birdDensity(startHour) * (1 - rain) > hash01(200, run.k, 6) else { continue }
            let d = hash01(200, run.k, 3) < 0.5 ? 1.0 : -1.0
            let y0 = 0.30 + 0.15 * hash01(200, run.k, 4)
            let x = d > 0 ? -0.1 + (aspect + 0.2) * run.progress : aspect + 0.1 - (aspect + 0.2) * run.progress
            let y = y0 - 0.05 * sin(run.progress * .pi)
            drawGull(context, at: p(x, y), span: len(0.022 + 0.006 * hash01(200, run.k, 5)),
                     up: wingBeat(run.k + 500, rate: 2.6), heading: d, tone: birdTone(backlit: false), alpha: 0.95)
        }
    }

    // MARK: Ships

    static func shipDensity(_ h: Double) -> Double {
        piecewise(h, [(0, 0.35), (5, 0.35), (7, 1), (19, 1), (21, 0.6), (24, 0.35)])
    }

    func drawShips(_ context: GraphicsContext) {
        // Ships pass behind the bell tower, the lighthouse and the chimneys.
        var clipped = context
        clipped.clip(to: occluders(), options: .inverse)
        clipped.drawLayer { sea in

        // Far lanes along the horizon: across the bay behind the bell tower,
        // and out on the open sea past the lighthouse.
        let far: [(x0: Double, x1: Double, y: Double, length: Double)] = [
            (0.33, 0.66, 0.206, 0.0065), (1.46, 1.80, 0.254, 0.0090)]
        for (lane, spec) in far.enumerated() {
            for slot in 0..<2 {
                let id = 300 + lane * 10 + slot
                let duration = (230 + 120 * hash01(id, 21)) * (spec.x1 - spec.x0) / 0.35
                let period = duration * (0.9 + 0.5 * hash01(id, 22))
                for run in runs(period: period, duration: duration, slot: id) {
                    guard shipAllowed(run, slot: id) else { continue }
                    let d = hash01(id, run.k, 3) < 0.5 ? 1.0 : -1.0
                    let u = d > 0 ? run.progress : 1 - run.progress
                    let x = spec.x0 + (spec.x1 - spec.x0) * u, y = spec.y + 0.005 * hash01(id, run.k, 4)
                    let fade = min(1, min(run.progress, 1 - run.progress) / 0.12)
                    drawShip(sea, at: p(x, y), length: len(spec.length * (1 + 0.3 * hash01(id, run.k, 5))),
                             heading: d, rig: Int(3 * hash01(id, run.k, 6)), seed: run.k * 7 + id, alpha: fade * 0.9)
                }
            }
        }
        // Ships coming in from the open sea to the long pier, or leaving it.
        let approach: [(Double, Double)] = [(1.66, 0.275), (1.60, 0.290), (1.55, 0.310), (1.50, 0.335), (1.47, 0.350)]
        for slot in 0..<2 {
            let duration = 190 + 60 * hash01(slot, 31), period = duration * (1.1 + 0.6 * hash01(slot, 32))
            for run in runs(period: period, duration: duration, slot: 310 + slot) {
                guard shipAllowed(run, slot: 310 + slot) else { continue }
                let arriving = hash01(310 + slot, run.k, 3) < 0.55
                let u = arriving ? run.progress : 1 - run.progress
                let (x, y) = along(approach, u)
                let fade = min(1, min(run.progress, 1 - run.progress) / 0.14)
                drawShip(sea, at: p(x, y), length: len(0.012 + 0.016 * u), heading: arriving ? -1 : 1,
                         rig: 1 + Int(2 * hash01(310 + slot, run.k, 6)), seed: run.k * 5 + slot + 40, alpha: fade)
            }
        }
        // The bay behind the bell tower, and the inner harbour below the quay.
        let bays: [(x0: Double, x1: Double, y: Double, length: Double)] = [
            (0.400, 0.600, 0.228, 0.013), (0.950, 1.170, 0.354, 0.019)]
        for (bay, spec) in bays.enumerated() {
            for slot in 0..<2 {
                let id = 320 + bay * 10 + slot
                let duration = 150 + 70 * hash01(id, 41), period = duration * (1.0 + 0.7 * hash01(id, 42))
                for run in runs(period: period, duration: duration, slot: id) {
                    guard shipAllowed(run, slot: id) else { continue }
                    let d = hash01(id, run.k, 3) < 0.5 ? 1.0 : -1.0
                    let u = d > 0 ? run.progress : 1 - run.progress
                    let x = spec.x0 + (spec.x1 - spec.x0) * u, y = spec.y + 0.008 * hash01(id, run.k, 4)
                    let fade = min(1, min(run.progress, 1 - run.progress) / 0.1)
                    drawShip(sea, at: p(x, y), length: len(spec.length * (1 + 0.3 * hash01(id, run.k, 5))),
                             heading: d, rig: Int(3 * hash01(id, run.k, 6)), seed: run.k * 3 + id + 80, alpha: fade)
                }
            }
        }
        }
    }

    func shipAllowed(_ run: Run, slot: Int) -> Bool {
        let startHour = HarborClock.hour(at: Date(timeIntervalSinceReferenceDate: run.start))
        return Self.shipDensity(startHour) > hash01(slot, run.k, 9)
    }

    /// A small sailing ship at a distance. `rig`: 0 sloop, 1 brig, 2 three-master.
    func drawShip(_ context: GraphicsContext, at water: CGPoint, length L: CGFloat, heading: Double,
                  rig: Int, seed: Int, alpha: Double) {
        guard alpha > 0.01 else { return }
        let ambient = light.ambient
        let dark = light.dark
        let warm = light.sunset
        // Aerial perspective: the further out (higher on the painting), the more
        // the ship takes on the colour of the sea air.
        let depth = clamp((0.37 - Double((water.y - origin.y) / side)) / 0.15)
        let air = RGB(0.72, 0.80, 0.92).mix(RGB(0.98, 0.70, 0.52), warm).mix(RGB(0.16, 0.19, 0.32), dark)
        let haze = 0.05 + 0.22 * depth
        func hazed(_ c: RGB) -> RGB { c.mix(air, haze) }
        let sailLit = hazed(RGB(0.93, 0.90, 0.83).mix(RGB(1.0, 0.80, 0.60), warm * 0.8) * ambient)
        let sailShade = hazed(RGB(0.72, 0.70, 0.67).mix(RGB(0.80, 0.53, 0.42), warm * 0.8) * ambient)
        let hull = hazed(RGB(0.36, 0.26, 0.18) * ambient.mix(RGB(1, 1, 1), 0.3))
        let trim = hazed(RGB(0.70, 0.56, 0.36) * ambient)
        let bob = CGFloat(sin(t * 1.3 + Double(seed)) * 0.012)
        let roll = sin(t * 0.9 + Double(seed) * 1.7) * 0.025

        var g = context
        g.opacity *= alpha
        // Reflection first, softened and broken by the water.
        g.drawLayer { r in
            r.addFilter(.blur(radius: max(0.4, L * 0.035)))
            r.opacity = 0.22 * (1 - 0.5 * dark)
            r.translateBy(x: water.x, y: water.y + L * 0.03)
            r.scaleBy(x: CGFloat(heading) * L, y: -L * 0.55)
            r.fill(hullPath(), with: .color(hull.color()))
            for sail in sailPaths(rig: rig) { r.fill(sail, with: .color(sailShade.color(0.9))) }
        }
        g.translateBy(x: water.x, y: water.y + bob * L)
        g.rotate(by: .radians(roll))
        g.scaleBy(x: CGFloat(heading) * L, y: L)
        let hairline = 1 / L
        // Wake.
        var wake = Path()
        wake.move(to: CGPoint(x: -0.48, y: 0.015))
        wake.addQuadCurve(to: CGPoint(x: -1.35, y: 0.05), control: CGPoint(x: -0.9, y: 0.02))
        wake.move(to: CGPoint(x: -0.48, y: 0.02))
        wake.addQuadCurve(to: CGPoint(x: -1.2, y: -0.005), control: CGPoint(x: -0.85, y: 0.0))
        g.stroke(wake, with: .color(RGB(0.95, 0.97, 1).color(0.35 * (1 - 0.6 * dark))),
                 style: StrokeStyle(lineWidth: hairline * 0.9, lineCap: .round))
        g.fill(Path(ellipseIn: CGRect(x: 0.36, y: -0.005, width: 0.2, height: 0.035)),
               with: .color(RGB(1, 1, 1).color(0.3 * (1 - 0.6 * dark))))
        // Hull, masts, sails.
        g.fill(hullPath(), with: .color(hull.color()))
        g.fill(Path(CGRect(x: -0.44, y: -0.048, width: 0.86, height: 0.012)), with: .color(trim.color()))
        var spars = Path()
        spars.move(to: CGPoint(x: 0.48, y: -0.10)); spars.addLine(to: CGPoint(x: 0.72, y: -0.17))
        for mast in masts(rig: rig) {
            spars.move(to: CGPoint(x: mast.x, y: -0.07)); spars.addLine(to: CGPoint(x: mast.x, y: mast.top))
        }
        g.stroke(spars, with: .color((hull * 0.9).color()), style: StrokeStyle(lineWidth: max(hairline * 0.7, 0.012)))
        for sail in sailPaths(rig: rig) {
            let box = sail.boundingRect
            g.fill(sail, with: .linearGradient(Gradient(colors: [sailLit.color(), sailShade.color()]),
                                                startPoint: CGPoint(x: box.minX, y: box.minY),
                                                endPoint: CGPoint(x: box.maxX, y: box.maxY)))
        }
        // Pennant.
        if let top = masts(rig: rig).min(by: { $0.top < $1.top }) {
            let flutter = CGFloat(sin(t * 7 + Double(seed)) * 0.02)
            var flag = Path()
            flag.move(to: CGPoint(x: top.x, y: top.top))
            flag.addLine(to: CGPoint(x: top.x - 0.16, y: top.top + 0.02 + flutter))
            flag.addLine(to: CGPoint(x: top.x, y: top.top + 0.045))
            flag.closeSubpath()
            g.fill(flag, with: .color((RGB(0.75, 0.16, 0.12) * ambient).color()))
        }
        // Lanterns after dusk.
        if dark > 0.05 {
            var lamp = g
            lamp.blendMode = .screen
            for spot in [CGPoint(x: -0.47, y: -0.14), CGPoint(x: masts(rig: rig)[0].x, y: -0.42)] {
                let rr = max(0.05, 3.5 / L)
                lamp.fill(Path(ellipseIn: CGRect(x: spot.x - rr, y: spot.y - rr, width: rr * 2, height: rr * 2)),
                          with: .radialGradient(Gradient(colors: [RGB(1, 0.82, 0.48).color(0.9 * dark), RGB(1, 0.6, 0.25).color(0.25 * dark), .clear]),
                                                center: spot, startRadius: 0, endRadius: rr))
            }
        }
    }

    func hullPath() -> Path {
        var hull = Path()
        hull.move(to: CGPoint(x: -0.50, y: -0.105))
        hull.addLine(to: CGPoint(x: -0.38, y: -0.105))
        hull.addLine(to: CGPoint(x: -0.35, y: -0.07))
        hull.addLine(to: CGPoint(x: 0.36, y: -0.07))
        hull.addQuadCurve(to: CGPoint(x: 0.50, y: -0.105), control: CGPoint(x: 0.45, y: -0.075))
        hull.addQuadCurve(to: CGPoint(x: 0.30, y: 0.02), control: CGPoint(x: 0.47, y: 0.005))
        hull.addLine(to: CGPoint(x: -0.42, y: 0.02))
        hull.addQuadCurve(to: CGPoint(x: -0.50, y: -0.105), control: CGPoint(x: -0.50, y: -0.01))
        hull.closeSubpath()
        return hull
    }

    func masts(rig: Int) -> [(x: CGFloat, top: CGFloat)] {
        switch rig {
        case 0: return [(0.04, -0.86)]
        case 1: return [(-0.10, -0.92), (0.22, -0.80)]
        default: return [(0.00, -0.96), (0.25, -0.82), (-0.28, -0.70)]
        }
    }

    func sailPaths(rig: Int) -> [Path] {
        var sails: [Path] = []
        func billowed(x: CGFloat, top: CGFloat, bottom: CGFloat, width: CGFloat) -> Path {
            var s = Path()
            s.move(to: CGPoint(x: x - width * 0.5, y: top))
            s.addLine(to: CGPoint(x: x + width * 0.5, y: top))
            s.addQuadCurve(to: CGPoint(x: x + width * 0.46, y: bottom), control: CGPoint(x: x + width * 0.62, y: (top + bottom) / 2))
            s.addQuadCurve(to: CGPoint(x: x - width * 0.46, y: bottom), control: CGPoint(x: x, y: bottom + 0.035))
            s.addQuadCurve(to: CGPoint(x: x - width * 0.5, y: top), control: CGPoint(x: x - width * 0.40, y: (top + bottom) / 2))
            return s
        }
        if rig == 0 {
            var main = Path()
            main.move(to: CGPoint(x: 0.02, y: -0.82))
            main.addQuadCurve(to: CGPoint(x: -0.38, y: -0.14), control: CGPoint(x: -0.26, y: -0.5))
            main.addLine(to: CGPoint(x: 0.02, y: -0.12))
            main.closeSubpath()
            sails.append(main)
        } else {
            for mast in masts(rig: rig) {
                let h = -mast.top
                let tiers = h > 0.85 ? 3 : 2
                for tier in 0..<tiers {
                    let bottom = -0.14 - CGFloat(tier) * 0.25 * h
                    let top = bottom - 0.22 * h
                    let width = (0.30 - CGFloat(tier) * 0.06) * (h / 0.9)
                    sails.append(billowed(x: mast.x, top: top, bottom: bottom, width: width))
                }
            }
        }
        var jib = Path()
        let fore = masts(rig: rig).max(by: { $0.x < $1.x })!
        jib.move(to: CGPoint(x: fore.x + 0.02, y: fore.top + 0.06))
        jib.addQuadCurve(to: CGPoint(x: 0.68, y: -0.16), control: CGPoint(x: fore.x + 0.30, y: (fore.top - 0.16) / 2 - 0.02))
        jib.addLine(to: CGPoint(x: fore.x + 0.04, y: -0.13))
        jib.closeSubpath()
        sails.append(jib)
        return sails
    }

    // MARK: People

    static func streetDensity(_ h: Double) -> Double {
        piecewise(h, [(0, 0.06), (4.5, 0.03), (6, 0.25), (7.5, 0.75), (9, 0.95), (12, 1), (17, 1),
                      (19, 0.85), (21, 0.5), (22.5, 0.25), (24, 0.06)])
    }

    /// Walking routes on open ground, traced on the spring day painting: feet
    /// position and the height of a standing person there (painting units).
    /// Every route starts and ends at a door or behind something that hides
    /// the walker (see `occluders`), so nobody appears or vanishes in the open.
    static let routes: [[(Double, Double, Double)]] = [
        // canal promenade, over the bridge, across the little square to the arched door
        [(0.458, 0.407, 0.009), (0.430, 0.409, 0.009), (0.400, 0.411, 0.010), (0.382, 0.420, 0.010),
         (0.381, 0.432, 0.011), (0.395, 0.439, 0.011), (0.425, 0.447, 0.012), (0.452, 0.456, 0.013),
         (0.474, 0.465, 0.014), (0.500, 0.477, 0.015), (0.525, 0.489, 0.016), (0.545, 0.494, 0.017),
         (0.563, 0.497, 0.017)],
        // from the arched door down the terrace walk and back, then over the bridge
        [(0.563, 0.497, 0.017), (0.535, 0.494, 0.017), (0.518, 0.500, 0.018), (0.514, 0.525, 0.020),
         (0.510, 0.550, 0.027), (0.505, 0.575, 0.035), (0.500, 0.600, 0.044), (0.490, 0.624, 0.053),
         (0.470, 0.638, 0.058), (0.448, 0.636, 0.058), (0.442, 0.622, 0.053), (0.462, 0.604, 0.046),
         (0.482, 0.584, 0.039), (0.490, 0.560, 0.030), (0.497, 0.534, 0.022), (0.503, 0.510, 0.019),
         (0.495, 0.482, 0.016), (0.474, 0.466, 0.014), (0.452, 0.456, 0.013), (0.425, 0.447, 0.012),
         (0.395, 0.439, 0.011), (0.381, 0.432, 0.011), (0.382, 0.420, 0.010), (0.400, 0.411, 0.010),
         (0.458, 0.407, 0.009)],
        // lower courtyard: out of the house door, round the planter, behind the big leaves
        [(1.218, 0.740, 0.031), (1.200, 0.750, 0.032), (1.170, 0.756, 0.032), (1.140, 0.766, 0.033),
         (1.115, 0.772, 0.034), (1.090, 0.782, 0.035), (1.062, 0.792, 0.035)],
        // works road: from behind the red roof, past the stall and the winch, into the covered stall
        [(1.725, 0.690, 0.031), (1.690, 0.684, 0.031), (1.660, 0.686, 0.031), (1.625, 0.692, 0.032),
         (1.597, 0.703, 0.032), (1.578, 0.722, 0.033), (1.566, 0.742, 0.034), (1.550, 0.760, 0.035),
         (1.522, 0.768, 0.035), (1.492, 0.776, 0.036), (1.462, 0.779, 0.036)],
        // market square: out of the corner house, along the crates, into the shed door opposite
        [(1.389, 0.815, 0.040), (1.410, 0.823, 0.040), (1.448, 0.833, 0.041), (1.480, 0.840, 0.041),
         (1.510, 0.846, 0.042), (1.540, 0.845, 0.042), (1.566, 0.842, 0.042), (1.588, 0.832, 0.041),
         (1.597, 0.824, 0.041)]]
    static let slotsPerRoute = [3, 3, 2, 3, 3]
    /// Street lamps near the routes (lamp groups of the spring light layer).
    static let lamps: [(Double, Double)] = [
        (0.442, 0.540), (0.459, 0.466), (0.568, 0.723), (0.716, 0.610), (0.933, 0.733), (0.980, 0.639),
        (1.150, 0.592), (1.183, 0.714), (1.244, 0.719), (1.516, 0.716), (1.532, 0.519), (1.634, 0.830)]

    /// Things standing in front of the walking places. A figure whose feet are
    /// higher on the painting (further away) than an outline's base is hidden
    /// where the outline covers it: walkers pass behind trunks, disappear into
    /// the covered stall, behind the handcart, the leaves or the red roof.
    static let occluders: [(base: Double, outline: [(Double, Double)])] = [
        (0.486, [(0.471, 0.440), (0.476, 0.440), (0.476, 0.486), (0.471, 0.486)]),      // tree after the bridge
        (0.497, [(0.532, 0.460), (0.538, 0.460), (0.538, 0.497), (0.532, 0.497)]),      // tree by the arched door
        (0.612, [(0.390, 0.535), (0.430, 0.528), (0.455, 0.545), (0.475, 0.553), (0.475, 0.590),
                 (0.455, 0.612), (0.390, 0.612)]),                                      // planters left of the walk
        (0.615, [(0.300, 0.520), (0.395, 0.520), (0.395, 0.615), (0.300, 0.615)]),      // garden gate and stair
        (0.700, [(0.538, 0.500), (0.600, 0.500), (0.600, 0.700), (0.538, 0.700)]),      // lamps and plants right of the walk
        (0.830, [(0.928, 0.714), (0.966, 0.714), (0.990, 0.730), (1.027, 0.755), (1.060, 0.755),
                 (1.085, 0.775), (1.085, 0.830), (0.928, 0.830)]),                      // big leaves, lower courtyard
        (0.830, [(0.920, 0.620), (0.948, 0.620), (0.948, 0.830), (0.920, 0.830)]),      // courtyard lamp
        (0.830, [(1.188, 0.737), (1.240, 0.737), (1.240, 0.830), (1.188, 0.830)]),      // balustrade post by the house
        (0.780, [(1.648, 0.684), (1.660, 0.676), (1.720, 0.656), (1.777, 0.660), (1.777, 0.780),
                 (1.645, 0.780)]),                                                      // red roof over the works road
        (0.727, [(1.538, 0.660), (1.598, 0.660), (1.598, 0.727), (1.538, 0.727)]),      // stall on the works road
        (0.763, [(1.584, 0.706), (1.657, 0.706), (1.657, 0.763), (1.584, 0.763)]),      // winch
        (0.803, [(1.424, 0.735), (1.492, 0.735), (1.492, 0.803), (1.424, 0.803)]),      // covered stall
        (0.828, [(1.452, 0.778), (1.531, 0.778), (1.531, 0.828), (1.452, 0.828)]),      // crate stacks
        (0.819, [(1.400, 0.794), (1.430, 0.794), (1.430, 0.819), (1.400, 0.819)]),      // rocks by the corner house
        (0.884, [(1.362, 0.825), (1.443, 0.825), (1.443, 0.884), (1.362, 0.884)]),      // big crate stack
        (0.884, [(1.530, 0.837), (1.610, 0.837), (1.610, 0.884), (1.530, 0.884)]),      // handcart and fence
        (0.930, [(1.449, 0.853), (1.539, 0.853), (1.539, 0.930), (1.449, 0.930)])]      // potted palm

    /// People standing and talking: on the fountain terrace, on the terrace walk,
    /// in the lower courtyard and in the market square.
    static let spots: [[(Double, Double, Double)]] = [
        [(1.185, 0.565, 0.014), (1.196, 0.566, 0.014)], [(0.525, 0.612, 0.050)],
        [(1.125, 0.797, 0.035), (1.141, 0.799, 0.035)], [(1.540, 0.818, 0.040), (1.553, 0.820, 0.040)]]

    /// The outlines hiding a figure whose feet are at painting row `y`.
    func occluderPath(feetY y: Double, near x: Double, height h: Double) -> Path? {
        var path = Path()
        var any = false
        for occluder in Self.occluders where occluder.base > y + 0.001 {
            let xs = occluder.outline.map { $0.0 }, ys = occluder.outline.map { $0.1 }
            guard xs.max()! > x - h, xs.min()! < x + h, ys.min()! < y, ys.max()! > y - h * 1.2 else { continue }
            path.addPath(polygon(occluder.outline))
            any = true
        }
        return any ? path : nil
    }

    func drawPeople(_ context: GraphicsContext) {
        var figures: [(y: Double, draw: (inout GraphicsContext) -> Void)] = []

        for (routeIndex, route) in Self.routes.enumerated() {
            let meters = routeMeters(route)
            for slot in 0..<Self.slotsPerRoute[routeIndex] {
                let id = 400 + routeIndex * 10 + slot
                let speed = (1.2 + 0.3 * hash01(id, 1)) * (1 + 0.25 * rain)
                let duration = meters / speed
                let period = duration * (1.15 + 0.5 * hash01(id, 2))
                for run in runs(period: period, duration: duration, slot: id) {
                    let startHour = HarborClock.hour(at: Date(timeIntervalSinceReferenceDate: run.start))
                    guard Self.streetDensity(startHour) * (1 - 0.6 * rain) > hash01(id, run.k, 3) else { continue }
                    let forward = hash01(id, run.k, 4) < 0.5
                    let s = (forward ? run.progress : 1 - run.progress) * meters
                    let (x, y, h, dx, dy) = point(on: route, meters: s)
                    let edge = min(run.progress, 1 - run.progress) * meters
                    let alpha = min(1, edge / 1.2)
                    let look = PersonLook(seed: id * 1000 + run.k, night: light.dark > 0.5, rain: rain)
                    let facing: PersonView = abs(dx) > abs(dy) * 0.9
                        ? .side(forward == (dx >= 0) ? 1 : -1)
                        : ((dy >= 0) == forward ? .front : .back)
                    let gait = still ? 0.25 : run.progress * duration * speed / 1.35
                    let hidden = occluderPath(feetY: y, near: x, height: h)
                    figures.append((y, { ctx in
                        var g = ctx
                        if let hidden { g.clip(to: hidden, options: .inverse) }
                        drawPerson(&g, feet: p(x, y), height: len(h * look.scale),
                                   look: look, view: facing, gait: gait, size: h, alpha: alpha)
                    }))
                }
            }
        }
        for (i, group) in Self.spots.enumerated() {
            let id = 500 + i
            for run in runs(period: 110 + 50 * hash01(id, 1), duration: 70 + 40 * hash01(id, 2), slot: id) {
                let startHour = HarborClock.hour(at: Date(timeIntervalSinceReferenceDate: run.start))
                guard Self.streetDensity(startHour) * (1 - rain) > 0.25 + 0.7 * hash01(id, run.k, 3) else { continue }
                let alpha = min(1, min(run.progress, 1 - run.progress) * 30)
                for (j, spot) in group.enumerated() {
                    let look = PersonLook(seed: id * 1000 + run.k * 10 + j, night: light.dark > 0.5, rain: rain)
                    let face: PersonView = group.count > 1 ? .side(j == 0 ? 1 : -1) : .front
                    figures.append((spot.1, { ctx in
                        drawPerson(&ctx, feet: p(spot.0, spot.1), height: len(spot.2 * look.scale),
                                   look: look, view: face, gait: nil, size: spot.2, alpha: alpha)
                    }))
                }
            }
        }

        guard !figures.isEmpty else { return }
        figures.sort { $0.y < $1.y }
        // Solid figures with crisp edges: no blur or halo, which made them look
        // see-through and feathered against the painting.
        var layer = context
        for figure in figures { figure.draw(&layer) }
    }

    func routeMeters(_ route: [(Double, Double, Double)]) -> Double {
        var total = 0.0
        for i in 1..<route.count { total += segmentMeters(route[i - 1], route[i]) }
        return total
    }

    /// A person is 1.7 m tall, so their height on the painting sets the scale.
    func segmentMeters(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
        let d = hypot(b.0 - a.0, b.1 - a.1)
        return d / ((a.2 + b.2) / 2) * 1.7
    }

    /// Feet position, person height and heading at `s` metres along a route.
    func point(on route: [(Double, Double, Double)], meters s: Double) -> (Double, Double, Double, Double, Double) {
        var remaining = s
        for i in 1..<route.count {
            let a = route[i - 1], b = route[i]
            let m = segmentMeters(a, b)
            if remaining <= m || i == route.count - 1 {
                let u = clamp(remaining / max(m, 0.0001))
                return (a.0 + (b.0 - a.0) * u, a.1 + (b.1 - a.1) * u, a.2 + (b.2 - a.2) * u, b.0 - a.0, b.1 - a.1)
            }
            remaining -= m
        }
        let last = route[route.count - 1]
        return (last.0, last.1, last.2, 0, 0)
    }

    func drawPerson(_ ctx: inout GraphicsContext, feet: CGPoint, height H: CGFloat, look: PersonLook,
                    view: PersonView, gait: Double?, size: Double, alpha: Double) {
        guard alpha > 0.01, H > 3 else { return }
        var g = ctx
        g.opacity *= alpha
        let ambient = light.ambient
        let sun = light.sun
        // Only the smallest (farthest) figures take on a little of the air.
        let haze = clamp((0.020 - size) / 0.012) * 0.10 * (1 - 0.7 * light.dark)
        let hazeColor = RGB(0.74, 0.78, 0.9).mix(RGB(0.95, 0.72, 0.58), light.sunset).mix(RGB(0.14, 0.16, 0.28), light.dark)
        // Nearby street lamp at night.
        var lampSide: CGFloat = 1
        var lamp = 0.0
        if light.dark > 0.05 {
            let px = Double((feet.x - origin.x) / side), py = Double((feet.y - origin.y) / side)
            if let near = Self.lamps.min(by: { hypot($0.0 - px, $0.1 - py) < hypot($1.0 - px, $1.1 - py) }) {
                let dist = hypot(near.0 - px, near.1 - py)
                lamp = light.dark * (1 - smooth(dist / (2.5 * size))) * 0.9
                lampSide = near.0 >= px ? 1 : -1
            }
        }
        // After dark, figures read as silhouettes against the lamp-lit stone,
        // with a warm edge on the side facing the nearest lamp.
        let figureAmbient = ambient * (1 - 0.4 * light.dark)
        func shades(_ base: RGB) -> (lit: Color, shade: Color) {
            var lit = base * figureAmbient * (1 + 0.38 * sun)
            var shade = base * figureAmbient * (1 - 0.42 * sun)
            lit = lit + RGB(1, 0.70, 0.40) * (lamp * 0.75) * base.mix(RGB(1, 1, 1), 0.6)
            shade = shade + RGB(0.5, 0.35, 0.25) * (lamp * 0.05)
            return (lit.mix(hazeColor, haze).color(), shade.mix(hazeColor, haze).color())
        }
        // Light comes from the upper right by day, from the nearest lamp at night.
        let lightFromRight: Bool = light.dark > 0.5 ? lampSide > 0 : true
        func paint(_ path: Path, _ base: RGB) {
            let (lit, shade) = shades(base)
            let box = path.boundingRect
            let a = CGPoint(x: lightFromRight ? box.minX : box.maxX, y: box.midY)
            let b = CGPoint(x: lightFromRight ? box.maxX : box.minX, y: box.midY)
            g.fill(path, with: .linearGradient(Gradient(colors: [shade, lit]), startPoint: a, endPoint: b))
        }

        // Contact shadow under the feet, and the cast shadow toward the lower
        // left like the painting's own shadows (longer in the low sun).
        let shadowAlpha = (0.38 * sun * (1 - light.dark) + 0.25 * light.dark) * (1 - 0.6 * rain)
        if shadowAlpha > 0.01 {
            let long = 1 + 1.4 * light.sunset
            g.fill(Path(ellipseIn: CGRect(x: feet.x - 0.16 * H, y: feet.y - 0.03 * H, width: 0.32 * H, height: 0.06 * H)),
                   with: .color(RGB(0.04, 0.04, 0.08).color(min(0.6, shadowAlpha * 1.5))))
            var cast = Path()
            cast.move(to: CGPoint(x: feet.x - 0.08 * H, y: feet.y))
            cast.addLine(to: CGPoint(x: feet.x + 0.08 * H, y: feet.y))
            cast.addLine(to: CGPoint(x: feet.x - 0.42 * H * long, y: feet.y + 0.10 * H))
            cast.addLine(to: CGPoint(x: feet.x - 0.56 * H * long, y: feet.y + 0.07 * H))
            cast.closeSubpath()
            g.fill(cast, with: .color(RGB(0.04, 0.04, 0.08).color(shadowAlpha * (1 - light.dark))))
        }

        let phase = (gait ?? 0) * 2 * .pi
        let swing = gait == nil ? 0 : sin(phase)
        let bob = gait == nil ? 0 : -abs(cos(phase)) * 0.018
        let hipY = -0.50 + bob, shY = -0.79 + bob, headY = -0.878 + bob
        var dir: CGFloat = 1
        var sideView = false
        if case .side(let f) = view { dir = f; sideView = true }
        func q(_ x: Double, _ yy: Double) -> CGPoint { CGPoint(x: feet.x + CGFloat(x) * H * dir, y: feet.y + CGFloat(yy) * H) }
        func poly(_ pts: [(Double, Double)]) -> Path {
            var path = Path()
            path.move(to: q(pts[0].0, pts[0].1))
            for pt in pts.dropFirst() { path.addLine(to: q(pt.0, pt.1)) }
            path.closeSubpath()
            return path
        }
        func limb(from a: (Double, Double), to b: (Double, Double), w0: Double, w1: Double) -> Path {
            let dx = b.0 - a.0, dy = b.1 - a.1
            let l = max(hypot(dx, dy), 0.0001)
            let nx = -dy / l, ny = dx / l
            return poly([(a.0 + nx * w0 / 2, a.1 + ny * w0 / 2), (b.0 + nx * w1 / 2, b.1 + ny * w1 / 2),
                         (b.0 - nx * w1 / 2, b.1 - ny * w1 / 2), (a.0 - nx * w0 / 2, a.1 - ny * w0 / 2)])
        }

        let skirt = look.form == .dress
        let hem = look.form == .coat ? -0.30 : (skirt ? -0.03 : -0.46)

        if sideView {
            let legs = [-0.40 * swing, 0.40 * swing]
            let arms = [0.42 * swing, -0.42 * swing]
            // back arm, back leg
            let back = 0
            func arm(_ i: Int) -> Path {
                let a = arms[i]
                return limb(from: (0.0, shY + 0.03), to: (sin(a) * 0.33, shY + 0.03 + cos(a) * 0.33), w0: 0.062, w1: 0.045)
            }
            func leg(_ i: Int) -> Path {
                let a = legs[i]
                let lift = gait == nil ? 0 : max(0, sin(phase + (i == 0 ? .pi : 0))) * 0.03
                return limb(from: (0.0, hipY), to: (sin(a) * 0.5, -lift), w0: 0.078, w1: 0.048)
            }
            paint(arm(back), look.top * 0.8)
            if !skirt { paint(leg(back), look.bottom * 0.85) }
            if !skirt { paint(leg(1), look.bottom) }
            for i in 0..<2 {
                let a = legs[i]
                let lift = gait == nil ? 0 : max(0, sin(phase + (i == 0 ? .pi : 0))) * 0.03
                g.fill(Path(ellipseIn: CGRect(x: q(sin(a) * 0.5 - 0.02, -lift - 0.02).x - (dir < 0 ? 0.08 * H : 0),
                                              y: q(0, -lift - 0.025).y, width: 0.08 * H, height: 0.035 * H)),
                       with: .color((RGB(0.1, 0.08, 0.07) * ambient).color()))
            }
            if skirt {
                paint(poly([(-0.07, -0.60 + bob), (0.07, -0.60 + bob), (0.16 + 0.03 * swing, -0.03), (-0.17 - 0.03 * swing, -0.03)]), look.bottom)
            }
            paint(poly([(-0.09, shY), (0.09, shY), (0.085, -0.52 + bob),
                        (look.form == .coat ? 0.12 + 0.02 * swing : 0.09, hem + (skirt ? -0.55 : 0)),
                        (look.form == .coat ? -0.13 - 0.02 * swing : -0.09, hem + (skirt ? -0.55 : 0)), (-0.085, -0.52 + bob)]), look.top)
            paint(arm(1), look.top)
            g.fill(circle(q(sin(arms[1]) * 0.35, shY + 0.03 + cos(arms[1]) * 0.35), 0.028 * H), with: .color(shades(look.skin).lit))
        } else {
            let liftL = gait == nil ? 0 : max(0, sin(phase)) * 0.035
            let liftR = gait == nil ? 0 : max(0, -sin(phase)) * 0.035
            if !skirt {
                paint(limb(from: (-0.04, hipY), to: (-0.05, -liftL), w0: 0.075, w1: 0.05), look.bottom)
                paint(limb(from: (0.04, hipY), to: (0.05, -liftR), w0: 0.075, w1: 0.05), look.bottom)
            }
            for (x, lift) in [(-0.05, liftL), (0.05, liftR)] {
                g.fill(Path(ellipseIn: CGRect(x: q(x - 0.03, 0).x, y: q(0, -lift - 0.03).y, width: 0.06 * H, height: 0.035 * H)),
                       with: .color((RGB(0.1, 0.08, 0.07) * ambient).color()))
            }
            if skirt {
                paint(poly([(-0.075, -0.60 + bob), (0.075, -0.60 + bob), (0.17 + 0.02 * swing, -0.03), (-0.17 + 0.02 * swing, -0.03)]), look.bottom)
            }
            let hw = look.form == .coat ? 0.125 : 0.10
            paint(poly([(-0.105, shY), (0.105, shY), (0.09, -0.52 + bob), (hw, hem + (skirt ? -0.55 : 0)),
                        (-hw, hem + (skirt ? -0.55 : 0)), (-0.09, -0.52 + bob)]), look.top)
            for (x, s) in [(-0.125, swing), (0.125, -swing)] {
                let reach = 0.31 - 0.05 * abs(s)
                paint(limb(from: (x, shY + 0.03), to: (x * 1.08, shY + 0.03 + reach), w0: 0.058, w1: 0.045), look.top * 0.92)
                g.fill(circle(q(x * 1.08, shY + 0.03 + reach + 0.02), 0.026 * H), with: .color(shades(look.skin).lit))
            }
        }
        // Neck and head.
        g.fill(Path(CGRect(x: q(-0.025, 0).x, y: q(0, shY - 0.035).y, width: 0.05 * H, height: 0.05 * H)),
               with: .color(shades(look.skin).shade))
        let headC = q(sideView ? 0.012 : 0, headY)
        let faceVisible = view != .back
        let head = Path(ellipseIn: CGRect(x: headC.x - 0.057 * H, y: headC.y - 0.064 * H, width: 0.114 * H, height: 0.128 * H))
        if faceVisible { paint(head, look.skin) } else { g.fill(head, with: .color(shades(look.hair).shade)) }
        // Hair on the back of the head.
        if faceVisible {
            var hair = Path()
            if sideView {
                hair.addEllipse(in: CGRect(x: headC.x - (dir > 0 ? 0.062 : 0.02) * H, y: headC.y - 0.07 * H, width: 0.082 * H, height: 0.1 * H))
            } else {
                hair.addEllipse(in: CGRect(x: headC.x - 0.06 * H, y: headC.y - 0.07 * H, width: 0.12 * H, height: 0.055 * H))
            }
            g.fill(hair, with: .color(shades(look.hair).shade))
            if look.form == .dress && look.hat == 0 {
                g.fill(circle(CGPoint(x: headC.x - dir * (sideView ? 0.05 : 0) * H, y: headC.y - 0.04 * H), 0.035 * H),
                       with: .color(shades(look.hair).shade))
            }
        }
        // Hats.
        let hat = shades(look.hatColor)
        switch look.hat {
        case 1: // top hat
            g.fill(Path(CGRect(x: headC.x - 0.05 * H, y: headC.y - 0.19 * H, width: 0.1 * H, height: 0.13 * H)), with: .color(hat.shade))
            g.fill(Path(ellipseIn: CGRect(x: headC.x - 0.085 * H, y: headC.y - 0.075 * H, width: 0.17 * H, height: 0.025 * H)), with: .color(hat.shade))
        case 2: // bowler
            g.fill(Path(ellipseIn: CGRect(x: headC.x - 0.06 * H, y: headC.y - 0.12 * H, width: 0.12 * H, height: 0.09 * H)), with: .color(hat.lit))
            g.fill(Path(ellipseIn: CGRect(x: headC.x - 0.08 * H, y: headC.y - 0.07 * H, width: 0.16 * H, height: 0.022 * H)), with: .color(hat.shade))
        case 3: // cap
            g.fill(Path(ellipseIn: CGRect(x: headC.x - 0.062 * H + dir * 0.012 * H, y: headC.y - 0.095 * H, width: 0.124 * H, height: 0.06 * H)), with: .color(hat.lit))
        case 4: // wide-brimmed lady's hat
            g.fill(Path(ellipseIn: CGRect(x: headC.x - 0.11 * H, y: headC.y - 0.08 * H, width: 0.22 * H, height: 0.04 * H)), with: .color(hat.lit))
            g.fill(Path(ellipseIn: CGRect(x: headC.x - 0.05 * H, y: headC.y - 0.12 * H, width: 0.1 * H, height: 0.06 * H)), with: .color(hat.shade))
        default:
            break
        }
        // Umbrella in the rain.
        if look.umbrella {
            let top = headY - 0.13
            let tilt = sideView ? 0.05 : 0.0
            var canopy = Path()
            canopy.move(to: q(-0.24 + tilt, top + 0.06))
            canopy.addQuadCurve(to: q(0.24 + tilt, top + 0.06), control: q(tilt, top - 0.16))
            canopy.addQuadCurve(to: q(0.08 + tilt, top + 0.07), control: q(0.16 + tilt, top + 0.04))
            canopy.addQuadCurve(to: q(-0.08 + tilt, top + 0.07), control: q(tilt, top + 0.04))
            canopy.addQuadCurve(to: q(-0.24 + tilt, top + 0.06), control: q(-0.16 + tilt, top + 0.04))
            canopy.closeSubpath()
            paint(canopy, look.umbrellaColor)
            var shaft = Path()
            shaft.move(to: q(tilt, top - 0.07)); shaft.addLine(to: q(sideView ? 0.10 : 0.12, -0.52 + bob))
            g.stroke(shaft, with: .color(shades(RGB(0.15, 0.13, 0.12)).shade), lineWidth: max(0.5, 0.012 * H))
        }
        // What they carry.
        let hand = sideView ? q(0.18, -0.46 + bob) : q(0.14, -0.45 + bob)
        switch look.carry {
        case 1:
            g.fill(Path(ellipseIn: CGRect(x: hand.x - 0.06 * H, y: hand.y, width: 0.12 * H, height: 0.07 * H)),
                   with: .color(shades(RGB(0.55, 0.40, 0.22)).lit))
        case 2:
            g.fill(Path(CGRect(x: hand.x - 0.05 * H, y: hand.y, width: 0.1 * H, height: 0.08 * H)),
                   with: .color(shades(RGB(0.62, 0.52, 0.38)).lit))
        case 3 where light.dark > 0.3:
            var glow = g
            glow.blendMode = .screen
            let c = CGPoint(x: hand.x, y: hand.y + 0.05 * H)
            glow.fill(circle(c, 0.35 * H), with: .radialGradient(
                Gradient(colors: [RGB(1, 0.82, 0.48).color(0.85 * light.dark), RGB(1, 0.55, 0.2).color(0.18 * light.dark), .clear]),
                center: c, startRadius: 0, endRadius: 0.35 * H))
            g.fill(Path(CGRect(x: c.x - 0.02 * H, y: c.y - 0.03 * H, width: 0.04 * H, height: 0.06 * H)),
                   with: .color(RGB(1, 0.9, 0.6).color()))
        default:
            break
        }
    }

    // MARK: Runs

    struct Run {
        let k: Int
        let start: Double
        let progress: Double
    }

    /// Active runs of a recurring event: run k starts near k·period (jittered)
    /// and lasts `duration` seconds; several may overlap.
    func runs(period: Double, duration: Double, slot: Int) -> [Run] {
        let now = still ? 1_000_000 + Double(slot) * 37 : t
        var result: [Run] = []
        let first = Int(floor((now - duration - period) / period))
        let last = Int(floor(now / period))
        guard first <= last else { return result }
        for k in first...last {
            let start = (Double(k) + hash01(slot, k, 1) * 0.6) * period
            let progress = (now - start) / duration
            if progress >= 0 && progress < 1 { result.append(Run(k: k, start: start, progress: progress)) }
        }
        return result
    }

    // MARK: Geometry helpers

    func polygon(_ points: [(Double, Double)]) -> Path {
        var path = Path()
        path.move(to: p(points[0].0, points[0].1))
        for point in points.dropFirst() { path.addLine(to: p(point.0, point.1)) }
        path.closeSubpath()
        return path
    }

    func along(_ points: [(Double, Double)], _ u: Double) -> (Double, Double) {
        let scaled = clamp(u) * Double(points.count - 1)
        let i = min(Int(scaled), points.count - 2)
        let f = scaled - Double(i)
        return (points[i].0 + (points[i + 1].0 - points[i].0) * f, points[i].1 + (points[i + 1].1 - points[i].1) * f)
    }
}

// MARK: - People

enum PersonView: Equatable {
    case side(CGFloat)
    case front
    case back
}

struct PersonLook {
    enum Form { case coat, dress, sailor, worker }
    let form: Form
    let top: RGB
    let bottom: RGB
    let skin: RGB
    let hair: RGB
    let hat: Int
    let hatColor: RGB
    let carry: Int
    let scale: Double
    let umbrella: Bool
    let umbrellaColor: RGB

    init(seed: Int, night: Bool, rain: Double = 0) {
        let coats = [RGB(0.18, 0.20, 0.30), RGB(0.34, 0.23, 0.16), RGB(0.22, 0.22, 0.23), RGB(0.30, 0.31, 0.21),
                     RGB(0.46, 0.18, 0.18), RGB(0.55, 0.48, 0.37)]
        let dresses = [RGB(0.50, 0.17, 0.23), RGB(0.20, 0.34, 0.30), RGB(0.70, 0.64, 0.55), RGB(0.42, 0.33, 0.50),
                       RGB(0.22, 0.26, 0.42), RGB(0.62, 0.40, 0.30)]
        let skins = [RGB(0.93, 0.78, 0.66), RGB(0.85, 0.66, 0.52), RGB(0.70, 0.52, 0.40), RGB(0.55, 0.38, 0.28)]
        let hairs = [RGB(0.16, 0.11, 0.08), RGB(0.35, 0.22, 0.12), RGB(0.55, 0.40, 0.22), RGB(0.10, 0.09, 0.09), RGB(0.6, 0.58, 0.55)]
        func pick<T>(_ list: [T], _ salt: Int) -> T { list[min(list.count - 1, Int(hash01(seed, salt) * Double(list.count)))] }
        let roll = hash01(seed, 1)
        if roll < 0.40 {
            form = .coat
            top = pick(coats, 2); bottom = RGB(0.16, 0.15, 0.15).mix(pick(coats, 3), 0.3)
            hat = [1, 2, 2, 3, 0][min(4, Int(hash01(seed, 4) * 5))]
            hatColor = RGB(0.12, 0.11, 0.11)
        } else if roll < 0.78 {
            form = .dress
            top = pick(dresses, 2).mix(RGB(0.9, 0.88, 0.84), 0.15); bottom = pick(dresses, 2)
            hat = hash01(seed, 4) < 0.5 ? 4 : 0
            hatColor = pick(dresses, 5).mix(RGB(0.9, 0.85, 0.75), 0.4)
        } else if roll < 0.9 {
            form = .sailor
            top = RGB(0.86, 0.87, 0.88); bottom = RGB(0.16, 0.19, 0.30)
            hat = 3; hatColor = RGB(0.14, 0.17, 0.27)
        } else {
            form = .worker
            top = RGB(0.52, 0.44, 0.34); bottom = RGB(0.28, 0.24, 0.20)
            hat = 3; hatColor = RGB(0.30, 0.26, 0.22)
        }
        skin = pick(skins, 6)
        hair = pick(hairs, 7)
        let c = hash01(seed, 8)
        if night && c < 0.35 { carry = 3 } else if c < 0.2 { carry = 1 } else if c < 0.35 { carry = 2 } else { carry = 0 }
        scale = hash01(seed, 9) < 0.08 ? 0.66 : 0.92 + 0.14 * hash01(seed, 10)
        umbrella = rain > 0.15 && hash01(seed, 11) < 0.35 + 0.6 * rain
        umbrellaColor = [RGB(0.10, 0.10, 0.11), RGB(0.12, 0.14, 0.24), RGB(0.40, 0.10, 0.12), RGB(0.20, 0.28, 0.22)][min(3, Int(hash01(seed, 12) * 4))]
    }
}

// MARK: - Small math

struct RGB {
    var r: Double
    var g: Double
    var b: Double

    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }

    static func * (a: RGB, k: Double) -> RGB { RGB(a.r * k, a.g * k, a.b * k) }
    static func * (a: RGB, b: RGB) -> RGB { RGB(a.r * b.r, a.g * b.g, a.b * b.b) }
    static func + (a: RGB, b: RGB) -> RGB { RGB(a.r + b.r, a.g + b.g, a.b + b.b) }
    func mix(_ other: RGB, _ t: Double) -> RGB { self * (1 - t) + other * t }
    func color(_ alpha: Double = 1) -> Color {
        Color(red: min(1, max(0, r)), green: min(1, max(0, g)), blue: min(1, max(0, b)), opacity: min(1, max(0, alpha)))
    }
}

/// Shared with CityAmbience so sound and picture agree on the same random draws.
enum HarborNoise {
    static func hash(_ a: Int, _ b: Int = 0, _ c: Int = 0) -> Double { hash01(a, b, c) }
    static func smooth(_ v: Double) -> Double { let x = clamp(v); return x * x * (3 - 2 * x) }
}

private func clamp(_ v: Double, _ lo: Double = 0, _ hi: Double = 1) -> Double { min(hi, max(lo, v)) }
private func smooth(_ v: Double) -> Double { let x = clamp(v); return x * x * (3 - 2 * x) }
private func fract(_ v: Double) -> Double { v - floor(v) }
private func bell(_ v: Double, _ centre: Double, _ width: Double) -> Double {
    let d = abs(v - centre) / width
    return d >= 1 ? 0 : smooth(1 - d)
}
private func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
}

private func piecewise(_ x: Double, _ points: [(Double, Double)]) -> Double {
    guard let first = points.first, let last = points.last else { return 0 }
    if x <= first.0 { return first.1 }
    if x >= last.0 { return last.1 }
    for i in 1..<points.count where x <= points[i].0 {
        let a = points[i - 1], b = points[i]
        return a.1 + (b.1 - a.1) * (x - a.0) / (b.0 - a.0)
    }
    return last.1
}

/// Centripetal-ish Catmull-Rom through (time, x, y) keys.
private func catmullRom(_ keys: [(Double, Double, Double)], _ time: Double) -> (Double, Double) {
    var i = 0
    while i < keys.count - 2 && time > keys[i + 1].0 { i += 1 }
    let p1 = keys[i], p2 = keys[i + 1]
    let p0 = i > 0 ? keys[i - 1] : p1
    let p3 = i + 2 < keys.count ? keys[i + 2] : p2
    let u = clamp((time - p1.0) / (p2.0 - p1.0))
    func cr(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
        0.5 * (2 * b + (-a + c) * u + (2 * a - 5 * b + 4 * c - d) * u * u + (-a + 3 * b - 3 * c + d) * u * u * u)
    }
    return (cr(p0.1, p1.1, p2.1, p3.1), cr(p0.2, p1.2, p2.2, p3.2))
}

/// Stable pseudo-random value in 0..<1 for a set of integers.
private func hash01(_ a: Int, _ b: Int = 0, _ c: Int = 0) -> Double {
    var x = UInt64(bitPattern: Int64(a &* 73_856_093 ^ b &* 19_349_663 ^ c &* 83_492_791))
    x ^= x >> 33
    x &*= 0xff51afd7ed558ccd
    x ^= x >> 33
    x &*= 0xc4ceb9fe1a85ec53
    x ^= x >> 33
    return Double(x % 1_000_003) / 1_000_003
}
