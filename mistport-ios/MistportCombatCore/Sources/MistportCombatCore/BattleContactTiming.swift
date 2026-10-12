import Foundation

/// Rule-owned contact deadlines, shared by watched combat and immediate settlement.
/// Durations are in combat seconds, before the normal 50 ms rule-tick quantization.
/// Unity's receipt is presentation telemetry; frame delivery must not change combat.
public enum MPCBattleContactTiming {
    public static func playerContact(_ skill: FoolSkillID?) -> TimeInterval {
        MPCChurchBattleDriver.playerContact(skill)
    }

    /// Time from an attack command to its hit. Authored preparations (charge,
    /// guard, recovery) must use `session.authoredPreparationDuration` first.
    /// `encounterID` is required because a calibration puppet is a scribe in
    /// Q9/Q12/Q14, but is an archivist with a different spell in Q10.
    public static func enemyContact(contentID: String, intent: String, encounterID: String) -> TimeInterval {
        if MPCChurchTowerCatalog.enemyConfiguration(contentID: contentID) != nil {
            // ChurchDemonPresentation20260917.Act: minions .5; scissors .35;
            // other demons .65. StonehidePresentation20260917.Strike: 1.0.
            return MPCChurchTowerCatalog.contactDuration(contentID: contentID, intent: intent)
        }
        if MPCChurchBountyCatalog.enemyDefinition(id: contentID) != nil {
            // BountyIdentityPresentation20260917.Strike and the B01 tempo body.
            return 0.65
        }
        if contentID == "enemy_memory_leech_node" {
            // ArchiveEncounterPresentation.Repair / BattlePrototype.RotateClockCoreCast.
            return intent == "repair_guard" ? 0.85 : 0.82
        }
        if contentID == "enemy_memory_leech" || contentID == "elite_memory_trimmer" {
            // MemoryLeechPresentation.Cast: .42 charge + .62 flight.
            return 1.04
        }
        if contentID == "enemy_emerald_revenant" {
            // BattlePrototype: .08 prelude + EmeraldRevenantSpell .24 + .78.
            return 1.1
        }
        if contentID == "enemy_clockwork_hound" {
            if encounterID == "chapter01_q04_encounter" {
                // Q4HoundPresentation.Shot, both probe and the two flame hits.
                return 0.45
            }
            if intent == "bite" || ["chapter01_q03_encounter", "chapter01_q16_encounter"].contains(encounterID) {
                // Early hound breath and PresentHellHoundPounceTurn.
                return 1.1
            }
            // Late armoured hound: SignatureEnemyPresentation.Cast.
            return 2.05
        }
        if ["guard", "fortify", "calibrate", "calibration", "recover"].contains(intent) {
            // BattlePrototype.PresentClockGuardPreparation. Longer authored
            // preparation windows have already been handled by the caller.
            return 0.65
        }
        if intent == "thirteenth_charge" {
            // PresentEliteChargedStrike: 1.1 wind-up + StoryStrikeTiming contact 1.
            return 2.1
        }
        if contentID == "enemy_resonant_clock_guard_q2" || contentID == "enemy_resonant_clock_guard_q2_split" {
            // Both colour variants use MainlineGhostRound2.Play, not the old
            // .94/.68 sampled deadlines from before that shared presentation.
            return 0.9
        }
        if contentID == "enemy_archive_gatekeeper"
            || (contentID == "enemy_calibration_puppet" && encounterID == "chapter01_q10_encounter")
            || (contentID == "enemy_hollow_clockmaker" && ["chapter01_q15_encounter", "chapter01_q22_encounter", "chapter01_q25_encounter"].contains(encounterID)) {
            // EnemySignatureSpellVFX: ChargeDuration 1.4 + TravelDuration .65.
            return 2.05
        }
        // StoryEnemyPresentation, HeavyArchivePresentation, ChronarchPresentation
        // and the ordinary guard all contact at 1.0 (StoryStrikeTiming20261010;
        // BattlePrototype's guard 150/60-second clip × .40 hit progress).
        return 1
    }
}

/// Two breaths fit one four-second phantom. The next pair gives the eighteen-
/// second mask cooldown two seconds of reaction room. Times are combat seconds.
public enum MPCQ3HoundTiming {
    public static let firstCast: TimeInterval = 2
    public static let pairSpacing: TimeInterval = 1.4
    public static let cycle: TimeInterval = 20

    public static let intents = ["memory_breath", "memory_breath", "bite", "bite", "bite", "bite", "bite"]
    public static let castOffsets: [TimeInterval] = [firstCast, firstCast + pairSpacing, 6, 9, 12, 15, 18]

    public static func castTime(start: TimeInterval, attackIndex: Int) -> TimeInterval {
        start + Double(attackIndex / intents.count) * cycle
            + castOffsets[attackIndex % intents.count]
    }
}
