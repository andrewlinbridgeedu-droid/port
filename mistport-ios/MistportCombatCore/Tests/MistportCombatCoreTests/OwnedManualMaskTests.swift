import Testing
@testable import MistportCombatCore
@Suite("Owned manual mask access") struct OwnedManualMaskTests {
 @Test(arguments: ["chapter01_q04_encounter", "chapter01_q05_encounter"])
 func unselectedOwnedCardCanCastWithoutChangingSequence(encounter: String) throws {
  var campaign = MPCChapterOneCampaignState.chapterStartState
  campaign.grantHoundTutorialCard()
  var loadout = campaign.loadout(forMissionID: encounter == "chapter01_q04_encounter" ? "chapter01_q04" : "chapter01_q05")
  loadout.normalSkillIDs = []
  var s = try MPCChapterOneEncounterSession.start(encounterID: encounter, party: campaign.party, companionIDs: [], loadout: loadout)
  let id = s.enemies[0].id
  #expect(try s.useOwnedManualMasquerade(targetID: id, isOwned: false, at: 5) == nil)
  #expect(s.masqueradeCharges == 0)
  #expect(try s.useOwnedManualMasquerade(targetID: id, isOwned: true, at: 6) != nil)
  #expect(s.masqueradeCharges == 2)
  #expect(s.loadout.normalSkillIDs.isEmpty)
  let hp = s.enemies[0].hp
  #expect(try s.useOwnedManualMasquerade(targetID: id, isOwned: true, at: 6.1) == nil)
  #expect(s.enemies[0].hp == hp)
  #expect(try s.useOwnedManualMasquerade(targetID: id, isOwned: true, at: 23.99) == nil)
  #expect(try s.useOwnedManualMasquerade(targetID: id, isOwned: true, at: 24) != nil)
  #expect(s.loadout.normalSkillIDs.isEmpty)
 }
}
