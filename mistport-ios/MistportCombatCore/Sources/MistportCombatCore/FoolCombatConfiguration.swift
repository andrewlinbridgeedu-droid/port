import Foundation

public struct FoolCombatConfiguration: Decodable, Sendable {
    public struct Player: Decodable, Sendable {
        public let maxHP: Int
        public let attack: Int
        public let defense: Int
        public let maxShield: Int
        public let normalSkillSlots: Int

        private enum CodingKeys: String, CodingKey {
            case maxHP = "max_hp"
            case attack
            case defense
            case maxShield = "max_shield"
            case normalSkillSlots = "normal_skill_slots"
        }
    }

    public struct Combat: Decodable, Sendable {
        public let turnOrder: String
        public let maxEnemies: Int
        public let damageReductionCapBP: Int
        public let minimumPositiveDamage: Int
        public let hitResolutionMode: String
        public let hitResults: [String]
        public let defaultHitPolicy: String
        public let guardReductionBP: Int
        public let damagePipeline: [String]

        private enum CodingKeys: String, CodingKey {
            case turnOrder = "turn_order"
            case maxEnemies = "max_enemies"
            case damageReductionCapBP = "damage_reduction_cap_bp"
            case minimumPositiveDamage = "minimum_positive_damage"
            case hitResolutionMode = "hit_resolution_mode"
            case hitResults = "hit_results"
            case defaultHitPolicy = "default_hit_policy"
            case guardReductionBP = "guard_reduction_bp"
            case damagePipeline = "damage_pipeline"
        }
    }

    public struct Skill: Decodable, Identifiable, Sendable {
        public let id: String
        public let name: String
        public let unlockStep: Int
        public let target: String
        public let reuseDelayActions: Int?
        public let baseCoefficientBP: Int?
        public let hits: [Int]?
        public let hitPolicy: String?
        public let damageType: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case unlockStep = "unlock_step"
            case target
            case reuseDelayActions = "reuse_delay_actions"
            case baseCoefficientBP = "base_coefficient_bp"
            case hits
            case hitPolicy = "hit_policy"
            case damageType = "damage_type"
        }
    }

    public struct EnemyTemplate: Decodable, Identifiable, Sendable {
        public let id: String
        public let rank: String
        public let maxHP: Int
        public let attack: Int
        public let defense: Int

        private enum CodingKeys: String, CodingKey {
            case id
            case rank
            case maxHP = "max_hp"
            case attack
            case defense
        }
    }

    public let schemaVersion: String
    public let balanceVersion: String
    public let percentageScale: Int
    public let rounding: String
    public let player: Player
    public let combat: Combat
    public let skills: [Skill]
    public let enemyTemplates: [EnemyTemplate]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case balanceVersion = "balance_version"
        case percentageScale = "percentage_scale"
        case rounding
        case player
        case combat
        case skills
        case enemyTemplates = "enemy_templates"
    }
}

public enum FoolCombatConfigurationLoader {
    public static func bundled() throws -> FoolCombatConfiguration {
        // SwiftPM CLI bundles sit beside the executable; signed macOS apps
        // place the same bundle under Contents/Resources. Preserve the normal
        // package/iOS lookup when no app resource bundle is present.
        #if os(macOS)
        let appBundle = Bundle.main.resourceURL
            .map { $0.appendingPathComponent("MistportCombatCore_MistportCombatCore.bundle") }
            .flatMap { Bundle(url: $0) }
        let resources = appBundle ?? Bundle.module
        #else
        let resources = Bundle.module
        #endif
        guard let url = resources.url(
            forResource: "fool_combat_config.v1.1",
            withExtension: "json"
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try load(from: url)
    }

    public static func load(from url: URL) throws -> FoolCombatConfiguration {
        try JSONDecoder().decode(FoolCombatConfiguration.self, from: Data(contentsOf: url))
    }
}
