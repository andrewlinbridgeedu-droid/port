# First Implementation Batch — Executable Combat Contract Lock

**Batch name:** B1.1 — Fool contract parity and semantic validation  
**Priority:** P1  
**Why first:** It is the smallest high-leverage source-only batch that can be independently implemented and verified with `swift test`. It needs no Xcode app run, Unity editor/export, simulator, physical device, binary assets, StoreKit account, signing credentials, or production service.

> **Snapshot scope:** This batch is based only on source ZIP SHA-256 `01eb9067d99c67e16fb96dae35eed61dbeece82dcd06aa79ec9990f7c1deb7df`. Later local changes may already have changed individual implementation-status facts; those later changes were not reviewed here.

## Problem to solve

The v0.5 implementation status declares `fool_combat_config.v1.1.json` an executable program contract and declares an independent programmer-pack copy. The live contract inventory is therefore:

| Role | File | Snapshot evidence |
|---|---|---|
| **Canonical executable config** | `mistport-ios/docs/game-design/fool_combat_config.v1.1.json` | SHA-256 `77514b1bb8ce7bd90a9039e4ee8cad42f9ff8945fc942811913d0a309fa02cca` |
| **Generated programmer handoff snapshot** | `mistport-ios/docs/game-design/programmer-pack/fool_combat_config.v1.1.json` | Live duplicate identified in the reviewed snapshot; record its pre-change SHA during implementation |
| **Generated SwiftPM runtime snapshot** | `mistport-ios/MistportCombatCore/Sources/MistportCombatCore/Resources/fool_combat_config.v1.1.json` | SHA-256 `41d298316ad69305fee16b7680397b54240bc084269fbfc0211797ef4ef815b0` |

Related canonical/handoff pairs that can encode or explain the same decision are:

- canonical `mistport-ios/docs/game-design/FOOL_COMBAT_IMPLEMENTATION_SPEC_v1.2.md` and generated `mistport-ios/docs/game-design/programmer-pack/FOOL_COMBAT_IMPLEMENTATION_SPEC_v1.2.md`;
- canonical `mistport-ios/docs/game-design/fool_combat_test_vectors.v1.1.json` and generated `mistport-ios/docs/game-design/programmer-pack/fool_combat_test_vectors.v1.1.json`.

The canonical design config and bundled runtime config are already verified different. Semantic differences include:

- `fool_skill_01.name`: `错步刺击` vs `错步穿幕`;
- `fool_skill_01.reuse_delay_actions`: **`0` vs `1`**;
- names for skills 2, 3, 5, and 6 also differ.

Existing `CombatMathTests.configurationLoads()` checks schema version, scale, and counts, but does not detect these changes or a stale programmer-pack snapshot.

## Batch objective

Create one explicit, validated, test-enforced source of truth for the Fool combat contract, with all runtime and programmer-pack copies treated as generated snapshots, without changing the v0.5 product boundary or adding dependencies.

## In scope

1. Inventory the canonical design config, programmer-pack config snapshot, and SwiftPM runtime snapshot; record their starting hashes.
2. Resolve every current diff using the declared authority order. Do not silently choose the newer timestamp.
3. Declare the root `docs/game-design/` config/spec/vector files canonical and the programmer-pack/runtime copies generated snapshots, unless an explicit authority decision records a different policy.
4. Make all three config copies byte-identical through deterministic generation/copying. Keep programmer-pack spec/vector snapshots identical to their canonical counterparts whenever the accepted decision changes names, cooldown semantics, descriptions, or expected results.
5. Add semantic validation to `FoolCombatConfigurationLoader`.
6. Add parity and negative tests that fail on future drift in any generated snapshot.
7. Preserve all current deterministic combat/vector outputs unless the authority decision explicitly requires an approved value change.

## Out of scope

- No SwiftUI/SpriteKit/Unity changes.
- No save-system change.
- No Party AI loader change; that is the next contract batch.
- No balance redesign, new skills, content, dependencies, or schema version bump unless required by the resolved authority.
- No source edits in this audit task; Codex owns implementation.

## Authority decision required

For each differing field, record the decision and source citation. In particular, determine whether `fool_skill_01.reuse_delay_actions` is `0` or `1` from this order:

1. `FOOL_COMBAT_IMPLEMENTATION_SPEC_v1.2.md`;
2. `PARTY_AI_IMPLEMENTATION_SPEC.md` where applicable;
3. `DUNGEON_COMBAT_SPEC.md` where applicable;
4. `GAME_BLUEPRINT.md`;
5. lower-priority v0.5 documents.

A timestamp, current UI label, or runtime behavior is not sufficient to override the authority chain.

## Expected files to change

### Always expected

1. `mistport-ios/docs/game-design/fool_combat_config.v1.1.json`
   - Canonical executable config. Change only if the authority resolution shows a canonical value/name is wrong.
2. `mistport-ios/docs/game-design/programmer-pack/fool_combat_config.v1.1.json`
   - Generated programmer handoff snapshot; must be regenerated from and byte-identical to the canonical config.
3. `mistport-ios/MistportCombatCore/Sources/MistportCombatCore/Resources/fool_combat_config.v1.1.json`
   - Generated runtime snapshot used by `Bundle.module`; must be regenerated from and byte-identical to the canonical config.
4. `mistport-ios/MistportCombatCore/Sources/MistportCombatCore/FoolCombatConfiguration.swift`
   - Add typed semantic validation and make `load` reject invalid contracts.
5. `mistport-ios/MistportCombatCore/Tests/MistportCombatCoreTests/FoolCombatConfigurationValidationTests.swift` **(new)**
   - Valid contract, three-copy parity, snapshot parity, and invalid-fixture tests.
6. `mistport-ios/MistportCombatCore/Tests/MistportCombatCoreTests/CombatMathTests.swift`
   - Strengthen frozen canonical assertions, or leave unchanged if the dedicated validation suite fully supersedes the broad check.

### Conditional authority/snapshot changes

7. `mistport-ios/docs/game-design/FOOL_COMBAT_IMPLEMENTATION_SPEC_v1.2.md`
   - Change only when the authority decision itself must be corrected or clarified.
8. `mistport-ios/docs/game-design/programmer-pack/FOOL_COMBAT_IMPLEMENTATION_SPEC_v1.2.md`
   - Regenerate whenever the canonical specification changes; otherwise verify byte parity and leave content unchanged.
9. `mistport-ios/docs/game-design/fool_combat_test_vectors.v1.1.json`
   - Change only when the accepted cooldown/name decision alters encoded descriptions, prerequisites, or expected results.
10. `mistport-ios/docs/game-design/programmer-pack/fool_combat_test_vectors.v1.1.json`
    - Regenerate whenever the canonical vectors change; otherwise verify byte parity and leave content unchanged.

A repository-level verification script may be added only if the three config copies and two programmer-pack spec/vector pairs cannot be robustly compared from Swift using `#filePath`. Prefer no new external dependency.

## Proposed implementation shape

### 1. Typed validation result

Add a public/internal validator that reports all errors in deterministic order, for example:

- supported `schema_version` and `balance_version`;
- `percentage_scale == 10000` and supported rounding mode;
- positive HP/attack/defense/shield/slot counts within declared safe bounds;
- unique, non-empty skill IDs and enemy-template IDs;
- supported target, rank, damage type, hit policy, hit result, turn order, and damage-pipeline tokens;
- coefficient/hit/cooldown ranges;
- required fields for each skill form;
- no arithmetic input outside the safe domain established for fixed-point math.

`bundled()` and `load(from:)` must return a typed error if validation fails. No `precondition`, `fatalError`, or `try!` should be needed for content rejection.

### 2. Parity enforcement

Use a test that locates all three config copies from `#filePath`, loads raw bytes, and asserts equality. Decode all three and assert semantic equality so line-ending/format policy is explicit. Also compare each programmer-pack specification/vector snapshot to its canonical root counterpart.

Required policy:

- canonical executable config, specification, and vectors remain under root `docs/game-design/`;
- `docs/game-design/programmer-pack/` files are deterministic handoff snapshots, never independently edited authorities;
- the SwiftPM resource is a deterministic runtime snapshot used for `Bundle.module`;
- CI/test fails when any generated snapshot is stale.

### 3. Frozen gameplay assertion

Add a direct assertion for the accepted skill-1 cooldown and all currently drifting names. A future intentional contract change must therefore update the authority, runtime copy, and test in one reviewed batch.

## Required automated tests

At minimum:

1. `canonicalProgrammerPackAndBundledContractsAreByteIdentical`
2. `programmerPackSpecificationMatchesCanonicalSpecification`
3. `programmerPackVectorsMatchCanonicalVectors`
4. `canonicalContractLoadsAndValidates`
5. `canonicalSkillIDsAreUnique`
6. `canonicalEnemyTemplateIDsAreUnique`
7. `canonicalSkillNamesAndSkillOneCooldownMatchAuthority`
8. `rejectsUnsupportedSchemaVersion`
9. `rejectsDuplicateSkillID`
10. `rejectsDuplicateEnemyTemplateID`
11. `rejectsUnsupportedEnumToken`
12. `rejectsNegativeOrUnsafeNumericValue`
13. `rejectsInvalidHitCoefficientShape`
14. Existing Fool vector and combat suites remain green.

Tests must not depend on dictionary iteration order or wall-clock timing.

## Required manual/static checks

No runtime visual test is required to merge this batch, but the reviewer should:

- inspect the authority decision record;
- verify no unrelated balance/content field changed;
- verify all three config SHA-256 values are identical after the change;
- verify programmer-pack specification/vector snapshots match their canonical counterparts;
- inspect the package resource in the built SwiftPM test bundle if available;
- confirm no product boundary changed.

A later app smoke test must confirm the displayed skill name/cooldown matches the accepted contract.

## Acceptance criteria

The batch is complete only when:

1. There is one recorded canonical answer for every current diff.
2. The root `docs/game-design/` config/spec/vector files are explicitly canonical; programmer-pack and SwiftPM copies are explicitly generated snapshots.
3. All three config copies are byte-identical and semantically identical.
4. Programmer-pack spec/vector snapshots match their canonical counterparts, including any approved name/cooldown expectation change.
5. `FoolCombatConfigurationLoader` validates semantics and returns typed errors.
6. An intentional one-byte/gameplay-field drift in any generated snapshot fails an automated test.
7. Duplicate IDs, unsupported tokens, and unsafe values fail without process termination.
8. All existing canonical deterministic vectors and combat tests pass, except an explicitly approved authority-driven expectation change.
9. No dependency is added and no app/Unity/source-of-payment code changes.

## Rollback boundary

Rollback is limited to the always-expected files plus any conditional canonical/programmer-pack spec or vector pair actually changed in this batch. Revert canonical decisions, all generated snapshots, and validation assertions as one unit. The batch must not modify save formats, encounter state, UI routing, Unity exports, product IDs, or binary assets; never leave same-version canonical, programmer-pack, or runtime copies with different content.

## Follow-on batch, not part of this one

After this batch is accepted, apply the same pattern to `party_ai_config.v1.json`: typed loading, semantic validation, injection into `MPCPartyAIPlanner`, and removal of duplicated hard-coded score weights/budgets.
