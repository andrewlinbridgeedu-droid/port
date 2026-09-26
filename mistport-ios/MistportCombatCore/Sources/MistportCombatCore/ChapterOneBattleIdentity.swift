import Foundation

/// Stable presentation identities for the whole wave, including defeated units.
/// Never rebuild ordinals from only the living enemies: an in-flight contact
/// must still identify the same actor after another enemy dies.
public enum MPCChapterOneBattleIdentity {
    /// Presentation notification for actual positive damage, including lethal hits.
    /// Unknown identities never fall back to a different living enemy.
    public static func impactAction(skill: FoolSkillID?, hits: [(String, Int)], enemies: [MPCRuntimeEnemy]) -> String? {
        var seen = Set<String>()
        let ids = hits.compactMap { targetID, damage -> String? in
            guard damage > 0, let id = battleID(for: targetID, in: enemies), seen.insert(id).inserted else { return nil }
            return id
        }
        guard !ids.isEmpty else { return nil }
        return "enemy-impact:\(skill?.rawValue ?? "basic"):\(ids.joined(separator: ","))"
    }

    /// Shared 3D battlefield with encounter-scoped visual overrides.
    public static func supportsUnity(encounterID: String) -> Bool {
        if MPCChurchTowerCatalog.encounter(id: encounterID) != nil || MPCChurchBountyCatalog.encounter(id: encounterID) != nil || MPCChurchMaintenanceCatalog.encounter(id: encounterID) != nil { return true }
        guard let mission = MPCChapterOneCatalog.mission(forEncounterID: encounterID) else { return false }
        return (1...30).contains(mission.number) // Models and objective runtime checked; device acceptance remains separate.
    }

    public static func battleID(for enemyID: String, in enemies: [MPCRuntimeEnemy]) -> String? {
        guard let enemy = enemies.first(where: { $0.id == enemyID }),
              let family = family(for: enemy.contentID) else { return nil }
        let siblings = enemies.filter { self.family(for: $0.contentID) == family }
        guard let index = siblings.firstIndex(where: { $0.id == enemyID }) else { return nil }
        let suffix = index == 0 ? "primary" : index == 1 ? "secondary" : "instance-\(index + 1)"
        return "\(family)-\(suffix)"
    }

    /// Visual overrides preserve stable contact/target identity and combat data.
    public static func visualDescriptor(for enemyID: String, in enemies: [MPCRuntimeEnemy], encounterID: String) -> String? {
        guard let id = battleID(for: enemyID, in: enemies),
              let enemy = enemies.first(where: { $0.id == enemyID }) else { return nil }
        if enemy.contentID.hasPrefix("bounty_b03_escort_") { return id + "@ghost" }
        if enemy.contentID.hasPrefix("bounty_b08_mirror_") { return id + "@bounty-b08-echo" }
        if enemy.contentID == "bounty_b10_life_vessel" { return id + "@bounty-b10-vessel" }
        let bountyVariants = [
            "bounty_b01_execution_body": "bounty-b01", "bounty_b02_abductor": "bounty-b02",
            "bounty_b03_drowned_captain": "bounty-b03", "bounty_b04_forgery_engine": "bounty-b04",
            "bounty_b05_silk_murderer": "bounty-b05", "bounty_b06_dark_hold_captain": "bounty-b06",
            "bounty_b07_knocker": "bounty-b07", "bounty_b08_miren": "bounty-b08",
            "bounty_b09_contract_eater": "bounty-b09", "bounty_b10_life_oracle": "bounty-b10"
        ]
        if let variant = bountyVariants[enemy.contentID] { return id + "@" + variant }
        if let species = MPCChurchTowerCatalog.enemyConfiguration(contentID: enemy.contentID)?.species {
            let variant: String
            switch species {
            case .riftHound: return nil // Retired tower body; never fall back to a mainline hound.
            case .shieldJaw: variant = "stonehide"
            case .saltSac: variant = "saltmaw"
            case .backSac: variant = "shellback"
            case .scissor: variant = "ironclaw"
            case .crown: variant = "frilled-naga"
            case .boneclaw: variant = "boneclaw"
            case .copperback: variant = "copperback"
            case .crimsonBrute: variant = "crimson-brute"
            case .veilOracle: variant = "veil-oracle"
            case .goldenThroat: variant = "golden-throat"
            case .moonfang: variant = "moonfang"
            }
            return id + "@" + variant
        }
        if MPCChurchTowerCatalog.isShieldJaw(enemy.contentID) { return id + "@stonehide" }
        if MPCChurchTowerCatalog.isRiftHound(enemy.contentID) { return nil }
        if ["chapter01_q09_encounter", "chapter01_q12_encounter", "chapter01_q14_encounter"].contains(encounterID), enemy.contentID == "enemy_calibration_puppet" { return id + "@scribe" }
        if ["chapter01_q13_encounter", "chapter01_q21_encounter"].contains(encounterID), enemy.contentID == "elite_clock_chaser" { return id + "@rescue" }
        if enemy.contentID == "enemy_archive_adjudicator" { return id + "@adjudicator" }
        if enemy.contentID == "enemy_archive_convoy" { return id + "@convoy" }
        if enemy.contentID == "boss_chronarch_sovereign" { return id + "@chronarch" }
        if enemy.contentID == "enemy_clockwork_hound", encounterID == "chapter01_q16_encounter" { return id + "@early-hell-hound" }
        if enemy.contentID == "enemy_codex_executor" { return id + "@executor" }
        if enemy.contentID == "enemy_archive_gatekeeper" { return id + "@archivist" }
        if enemy.contentID == "enemy_resonant_clock_guard_q2_split" { return id + "@crimson-ghost" }
        if encounterID == "chapter01_q10_encounter", enemy.contentID == "enemy_calibration_puppet" { return id + "@archivist" }
        if ["chapter01_q15_encounter", "chapter01_q22_encounter", "chapter01_q25_encounter"].contains(encounterID), enemy.contentID == "enemy_hollow_clockmaker" { return id + "@matriarch" }
        return id
    }

    public static func presentationName(contentID: String, encounterID: String, fallback: String) -> String {
        if ["chapter01_q09_encounter", "chapter01_q12_encounter", "chapter01_q14_encounter"].contains(encounterID), contentID == "enemy_calibration_puppet" { return "抄录书记员" }
        if ["chapter01_q13_encounter", "chapter01_q21_encounter"].contains(encounterID), contentID == "elite_clock_chaser" { return "洛克 · 失令救援者" }
        if encounterID == "chapter01_q10_encounter", contentID == "enemy_calibration_puppet" { return "档案守卫" }
        if ["chapter01_q15_encounter", "chapter01_q22_encounter", "chapter01_q25_encounter"].contains(encounterID), contentID == "enemy_hollow_clockmaker" { return "维娅 · 织幕者" }
        return fallback
    }

    /// Zero combat HP means incapacitated; named survivors must not play death.
    public static func defeatPresentation(contentID: String, encounterID: String) -> String {
        if contentID == "enemy_clockwork_hound", ["chapter01_q03_encounter", "chapter01_q04_encounter"].contains(encounterID) { return "retreat" }
        if ["chapter01_q13_encounter", "chapter01_q21_encounter"].contains(encounterID), contentID == "elite_clock_chaser" { return "subdued" }
        if ["chapter01_q15_encounter", "chapter01_q22_encounter", "chapter01_q25_encounter"].contains(encounterID), contentID == "enemy_hollow_clockmaker" { return "subdued" }
        if encounterID == "chapter01_q10_encounter", contentID == "enemy_clockwork_hound" { return "retreat" }
        if encounterID == "chapter01_q20_encounter", contentID == "enemy_archive_convoy" { return "retreat" }
        if ["chapter01_q28_encounter", "chapter01_q29_encounter"].contains(encounterID), contentID == "boss_chronarch_sovereign" { return "retreat" }
        return "hidden"
    }

    public static func family(for contentID: String) -> String? {
        if MPCChurchBountyCatalog.enemyDefinition(id: contentID) != nil { return "clock-guard" }
        if let species = MPCChurchTowerCatalog.enemyConfiguration(contentID: contentID)?.species { return species == .riftHound ? "hell-hound" : "clock-guard" }
        if MPCChurchTowerCatalog.isRiftHound(contentID) { return "hell-hound" }
        switch contentID {
        // Stable bridge actor slot; Native installs the dedicated Emerald model.
        // This ID is contact routing, not the visible creature identity.
        case "enemy_emerald_revenant": return "hell-hound"
        case "enemy_memory_leech": return "memory-leech"
        case "enemy_memory_leech_node": return "clock-core"
        case "enemy_clockwork_hound": return "hell-hound"
        case "enemy_archive_gatekeeper", "enemy_resonant_clock_guard_q2", "enemy_resonant_clock_guard_q2_split", "enemy_calibration_puppet",
             "boss_hollow_clock_guard", "enemy_hollow_clockmaker",
             "enemy_hollow_clockmaker_q1": return "clock-guard"
        // Same-family placeholders keep the battlefield scale consistent.
        // Replace these art mappings when dedicated models arrive; the
        // content IDs and elite combat rules do not change with the art.
        case "enemy_archive_adjudicator", "enemy_archive_convoy", "boss_chronarch_sovereign", "enemy_codex_executor", "elite_clock_chaser": return "clock-guard"
        case "elite_memory_trimmer": return "memory-leech"
        default: return nil
        }
    }
}
