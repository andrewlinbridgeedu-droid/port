import SwiftUI

struct VenueView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var game: GameStore
    let venue: VenueDefinition

    var body: some View {
        HomeCounterScene(title: venue.name, room: venue.kind == .cafe ? .cafe : .restaurant,
                         actorArt: venue.ownerArtName) {
            HStack {
                Text("\(venue.ownerName) · \(venue.ownerTitle)").font(.headline)
                Spacer()
                Text("\(game.venueCoins) 铜").monospacedDigit()
            }
            Text(game.venueMessage.isEmpty ? venue.greeting : game.venueMessage)
            offerShelf
        }
    }

    private var ownerCounterScene: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill((venue.kind == .cafe ? Color.purple : Color.orange).opacity(0.18))
                .frame(width: 210, height: 74)
                .blur(radius: 22)
                .offset(y: -28)

            Image(venue.ownerArtName)
                .resizable()
                .scaledToFit()
                .frame(width: 430, height: 430)
                .compositingGroup()
                .offset(y: 8)
                .shadow(color: .black.opacity(0.34), radius: 12, y: 7)
        }
        .accessibilityHidden(true)
    }

    private var venueHeader: some View {
        HStack(spacing: 10) {
            GameArtReturnButton { dismiss() }

            VStack(alignment: .leading, spacing: 1) {
                Text(venue.name)
                    .font(.headline.bold())
                Text(venue.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.62))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 5) {
                Image(decorative: "RewardCoin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 25, height: 25)
                Text("\(game.venueCoins)")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(.yellow)
            }
            .padding(.horizontal, 9)
            .frame(height: 36)
            .background(.black.opacity(0.58), in: VenuePlateShape(cut: 8))
            .accessibilityLabel("金币 \(game.venueCoins)")
        }
        .foregroundStyle(.white)
    }

    private var ownerDialogue: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(venue.ownerName)
                    .font(.headline.bold())
                Text(venue.ownerTitle)
                    .font(.caption2.bold())
                    .foregroundStyle(.purple)
            }
            Text(game.venueMessage)
                .font(.callout)
                .foregroundStyle(.black.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .foregroundStyle(.black.opacity(0.88))
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 2)
                .fill(.white.opacity(0.82))
                .frame(width: 19, height: 19)
                .rotationEffect(.degrees(45))
                .offset(x: -22, y: 8)
        }
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.92), lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }

    private var offerShelf: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ],
            spacing: 8
        ) {
            ForEach(game.venueOffers) { offer in
                VenueOfferView(
                    offer: offer,
                    canAfford: game.venueCoins >= offer.item.price,
                    onPurchase: { game.purchaseVenueOffer(offer.id) }
                )
            }
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .contain)
    }
}

private struct VenueOfferView: View {
    let offer: VenueOffer
    let canAfford: Bool
    let onPurchase: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Group {
                    if let artName = offer.item.artName {
                        Image(decorative: artName)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: offer.item.symbol)
                            .font(.title2.bold())
                            .foregroundStyle(offer.item.rarity.tint)
                    }
                }
                .frame(width: 48, height: 48)
                .shadow(color: offer.item.rarity.tint.opacity(0.26), radius: 7)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(offer.item.rarity.title)
                        .font(.system(size: 9, weight: .bold))
                    Text("I阶")
                        .font(.system(size: 8, weight: .semibold))
                }
                .foregroundStyle(offer.item.rarity.tint)
            }

            Text(offer.item.name)
                .font(.caption.bold())
                .lineLimit(1)
            Text(offer.item.detail)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Button(action: onPurchase) {
                HStack {
                    Text(offer.isSold ? "已售出" : "购买")
                    Spacer()
                    if !offer.isSold {
                        HStack(spacing: 3) {
                            Image(decorative: "RewardCoin")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 17, height: 17)
                            Text("\(offer.item.price)")
                                .monospacedDigit()
                        }
                    }
                }
                .font(.caption.bold())
            }
            .buttonStyle(GameArtButtonStyle(compact: true))
            .disabled(offer.isSold || !canAfford)
        }
        .foregroundStyle(.white)
        .padding(8)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 174)
        .background(.black.opacity(0.48), in: VenuePlateShape(cut: 13))
        .overlay {
            VenuePlateShape(cut: 13)
                .stroke(offer.item.rarity.tint.opacity(offer.item.rarity == .rare ? 0.70 : 0.20), lineWidth: offer.item.rarity == .rare ? 1.5 : 1)
        }
        .opacity(offer.isSold ? 0.58 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(offer.item.name)，\(offer.item.detail)，价格 \(offer.item.price) 铜币，\(offer.isSold ? "已售出" : "可购买")")
    }
}

private struct VenuePlateShape: Shape {
    let cut: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        path.closeSubpath()
        return path
    }
}

#if DEBUG
#Preview {
    let game = GameStore(launchArguments: ["--preview-venue"], defaults: UserDefaults(suiteName: "venue-preview") ?? .standard)
    VenueView(game: game, venue: GameContent.oldClockVenues[0])
}
#endif

#if DEBUG
/// The legacy rotating venue shelf is gated in this build; show its real card component without unlocking gameplay.
struct VenueOfferArtReview: View {
    @State private var sold: Set<String> = []
    var body: some View {
        GameArtPage(title: "商品柜台", subtitle: "商品组件 · 隔离预览", art: "HomeCafeEmpty20260929") {
            Text("此处仅查看商品卡样式。正式随机货架尚未开放。")
                .font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(GameContent.oldClockVenues[0].catalog) { item in
                    VenueOfferView(offer: VenueOffer(id: item.id, item: item, isSold: sold.contains(item.id)),
                        canAfford: item.price <= 30, onPurchase: { sold.insert(item.id) })
                }
            }
        }
    }
}
#endif
