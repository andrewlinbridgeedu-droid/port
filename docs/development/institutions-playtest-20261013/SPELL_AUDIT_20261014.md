# 171.6 spell version audit

Reference: eaece4f6ecf857c9eb2f7dbe98be7661e9b44ac2, confirmed by the other build thread. Compared all tracked Unity Assets and BuildSupport files physically: 2938 identical files, 30 AIHero metadata files with whitespace-only differences, and two code differences. CombatTempoPresentation removes retired RefinedHero selection paths. HellHoundEffekseerFireball adds a DrawsBreath guard that suppresses the legacy fireball when the painted breath owns presentation. Missing files are exclusively the authorized retired heroes and unmapped HandDrawn/Effekseer samples. No unexpected missing files. 1012 spell-related files, including metadata, match. Git blob comparison includes LFS pointers; physical_state is authoritative for actual content.

Unity export freshness passed. All 17 exported Data files are identical in the compiled App. These checks establish packaging consistency, not per-spell physical visual approval.

Basic route: ChapterOneTestView basic + target -> UnityBattleBridge -> BattlePrototype.PresentPlayerAction(Basic) -> AIHero action, FoolBasicTarotVFX flying card, SpellSpectacle paper/Form.Flick -> FormImpact -> InkHit burst. FullScreenOverlay=false, InkStrokes=true. The retained flying tarot releases at 0.16s and contacts at 0.58s; gold-violet trails accompany it and the Ink burst is preferred on contact. A legacy impact fallback exists if Ink material is unavailable. No runtime branch log was obtained; fallback has not been excluded.

02:08 physical iPhone Mirroring Q12 with Unity: four selected cards at bottom, items default right; toggled left then restored right. Configuration only, no Q12 settlement. 02:10 Q1 in separate visual-review-20261014 profile: observed purple flying-tarot casting frame and third-contact dialogue. Impact and recovery were not fully reviewed. 02:16 explicit process termination and no-argument restart: title, Enter Mistport and Playtest Settings visually observed.

Preferences: 9 -> 10 files, added isolated visual-review profile. Existing semantics changed only music setting and initialization of combatItemsOnLeft=false. Wallet, mission progress, materials, ownership, bank and contracts unchanged. See preferences-hud-1716-comparison.json.

The user's report that basic looks older remains unresolved at the impact-branch level. No basic effect was modified during this audit.
