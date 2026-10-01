import SwiftUI

struct MistBackground: View {
    let tint: Color
    var showsDriftingMist = false

    var body: some View {
        GeometryReader { geometry in
            Group {
                if showsDriftingMist {
                    CrimsonHeroAnimation()
                        .overlay { TitleGhostShip() }
                } else {
                    Image("MistportHero")
                        .resizable()
                        .scaledToFill()
                }
            }
                .frame(width: geometry.size.width, height: geometry.size.height)
                // 只给标题留出读字空间，城景本身保持清晰，不再覆盖紫色雾幕。
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.08), .clear, Color(red: 0.015, green: 0.012, blue: 0.05).opacity(0.34)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .overlay {
                    RadialGradient(
                        colors: [tint.opacity(0.11), .clear],
                        center: .top,
                        startRadius: 0,
                        endRadius: 420
                    )
                }
                .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// The supplied paintings are ordered by measured moon luminance, then played
/// forward and backward over 45 seconds. The full paintings cross-fade without
/// a visible moon mask while the foreground mist moves independently.
private struct CrimsonHeroAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let frames = [
        "MistportHeroCrimson06", "MistportHeroCrimson01", "MistportHeroCrimson02",
        "MistportHeroCrimson08", "MistportHeroCrimson03", "MistportHeroCrimson04",
        "MistportHeroCrimson07", "MistportHeroCrimson05", "MistportHeroCrimson09",
        "MistportHeroCrimson05", "MistportHeroCrimson07", "MistportHeroCrimson04",
        "MistportHeroCrimson03", "MistportHeroCrimson08", "MistportHeroCrimson02",
        "MistportHeroCrimson01"
    ]

    var body: some View {
        GeometryReader { _ in
            ZStack {
                heroFrame(named: frames[0])

                TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { timeline in
                    let state = reduceMotion
                        ? (current: 0, next: 0, linearBlend: 0.0)
                        : animationState(at: timeline.date.timeIntervalSinceReferenceDate)
                    let linearBlend = state.linearBlend
                    let blend = linearBlend * linearBlend * (3 - 2 * linearBlend)

                    ZStack {
                        heroFrame(named: frames[state.current])
                            .opacity(1 - blend)
                        heroFrame(named: frames[state.next])
                            .opacity(blend)
                    }
                }
            }
        }
    }

    private func heroFrame(named name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
    }

    private func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }

    private func animationState(at time: TimeInterval) -> (current: Int, next: Int, linearBlend: Double) {
        let transitionDuration = 2.8125
        let crimsonHoldDuration = 2.0
        let crimsonVisits = frames.filter { $0 == "MistportHeroCrimson08" }.count
        let cycleDuration = transitionDuration * Double(frames.count)
            + crimsonHoldDuration * Double(crimsonVisits)
        var elapsed = time.truncatingRemainder(dividingBy: cycleDuration)
        if elapsed < 0 { elapsed += cycleDuration }

        for index in frames.indices {
            if frames[index] == "MistportHeroCrimson08" {
                if elapsed < crimsonHoldDuration {
                    return (index, index, 0)
                }
                elapsed -= crimsonHoldDuration
            }

            if elapsed < transitionDuration {
                return (
                    index,
                    positiveModulo(index + 1, frames.count),
                    elapsed / transitionDuration
                )
            }
            elapsed -= transitionDuration
        }

        return (0, 0, 0)
    }

}

/// Waterline follows the user's lower-left → inner-harbor route in full-screen coordinates.
private struct TitleGhostShip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var voyageStart = Date()

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                    paused: reduceMotion || scenePhase != .active)) { timeline in
                let elapsed = max(0, timeline.date.timeIntervalSince(voyageStart))
                // A quiet gap after disappearance prevents a visible loop reset.
                let phase = elapsed.truncatingRemainder(dividingBy: 32)
                let progress = min(1, max(0, (phase - 1) / 23))
                let t = CGFloat(progress)
                let inverse = 1 - t
                let x = inverse * inverse * inverse * -0.13
                    + 3 * inverse * inverse * t * 0.16
                    + 3 * inverse * t * t * 0.47 + t * t * t * 0.59
                let y = inverse * inverse * inverse * 0.855
                    + 3 * inverse * inverse * t * 0.848
                    + 3 * inverse * t * t * 0.810 + t * t * t * 0.764
                let width = geometry.size.width * (0.43 - 0.32 * t)
                let fadeIn = min(1, max(0, (phase - 1) / 2))
                let fog = min(1, max(0, (progress - 0.52) / 0.48))
                let opacity = fadeIn * (1 - fog * fog * (3 - 2 * fog))
                let bob = sin(elapsed * 1.6) * 1.0 * Double(1 - t)
                let waterline = CGPoint(x: geometry.size.width * x,
                                        y: geometry.size.height * y + bob)
                let roll = sin(elapsed * 1.2) * 0.65

                ZStack {
                    ShipWaterReflection(width: width, waterline: waterline,
                                        elapsed: elapsed, roll: roll)
                        .opacity(reduceMotion ? 0 : opacity)
                    ShipWaterWake(width: width, waterline: waterline, elapsed: elapsed)
                        .opacity(reduceMotion ? 0 : opacity)
                Image("TitleGhostShip")
                    .resizable()
                    .scaledToFit()
                    .frame(width: width, height: width * 2 / 3)
                    .rotationEffect(.degrees(roll))
                    .blur(radius: fog * 0.7)
                    .opacity(reduceMotion ? 0 : opacity * 0.88)
                    // The PNG hull sits near its lower edge: anchor that edge to the water.
                    .position(x: waterline.x, y: waterline.y - width * 0.30)
                }
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { voyageStart = Date() }
    }
}

/// Rolling crests rise at the bow and travel astern through the textured wake.
private struct ShipWaterWake: View {
    let width: CGFloat
    let waterline: CGPoint
    let elapsed: Double

    var body: some View {
        Canvas { context, _ in
            let foam = context.resolve(Image("TitleShipNaturalWake"))
            let size = CGSize(width: width * 1.45, height: width * 0.26)
            let rect = CGRect(x: waterline.x + width * 0.31 - size.width * 0.975,
                              y: waterline.y - width * 0.045 - size.height * 0.55,
                              width: size.width, height: size.height)
            // Visible local heave, rather than shifting the entire wake as one decal.
            let bands = 72
            let bandWidth = size.width / CGFloat(bands)
            for band in 0..<bands {
                let u = Double(band) / Double(bands - 1)
                let phase = elapsed * 2.7 + u * 14
                let crest = sin(phase)
                let chop = sin(elapsed * 4.1 + u * 29) * 0.22
                let heave = (crest + chop) * width * (0.013 + 0.007 * u)
                let swell = 1 + 0.16 * crest
                var water = context
                water.opacity = 0.40 + 0.10 * crest
                water.clip(to: Path(CGRect(x: rect.minX + CGFloat(band) * bandWidth,
                                          y: rect.minY - width * 0.08, width: bandWidth + 0.1,
                                          height: rect.height + width * 0.16)))
                // Scale each local column about the waterline: rising foam opens
                // out, then settles, with the phase carrying that motion leftward.
                water.translateBy(x: 0, y: waterline.y + heave)
                water.scaleBy(x: 1, y: swell)
                water.translateBy(x: 0, y: -waterline.y)
                water.draw(foam, in: rect)
            }
        }
    }
}

/// A compressed mirror broken into drifting water bands, fading with depth.
private struct ShipWaterReflection: View {
    let width: CGFloat
    let waterline: CGPoint
    let elapsed: Double
    let roll: Double

    var body: some View {
        Canvas { context, _ in
            let ship = context.resolve(Image("TitleGhostShip"))
            let imageHeight = width * 2 / 3
            let compression: CGFloat = 0.54
            let depth = imageHeight * 0.95 * compression
            let bands = 24
            let bandHeight = depth / CGFloat(bands)
            for band in 0..<bands {
                let fraction = Double(band) / Double(bands)
                let ripple = sin(elapsed * 1.7 + fraction * 19)
                    + 0.45 * sin(elapsed * 2.3 - fraction * 31)
                var water = context
                water.opacity = 0.40 * pow(1 - fraction, 1.6)
                    * (0.82 + 0.18 * sin(fraction * 41 + elapsed))
                water.clip(to: Path(CGRect(x: waterline.x - width * 0.58,
                                          y: waterline.y + CGFloat(band) * bandHeight,
                                          width: width * 1.16, height: bandHeight + 0.25)))
                water.translateBy(x: waterline.x + ripple * (0.5 + fraction * 1.7) * width / 150,
                                  y: waterline.y)
                water.scaleBy(x: 1, y: -compression)
                water.rotate(by: .degrees(roll))
                water.draw(ship, in: CGRect(x: -width / 2, y: -imageHeight * 0.95,
                                           width: width, height: imageHeight))
            }
        }
        .blur(radius: 0.55)
    }
}

struct TitleView: View {
    let onBegin: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 128)

            Image("TitleArcanaEmblem")
                .resizable()
                .scaledToFit()
                .frame(width: 132, height: 132)
                .shadow(color: .black.opacity(0.58), radius: 10, y: 4)
                .accessibilityLabel("星潮秘仪徽记")
            Text("秘仪：\n雾港升序")
                .font(.system(size: 48, weight: .black, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(.linearGradient(colors: [.white, Color(red: 1, green: 0.78, blue: 0.42)], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.35), radius: 12, y: 5)
                .accessibilityLabel("秘仪：雾港升序")
            Text("原创塔罗战斗 RPG")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(Color(red: 0.86, green: 0.78, blue: 0.57))
                .shadow(color: .black.opacity(0.4), radius: 3, y: 1)

            // The interactive gate is rendered by ContentView above the fog layer.
            // This placeholder preserves the title composition at every screen size.
            Color.clear
                .frame(width: 164, height: 46)
                .padding(.top, 14)

            Spacer()

            HStack {
                Spacer()
                Text("UBAI开发制作")
                    .font(.caption2.weight(.medium))
                    .tracking(0.7)
                    .foregroundStyle(.white.opacity(0.52))
            }
            .padding(.trailing, 8)
            .padding(.bottom, 4)
        }
        .accessibilityElement(children: .contain)
    }
}

/// 独立于背景图的一整团动态雾：整体二维漂浮，并像呼吸一样改变浓淡与大小。
struct DriftingMist: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            GeometryReader { proxy in
                let seconds = timeline.date.timeIntervalSinceReferenceDate
                let motion: CGFloat = reduceMotion ? 0 : 1
                // Several long, incommensurate cycles avoid an obvious looping path.
                let driftXWave = sin(seconds * .pi * 2 / 36) + 0.25 * sin(seconds * .pi * 2 / 56 + 1.3)
                let driftYWave = cos(seconds * .pi * 2 / 46 + 0.7) + 0.22 * sin(seconds * .pi * 2 / 70)
                let scaleWave = sin(seconds * .pi * 2 / 58 + 0.4) + 0.20 * cos(seconds * .pi * 2 / 86)
                let opacityWave = cos(seconds * .pi * 2 / 113 + 1.1)
                let driftX = CGFloat(driftXWave) * proxy.size.width * 0.24 * motion
                let driftY = CGFloat(driftYWave) * proxy.size.height * 0.095 * motion
                let breathingScale = 1.02 + CGFloat(scaleWave) * 0.14 * motion
                // Nearly constant opacity: just enough depth change to feel alive, never a pulse.
                let breathingOpacity = 0.55 + opacityWave * 0.012 * Double(motion)
                let sway = sin(seconds * .pi * 2 / 89) * 0.7 * Double(motion)

                ZStack {
                    mistCloud(width: proxy.size.width * 1.04, height: 182, opacity: 0.62)
                        .offset(x: -proxy.size.width * 0.24, y: -proxy.size.height * 0.19)
                        .rotationEffect(.degrees(-6))
                    mistCloud(width: proxy.size.width * 1.20, height: 218, opacity: 0.84)
                        .offset(x: proxy.size.width * 0.12, y: -proxy.size.height * 0.02)
                        .rotationEffect(.degrees(4))
                    mistCloud(width: proxy.size.width * 0.88, height: 162, opacity: 0.54)
                        .offset(x: -proxy.size.width * 0.28, y: proxy.size.height * 0.16)
                        .rotationEffect(.degrees(-2))
                    mistCloud(width: proxy.size.width * 0.70, height: 136, opacity: 0.72)
                        .offset(x: proxy.size.width * 0.30, y: proxy.size.height * 0.27)
                        .rotationEffect(.degrees(7))
                    mistCloud(width: proxy.size.width * 0.48, height: 116, opacity: 0.46)
                        .offset(x: -proxy.size.width * 0.34, y: proxy.size.height * 0.02)
                        .rotationEffect(.degrees(-11))
                }
                // Keep the compositing canvas far outside every screen edge so
                // blur and rotation never reveal a rectangular seam.
                .frame(width: proxy.size.width * 1.80, height: proxy.size.height * 1.55)
                .position(x: proxy.size.width / 2, y: proxy.size.height * 0.50)
                .scaleEffect(breathingScale)
                .rotationEffect(.degrees(sway))
                .opacity(breathingOpacity)
                .offset(x: driftX, y: driftY)
                .blendMode(.screen)
                .drawingGroup()
            }
        }
    }

    private func mistCloud(width: CGFloat, height: CGFloat, opacity: Double) -> some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        Color(red: 0.72, green: 0.82, blue: 0.90).opacity(opacity * 0.72),
                        .white.opacity(opacity),
                        Color(red: 0.63, green: 0.76, blue: 0.86).opacity(opacity * 0.64),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: height)
            .blur(radius: 17)
    }
}

struct TitleGateButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text("‹‹")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .tracking(-2)
                Text("进入雾港")
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .tracking(1.5)
                    .foregroundStyle(Color(red: 1.0, green: 0.94, blue: 0.82))
                Text("››")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .tracking(-2)
            }
            .foregroundStyle(Color(red: 0.82, green: 0.67, blue: 0.37))
            .frame(width: 190, height: 46)
            .contentShape(.rect)
            .shadow(color: Color(red: 0.58, green: 0.39, blue: 0.14).opacity(0.38), radius: 7)
            .shadow(color: .black.opacity(0.40), radius: 3, y: 2)
        }
        .buttonStyle(TitleGatePressStyle())
        .accessibilityHint("开始游戏并选择路径")
    }
}

private struct TitleGatePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct TitleFact: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.monospaced()).foregroundStyle(.yellow)
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.55))
        }
        .frame(minWidth: 64)
    }
}

struct PathSelectionView: View {
    let onSelect: (Pathway, CharacterGender) -> Void
    let onBack: () -> Void
    @State private var selectedGender: CharacterGender = .male

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GameArtReturnButton(title: "返回", action: onBack)
            Text("第一张牌决定\n最初的道路")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("当前开放愚者路径与第一章30关调查。")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 28) {
                ForEach(CharacterGender.allCases) { gender in
                    Button {
                        withAnimation(.easeInOut(duration: 0.28)) {
                            selectedGender = gender
                        }
                    } label: {
                        VStack(spacing: 7) {
                            Text(gender.title)
                                .font(.headline.weight(selectedGender == gender ? .bold : .medium))
                                .foregroundStyle(
                                    selectedGender == gender
                                        ? Color(red: 0.91, green: 0.79, blue: 0.53)
                                        : .white.opacity(0.52)
                                )
                            Capsule()
                                .fill(
                                    selectedGender == gender
                                        ? Color(red: 0.68, green: 0.49, blue: 0.21)
                                        : .clear
                                )
                                .frame(height: 2)
                                .shadow(
                                    color: Color(red: 0.86, green: 0.68, blue: 0.34).opacity(selectedGender == gender ? 0.65 : 0),
                                    radius: 5
                                )
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .accessibilityHint("切换三条路径的男性或女性角色")

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(GameContent.initiallyAvailablePathways.filter { $0.id == .fool }) { path in
                        PathCard(
                            path: path,
                            gender: selectedGender,
                            action: { onSelect(path, selectedGender) }
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

struct PathCard: View {
    let path: Pathway
    let gender: CharacterGender
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    Image(path.artName(for: gender))
                        .resizable()
                        .scaledToFill()
                        .frame(height: 230)
                        .clipped()
                        .accessibilityHidden(true)
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.85)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(path.displayName(for: gender))
                            .font(.title2.bold())
                            .foregroundStyle(path.tint)
                        Text("序列 9 · \(path.sequenceNineTitle(for: gender))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    .padding(14)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(path.characterDescription(for: gender))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                        .multilineTextAlignment(.leading)
                    Text("扮演原则：\(path.principle)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.yellow.opacity(0.92))
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(path.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(path.tint.opacity(0.45), lineWidth: 1) }
            .compositingGroup()
            .clipShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("选择\(path.displayName(for: gender))路径，\(gender.title)角色，序列九\(path.sequenceNineTitle(for: gender))")
        .accessibilityHint(path.principle)
    }
}

struct AdventureView: View {
    let game: GameStore
    let onExit: () -> Void

    var body: some View {
        if let path = game.selectedPath, let encounter = game.currentEncounter, let alignedChoice = game.currentAlignedChoice {
            GeometryReader { geometry in
                ZStack {
                    Image(decorative: encounter.artName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()

                    LinearGradient(
                        colors: [.black.opacity(0.18), .clear, .black.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    SceneAtmosphere(
                        rainStrength: rainStrength,
                        fogOpacity: game.encounterIndex >= 2 ? 0.24 : 0.14,
                        tint: path.tint
                    )

                    VStack(spacing: 10) {
                        SceneAdventureHUD(
                            path: path,
                            eventIndex: game.encounterIndex + 1,
                            game: game,
                            onExit: onExit
                        )
                        Spacer()
                        SceneResultToast(message: game.latestResult, tint: path.tint)
                            .opacity(game.latestResult.isEmpty ? 0 : 1)
                            .offset(y: game.latestResult.isEmpty ? 10 : 0)
                        SceneActionDock(
                            encounter: encounter,
                            path: path,
                            alignedChoice: alignedChoice,
                            game: game
                        )
                    }
                    .frame(
                        width: max(0, geometry.size.width - 28),
                        height: max(0, geometry.size.height - 16)
                    )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
            .ignoresSafeArea()
            .animation(.smooth(duration: 0.42), value: encounter.id)
            .animation(.easeInOut(duration: 0.22), value: game.latestResult)
            .sensoryFeedback(.selection, trigger: game.encounterIndex)
        } else {
            EmptyView()
        }
    }

    private var rainStrength: Int {
        switch game.encounterIndex {
        case 0: 36
        case 1: 22
        default: 0
        }
    }
}

private struct SceneAdventureHUD: View {
    let path: Pathway
    let eventIndex: Int
    let game: GameStore
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                GameArtReturnButton(action: onExit)
                ArcanaSeal(symbol: path.symbol, tint: path.tint, size: 34)
                VStack(alignment: .leading, spacing: 0) {
                    Text(path.name)
                        .font(.caption.bold())
                        .foregroundStyle(path.tint)
                    Text("雾岬调查")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
                Text("\(eventIndex)/\(GameContent.encounters.count)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(path.tint)
            }
            HStack(spacing: 20) {
                SceneResourcePill(symbol: "circle.dotted", value: game.acting, goal: 3, tint: .purple)
                SceneResourcePill(symbol: "waveform.path.ecg", value: game.clues, goal: 2, tint: .cyan)
                SceneResourcePill(symbol: "diamond.fill", value: game.materials, goal: 2, tint: .yellow)
            }
            .frame(maxWidth: .infinity)
            ProgressView(value: Double(eventIndex - 1), total: Double(GameContent.encounters.count))
                .tint(path.tint)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.14), lineWidth: 1) }
    }
}

private struct SceneResourcePill: View {
    let symbol: String
    let value: Int
    let goal: Int
    let tint: Color

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: symbol)
                .font(.caption2)
            Text("\(value)/\(goal)")
                .font(.caption2.bold().monospacedDigit())
        }
        .foregroundStyle(tint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("进度 \(value)，目标 \(goal)")
    }
}

private struct SceneActionDock: View {
    let encounter: Encounter
    let path: Pathway
    let alignedChoice: StoryChoice
    let game: GameStore

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(encounter.district)
                        .font(.caption2.bold())
                        .foregroundStyle(path.tint)
                    Text(encounter.title)
                        .font(.title3.bold())
                }
                Spacer()
                SceneAbilityButton(path: path, game: game)
            }

            Text(encounter.body)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.70))
                .lineLimit(2)

            VStack(spacing: 6) {
                SceneChoiceButton(choice: alignedChoice, path: path, isDisabled: game.isResolving) {
                    game.choose(alignedChoice)
                }
                SceneChoiceButton(choice: encounter.fallbackChoice, path: path, isDisabled: game.isResolving) {
                    game.choose(encounter.fallbackChoice)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(path.tint.opacity(0.42), lineWidth: 1) }
        .compositingGroup()
        .clipShape(.rect(cornerRadius: 20))
    }
}

private struct SceneChoiceButton: View {
    let choice: StoryChoice
    let path: Pathway
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(choice.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(choice.isPathAligned ? path.tint : .white.opacity(0.84))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                .padding(.leading, 46)
                .padding(.trailing, 12)
                .background {
                    Image("ButtonArt20SceneChoice")
                        .resizable(capInsets: EdgeInsets(top: 18, leading: 52, bottom: 18, trailing: 52), resizingMode: .stretch)
                        .accessibilityHidden(true)
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.56 : 1)
        .accessibilityHint(choice.isPathAligned ? "契合当前路径" : "稳妥行动")
    }
}

private struct SceneAbilityButton: View {
    let path: Pathway
    let game: GameStore

    var body: some View {
        Button(action: game.enableAbility) {
            Text(game.abilityEnabled ? "已启用" : "启用路径能力")
                .font(.caption.bold())
                .foregroundStyle(Color(red: 0.92, green: 0.89, blue: 0.79))
                .frame(width: 156, height: 48)
                .background {
                    Image("ButtonArt22SceneAbility")
                        .resizable(capInsets: EdgeInsets(top: 30, leading: 54, bottom: 30, trailing: 54), resizingMode: .stretch)
                        .accessibilityHidden(true)
                }
        }
        .buttonStyle(.plain)
        .disabled(game.abilityUsed || game.isResolving)
        .opacity(game.abilityUsed || game.isResolving ? 0.58 : 1)
        .accessibilityLabel("启用\(path.abilityName)")
        .accessibilityValue(game.abilityEnabled ? "已启用" : game.abilityUsed ? "本场已使用" : "可用")
    }
}

private struct SceneResultToast: View {
    let message: String
    let tint: Color

    var body: some View {
        Label(message.isEmpty ? "行动结果" : message, systemImage: "sparkles")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.black.opacity(0.72), in: Capsule())
            .overlay { Capsule().stroke(tint.opacity(0.42), lineWidth: 1) }
    }
}

struct PathMiniHeader: View {
    let path: Pathway

    var body: some View {
        HStack(spacing: 9) {
            ArcanaSeal(symbol: path.symbol, tint: path.tint, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(path.name).font(.headline).foregroundStyle(path.tint)
                Text("序列 9 · \(path.sequenceNineTitle)").font(.caption2).foregroundStyle(.white.opacity(0.56))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct ProgressHeader: View {
    let index: Int
    let total: Int
    let path: Pathway

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("雾港调查")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.68))
                Spacer()
                Text("事件 \(index) / \(total)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(path.tint)
            }
            ProgressView(value: Double(index - 1), total: Double(total))
                .tint(path.tint)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("雾港调查进度，事件 \(index)，共 \(total) 个事件")
    }
}

struct ResourceBoard: View {
    let game: GameStore

    var body: some View {
        HStack(spacing: 8) {
            ResourceMeter(label: "扮演", symbol: "circle.dotted", value: game.acting, goal: 3, tint: .purple)
            ResourceMeter(label: "线索", symbol: "waveform.path.ecg", value: game.clues, goal: 2, tint: .cyan)
            ResourceMeter(label: "材料", symbol: "diamond.fill", value: game.materials, goal: 2, tint: .yellow)
            ResourceMeter(label: "失控", symbol: "flame.fill", value: game.instability, goal: 6, tint: .red)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("晋升资源")
    }
}

struct ResourceMeter: View {
    let label: String
    let symbol: String
    let value: Int
    let goal: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: symbol).foregroundStyle(tint).font(.caption)
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.6))
            Text("\(value)/\(goal)").font(.caption.bold().monospacedDigit()).foregroundStyle(.white)
            ProgressView(value: Double(value), total: Double(goal)).tint(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value)，目标 \(goal)")
    }
}

struct EncounterPanel: View {
    let encounter: Encounter
    let path: Pathway

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(encounter.district, systemImage: "location.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(path.tint)
            Text(encounter.title).font(.title2.bold()).foregroundStyle(.white)
            Text(encounter.body).font(.body).foregroundStyle(.white.opacity(0.74)).lineSpacing(4)
        }
        .padding(18)
        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.14), lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}

struct StoryChoiceButton: View {
    let choice: StoryChoice
    let path: Pathway
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: choice.isPathAligned ? path.symbol : "diamond")
                    .font(.title3)
                    .foregroundStyle(choice.isPathAligned ? path.tint : .white.opacity(0.65))
                    .frame(width: 30)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(choice.title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                    Text(choice.detail).font(.caption).foregroundStyle(.white.opacity(0.60)).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                if choice.isPathAligned {
                    Text("契合")
                        .font(.caption2.bold())
                        .foregroundStyle(path.tint)
                }
            }
            .foregroundStyle(.white)
            .padding(14)
            .background(choice.isPathAligned ? path.tint.opacity(0.14) : .white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(choice.isPathAligned ? path.tint.opacity(0.5) : .white.opacity(0.16), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.58 : 1)
        .accessibilityHint(choice.isPathAligned ? "契合当前路径" : "稳妥行动，但失控侵蚀加一")
    }
}

struct AbilityPanel: View {
    let path: Pathway
    let isUsed: Bool
    let isEnabled: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ArcanaSeal(symbol: path.symbol, tint: path.tint, size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text("路径能力 · 每场一次").font(.caption2).foregroundStyle(.white.opacity(0.52))
                Text(path.abilityName).font(.subheadline.bold()).foregroundStyle(path.tint)
                Text(path.abilityDescription).font(.caption).foregroundStyle(.white.opacity(0.66))
            }
            Spacer(minLength: 0)
            Button(isUsed ? (isEnabled ? "已启用" : "已使用") : "启用", action: action)
                .font(.caption.bold())
                .buttonStyle(.bordered)
                .tint(path.tint)
                .disabled(isUsed || isDisabled)
        }
        .padding(12)
        .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct RitualView: View {
    let game: GameStore

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(decorative: "SceneSaltRitual")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                LinearGradient(
                    colors: [.black.opacity(0.22), .clear, .black.opacity(0.74)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                SceneAtmosphere(rainStrength: 0, fogOpacity: 0.24, tint: game.selectedPath?.tint ?? .purple)

                VStack(spacing: 12) {
                    Label("晋升仪式 · 9 → 8", systemImage: game.selectedPath?.symbol ?? "sparkles")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.60), in: Capsule())
                    Spacer()
                    RitualAura(tint: game.selectedPath?.tint ?? .purple)
                    Spacer()
                    VStack(spacing: 12) {
                        Text(game.ritualIsReady ? "仪式已稳固" : "锚点不足")
                            .font(.title2.bold())
                        HStack(spacing: 8) {
                            RitualCheck(label: "扮演", value: game.acting, goal: 3)
                            RitualCheck(label: "线索", value: game.clues, goal: 2)
                            RitualCheck(label: "材料", value: game.materials, goal: 2)
                        }
                        MistButton(
                            title: game.ritualIsReady ? "开始晋升" : "强行晋升",
                            symbol: "sparkles",
                            tint: game.selectedPath?.tint ?? .purple,
                            action: game.resolveRitual
                        )
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))
                    .overlay { RoundedRectangle(cornerRadius: 20).stroke((game.selectedPath?.tint ?? .purple).opacity(0.44), lineWidth: 1) }
                }
                .frame(
                    width: max(0, geometry.size.width - 28),
                    height: max(0, geometry.size.height - 16)
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }
}

private struct RitualAura: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let tint: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let elapsed = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let pulse = 1 + (sin(elapsed * 1.8) + 1) * 0.05

            ZStack {
                Circle()
                    .stroke(tint.opacity(0.62), style: StrokeStyle(lineWidth: 2, dash: [7, 8]))
                    .rotationEffect(.degrees(elapsed * 15))
                Circle()
                    .stroke(.cyan.opacity(0.42), style: StrokeStyle(lineWidth: 1, dash: [2, 12]))
                    .padding(18)
                    .rotationEffect(.degrees(-elapsed * 22))
                ArcanaSeal(symbol: "sparkles", tint: tint, size: 76)
            }
            .frame(width: 170, height: 170)
            .scaleEffect(pulse)
            .shadow(color: tint.opacity(0.55), radius: 24)
        }
        .accessibilityHidden(true)
    }
}

struct RitualCheck: View {
    let label: String
    let value: Int
    let goal: Int

    var body: some View {
        Text("\(label) \(value)/\(goal)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(value >= goal ? .yellow : .white.opacity(0.5))
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(.white.opacity(0.08), in: Capsule())
    }
}

struct EndingView: View {
    let success: Bool
    let path: Pathway?
    let onRestart: () -> Void
    let onStore: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ArcanaSeal(symbol: success ? (path?.symbol ?? "sparkles") : "flame.fill", tint: success ? (path?.tint ?? .purple) : .red, size: 104)
            Text("雾港篇 · 结算").font(.caption.weight(.semibold)).tracking(1.1).foregroundStyle(.white.opacity(0.6))
            Text(success ? "晋升成功：\n序列 8" : "仪式反噬：\n暂退雾港")
                .font(.largeTitle.bold()).multilineTextAlignment(.center).foregroundStyle(.white)
            Text(success ? "盐雾让开一道缝隙。远处那面剧院镜子碎裂前，映出了第二张塔罗牌。" : "仪式没有完全拒绝你，但海雾吞去了部分记忆。下一次，你需要更完整地理解自己的路径。")
                .multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.72)).lineSpacing(4)
            MistButton(title: "再次进入雾港", symbol: "arrow.clockwise", tint: path?.tint ?? .purple, action: onRestart)
            Button("查看后续篇章", action: onStore).font(.subheadline.weight(.semibold)).foregroundStyle(.yellow)
            Spacer()
        }
    }
}

struct StoreView: View {
    @Environment(\.dismiss) private var dismiss
    let storefront: Storefront

    var body: some View {
        ZStack {
            Image("MistportWorldMap")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            LinearGradient(
                colors: [.white.opacity(0.10), Color(red: 0.02, green: 0.08, blue: 0.18).opacity(0.34), Color(red: 0.02, green: 0.03, blue: 0.10).opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        GameArtReturnButton { dismiss() }
                        Spacer()
                        Text("篇章典藏")
                            .font(.caption.weight(.bold))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.84))
                    }

                    Image("EmblemChapter")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 112, height: 112)
                        .shadow(color: .cyan.opacity(0.45), radius: 18)
                        .accessibilityHidden(true)

                    VStack(spacing: 5) {
                        Text("雾港之后")
                            .font(.system(size: 36, weight: .black, design: .serif))
                        Text("大型篇章扩展")
                            .font(.subheadline.weight(.bold))
                            .tracking(3)
                            .foregroundStyle(.yellow)
                    }
                    .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("第一章 · 雾港自由联邦")
                                .font(.headline)
                            Spacer()
                            Text("完整免费")
                                .font(.caption.weight(.black))
                                .foregroundStyle(Color(red: 0.10, green: 0.42, blue: 0.32))
                        }

                        Text("20 项主任务 · 愚者序列 9→8 · 波次战斗 · 单人完整晋阶")
                            .font(.subheadline)
                            .foregroundStyle(.black.opacity(0.68))

                        HStack(spacing: 6) {
                            StorePromiseBadge(title: "无体力")
                            StorePromiseBadge(title: "无抽卡")
                            StorePromiseBadge(title: "无付费战力")
                        }
                    }
                    .padding(18)
                    .background(.white.opacity(0.90), in: .rect(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.white.opacity(0.92), lineWidth: 1)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("扩展内容")
                            .font(.caption.weight(.bold))
                            .tracking(2)
                            .foregroundStyle(.cyan)
                        Text("新的联邦、序列晋升、敌人与剧情")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text("一次购买，永久拥有。衣装只改变外观；付费内容不会提高第一章战力。")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                            .lineSpacing(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color(red: 0.03, green: 0.08, blue: 0.18).opacity(0.88), in: .rect(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.cyan.opacity(0.42), lineWidth: 1)
                    }

                    if storefront.hasChapterExpansion {
                        Text("◆  后续篇章已永久解锁  ◆")
                            .font(.headline.weight(.black))
                            .foregroundStyle(.yellow)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.black.opacity(0.68), in: Capsule())
                    } else {
                        Button {
                            Task { await storefront.purchaseChapterExpansion() }
                        } label: {
                            Text(purchaseTitle)
                                .font(.headline.weight(.black))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ChapterPurchaseButtonStyle())
                        .disabled(storefront.purchaseState == .loading || storefront.purchaseState == .purchasing || storefront.product == nil)

                        Button("恢复已有购买") {
                            Task { await storefront.restorePurchases() }
                        }
                        .buttonStyle(ChapterTextButtonStyle())
                    }

                    if case .failed(let message) = storefront.purchaseState {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(10)
                            .background(.white.opacity(0.90), in: Capsule())
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var purchaseTitle: String {
        switch storefront.purchaseState {
        case .loading:
            return "正在连接 App Store…"
        case .purchasing:
            return "正在处理购买…"
        case .unavailable:
            return "上架后显示价格"
        default:
            return storefront.product.map { "解锁后续篇章 · \($0.displayPrice)" } ?? "后续篇章尚未上架"
        }
    }
}

private struct StorePromiseBadge: View {
    let title: String

    var body: some View {
        Text("◆ \(title)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color(red: 0.08, green: 0.28, blue: 0.42))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(Color.cyan.opacity(0.13), in: Capsule())
    }
}

private struct ChapterTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color(red: 0.15, green: 0.13, blue: 0.17).opacity(configuration.isPressed ? 0.58 : 0.92))
            .padding(.horizontal, 26)
            .frame(minHeight: 48)
            .background {
                Image("ButtonArt23ChapterText")
                    .resizable(capInsets: EdgeInsets(top: 0, leading: 96, bottom: 0, trailing: 96), resizingMode: .stretch)
                    .accessibilityHidden(true)
            }
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct ChapterPurchaseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.black))
            .foregroundStyle(Color(red: 0.13, green: 0.11, blue: 0.16))
            .frame(maxWidth: .infinity, minHeight: 68)
            .background {
                Image("ButtonArt24ChapterPurchase")
                    .resizable(capInsets: EdgeInsets(top: 26, leading: 120, bottom: 26, trailing: 120), resizingMode: .stretch)
                    .accessibilityHidden(true)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ArcanaSeal: View {
    let symbol: String
    let tint: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(.black.opacity(0.22))
            Circle().stroke(tint.opacity(0.72), lineWidth: 1)
            Circle().stroke(tint.opacity(0.25), lineWidth: 1).padding(size * 0.12)
            Image(systemName: symbol).font(.system(size: size * 0.35, weight: .medium)).foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct MistButton: View {
    let title: String
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        MistportPlaqueButton(title: title, action: action)
    }
}
