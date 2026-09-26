/// Stable battle-theme routing. Only the music changes; combat rules and saves do not.
public enum MPCBattleMusicCue: String, CaseIterable, Sendable {
    case petals
    case gears
    case harbor
    case brass

    public var assetName: String {
        switch self {
        case .petals: "BattlePetalsRiver"
        case .gears: "BattleGearsFog"
        case .harbor: "BattleHarborIronToll"
        case .brass: "BattleBrassTide"
        }
    }

    public static func forEncounterID(_ encounterID: String) -> Self {
        if let mission = MPCChapterOneCatalog.mission(forEncounterID: encounterID) {
            switch mission.number {
            case 1...5: return .petals       // Rainy old-city streets and first encounters.
            case 6...15: return .gears       // Archive and clockwork investigation.
            case 16...27: return .harbor     // Signing, convoy, and harbor rescue.
            default: return .brass          // The three Chronarch boss battles.
            }
        }

        if let bounty = MPCChurchBountyCatalog.all.first(where: { $0.encounterID == encounterID }) {
            switch bounty.id {
            case "b07", "b08": return .petals
            case "b01", "b04", "b09": return .gears
            case "b02", "b03", "b06": return .harbor
            default: return .brass          // B05 and B10, the late dramatic cases.
            }
        }

        let towerFloor: Int?
        if encounterID.hasPrefix("church_tower_") {
            towerFloor = Int(encounterID.dropFirst("church_tower_".count))
        } else {
            towerFloor = MPCChurchMaintenanceCatalog.towerFloor(encounterID: encounterID)
        }
        if let towerFloor, (1...100).contains(towerFloor) {
            switch towerFloor {
            case 1...30: return .gears
            case 31...70: return .harbor
            default: return .brass
            }
        }
        return .gears                         // An unknown battle still has a theme.
    }
}
