import MistportCombatCore
import SwiftUI

struct CharacterWeaponDefinition: Identifiable {
    let id: String
    let name: String
    let effect: String
    let power: Int
    let unlockAt: Int
    let color: Color
}

struct CharacterOutfitDefinition: Identifiable {
    let id: String
    let name: String
    let detail: String
    let artName: String
    let color: Color

    var bonus: MPCOutfitBonus { MPCOutfit(rawValue: id)?.bonus ?? .none }
}

struct CharacterPassiveDefinition: Identifiable {
    let id: String
    let name: String
    let effect: String
    let unlockAt: Int
    let color: Color
}

enum CharacterLoadoutCatalog {
    static let foolWeapons = [
        CharacterWeaponDefinition(id: "silver-lie-blade", name: "偏差透镜", effect: "攻击4层误认目标时获得穿甲", power: 18, unlockAt: 0, color: .purple),
        CharacterWeaponDefinition(id: "paper-moon-token", name: "纸月筹码", effect: "控场技能额外削减意志", power: 12, unlockAt: 0, color: .mint),
        CharacterWeaponDefinition(id: "mirror-card-case", name: "镜面卡匣", effect: "影牌射程与弹射强化", power: 28, unlockAt: 5, color: .cyan),
        CharacterWeaponDefinition(id: "backward-watch", name: "倒走怀表", effect: "闪避缩短技能冷却", power: 40, unlockAt: 10, color: .orange)
    ]

    static let foolPassives = [
        CharacterPassiveDefinition(id: "marked-deck", name: "记号牌组", effect: "攻击技能伤害 +10", unlockAt: 0, color: .purple),
        CharacterPassiveDefinition(id: "false-exit", name: "虚假出口", effect: "应变技能冷却 -1回合", unlockAt: 0, color: .cyan),
        CharacterPassiveDefinition(id: "borrowed-name", name: "借来的名字", effect: "控场技能伤害与削韧强化", unlockAt: 5, color: .mint),
        CharacterPassiveDefinition(id: "last-applause", name: "最后掌声", effect: "终结技伤害 +18", unlockAt: 10, color: .orange)
    ]

    static let outfits = [
        CharacterOutfitDefinition(id: "mistport-night", name: "雾港夜行", detail: "雾色轻装 · 守中有变", artName: "CharacterFoolBright", color: .purple),
        CharacterOutfitDefinition(id: "starlight-magician", name: "星辉魔术师", detail: "星纹礼服 · 偏向趋吉", artName: "CharacterFoolStarlight", color: .cyan),
        CharacterOutfitDefinition(id: "midnight-carnival", name: "午夜嘉年华", detail: "金红戏服 · 偏向攻势", artName: "CharacterFoolCarnival", color: .orange)
    ]

    static func weapon(id: String) -> CharacterWeaponDefinition? {
        foolWeapons.first { $0.id == id }
    }

    static func passive(id: String) -> CharacterPassiveDefinition? {
        foolPassives.first { $0.id == id }
    }
}

private extension CharacterWeaponDefinition {
    var artName: String {
        switch id {
        case "silver-lie-blade": "IconRelicOwnerlessMask"
        case "paper-moon-token": "IconRelicPaperMoon"
        case "mirror-card-case": "IconRelicMirrorCase"
        case "backward-watch": "IconRelicBackwardWatch"
        default: "IconRelicOwnerlessMask"
        }
    }
}

private extension DungeonSkillID {
    var artName: String {
        switch self {
        case .strike: "IconSkillWeakness"
        case .mobility: "IconSkillSpiritualDodge"
        case .control: "IconSkillDivination"
        case .ward: "IconSkillDangerPremonition"
        case .ultimate: "IconSkillOmenRecord"
        }
    }
}

struct CharacterProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let game: GameStore

    @State private var selectedSection: CharacterSection = {
        let arguments = ProcessInfo.processInfo.arguments
        #if DEBUG
        if arguments.contains("--daily-ui-review=profile") { return .skills }
        #endif
        if MPCChapterOneCatalog.relicsEnabled && arguments.contains("--preview-relics") { return .equipment }
        return .talent
    }()
    @State private var inspectedSkill: MPCSkillContent?
    @State private var isBreathing = false
    @State private var relicRepairNotice = ""
    @State private var showsTalentTree = ProcessInfo.processInfo.arguments.contains("--preview-talents")

    private var path: Pathway { game.selectedPath ?? GameContent.pathways[0] }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                characterBackdrop
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .allowsHitTesting(false)
                characterArt(in: geometry.size)
                vignette
                outfitControls(in: geometry.size)

                VStack(spacing: 0) {
                    characterHeader
                    Spacer()
                    characterSummary
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(2)
                    sectionRibbon
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(2)
                    sectionDetail
                        .frame(height: 184, alignment: .top)
                        .clipped()
                }
                .padding(.horizontal, 14)
                .padding(.top, max(geometry.safeAreaInsets.top, 48) + 6)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 8))
                .frame(width: geometry.size.width)

                if !game.featureMessage.isEmpty {
                    VStack {
                        Text(game.featureMessage)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(red: 0.16, green: 0.09, blue: 0.28).opacity(0.94), in: Capsule())
                            .overlay { Capsule().stroke(path.tint.opacity(0.75), lineWidth: 1) }
                            .shadow(color: .black.opacity(0.24), radius: 8, y: 3)
                            .padding(.top, max(geometry.safeAreaInsets.top, 48) + 62)
                        Spacer()
                    }
                    .padding(.horizontal, 28)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        .onAppear { startAmbientMotion() }
        .sheet(item: $inspectedSkill) { skill in
            ChapterSkillDetailSheet(skill: skill)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $showsTalentTree) {
            LegacyHermitTalentTreeView(game: game)
        }
    }

    private var characterBackdrop: some View {
        ZStack {
            Image(decorative: "MistportCityHub")
                .resizable()
                .scaledToFill()
                .blur(radius: 2)
            LinearGradient(
                colors: [
                    Color(red: 0.88, green: 0.96, blue: 1.0).opacity(0.70),
                    Color(red: 0.70, green: 0.88, blue: 0.96).opacity(0.30),
                    Color(red: 0.18, green: 0.12, blue: 0.32).opacity(0.52)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func characterArt(in size: CGSize) -> some View {
        let artName = path.id == .fool ? currentOutfit.artName : path.artName

        Image(decorative: artName)
            .resizable()
            .scaledToFit()
            .scaleEffect(x: 1, y: isBreathing ? 1.006 : 1, anchor: .bottom)
            .rotationEffect(.degrees(isBreathing ? 0.16 : -0.12), anchor: .bottom)
            .frame(width: size.width * 1.03, height: size.height * 0.82, alignment: .bottom)
            .position(x: size.width * 0.51, y: size.height * 0.53)
            .shadow(color: path.tint.opacity(0.24), radius: 18, x: 0, y: 8)
            .accessibilityHidden(true)

    }

    private func outfitControls(in size: CGSize) -> some View {
        HStack {
            outfitArrow(direction: -1)
            Spacer()
            outfitArrow(direction: 1)
        }
        .padding(.horizontal, 24)
        .frame(width: size.width, height: 48)
        .position(x: size.width / 2, y: size.height * 0.43)
        .frame(width: size.width, height: size.height)
    }

    private func outfitArrow(direction: Int) -> some View {
        let nextIndex = (currentOutfitIndex + direction + CharacterLoadoutCatalog.outfits.count)
            % CharacterLoadoutCatalog.outfits.count
        let next = CharacterLoadoutCatalog.outfits[nextIndex]
        return Button {
            withAnimation(.easeOut(duration: 0.18)) { game.equipOutfit(next.id) }
        } label: {
            Image(systemName: direction < 0 ? "chevron.left" : "chevron.right")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color(red: 0.91, green: 0.83, blue: 0.66))
                .frame(width: 48, height: 48)
                .background(.black.opacity(0.63), in: Circle())
                .overlay { Circle().stroke(Color(red: 0.79, green: 0.68, blue: 0.46).opacity(0.85), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(direction < 0 ? "character-outfit-previous" : "character-outfit-next")
        .accessibilityLabel("换上\(next.name)")
        .accessibilityHint(direction < 0 ? "上一套衣装" : "下一套衣装")
    }

    private var vignette: some View {
        LinearGradient(
            colors: [.clear, .clear, Color(red: 0.07, green: 0.04, blue: 0.13).opacity(0.88)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var characterHeader: some View {
        HStack(alignment: .center) {
            GameArtReturnButton { dismiss() }

            VStack(alignment: .leading, spacing: 1) {
                Text("角色")
                    .font(.system(size: 22, weight: .heavy, design: .serif))
                Text("雾岬联邦 · 序列档案")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.black.opacity(0.58))
            }
            .foregroundStyle(.black.opacity(0.84))

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("最大生命")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.black.opacity(0.55))
                Text(game.chapterOneCampaign.party.playerMaxHP.formatted())
                    .font(.headline.bold().monospacedDigit())
                    .foregroundStyle(Color(red: 0.50, green: 0.25, blue: 0.68))
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.white.opacity(0.48), in: Capsule())
    }

    private var characterSummary: some View {
        let bonus = currentOutfit.bonus
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentOutfit.name)
                        .font(.system(size: 20, weight: .bold, design: .serif))
                    Text("\(path.name) · \(currentOutfit.detail)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.black.opacity(0.60))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text("\(currentOutfitIndex + 1) / \(CharacterLoadoutCatalog.outfits.count)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.black.opacity(0.55))
            }
            HStack(spacing: 7) {
                outfitBonusCell("幸运", basisPoints: bonus.luckDodgeBP)
                outfitBonusCell("攻击", basisPoints: bonus.attackBP)
                outfitBonusCell("减伤", basisPoints: bonus.damageReductionBP)
            }
            Text("幸运提高可闪避直击的躲闪率 · 加成在下次出战时生效")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.black.opacity(0.59))
                .lineLimit(2)
        }
        .foregroundStyle(.black.opacity(0.86))
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(.white.opacity(0.64), in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(currentOutfit.color.opacity(0.42), lineWidth: 1) }
    }

    private func outfitBonusCell(_ title: String, basisPoints: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.black.opacity(0.58))
            Text(basisPoints == 0 ? "—" : "+\(basisPoints / 100)%")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(basisPoints == 0 ? .black.opacity(0.35) : .black.opacity(0.82))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(.white.opacity(0.53), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title)\(basisPoints == 0 ? "无加成" : "加\(basisPoints / 100)百分比")")
    }

    private var sectionRibbon: some View {
        HStack(spacing: 2) {
            ForEach(CharacterSection.allCases.filter { MPCChapterOneCatalog.relicsEnabled || game.chapterOneCampaign.ownsManualMask || game.chapterOneCampaign.ownsUsurpedLifeMedal || $0 != .equipment }) { section in
                Button(action: { withAnimation(.easeOut(duration: 0.18)) { selectedSection = section } }) {
                    VStack(spacing: 5) {
                        if let artName = section.artName {
                            Image(decorative: artName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 27, height: 27)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                                .overlay { RoundedRectangle(cornerRadius: 7).stroke(path.tint.opacity(selectedSection == section ? 0.9 : 0.25), lineWidth: 1) }
                        } else {
                            Text(section.glyph)
                                .font(.system(size: 19, weight: .bold, design: .serif))
                                .frame(height: 27)
                        }
                        Text(section.title)
                            .font(.caption2.bold())
                        Capsule()
                            .fill(selectedSection == section ? path.tint : .clear)
                            .frame(width: 28, height: 3)
                    }
                    .foregroundStyle(selectedSection == section ? .white : .white.opacity(0.56))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.black.opacity(0.56), in: UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18))
        .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.16)).frame(height: 1)
        }
    }

    @ViewBuilder
    private var sectionDetail: some View {
        switch selectedSection {
        case .equipment:
            weaponPanel
        case .skills:
            skillPanel
        case .battleSequence:
            battleSequencePanel
        case .talent:
            talentPanel
        }
    }

    private var weaponPanel: some View {
        let owned = MPCChapterOneCatalog.relics.filter { MPCChapterOneCatalog.isRelicEnabled($0.id) && game.chapterOneCampaign.ownedRelicIDs.contains($0.id) }
        return VStack(spacing: 10) {
            WorkshopGearCareSection(game: game)
            if owned.isEmpty {
                Text("尚未获得遗落物")
                    .font(.headline).foregroundStyle(.primary)
                Text("调查中取得并确认来源后，会出现在这里。")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                CharacterIconChoiceRail {
                    ForEach(owned) { relic in
                        CharacterIconChoiceCard(
                            title: relic.name,
                            detail: ownedRelicIsDepleted(relic.id) ? "完好度0% · 本次战斗不会生效" : EarlyRelicShop.ids.contains(relic.id) ? EarlyRelicShop.detail(relic.id) : relic.id == MPCChapterOneCatalog.usurpedLifeMedalRelicID ? "8秒生命×1.5、攻击+30%；结束交出剩余生命一半。24秒冷却。" : relic.id == MPCChapterOneCatalog.ownerlessMaskRelicID ? "4秒内两次直接承伤 · 18秒冷却 · 裂纹\(game.chapterOneCampaign.masqueradeCrackCount)/10" : relic.id == "relic_encore_bell" ? "蓄力延后3秒；该次返场伤害增加50%。" : "调查所得遗落物",
                            value: ownedRelicIsDepleted(relic.id) ? "已失效 · 下方修复" : EarlyRelicShop.activeIDs.contains(relic.id)
                                ? ((game.chapterOneCampaign.loadout.selectedActiveRelicID ?? MPCChapterOneCatalog.ownerlessMaskRelicID) == relic.id ? "当前主动遗落物" : "选为主动遗落物")
                                : game.chapterOneCampaign.loadout.relicIDs.contains(relic.id) ? "已装备" : "装备",
                            artName: EarlyRelicShop.ids.contains(relic.id) ? EarlyRelicShop.art(relic.id) : relic.id == MPCChapterOneCatalog.usurpedLifeMedalRelicID ? "IconRelicUsurpedLifeMedal" : relic.id == MPCChapterOneCatalog.ownerlessMaskRelicID ? "IconRelicOwnerlessMask" : relic.id == "relic_encore_bell" ? "ItemEncoreBellCutout"
                                : relic.id == "relic_paper_raincoat" ? "IconRelicPaperDouble"
                                : relic.id == "relic_trimmed_nameplate" ? "IconRelicTrimmedNameplate"
                                : relic.id == "relic_unified_gear" ? "IconRelicThreeProofRing"
                                : relic.id == "relic_nameless_seal" ? "IconRelicNamelessSeal" : "RewardMaterial",
                            tint: .purple,
                            isSelected: !ownedRelicIsDepleted(relic.id) && (EarlyRelicShop.activeIDs.contains(relic.id)
                                ? (game.chapterOneCampaign.loadout.selectedActiveRelicID ?? MPCChapterOneCatalog.ownerlessMaskRelicID) == relic.id
                                : game.chapterOneCampaign.loadout.relicIDs.contains(relic.id)),
                            isLocked: false,
                            action: { if !ownedRelicIsDepleted(relic.id) { game.toggleCampaignRelic(relic.id) } }
                        )
                    }
                }
            }
            ForEach(owned.filter { ownedRelicIsDepleted($0.id) }) { relic in
                if let offer = MPCChurchLoanOffer.all.first(where: { $0.relicID == relic.id }) {
                    let price = MPCChurchLoanLedger.ownedRepairPrice(value: offer.value, durability: 0)
                    HStack {
                        Text("\(relic.name) · 已失效（0%）")
                            .font(.caption.bold())
                        Spacer()
                        Button("修复 · \(price)铜币") {
                            do {
                                try game.repairOwnedChurchRelic(relic.id)
                                relicRepairNotice = "\(relic.name)已修复，出征前可正常装备。"
                            } catch {
                                relicRepairNotice = "修复失败：\(error.localizedDescription)"
                            }
                        }
                        .buttonStyle(GameArtButtonStyle(compact: true))
                        .disabled(game.venueCoins < price)
                    }
                }
            }
            if !relicRepairNotice.isEmpty {
                Text(relicRepairNotice).font(.caption).foregroundStyle(.secondary)
            }
            Text("主动遗落物 1 件 · 被动遗落物 1 件；进入战斗后不可更换。")
                .font(.caption).foregroundStyle(.secondary)
            if game.earlyRelicShopUnlocked {
                HStack {
                    Image("ItemPainSalve").resizable().scaledToFit().frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("诊所补给 · 止痛膏").font(.headline)
                        Text("恢复25%生命 · 持有\(game.painSalveStock)份")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(game.painSalveStock > 0 ? "已备妥" : "\(game.painSalvePrice) 铜币") { game.purchasePainSalve() }
                        .buttonStyle(GameArtButtonStyle(compact: true)).disabled(game.painSalveStock > 0)
                        .accessibilityLabel("采购止痛膏，\(game.painSalvePrice)铜币，恢复25%生命")
                }
                Divider()
                Text("遗落物采购 · 铜币 \(game.venueCoins)").font(.headline)
                ForEach(EarlyRelicShop.ids.filter(game.relicPurchaseUnlocked), id: \.self) { id in
                    if !game.chapterOneCampaign.ownedRelicIDs.contains(id) {
                        HStack {
                            Image(EarlyRelicShop.art(id)).resizable().scaledToFit().frame(width: 52, height: 52)
                            VStack(alignment: .leading) {
                                Text(EarlyRelicShop.name(id)).font(.subheadline.bold())
                                Text(EarlyRelicShop.detail(id)).font(.caption).foregroundStyle(.secondary)
                            }
                            Button("\(EarlyRelicShop.price(id) ?? 0) 铜币") { game.purchaseEarlyRelic(id) }
                                .buttonStyle(GameArtButtonStyle(compact: true))
                                .accessibilityLabel("购买\(EarlyRelicShop.name(id))，\(EarlyRelicShop.price(id) ?? 0)铜币")
                        }
                    }
                }
                Divider()
                Text("晋阶主材采购").font(.headline)
                Text("已有主材不重复购买；第一章筹备，黑盐岸举行仪式。")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(AdvancementIngredient.allCases) { ingredient in
                    HStack {
                        Image(ingredient.purchaseArt).resizable().scaledToFit().frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(ingredient.name).font(.subheadline.bold())
                            Text(game.advancementIngredients.contains(ingredient) ? "已持有 · 旧主材同样有效" : "第\(ingredient.purchaseOffer.unlockMission)关后开放")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(game.advancementIngredients.contains(ingredient) ? "已持有" : "\(ingredient.purchaseOffer.price) 铜币") {
                            game.purchaseAdvancementIngredient(ingredient)
                        }.buttonStyle(GameArtButtonStyle(compact: true))
                            .disabled(!game.advancementPurchaseUnlocked(ingredient) || game.advancementIngredients.contains(ingredient))
                            .accessibilityLabel("\(ingredient.name)，\(ingredient.purchaseOffer.price)铜币，第\(ingredient.purchaseOffer.unlockMission)关后开放")
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("黑盐岸 · 序列 8 仪式").font(.subheadline.bold())
                    Text(game.sequenceEightRitualStatus)
                        .font(.caption).foregroundStyle(.secondary)
                    PlateButton(title: game.sequenceEightQualified ? "序列 8 仪式已完成" : "举行仪式 · \(MPCSequenceEightRitual.fee) 铜币",
                                plate: .ritual,
                                enabled: !game.sequenceEightQualified
                                    && game.churchTowerMissionNumbers.contains(MPCSequenceEightRitual.storyMission)) {
                        game.performAdvancement()
                    }
                }
                .padding(.top, 4)
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("邮务核对 · 第\(game.postalJobSerial + 1)单").font(.headline)
                    Text("核对三个字段，本单可领\(game.repeatWorkPreview(copper: 40))。无需战斗或消耗品。")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(game.repeatWorkNotice).font(.caption).foregroundStyle(.secondary)
                    Text("原始单据：\(game.postalJobFields.joined(separator: " · "))")
                        .font(.subheadline).padding(8)
                        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    Text(["请选择收件人", "请选择投递街道", "请选择封记"][game.postalJobStep]).font(.caption.bold())
                    HStack {
                        ForEach(game.postalJobOptions, id: \.self) { answer in
                            StaminaCostView(activity: .post)
            let serial = game.postalJobSerial
                            let step = game.postalJobStep
                            Button(answer) { Task { await game.verifyPostalField(answer, serial: serial, step: step) } }
                                .buttonStyle(GameArtButtonStyle(compact: true))
                        }
                    }
                }
            }
        }
    }

    private func ownedRelicIsDepleted(_ id: String) -> Bool {
        EarlyRelicShop.ids.contains(id)
            && game.churchServices.ownedCondition.currentDurability(id) == 0
    }

    private var skillPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("技能粉尘 \(game.skillDust)").font(.caption.bold())
                Spacer()
                Text("每级数值 +10% · 最高5级").font(.system(size: 10))
            }
            .foregroundStyle(.white.opacity(0.85))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(MPCChapterOneCatalog.visibleSkills.filter { $0.id != .paperDouble }) { skill in
                        growthCard(skill)
                    }
                }
            }
        }
        .padding(.horizontal, 10).padding(.top, 6)
    }

    private func growthCard(_ skill: MPCSkillContent) -> some View {
        let unlocked = game.chapterOneCampaign.unlockedSkillIDs.contains(skill.id)
        let level = game.foolSkillLevel(for: skill.id)
        let supported = MPCSkillGrowth.canUpgrade(skill.id)
        let cost = MPCSkillGrowth.upgradeCost(from: level)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(chapterOneSkillArtName(skill.id)).resizable().scaledToFit().frame(width: 35, height: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(skill.name).font(.system(size: 13, weight: .bold))
                    Text(unlocked ? (supported ? "Lv.\(level) · 数值 +\((level - 1) * 10)%" : "机制卡 · 完整效果") : skillUnlockDescription(skill.id))
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.65))
                }
            }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.45) { inspectedSkill = skill }
            .accessibilityAction(named: "查看技能介绍") { inspectedSkill = skill }
            Text(skill.summary).font(.system(size: 10)).lineLimit(2).frame(height: 27, alignment: .topLeading)
            Text(supported ? (level < 5 ? "下一级：直接伤害 / 自身盾 +\(level * 10)%" : "已达到本次强化上限") : "层数与时机固定，无需消耗粉尘强化。")
                .font(.system(size: 9)).foregroundStyle(.yellow.opacity(0.9)).lineLimit(1)
            Button { game.upgradeFoolSkill(skill.id) } label: {
                Text(!unlocked ? "尚未解锁" : !supported ? "无需强化" : cost.map { "强化 · \($0) 粉尘" } ?? "已满级")
                    .font(.system(size: 11, weight: .bold)).frame(maxWidth: .infinity)
            }
            .buttonStyle(GameArtButtonStyle(compact: true))
            .disabled(!unlocked || !supported || cost == nil || game.skillDust < (cost ?? 0))
            .accessibilityLabel("强化\(skill.name)")
            .accessibilityValue("当前\(level)级，\(cost.map { "需要\($0)粉尘" } ?? "已满级")")
        }
        .foregroundStyle(.white).padding(9).frame(width: 225)
        .background(Color(red: 0.12, green: 0.065, blue: 0.19), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.yellow.opacity(unlocked ? 0.45 : 0.15), lineWidth: 1))
        .opacity(unlocked ? 1 : 0.6)
    }

    private func skillUnlockDescription(_ id: FoolSkillID) -> String {
        switch id {
        case .sidestepStrike: "第1关教学获得"
        case .maskedWhisper: "第3关战前获得"
        case .identityDisplacement: "第8关战前获得"
        case .fabricatedEvidence: "第9关通关获得"
        case .mirrorPursuit: "第10关通关获得"
        case .absurdFinale: "第11关通关获得"
        case .turnTheTables: "第12关通关获得"
        case .namelessStage: "第13关通关获得"
        case .backstageChange: "后续篇章开放"
        case .paperDouble: "已停用"
        }
    }

    private var chapterOneUnlockedSkills: [MPCSkillContent] {
        MPCChapterOneCatalog.visibleSkills.filter {
            !$0.isUltimate
                && $0.id != .paperDouble
                && game.chapterOneCampaign.unlockedSkillIDs.contains($0.id)
        }
    }

    private var chapterOneSelectedSkills: [MPCSkillContent] {
        let lookup = Dictionary(uniqueKeysWithValues: MPCChapterOneCatalog.visibleSkills.map { ($0.id, $0) })
        return game.chapterOneCampaign.loadout.normalSkillIDs.compactMap { lookup[$0] }
    }

    private var battleSequencePanel: some View {
        let selectedSkills = chapterOneSelectedSkills
        let selectedIDs = Set(selectedSkills.map(\.id))
        let slotCapacity = game.chapterOneLoadoutSlotCapacity

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Label("出战技能顺序", systemImage: "list.number")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer(minLength: 4)
                    Text("左→右执行 · \(selectedSkills.count)/\(slotCapacity)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(path.tint)
                }

                Text("这里只保存参考牌组。每场战前仍需手动点牌，按点击顺序执行；未点牌只普攻。")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.64))
                    .lineLimit(2)

                if !selectedSkills.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(selectedSkills.enumerated()), id: \.element.id) { index, skill in
                                CharacterBattleSequenceCard(
                                    skill: skill,
                                    order: index + 1,
                                    artName: chapterOneSkillArtName(skill.id),
                                    canMoveLeft: index > 0,
                                    canMoveRight: index < selectedSkills.count - 1,
                                    onMoveLeft: { moveChapterOneBattleSkill(skill.id, by: -1) },
                                    onMoveRight: { moveChapterOneBattleSkill(skill.id, by: 1) },
                                    onRemove: { toggleChapterOneBattleSkill(skill.id) },
                                    onInspect: { inspectedSkill = skill }
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .scrollClipDisabled()
                    .frame(height: 90)
                }

                HStack(spacing: 5) {
                    Text("可编入技能")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("点击编入 · 长按介绍")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.52))
                    Spacer(minLength: 0)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(chapterOneUnlockedSkills) { skill in
                            let isSelected = selectedIDs.contains(skill.id)
                            Button {
                                guard isSelected || selectedSkills.count < slotCapacity else { return }
                                toggleChapterOneBattleSkill(skill.id)
                            } label: {
                                VStack(spacing: 2) {
                                    Image(decorative: chapterOneSkillArtName(skill.id))
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 43, height: 52)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 7))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 7)
                                                .stroke(isSelected ? path.tint : .white.opacity(0.18), lineWidth: isSelected ? 2 : 1)
                                        }
                                    Text(isSelected ? "已编入" : skill.name)
                                        .font(.system(size: 7, weight: .bold))
                                        .lineLimit(1)
                                        .foregroundStyle(isSelected ? path.tint : .white.opacity(0.76))
                                }
                                .frame(width: 50, height: 67)
                            }
                            .buttonStyle(CharacterSkillInspectionStyle { inspectedSkill = skill })
                            .accessibilityAction(named: "查看技能介绍") { inspectedSkill = skill }
                            .opacity(!isSelected && selectedSkills.count >= slotCapacity ? 0.38 : 1)
                            .accessibilityLabel(skill.name + "，" + (isSelected ? "已编入出战顺序" : "加入出战顺序"))
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollClipDisabled()
                .frame(height: 72)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.025, blue: 0.085).opacity(0.98),
                    Color(red: 0.10, green: 0.045, blue: 0.16).opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )

    }

    private func toggleChapterOneBattleSkill(_ id: FoolSkillID) {
        var skillIDs = game.chapterOneCampaign.loadout.normalSkillIDs
        if let index = skillIDs.firstIndex(of: id) {
            skillIDs.remove(at: index)
        } else if skillIDs.count < game.chapterOneLoadoutSlotCapacity {
            skillIDs.append(id)
        }
        game.saveChapterOneBattleLoadout(skillIDs)
    }

    private func moveChapterOneBattleSkill(_ id: FoolSkillID, by offset: Int) {
        var skillIDs = game.chapterOneCampaign.loadout.normalSkillIDs
        guard let index = skillIDs.firstIndex(of: id) else { return }
        let destination = index + offset
        guard skillIDs.indices.contains(destination) else { return }
        skillIDs.swapAt(index, destination)
        game.saveChapterOneBattleLoadout(skillIDs)
    }

    private func chapterOneSkillArtName(_ skillID: FoolSkillID) -> String {
        switch skillID {
        case .sidestepStrike, .fabricatedEvidence: "IconSkillWeakness"
        case .maskedWhisper: "IconSkillDangerPremonition"
        case .paperDouble: "IconSkillPaperDouble"
        case .identityDisplacement, .turnTheTables: "IconSkillDivination"
        case .mirrorPursuit, .backstageChange: "IconSkillSpiritualDodge"
        case .absurdFinale, .namelessStage: "IconSkillOmenRecord"
        }
    }

    private var talentPanel: some View {
        Button { showsTalentTree = true } label: {
            HStack(spacing: 18) {
                Image("IconTalentTrickster").resizable().scaledToFit().frame(width: 72, height: 80)
                VStack(alignment: .leading, spacing: 8) {
                    Text("愚者 · 天赋星图").font(.system(size: 20, weight: .bold, design: .serif))
                    Text("诡术 / 幻身 / 秘兆").font(.subheadline)
                    Text("可用 \(game.hermitTalentPoints) 点 · 第9关获得4点")
                        .font(.caption).foregroundStyle(.yellow)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(.white).padding(16)
            .background(Color(red: 0.06, green: 0.055, blue: 0.11), in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.62, green: 0.47, blue: 0.28), lineWidth: 2) }
        }.buttonStyle(.plain)
    }

    private func skillVariantDetail(_ skillID: DungeonSkillID) -> String {
        switch skillID {
        case .strike: "连锁牌 · 增加弹射"
        case .mobility: "残像步 · 留下替身"
        case .control: "身份误植 · 削减意志"
        case .ward: "替身谢幕 · 化解强攻"
        case .ultimate: "落幕式 · 复制技能"
        }
    }

    private var currentOutfitIndex: Int {
        CharacterLoadoutCatalog.outfits.firstIndex { $0.id == game.equippedOutfitID } ?? 0
    }

    private var currentOutfit: CharacterOutfitDefinition {
        CharacterLoadoutCatalog.outfits[currentOutfitIndex]
    }

    private func startAmbientMotion() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
            isBreathing = true
        }
    }
}

private enum CharacterSection: String, CaseIterable, Identifiable {
    case equipment
    case skills
    case battleSequence
    case talent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .equipment: "遗落物"
        case .skills: "技能"
        case .battleSequence: "出战序列"
        case .talent: "天赋"
        }
    }

    var glyph: String {
        switch self {
        case .equipment: "†"
        case .skills: "✦"
        case .battleSequence: "≡"
        case .talent: "✧"
        }
    }

    var artName: String? {
        switch self {
        case .equipment: "IconRelicOwnerlessMask"
        case .skills: "IconSkillWeakness"
        case .battleSequence: "IconSkillWeakness"
        case .talent: "IconTalentTrickster"
        }
    }
}

// A hold inspects without also firing the loadout toggle on release.
private struct CharacterSkillInspectionStyle: PrimitiveButtonStyle {
    let onInspect: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .gesture(
                LongPressGesture(minimumDuration: 0.45, maximumDistance: 12)
                    .exclusively(before: TapGesture())
                    .onEnded { gesture in
                        switch gesture {
                        case .first(true): onInspect()
                        case .second: configuration.trigger()
                        default: break
                        }
                    }
            )
            .accessibilityAction { configuration.trigger() }
    }
}

private struct CharacterBattleSequenceCard: View {
    let skill: MPCSkillContent
    let order: Int
    let artName: String
    let canMoveLeft: Bool
    let canMoveRight: Bool
    let onMoveLeft: () -> Void
    let onMoveRight: () -> Void
    let onRemove: () -> Void
    let onInspect: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Button(action: onInspect) {
                ZStack(alignment: .topLeading) {
                    Image(decorative: artName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 62)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("\(order)")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(width: 15, height: 15)
                        .background(.yellow, in: Circle())
                        .padding(2)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.yellow.opacity(0.72), lineWidth: 1.2)
                }
            }
            .buttonStyle(CharacterSkillInspectionStyle(onInspect: onInspect))
            .accessibilityLabel("查看\(skill.name)介绍")

            HStack(spacing: 2) {
                Button(action: onMoveLeft) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!canMoveLeft)

                Button(action: onRemove) {
                    Image(systemName: "minus.circle")
                }

                Button(action: onMoveRight) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!canMoveRight)
            }
            .font(.system(size: 9, weight: .black))
            .foregroundStyle(.white.opacity(0.82))
            .buttonStyle(.plain)

            Text(skill.name)
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.white.opacity(0.66))
                .lineLimit(1)
                .frame(width: 62)
        }
        .frame(width: 68, height: 88)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("第\(order)张，\(skill.name)")
        .accessibilityHint("使用左右箭头调整顺序，减号移出出战序列")
    }
}

private struct CharacterTag: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(tint.opacity(0.55), in: Capsule())
    }
}

private struct CharacterDetailStrip: View {
    let title: String
    let detail: String
    let accent: Color
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accent)
                .frame(width: 4, height: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Text(value)
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(accent)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(Color(red: 0.055, green: 0.035, blue: 0.10).opacity(0.94))
    }
}

private struct CharacterChoiceRail<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) { content() }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
        }
        .frame(height: 130)
        .background(Color(red: 0.055, green: 0.035, blue: 0.10).opacity(0.95))
    }
}

private struct CharacterIconChoiceRail<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) { content() }
                .padding(.horizontal, 9)
                .padding(.vertical, 10)
        }
        .frame(height: 184)
        .background(
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.025, blue: 0.085).opacity(0.98), Color(red: 0.09, green: 0.045, blue: 0.15).opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private struct CharacterIconChoiceCard: View {
    let title: String
    let detail: String
    let value: String
    let artName: String
    let tint: Color
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(decorative: artName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 126, height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                        .saturation(isLocked ? 0.10 : 1)
                        .brightness(isLocked ? -0.25 : 0)

                    Text(isLocked ? "未解锁" : value)
                        .font(.system(size: 9, weight: .heavy).monospacedDigit())
                        .foregroundStyle(isLocked ? .white.opacity(0.66) : .black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(isLocked ? .black.opacity(0.70) : tint, in: Capsule())
                        .padding(6)

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.82))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(isSelected ? tint : .white.opacity(0.20), lineWidth: isSelected ? 2.2 : 1)
                }

                Text(title)
                    .font(.caption.bold())
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(7)
            .frame(width: 140, height: 164, alignment: .topLeading)
            .background(.white.opacity(isSelected ? 0.11 : 0.045), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? tint : .white.opacity(0.10), lineWidth: isSelected ? 1.5 : 1)
            }
            .shadow(color: isSelected ? tint.opacity(0.28) : .clear, radius: 8)
            .opacity(isLocked ? 0.72 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)，\(isLocked ? "未解锁" : value)，\(detail)")
    }
}

private struct CharacterChoiceCard: View {
    let title: String
    let detail: String
    let value: String
    let tint: Color
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Circle()
                        .fill(tint)
                        .frame(width: 10, height: 10)
                    Spacer()
                    Text(isLocked ? "未解锁" : value)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isLocked ? .white.opacity(0.42) : tint)
                }
                Text(title)
                    .font(.caption.bold())
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
                Spacer(minLength: 0)
                Capsule()
                    .fill(isSelected ? tint : .white.opacity(0.12))
                    .frame(height: 3)
            }
            .foregroundStyle(.white)
            .padding(10)
            .frame(width: 115, height: 104)
            .background(.white.opacity(isSelected ? 0.13 : 0.06), in: RoundedRectangle(cornerRadius: 13))
            .overlay { RoundedRectangle(cornerRadius: 13).stroke(isSelected ? tint : .white.opacity(0.12), lineWidth: isSelected ? 1.5 : 1) }
            .opacity(isLocked ? 0.62 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)，\(isLocked ? "未解锁" : isSelected ? "已选择" : "可选择")")
    }
}

private extension HermitBranch {
    var tint: Color { switch self { case .trickery: Color(red: 0.77, green: 0.57, blue: 0.98); case .phantom: Color(red: 0.40, green: 0.80, blue: 0.84); case .omen: Color(red: 0.91, green: 0.72, blue: 0.39) } }
    var art: String { switch self { case .trickery: "IconTalentTrickster"; case .phantom: "IconTalentDeceiver"; case .omen: "IconTalentBoundary" } }
    var buttonArt: String { switch self { case .trickery: "ButtonArt04TalentBranchTrickery"; case .phantom: "ButtonArt04TalentBranchPhantom"; case .omen: "ButtonArt04TalentBranchOmen" } }
    var combo: String { switch self {
    case .trickery: "错步穿行 → 镜像追击 → 其他伤害技能\n用不同技能接续攻击，持续兑现破防收益。"
    case .phantom: "遗落物假面 → 幻影承伤 → 错步穿行\n承伤后强化下一击；幻影仍按实际命中消耗。"
    case .omen: "伪证烙印 → 叠加误认 → 荒谬归结\n先铺垫再兑现；未获得的技能仍需剧情解锁。"
    } }
}

private enum HermitTalentActionArt: String {
    case learned = "已掌握"
    case available = "点亮天赋"
    case insufficient = "天赋点不足"
    case prerequisite = "前置未满足"

    var assetName: String {
        switch self {
        case .learned: "ButtonArtTalentInvocationLearned"
        case .available: "ButtonArtTalentInvocationAvailable"
        case .insufficient: "ButtonArtTalentInvocationInsufficient"
        case .prerequisite: "ButtonArtTalentInvocationPrerequisite"
        }
    }
}

struct LegacyHermitTalentTreeView: View {
    let game: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var branch: HermitBranch = .trickery
    @State private var selectedID = "trickery.0"
    @State private var confirmsReset = false
    private let brass = Color(red: 0.61, green: 0.47, blue: 0.29)
    private var selected: HermitTalent { HermitTalent.all.first { $0.id == selectedID } ?? HermitTalent.all[0] }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.075, green: 0.065, blue: 0.13), Color(red: 0.025, green: 0.035, blue: 0.055)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            GeometryReader { proxy in
                Image("TalentAstrolabeBackdrop").resizable().scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height).clipped()
                    .overlay(Color.black.opacity(0.12))
            }.ignoresSafeArea().allowsHitTesting(false)
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        GameArtReturnButton(title: "返回角色") { dismiss() }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("愚者 · 天赋星图").font(.system(size: 23, weight: .bold, design: .serif))
                            Text("以不同的选择，成为不同的自己").font(.caption).foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer(minLength: 0)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(game.hermitTalentPoints)").font(.system(size: 32, weight: .medium, design: .serif)).foregroundStyle(branch.tint)
                        Text("可用天赋点").font(.caption)
                        Spacer()
                        Text("已投入 \(game.hermitTalents.learned.count) / \(game.hermitTalentBudget)").font(.caption).foregroundStyle(.white.opacity(0.6))
                    }.padding(.horizontal, 10)
                    HStack(spacing: 8) {
                        ForEach(HermitBranch.allCases, id: \.self) { item in
                            Button {
                                branch = item; selectedID = item.rawValue + ".0"
                            } label: {
                                VStack(spacing: 5) {
                                    Text(item.title).font(.system(size: 15, weight: .bold, design: .serif))
                                    Text("\(game.hermitTalents.learned.filter { $0.hasPrefix(item.rawValue) }.count) / 6").font(.caption2)
                                }
                                .foregroundStyle(branch == item ? Color(red: 0.12, green: 0.11, blue: 0.15) : Color(red: 0.88, green: 0.84, blue: 0.75))
                                .frame(maxWidth: .infinity, minHeight: 62, maxHeight: 62)
                                .background {
                                    Image(item.buttonArt)
                                        .resizable(capInsets: EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18), resizingMode: .stretch)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(branch == item ? Color(red: 0.91, green: 0.87, blue: 0.75) : Color(red: 0.14, green: 0.12, blue: 0.20))
                                                .padding(4)
                                        }
                                        .accessibilityHidden(true)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(item.title)天赋系")
                            .accessibilityValue("\(branch == item ? "已选择" : "未选择")，已点亮 \(game.hermitTalents.learned.filter { $0.hasPrefix(item.rawValue) }.count) / 6")
                        }
                    }
                    Text(branch.summary).font(.system(size: 13, design: .serif)).foregroundStyle(branch.tint)
                    tree.frame(height: 425)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("配牌思路").font(.subheadline.bold()).foregroundStyle(brass)
                        Text(branch.combo).font(.footnote).lineSpacing(5).foregroundStyle(.white.opacity(0.65))
                        Text("可跨系投入 · 每个节点 1 点 · 同次伤害加成相加")
                            .font(.caption2).foregroundStyle(.white.opacity(0.4))
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                    HStack {
                        Text("第9关首次通关获得4点，可免费重置")
                            .font(.caption2).foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Button("免费重置") { confirmsReset = true }
                            .font(.footnote).foregroundStyle(brass).disabled(game.hermitTalents.learned.isEmpty)
                    }.padding(.bottom, 20)
                }.padding(.horizontal, 20)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                detail
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .background(Color(red: 0.025, green: 0.035, blue: 0.055).opacity(0.96))
            }
        }
        .foregroundStyle(Color(red: 0.93, green: 0.88, blue: 0.77))
        .preferredColorScheme(.dark)
        .overlay {
            if confirmsReset {
                ZStack {
                    Color.black.opacity(0.8).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Image("CityMissionWaxSeal").resizable().scaledToFit().frame(width: 64, height: 64).saturation(0.6).brightness(-0.1)
                        Text("重绘命途").font(.system(size: 27, weight: .bold, design: .serif))
                        Text("返还全部 \(game.hermitTalents.learned.count) 点天赋，重新选择你的道路。")
                            .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.7))
                        Button("确认重置 · 免费") { game.resetHermitTalents(); confirmsReset = false }
                            .buttonStyle(TalentMetalButton(tint: brass))
                        Button("保留当前命途") { confirmsReset = false }.font(.subheadline).padding(8)
                    }.padding(28).background { TalentCarvedPanel() }.padding(26)
                }.foregroundStyle(Color(red: 0.93, green: 0.88, blue: 0.77))
            }
        }
    }

    private func point(_ index: Int, width: CGFloat) -> CGPoint {
        let locations: [(CGFloat, CGFloat)] = [(0.5, 43), (0.24, 151), (0.76, 151), (0.24, 267), (0.76, 267), (0.5, 377)]
        return CGPoint(x: width * locations[index].0, y: locations[index].1)
    }

    private var tree: some View {
        GeometryReader { geometry in
            ZStack {
                Circle().stroke(brass.opacity(0.08), lineWidth: 1).frame(width: 300, height: 300)
                Circle().stroke(brass.opacity(0.06), lineWidth: 1).frame(width: 220, height: 220)
                ForEach(HermitTalent.all.filter { $0.branch == branch }) { node in
                    ForEach(node.prerequisites, id: \.self) { parent in
                        let parentNode = HermitTalent.all.first { $0.id == parent }!
                        TalentConduit(start: point(parentNode.index, width: geometry.size.width), end: point(node.index, width: geometry.size.width), active: game.hermitTalents.has(node.id), tint: branch.tint)
                    }
                }
                ForEach(HermitTalent.all.filter { $0.branch == branch }) { node in
                    let learned = game.hermitTalents.has(node.id)
                    let available = game.hermitTalents.canLearn(node.id, budget: game.hermitTalentBudget)
                    VStack(spacing: 5) {
                        Button { selectedID = node.id } label: {
                            ZStack {
                                Circle().fill(branch.tint.opacity(learned ? 0.18 : 0.02)).frame(width: 64, height: 64)
                                    .shadow(color: branch.tint.opacity(learned ? 0.65 : 0), radius: 14)
                                Image("ButtonArt05TalentNode").resizable().scaledToFit()
                                    .saturation(learned || available ? 0.85 : 0.35)
                                    .brightness(learned || available ? 0 : -0.12)
                                if selectedID == node.id {
                                    Circle().stroke(branch.tint.opacity(0.8), lineWidth: 2).frame(width: 52, height: 52)
                                        .shadow(color: branch.tint.opacity(0.8), radius: 6)
                                }
                                Image(systemName: node.symbol).font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(LinearGradient(colors: [learned || available ? branch.tint : brass, Color(red: 0.38, green: 0.26, blue: 0.16)], startPoint: .top, endPoint: .bottom))
                                    .shadow(color: .black, radius: 1, x: 1, y: 2)
                                if learned { Circle().fill(branch.tint).frame(width: 5, height: 5).offset(y: 30).shadow(color: branch.tint, radius: 4) }
                            }.frame(width: 78, height: 78)
                        }.buttonStyle(.plain).accessibilityLabel("\(node.title)，\(learned ? "已学习" : available ? "可学习" : "前置未满足")")
                        Text(node.title).font(.system(size: 12, weight: .medium, design: .serif)).foregroundStyle(learned ? branch.tint : .white.opacity(0.7)).padding(.horizontal, 5).background(Color(red: 0.045, green: 0.04, blue: 0.075))
                    }.position(point(node.index, width: geometry.size.width))
                }
            }
        }
    }

    private var detail: some View {
        let learned = game.hermitTalents.has(selected.id)
        let available = game.hermitTalents.canLearn(selected.id, budget: game.hermitTalentBudget)
        let missing = selected.prerequisites.filter { !game.hermitTalents.has($0) }.compactMap { id in HermitTalent.all.first { $0.id == id }?.title }
        let actionArt: HermitTalentActionArt = learned ? .learned : available ? .available : missing.isEmpty ? .insufficient : .prerequisite
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selected.title).font(.system(size: 21, weight: .bold, design: .serif))
                Spacer()
                Text(learned ? "已点亮" : "消耗 1 点").font(.caption).foregroundStyle(branch.tint)
            }
            Text(selected.detail).font(.system(size: 14)).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
            Text(missing.isEmpty ? "\(selected.index == 0 ? "起始节点" : "前置已满足") · 配置在下次进入战斗时生效" : "需要先点亮：" + missing.joined(separator: "、"))
                .font(.caption).foregroundStyle(.white.opacity(0.5)).fixedSize(horizontal: false, vertical: true)
            Button { game.learnHermitTalent(selected.id) } label: {
                Image(decorative: actionArt.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!available)
            .opacity(available ? 1 : 0.72)
            .accessibilityLabel(actionArt.rawValue)
        }.padding(22).padding(.top, 8).background { TalentCarvedPanel() }
    }
}

private struct TalentPennant: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 5, y: 0)); p.addLine(to: CGPoint(x: r.maxX - 5, y: 0))
            p.addLine(to: CGPoint(x: r.maxX, y: 5)); p.addLine(to: CGPoint(x: r.maxX - 3, y: r.maxY - 15))
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY)); p.addLine(to: CGPoint(x: 3, y: r.maxY - 15))
            p.addLine(to: CGPoint(x: 0, y: 5)); p.closeSubpath()
        }
    }
}

private struct TalentConduit: View {
    let start: CGPoint
    let end: CGPoint
    let active: Bool
    let tint: Color
    private var curve: Path {
        Path { p in
            p.move(to: start)
            p.addCurve(to: end, control1: CGPoint(x: start.x, y: start.y + 42), control2: CGPoint(x: end.x, y: end.y - 42))
        }
    }
    var body: some View {
        ZStack {
            curve.stroke(.black.opacity(0.9), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .shadow(color: .black, radius: 3, y: 2)
            curve.stroke(LinearGradient(colors: [Color(red: 0.65, green: 0.47, blue: 0.25), Color(red: 0.2, green: 0.13, blue: 0.09), Color(red: 0.49, green: 0.33, blue: 0.17)], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            curve.stroke(active ? tint : Color.black.opacity(0.55), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .shadow(color: active ? tint : .clear, radius: 5)
            Circle().fill(active ? tint : Color(red: 0.64, green: 0.46, blue: 0.24))
                .frame(width: 5, height: 5).shadow(color: .black, radius: 1, y: 1)
                .position(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        }.allowsHitTesting(false)
    }
}

private struct TalentCarvedPanel: View {
    private let bronze = Color(red: 0.52, green: 0.36, blue: 0.19)
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 9).fill(Color(red: 0.07, green: 0.052, blue: 0.065))
                Image("TalentAstrolabeBackdrop").resizable().scaledToFill().frame(width: proxy.size.width, height: proxy.size.height).clipped().opacity(0.35)
                RoundedRectangle(cornerRadius: 9).stroke(LinearGradient(colors: [Color(red: 0.77, green: 0.60, blue: 0.34), bronze, .black, bronze], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 5)
                RoundedRectangle(cornerRadius: 5).stroke(bronze.opacity(0.7), lineWidth: 1).padding(6)
                ForEach(0..<4) { corner in
                    Image("TalentBronzeSocket").resizable().scaledToFit().frame(width: 23, height: 23)
                        .position(x: corner % 2 == 0 ? 8 : proxy.size.width - 8, y: corner < 2 ? 8 : proxy.size.height - 8)
                }
                Image("TalentBronzeSocket").resizable().scaledToFit().frame(width: 30, height: 30).position(x: proxy.size.width / 2, y: 0)
            }.clipShape(RoundedRectangle(cornerRadius: 9)).shadow(color: .black.opacity(0.8), radius: 8, y: 5)
        }.allowsHitTesting(false)
    }
}

private struct TalentMetalButton: ButtonStyle {
    let tint: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 15, weight: .bold, design: .serif))
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .padding(.leading, 56)
            .foregroundStyle(Color(red: 0.95, green: 0.86, blue: 0.66))
            .background {
                Image("ButtonArt02TalentMetal")
                    .resizable(capInsets: EdgeInsets(top: 24, leading: 110, bottom: 24, trailing: 44), resizingMode: .stretch)
                    .accessibilityHidden(true)
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// P0 is isolated from the legacy combat allocation until resource mechanics are implemented.
struct HermitTalentTreeView: View {
    let game: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: S9TalentDraft?
    @State private var tree = "T"
    @State private var selectedCode = "T1"
    @State private var message: String?
    @State private var removal: S9Removal?
    @State private var details = false
    @State private var resetPrompt = false
    private let gold = Color(red: 0.32, green: 0.40, blue: 0.49)
    private var tint: Color { tree == "T" ? Color(red: 0.46, green: 0.33, blue: 0.68) : tree == "P" ? Color(red: 0.13, green: 0.52, blue: 0.57) : Color(red: 0.25, green: 0.44, blue: 0.69) }
    private var node: S9TalentNode { S9TalentNode.all.first { $0.code == selectedCode }! }
    private var rank: Int { draft?.ranks[node.id] ?? 0 }
    private var store: S9TalentFileStore {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return S9TalentFileStore(url: root.appendingPathComponent("HermitP0/sandbox-s9.json"))
    }
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                Image("TalentStudyAnime").resizable().scaledToFill()
                    .saturation(0.55).contrast(0.82)
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                    .overlay {
                        LinearGradient(stops: [
                            .init(color: Color(red: 0.94, green: 0.97, blue: 1).opacity(0.76), location: 0),
                            .init(color: Color(red: 0.94, green: 0.97, blue: 1).opacity(0.62), location: 0.22),
                            .init(color: Color(red: 0.94, green: 0.97, blue: 1).opacity(0.43), location: 0.55),
                            .init(color: Color(red: 0.94, green: 0.97, blue: 1).opacity(0.30), location: 1)
                        ], startPoint: .top, endPoint: .bottom)
                    }
            }.ignoresSafeArea()
            VStack(spacing: 8) {
                HStack {
                    GameArtReturnButton(title: "返回角色") { dismiss() }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("愚者 · 序列9").font(.system(size: 22, weight: .bold, design: .serif))
                        Text("开发预览 · 战斗效果未接入").font(.caption).foregroundStyle(gold)
                    }
                    Spacer(minLength: 0)
                    Button { resetPrompt = true } label: { Image(systemName: "arrow.counterclockwise").frame(width: 48, height: 48) }
                        .accessibilityLabel("重置天赋").disabled(draft == nil)
                }
                if let draft {
                    HStack {
                        Text("可用 \(draft.remaining)").foregroundStyle(tint).bold()
                        Spacer()
                        Text("沙盘投入 \(draft.spent) / 30").foregroundStyle(gold)
                        Text("自动保存").foregroundStyle(gold)
                    }.font(.caption).padding(.horizontal, 8)
                    HStack(spacing: 8) {
                        branchButton("T", "诡术", "IconTalentTrickster")
                        branchButton("P", "幻身", "IconTalentDeceiver")
                        branchButton("S", "秘兆", "IconTalentBoundary")
                    }
                    ScrollView {
                        constellation
                    }.frame(maxHeight: .infinity)
                    editor
                } else {
                    Spacer()
                    VStack(spacing: 18) {
                        Text("五级天赋 · 独立沙盘").font(.title3.bold())
                        Text("三系各6个节点，每节点5级；总预算30点。\n可尝试专精、20＋10、15＋15。")
                        Text("正式发点需确认任务里程碑映射。旧天赋继续用于战斗，新版不会自动覆盖旧配置。")
                            .foregroundStyle(gold)
                        #if DEBUG
                        Button("进入30点测试沙盘") { openSandbox() }.buttonStyle(FantasyTalentButton(tint: tint))
                        #else
                        Text("新版尚未开放正式配点")
                        #endif
                    }.font(.subheadline).multilineTextAlignment(.center).padding(22).background { FantasyTalentPanel() }
                    Spacer()
                }
            }.padding(.horizontal, 16).padding(.bottom, 8)
            if let message {
                modal(title: "提示", text: message) {
                    Button("知道了") { self.message = nil }.buttonStyle(FantasyTalentButton(tint: tint))
                }
            } else if let removal {
                modal(title: "确认退点", text: refundText(removal)) {
                    Button("退还 \(removal.total) 点") { updateAndSave { try $0.confirm(removal) }; self.removal = nil }.buttonStyle(FantasyTalentButton(tint: tint))
                    Button("取消") { self.removal = nil }.frame(minHeight: 48)
                }
            } else if resetPrompt {
                modal(title: "重置天赋", text: "免费返还测试点数，并立即保存。") {
                    Button("重置当前系") { updateAndSave { $0.reset(tree: tree) }; resetPrompt = false }.buttonStyle(FantasyTalentButton(tint: tint))
                    Button("重置全部三系") { updateAndSave { $0.reset() }; resetPrompt = false }.frame(minHeight: 48)
                    Button("取消") { resetPrompt = false }.frame(minHeight: 48)
                }
            } else if details {
                modal(title: node.name, text: "\(node.conditions)\n\n前置：\(node.parent?.components(separatedBy: "/").last ?? "起始节点")；本系其他有效投入至少\(node.threshold)点。\n剧情条件：\(node.story.isEmpty ? "无" : node.story)。测试沙盘全部开放。\n\n五级效果：\n" + (1...5).map { "\($0)级：\(node.effect(rank: $0))" }.joined(separator: "\n")) {
                    if rank > 0 {
                        Button("退还一级") { perform { removal = try draft?.removal(node.id) }; details = false }.frame(minHeight: 48)
                    }
                    GameArtReturnButton(title: "返回星图") { details = false }
                }
            }
        }.foregroundStyle(Color(red: 0.18, green: 0.25, blue: 0.34))
            .preferredColorScheme(.light)
            .task {
                #if DEBUG
                if draft == nil { openSandbox() }
                #endif
            }
    }
    private func branchButton(_ code: String, _ title: String, _ art: String) -> some View {
        let accent = code == "T" ? Color(red: 0.49, green: 0.34, blue: 0.69) : code == "P" ? Color(red: 0.18, green: 0.52, blue: 0.56) : Color(red: 0.29, green: 0.44, blue: 0.67)
        let selected = code == tree
        return Button { tree = code; selectedCode = code + "1" } label: {
            VStack(spacing: 3) {
                Image(art).resizable().scaledToFit().frame(width: 76, height: 76)
                    .scaleEffect(selected ? 1.08 : 0.94)
                    .shadow(color: accent.opacity(selected ? 0.65 : 0.18), radius: selected ? 10 : 3)
                Text(title).font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundStyle(Color(red: 0.18, green: 0.25, blue: 0.34))
                    .shadow(color: .white.opacity(0.9), radius: 3)
                Text("\(S9TalentNode.all.filter { $0.tree == code }.reduce(0) { $0 + (draft?.ranks[$1.id] ?? 0) }) / 30")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(red: 0.16, green: 0.20, blue: 0.29))
                    .padding(.horizontal, 10).padding(.vertical, 2)
                    .background(accent.opacity(selected ? 0.28 : 0.16), in: Capsule())
            }.padding(.horizontal, 3).padding(.top, 2)
                .frame(maxWidth: .infinity).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
    private var constellation: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack {
                ForEach(0..<4, id: \.self) { index in
                    let column = index % 2
                    let row = index / 2
                    Path { path in
                        let x = width * (column == 0 ? 0.25 : 0.75)
                        path.move(to: CGPoint(x: x, y: CGFloat(row) * 168 + 53))
                        path.addLine(to: CGPoint(x: x, y: CGFloat(row + 1) * 168 + 53))
                    }.stroke(tint.opacity(0.35), style: StrokeStyle(lineWidth: 3, lineCap: .round))

                }
                ForEach(S9TalentNode.all.filter { $0.tree == tree }) { item in
                    Button { selectedCode = item.code } label: {
                        VStack(spacing: 1) {
                            ZStack(alignment: .bottom) {
                                Image(talentArt(item)).resizable().scaledToFill().frame(width: 90, height: 90)
                                    .clipShape(Circle())
                                Circle().stroke(item.code == selectedCode ? Color(red: 1, green: 0.75, blue: 0.26) : .white, lineWidth: 3)
                                Text("\(draft?.ranks[item.id] ?? 0)/5").font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color(red: 0.16, green: 0.20, blue: 0.29)).padding(.horizontal, 9).padding(.vertical, 2)
                                    .background(Color.white.opacity(0.88), in: Capsule()).offset(y: 8)
                            }.frame(width: 90, height: 90)
                                .shadow(color: item.code == selectedCode ? Color.orange.opacity(0.32) : tint.opacity(0.15), radius: 8)
                            Text(item.name).font(.system(size: 15, weight: .semibold))
                                .padding(.horizontal, 5).background(.white.opacity(0.55), in: Capsule()).padding(.top, 19)

                        }
                    }.buttonStyle(.plain).accessibilityLabel("\(item.name)，\(draft?.ranks[item.id] ?? 0)级")
                        .position(x: width * (item.index % 2 == 0 ? 0.25 : 0.75), y: CGFloat(item.index / 2) * 168 + 64)
                }
            }
        }.frame(height: 510)
    }
    private var editor: some View {
        VStack(spacing: 6) {
            Button { details = true } label: {
                HStack(spacing: 6) {
                    Text("\(node.name)  \(rank)/5").font(.headline)
                    Image(systemName: "info.circle").font(.subheadline)
                }.frame(minHeight: 44)
            }.buttonStyle(.plain).accessibilityLabel("查看天赋详情")
            Text(rank == 5 ? node.effect(rank: 5) : node.effect(rank: rank + 1))
                .font(.system(size: 13)).multilineTextAlignment(.center).lineLimit(2)
            if !canAdd && rank < 5 {
                Text(status).font(.caption2).foregroundStyle(gold).lineLimit(2)
            }
            Button(rank == 5 ? "已满级" : rank == 0 ? "激活 · 1点" : "升级 · 1点") {
                updateAndSave { try $0.add(node.id) }
            }.buttonStyle(TalentInvocationButton(tint: tint)).disabled(!canAdd)
                .frame(maxWidth: 240)
        }.frame(maxWidth: .infinity).padding(.horizontal, 16).padding(.bottom, 12)
            .background {
                Ellipse().fill(.white.opacity(0.72)).blur(radius: 24)
                    .padding(.horizontal, -12).allowsHitTesting(false)
            }
    }
    private func talentArt(_ item: S9TalentNode) -> String {
        let art: [String] = item.tree == "T"
            ? ["IconSkillSpiritualDodge", "IconSkillWeakness", "IconSkillPaperDouble", "IconRelicBackwardWatch", "IconSkillDivination", "IconBasicAttackFool"]
            : item.tree == "P"
            ? ["IconRelicOwnerlessMask", "IconSkillPaperDouble", "IconRelicPaperMoon", "IconTalentDeceiver", "IconRelicMirrorCase", "IconBasicDefenseFool"]
            : ["IconSkillOmenRecord", "IconSkillDivination", "IconSkillWeakness", "IconSkillDangerPremonition", "IconRelicPaperDouble", "IconRelicBackwardWatch"]
        return art[item.index]
    }
    private var canAdd: Bool { guard var copy = draft else { return false }; return (try? copy.add(node.id)) != nil }
    private var status: String {
        if rank == 5 { return "已满级 · 战斗效果未接入" }
        guard let draft else { return "未开启沙盘" }
        if !draft.unlocked.contains(node.id) { return "剧情未解锁：\(node.story)" }
        var test = draft.ranks; test[node.id, default: 0] += 1
        if (try? S9TalentRules.prefix(test, unlocked: draft.unlocked)) != test { return "需前置1级，且本系其他有效投入≥\(node.threshold)点" }
        if draft.remaining == 0 { return "可用点数不足" }
        return "每级消耗1点"
    }
    private func perform(_ operation: () throws -> Void) { do { try operation() } catch { message = error.localizedDescription } }
    private func openSandbox() {
        perform {
            let directory = store.url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let legacyBackup = directory.appendingPathComponent("legacy-v1-preserved.json")
            if !FileManager.default.fileExists(atPath: legacyBackup.path) {
                let bytes = try JSONEncoder().encode(Array(game.hermitTalents.learned).sorted())
                try bytes.write(to: legacyBackup, options: .atomic)
                try Data("旧版节点语义不兼容，未映射等级；旧战斗配置保留。新版沙盘独立保存，30点仅用于测试，不作为正式已得点数。".utf8)
                    .write(to: directory.appendingPathComponent("migration-report.txt"), options: .atomic)
            }
            let saved = try store.load(earned: 30, unlocked: S9TalentRules.ids)
            draft = try S9TalentDraft(ranks: saved.nodes, earned: 30, saveRevision: saved.saveRevision)
        }
    }
    // Commit a candidate before publishing it to the UI; failed writes preserve the last saved allocation.
    private func updateAndSave(_ edit: (inout S9TalentDraft) throws -> Void) {
        guard var candidate = draft else { return }
        do {
            try edit(&candidate)
            candidate.didSave(try store.commit(candidate))
            draft = candidate
        } catch { message = error.localizedDescription }
    }
    private func refundText(_ preview: S9Removal) -> String {
        "本次共返还\(preview.total)点：\n" + S9TalentNode.all.compactMap { item in preview.refunds[item.id].map { "\(item.name)：\($0)点" } }.joined(separator: "\n") + "\n确认后立即保存。"
    }
    private func modal<Actions: View>(title: String, text: String, @ViewBuilder actions: () -> Actions) -> some View {
        ZStack {
            Color(red: 0.15, green: 0.20, blue: 0.30).opacity(0.38).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(title).font(.title3.bold())
                ScrollView { Text(text).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 300)
                actions()
            }.padding(22).background { FantasyTalentPanel() }.padding(22)
        }
    }
}

private struct FantasyCutCorner: Shape {
    func path(in rect: CGRect) -> Path {
        let cut: CGFloat = 8
        return Path { p in
            p.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
            p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
            p.closeSubpath()
        }
    }
}
private struct TalentRibbon: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: r.width, y: 0))
            p.addLine(to: CGPoint(x: r.width - 7, y: r.height * 0.5))
            p.addLine(to: CGPoint(x: r.width, y: r.height - 6))
            p.addQuadCurve(to: CGPoint(x: 0, y: r.height - 6), control: CGPoint(x: r.midX, y: r.height + 6))
            p.addLine(to: CGPoint(x: 7, y: r.height * 0.5)); p.closeSubpath()
        }
    }
}
private struct TalentScroll: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 10, y: 4))
            p.addQuadCurve(to: CGPoint(x: r.width - 10, y: 4), control: CGPoint(x: r.midX, y: 14))
            p.addQuadCurve(to: CGPoint(x: r.width - 6, y: r.height - 5), control: CGPoint(x: r.width - 20, y: r.midY))
            p.addQuadCurve(to: CGPoint(x: 6, y: r.height - 5), control: CGPoint(x: r.midX, y: r.height - 14))
            p.addQuadCurve(to: CGPoint(x: 10, y: 4), control: CGPoint(x: 20, y: r.midY))
            p.closeSubpath()
        }
    }
}
private struct FantasyTalentPanel: View {
    private let ink = Color(red: 0.60, green: 0.54, blue: 0.43)
    var body: some View {
        ZStack {
            TalentScroll().fill(LinearGradient(colors: [Color(red: 1, green: 0.97, blue: 0.88), Color(red: 0.97, green: 0.98, blue: 1), Color(red: 0.91, green: 0.92, blue: 0.98)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: Color.indigo.opacity(0.15), radius: 4, y: 3)
            TalentScroll().stroke(ink.opacity(0.65), lineWidth: 1)
            TalentScroll().stroke(.white.opacity(0.85), lineWidth: 1).padding(4)
            VStack {
                ornament
                Spacer(minLength: 0)
                ornament.rotationEffect(.degrees(180))
            }.padding(.horizontal, 25)
            HStack {
                roller
                Spacer()
                roller
            }.padding(.horizontal, 2)
        }.allowsHitTesting(false)
    }
    private var ornament: some View {
        HStack(spacing: 5) {
            Rectangle().fill(LinearGradient(colors: [.clear, ink.opacity(0.5)], startPoint: .leading, endPoint: .trailing)).frame(height: 1)
            Image(systemName: "sparkle").font(.system(size: 13)).foregroundStyle(ink)
            Rectangle().fill(LinearGradient(colors: [ink.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)).frame(height: 1)
        }.frame(height: 12)
    }
    private var roller: some View {
        Capsule().fill(LinearGradient(colors: [Color(red: 0.77, green: 0.70, blue: 0.56), .white, Color(red: 0.82, green: 0.77, blue: 0.67)], startPoint: .leading, endPoint: .trailing))
            .frame(width: 7).padding(.vertical, 6)
            .overlay { Capsule().stroke(ink.opacity(0.4), lineWidth: 0.5).padding(.vertical, 6) }
    }
}
private struct TalentInvocationButton: ButtonStyle {
    let tint: Color
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold, design: .serif))
            .foregroundStyle(Color(red: 0.13, green: 0.11, blue: 0.17))
            .frame(maxWidth: .infinity, minHeight: 68)
            .background {
                Image("ButtonArt01TalentInvocation")
                    .resizable(capInsets: EdgeInsets(top: 24, leading: 130, bottom: 24, trailing: 130), resizingMode: .stretch)
                    .saturation(isEnabled ? 1 : 0)
                    .brightness(configuration.isPressed ? -0.12 : 0)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .offset(y: configuration.isPressed ? 3 : 0)
            .opacity(isEnabled ? 1 : 0.5)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct FantasyTalentButton: ButtonStyle {
    let tint: Color
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(isEnabled ? Color(red: 0.19, green: 0.12, blue: 0.15) : Color.gray)
            .background {
                Capsule().fill(LinearGradient(colors: isEnabled ? [Color(red: 1, green: 0.56, blue: 0.16), Color(red: 1, green: 0.72, blue: 0.27)] : [Color.gray.opacity(0.16), Color.gray.opacity(0.16)], startPoint: .leading, endPoint: .trailing))
            }
            .overlay(Capsule().stroke(.white.opacity(0.8), lineWidth: 1))
            .shadow(color: .orange.opacity(isEnabled ? 0.18 : 0), radius: 3, y: 2)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
