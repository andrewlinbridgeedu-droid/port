import SwiftUI

enum GameEmblem: CaseIterable {
    case profile
    case chapter
    case build
    case expedition
    case supply
    case inventory
    case advancement

    var assetName: String {
        switch self {
        case .profile: "EmblemProfile"
        case .chapter: "EmblemChapter"
        case .build: "IconRelicMirrorCase"
        case .expedition: "EmblemExpedition"
        case .supply: "EmblemSupply"
        case .inventory: "EmblemInventory"
        case .advancement: "EmblemAdvancement"
        }
    }
}

struct GameEmblemView: View {
    let emblem: GameEmblem
    let tint: Color

    var body: some View {
        Image(decorative: emblem.assetName)
            .resizable()
            .scaledToFit()
            .shadow(color: tint.opacity(0.22), radius: 4)
        .accessibilityHidden(true)
    }
}

private struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.25))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.25))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.25))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.25))
            path.closeSubpath()
        }
    }
}

struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)); path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY)); path.addLine(to: CGPoint(x: rect.minX, y: rect.midY)); path.closeSubpath()
        }
    }
}

struct OrnamentLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}
