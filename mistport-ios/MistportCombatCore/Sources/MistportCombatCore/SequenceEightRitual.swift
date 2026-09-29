import Foundation

/// Chapter One's Sequence 8 ritual at Black Salt Shore, qualification only.
/// The three main materials and the 280-copper fee are spent once; the three
/// story proofs are checked and kept. No Sequence 8 combat rule is granted:
/// the receipt is the record that the player reached Sequence 8.
public enum MPCSequenceEightRitual {
    public static let ruleVersion = "chapter1-s8-qualification-v1"
    public static let feeID = "chapter1.ritual.fee"
    public static let fee = 280
    /// Black Salt Shore is reached after Q30.
    public static let storyMission = 30
    public static let ingredientIDs = MPCAdvancementMaterialMarket.offers.map(\.id)
    /// Personal proof (Q25), paradox proof (Q26) and the ownerless echo (Q30).
    public static let proofIDs = ["chapter30_p04_personal_proof", "chapter30_p05_paradox_proof", "chapter30_p06_ownerless_echo"]

    public enum Failure: Error, Equatable { case completed, locked, materials, proofs, funds }

    public struct Receipt: Codable, Equatable, Sendable {
        public let id: String
        public let ruleVersion: String
        public let feeID: String
        public let fee: Int
        public let coinsBefore: Int
        public let coinsAfter: Int
        public let consumedIngredientIDs: [String]
        public let verifiedProofIDs: [String]
    }

    /// Checks everything before touching anything, so a refusal spends nothing.
    public static func perform(id: String, completedMissions: Set<Int>, coins: inout Int,
                               ingredients: inout Set<String>, inventory: [String: Int],
                               existing: Receipt?) throws -> Receipt {
        guard existing == nil else { throw Failure.completed }
        guard completedMissions.contains(storyMission) else { throw Failure.locked }
        guard ingredientIDs.allSatisfy(ingredients.contains) else { throw Failure.materials }
        guard proofIDs.allSatisfy({ inventory[$0, default: 0] > 0 }) else { throw Failure.proofs }
        guard coins >= fee else { throw Failure.funds }
        let receipt = Receipt(id: id, ruleVersion: ruleVersion, feeID: feeID, fee: fee,
                              coinsBefore: coins, coinsAfter: coins - fee,
                              consumedIngredientIDs: ingredientIDs, verifiedProofIDs: proofIDs)
        coins -= fee
        ingredients.subtract(ingredientIDs)
        return receipt
    }
}
