import SwiftUI

/// A name plate pinned to a building on the city hub panorama, in the same
/// dark-glass-and-gold language as the hub's status card: gold serif name on
/// a small dark plate with a gold rim, a hairline stem and a glowing pin that
/// marks the building itself. Places you can enter carry a small arrow.
struct CityLandmarkPlaque: View {
    let title: String
    var enterable = false

    private static let gold = Color(red: 0.93, green: 0.78, blue: 0.48)
    private static let paleGold = Color(red: 1.0, green: 0.93, blue: 0.76)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .tracking(2)
                    .foregroundStyle(LinearGradient(colors: [Self.paleGold, Self.gold],
                                                    startPoint: .top, endPoint: .bottom))
                    .lineLimit(1)
                    .fixedSize()
                if enterable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Self.gold.opacity(0.9))
                }
            }
            .padding(.leading, 11)
            .padding(.trailing, enterable ? 8 : 9)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.07, green: 0.06, blue: 0.08).opacity(0.78),
                                                  Color(red: 0.12, green: 0.09, blue: 0.06).opacity(0.62)],
                                         startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Self.paleGold.opacity(0.75), Self.gold.opacity(0.35)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 0.8)
            }
            .overlay(alignment: .leading) { diamond.offset(x: -2.5) }
            .overlay(alignment: .trailing) { diamond.offset(x: 2.5) }
            // Stem and pin on the building.
            Rectangle()
                .fill(LinearGradient(colors: [Self.gold.opacity(0.7), Self.gold.opacity(0.2)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 1, height: 9)
            Circle()
                .fill(Self.paleGold)
                .frame(width: 4, height: 4)
                .shadow(color: Self.gold.opacity(0.9), radius: 3)
        }
        .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
    }

    private var diamond: some View {
        Rectangle()
            .fill(Self.gold)
            .frame(width: 4, height: 4)
            .rotationEffect(.degrees(45))
    }
}
