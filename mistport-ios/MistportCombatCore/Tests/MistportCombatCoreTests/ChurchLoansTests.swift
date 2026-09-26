import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Church loan escrow and battle transactions")
struct ChurchLoansTests {
    @Test(arguments: [
        ("relic_salt_sealed_breathing_bag", 20, 80, 12),
        ("relic_return_gift_clasp", 20, 110, 16),
        ("relic_deferred_stamp", 20, 240, 36),
        ("relic_reflecting_ink_mirror", 40, 350, 52),
        ("relic_sealed_paperweight", 40, 270, 40),
        ("relic_countertide_anchor", 80, 430, 64),
        ("relic_ownership_severing_needle", 80, 480, 72),
        ("relic_blank_name_card", 80, 460, 68)
    ])
    func priceAndMeritTier(relicID: String, threshold: Int, deposit: Int, rent: Int) throws {
        let offer = try #require(MPCChurchLoanOffer.all.first { $0.relicID == relicID })
        #expect(offer.requiredLifetimeMerit == threshold)
        #expect(offer.deposit == deposit)
        #expect(offer.rentalFee == rent)
        #expect(offer.totalDue == deposit + rent)
    }
    @Test func threeBattleRentalKeepsRentButRefundsFullDepositDespiteWear() throws {
        var ledger = MPCChurchLoanLedger(coins:1000,lifetimeMerit:60,availableMerit:50)
        let loan = try ledger.borrow(relicID:"relic_reflecting_ink_mirror",completedMissions:[14],loanID:"sample")
        #expect(ledger.coins == 598 && ledger.availableMerit == 50 && ledger.lifetimeMerit == 60)
        #expect(loan.depositHeld == 350 && loan.rentalFeePaid == 52)
        for (i,outcome) in [MPCChurchBattleOutcome.victory,.defeat,.retreat].enumerated() {
            let started = try ledger.beginBattle(battleID:"b\(i)",equippedLoanID:loan.id)
            #expect(started)
            let settled = try ledger.settleBattle(battleID:"b\(i)",outcome:outcome)
            #expect(settled)
        }
        #expect(ledger.loans[loan.id]?.durability == 90)
        #expect(ledger.effectiveRelicID(loanID:loan.id) == nil)
        let receipt = try ledger.returnLoan(loan.id)
        #expect(receipt.damageFee == 0 && receipt.copperRefund == 350 && receipt.meritRefund == 0)
        #expect(ledger.coins == 948 && ledger.availableMerit == 50 && ledger.lifetimeMerit == 60)
        let snapshot = ledger
        #expect(try ledger.returnLoan(loan.id) == receipt)
        #expect(ledger == snapshot)
    }
    @Test func beforeBattleAndEarlyReturnNeverRefundRent() throws {
        var ledger = MPCChurchLoanLedger(coins:1000,lifetimeMerit:60,availableMerit:50)
        let canceled = try ledger.borrow(relicID:"relic_reflecting_ink_mirror",completedMissions:[14],loanID:"cancel")
        let canceledReceipt = try ledger.returnLoan(canceled.id)
        #expect(canceledReceipt.copperRefund == 350 && canceledReceipt.meritRefund == 0)
        #expect(ledger.coins == 948 && ledger.availableMerit == 50)
        let loan = try ledger.borrow(relicID:"relic_reflecting_ink_mirror",completedMissions:[14])
        _ = try ledger.beginBattle(battleID:"one",equippedLoanID:loan.id)
        _ = try ledger.settleBattle(battleID:"one",outcome:.victory)
        let receipt = try ledger.returnLoan(loan.id)
        #expect(receipt.damageFee == 0 && receipt.copperRefund == 350 && receipt.meritRefund == 0)
        #expect(ledger.coins == 896 && ledger.availableMerit == 50 && ledger.lifetimeMerit == 60)
    }
    @Test func lostCopyForfeitsOnlyItsEscrow() throws {
        var ledger = MPCChurchLoanLedger(coins:1000,lifetimeMerit:20,availableMerit:0)
        let loan = try ledger.borrow(relicID:"relic_salt_sealed_breathing_bag",completedMissions:[4],loanID:"lost")
        #expect(ledger.coins == 908)
        #expect(try ledger.markLost(loan.id))
        #expect(try !ledger.markLost(loan.id))
        #expect(ledger.effectiveRelicID(loanID:loan.id) == nil)
        let receipt = try ledger.returnLoan(loan.id)
        #expect(receipt.damageFee == 80 && receipt.copperRefund == 0 && receipt.meritRefund == 0)
        #expect(ledger.coins == 908 && ledger.availableMerit == 0)
    }
    @Test func resumeCannotRefreshBattleOrEvadeRetreatCost() throws {
        var ledger = MPCChurchLoanLedger(coins:1000,lifetimeMerit:80,availableMerit:80)
        let loan = try ledger.borrow(relicID:"relic_return_gift_clasp",completedMissions:[4])
        _ = try ledger.beginBattle(battleID:"running",equippedLoanID:loan.id)
        ledger = try JSONDecoder().decode(MPCChurchLoanLedger.self,from:JSONEncoder().encode(ledger))
        let duplicate = try ledger.beginBattle(battleID:"running",equippedLoanID:loan.id)
        #expect(!duplicate && ledger.loans[loan.id]?.remainingBattles == 2)
        #expect(throws:MPCChurchLoanError.battlePending) { try ledger.returnLoan(loan.id) }
        #expect(throws:MPCChurchLoanError.battlePending) { try ledger.beginBattle(battleID:"fresh",equippedLoanID:loan.id) }
        _ = try ledger.settleBattle(battleID:"running",outcome:.retreat)
        let repeated = try ledger.settleBattle(battleID:"running",outcome:.victory)
        #expect(!repeated && ledger.loans[loan.id]?.durability == 97)
        #expect(throws:MPCChurchLoanError.invalidBattle) { try ledger.beginBattle(battleID:"running",equippedLoanID:loan.id) }
        _ = try ledger.returnLoan(loan.id)
        #expect(ledger.coins == 984 && ledger.availableMerit == 80)
    }
    @Test func independentOwnershipAndUnequippedBattle() throws {
        var ledger = MPCChurchLoanLedger(coins:1000,lifetimeMerit:80,availableMerit:80)
        let owned = ["own-salt":37]
        let loan = try ledger.borrow(relicID:"relic_salt_sealed_breathing_bag",completedMissions:[4])
        #expect(ledger.effectiveRelicID(loanID:loan.id) == loan.offer.relicID)
        #expect(!ledger.mayTransferItem(uid:loan.itemUID))
        #expect(ledger.mayTransferItem(uid:"own-salt"))
        let ignored = try ledger.beginBattle(battleID:"unrelated",equippedLoanID:nil)
        #expect(!ignored && ledger.loans[loan.id]?.remainingBattles == 3)
        _ = try ledger.returnLoan(loan.id)
        #expect(owned["own-salt"] == 37)
    }
    @Test func eligibilityFundsAndForbiddenBoundItems() throws {
        var ledger = MPCChurchLoanLedger(coins:1000,lifetimeMerit:19,availableMerit:100)
        #expect(throws:MPCChurchLoanError.ineligible) { try ledger.borrow(relicID:"relic_salt_sealed_breathing_bag",completedMissions:[4]) }
        ledger.lifetimeMerit = 20
        #expect(throws:MPCChurchLoanError.ineligible) { try ledger.borrow(relicID:"relic_salt_sealed_breathing_bag",completedMissions:[]) }
        ledger.coins = 91
        #expect(throws:MPCChurchLoanError.insufficientFunds) { try ledger.borrow(relicID:"relic_salt_sealed_breathing_bag",completedMissions:[4]) }
        ledger.coins = 1000
        ledger.availableMerit = 0
        _ = try ledger.borrow(relicID:"relic_salt_sealed_breathing_bag",completedMissions:[4])
        #expect(ledger.availableMerit == 0 && ledger.lifetimeMerit == 20)
        #expect(throws:MPCChurchLoanError.unavailable) { try ledger.borrow(relicID:MPCChapterOneCatalog.ownerlessMaskRelicID,completedMissions:Set(1...30)) }
        #expect(throws:MPCChurchLoanError.unavailable) { try ledger.borrow(relicID:MPCChapterOneCatalog.usurpedLifeMedalRelicID,completedMissions:Set(1...30)) }
    }
    @Test func twoSlotsChargeAndSettleAtomically() throws {
        var ledger = MPCChurchLoanLedger(coins:2000,lifetimeMerit:100,availableMerit:100)
        let active = try ledger.borrow(relicID:"relic_blank_name_card",completedMissions:[17])
        let passive = try ledger.borrow(relicID:"relic_salt_sealed_breathing_bag",completedMissions:[4])
        let other = try ledger.borrow(relicID:"relic_return_gift_clasp",completedMissions:[4])
        let before = ledger
        #expect(throws:MPCChurchLoanError.invalidBattle) { try ledger.beginBattle(battleID:"bad",equippedLoanIDs:[passive.id,other.id]) }
        #expect(ledger == before)
        _ = try ledger.beginBattle(battleID:"both",equippedLoanIDs:[active.id,passive.id])
        #expect(ledger.loans[active.id]?.remainingBattles == 2 && ledger.loans[passive.id]?.remainingBattles == 2)
        _ = try ledger.settleBattle(battleID:"both",outcome:.defeat)
        #expect(ledger.loans[active.id]?.durability == 95 && ledger.loans[passive.id]?.durability == 95)
        #expect(ledger.loans[other.id]?.durability == 100)
        let final = ledger
        _ = try ledger.settleBattle(battleID:"both",outcome:.victory)
        #expect(ledger == final)
    }
    @Test func repairThenSaleNeverCreatesMoney() {
        for value in [120,160,360,520,680,720] {
            for durability in 0...100 {
                let before = MPCChurchLoanLedger.ownedSalePrice(value:value,durability:durability)
                let after = MPCChurchLoanLedger.ownedSalePrice(value:value,durability:100) - MPCChurchLoanLedger.ownedRepairPrice(value:value,durability:durability)
                #expect(after <= before)
            }
        }
    }
    @Test func legacySavedContractKeepsOldRefundAndMeritTerms() throws {
        let saved = """
        {
          "coins": 870, "lifetimeMerit": 60, "availableMerit": 35,
          "loans": {"legacy": {
            "id": "legacy", "itemUID": "loan-item-legacy",
            "offer": {"relicID":"relic_reflecting_ink_mirror","church":"mirror","value":520,"unlockMission":14,"requiredLifetimeMerit":40},
            "durability":90,"remainingBattles":0,"returned":false
          }},
          "battleLoans":{},"settledBattleIDs":[],"returnReceipts":{}
        }
        """
        var ledger = try JSONDecoder().decode(MPCChurchLoanLedger.self, from: Data(saved.utf8))
        let loan = try #require(ledger.loans["legacy"])
        #expect(loan.isLegacyContract && loan.depositHeld == 130 && loan.rentalFeePaid == 0)
        let receipt = try ledger.returnLoan("legacy")
        #expect(receipt.damageFee == 26 && receipt.copperRefund == 104 && receipt.meritRefund == 0)
        #expect(ledger.coins == 974 && ledger.availableMerit == 35)
    }
}
