import SwiftUI

/// Review harness for the home harbour scene: the phone framing of the city
/// hub (the 16:9 painting fills the height, centred), without the rest of the
/// game. Launch arguments: -MistportCityHour, -MistportCityTimeScale,
/// -MistportCityRain (see CityLivingScene.swift), -HarnessChrome to dim the
/// areas covered by the hub's status card, mission strip and bottom bar.
@main
struct HarborHarnessApp: App {
    var body: some Scene { WindowGroup { HarnessView() } }
}

struct HarnessView: View {
    var body: some View {
        GeometryReader { geo in
            let side = max(geo.size.width, geo.size.height * HarborPainting.aspect)
            // -HarnessPan left | right | 0.5 …: like dragging the hub panorama to
            // its left or right end; omitted is the default centred view.
            // (A value starting with "-" would be read as another argument.)
            let panText = UserDefaults.standard.string(forKey: "HarnessPan") ?? ""
            let pan = panText == "left" ? -1 : panText == "right" ? 1 : (Double(panText) ?? 0)
            let travel = (side - geo.size.width) / 2
            ZStack {
                ZStack {
                    CityLivingScene()
                    HarnessTags(viewport: geo.size, panoramaWidth: side)
                }
                    .frame(width: side, height: geo.size.height)
                    .offset(x: -CGFloat(pan) * travel)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                if ProcessInfo.processInfo.arguments.contains("-HarnessChrome") {
                    VStack(spacing: 0) {
                        HStack {
                            RoundedRectangle(cornerRadius: 16).fill(.black.opacity(0.62)).frame(width: 92, height: 86)
                            Spacer()
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, geo.safeAreaInsets.top + 8)
                        Spacer()
                        RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.72)).frame(height: 88).padding(.horizontal, 28)
                        Rectangle().fill(.black.opacity(0.55)).frame(height: 120 + geo.safeAreaInsets.bottom)
                    }
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

/// -HarnessTags new | old: the hub's building labels at the hub's positions
/// (see SceneViews.cityHotspots), in the new plaque style or the old pill.
struct HarnessTags: View {
    let viewport: CGSize
    let panoramaWidth: CGFloat

    func at(_ x: Double, _ y: Double) -> CGPoint {
        let painting = HarborPainting.rect(in: CGSize(width: panoramaWidth, height: viewport.height))
        return CGPoint(x: painting.minX + CGFloat(x) * painting.height, y: painting.minY + CGFloat(y) * painting.height - 20)
    }

    var body: some View {
        let style = UserDefaults.standard.string(forKey: "HarnessTags") ?? ""
        let tags: [(String, CGPoint, Bool)] = [
            ("皇宫", at(1.180, 0.223), false), ("教会", at(0.532, 0.277), true), ("银行", at(0.374, 0.390), false),
            ("科学委员会", at(0.140, 0.444), false), ("报社", at(0.584, 0.430), false),
            ("市政厅", at(1.180, 0.464), false), ("工业委员会", at(1.256, 0.647), false)]
        ZStack {
            if style == "new" || style == "old" {
                ForEach(tags, id: \.0) { tag in
                    Group {
                        if style == "new" {
                            CityLandmarkPlaque(title: tag.0, enterable: tag.2)
                        } else {
                            Text(tag.0)
                                .font(.system(size: 14, weight: .semibold, design: .serif))
                                .foregroundStyle(Color(red: 0.16, green: 0.17, blue: 0.20))
                                .padding(.horizontal, 13).padding(.vertical, 7)
                                .background(.white.opacity(0.83), in: Capsule())
                                .overlay { Capsule().stroke(.white.opacity(0.52), lineWidth: 1) }
                                .shadow(color: .black.opacity(0.30), radius: 4, y: 2)
                        }
                    }
                    .position(tag.1)
                }
            }
        }
        .frame(width: panoramaWidth, height: viewport.height)
    }
}
