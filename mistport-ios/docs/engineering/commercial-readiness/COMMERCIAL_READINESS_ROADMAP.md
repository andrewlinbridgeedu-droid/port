# Mistport Commercial Readiness Roadmap

**Date:** 2026-07-28  
**Basis:** Static findings in `COMMERCIAL_READINESS_AUDIT.md`  
**Planning unit:** Engineering batch, not calendar estimate. A batch is a reviewable, reversible change set with its own automated and manual acceptance evidence.

> **Snapshot scope:** This roadmap derives only from the audit of source ZIP SHA-256 `01eb9067d99c67e16fb96dae35eed61dbeece82dcd06aa79ec9990f7c1deb7df`. Later local changes may supersede individual implementation-status findings; they were not reviewed here.

## Delivery strategy

The roadmap is ordered to reduce invalid work. It first locks authority and recovery, then consolidates simulation, then hardens presentation, and only then spends heavily on art, optimization, commerce, and release polish.

The core sequencing rule is:

> **Contract → save/recovery → single simulation → presenters/lifecycle → UX/accessibility/localization → device performance/visual → commerce/privacy/release.**

No phase may claim completion from compilation alone. Each phase closes with an acceptance gate and stored evidence.

## Review-package provenance — outside the product launch roadmap

The reduced collaboration package promised `SOURCE_FILE_SHA256SUMS.txt` in `SOURCE_PACKAGE_NOTES.md` but omitted it. This is a review-input provenance limitation, not a commercial runtime/release defect and not a game launch gate. Before distributing another review snapshot, generate and verify the promised per-file manifest, but do not count that packaging task as a product P2 or as evidence that the game archive itself is reproducible.

## Phase 0 — Baseline, ownership, and reproducible inputs

**Goal:** Make every later result attributable to a known source/config/asset/toolchain set.

### Batch 0.1 — Product baseline ownership

- Record Swift/Xcode/Unity versions and required generated-input versions.
- Name the canonical location for each executable JSON contract.
- Inventory omitted assets by path, SHA-256, dimensions/format, license/provenance, and intended bundle/import settings.
- Record production bundle ID, version/build-number policy, StoreKit product IDs, and release configuration ownership without including credentials.

### Batch 0.2 — Release build recipe

- Add a deterministic, credential-free process for:
  1. validating contracts;
  2. assembling binary assets;
  3. exporting Unity 6.3 LTS to `mistport-ios/UnityBuild`;
  4. building an unsigned Release archive;
  5. extracting archive, privacy, symbol, app-size, and asset reports.
- Fail early on missing assets/export or placeholder IDs.

### Phase 0 acceptance gate

- A clean environment can assemble an unsigned Release archive from documented inputs.
- No placeholder release identifier remains.
- Every binary has provenance and an expected import/bundle rule.
- Archive report is retained as an artifact.

### Dependencies

None. This phase does not require credentials for unsigned build/reproducibility.

## Phase 1 — Executable contract and deterministic-core lock

**Goal:** Ensure design authority, runtime data, and tests describe the same rules.

### Batch 1.1 — Fool contract parity and semantic validation

This is the recommended first implementation batch and is specified in `FIRST_IMPLEMENTATION_BATCH.md`.

- Inventory all three live `fool_combat_config.v1.1.json` copies: canonical design contract, programmer-pack snapshot, and SwiftPM bundled resource.
- Declare `docs/game-design/fool_combat_config.v1.1.json` canonical unless the authority decision explicitly changes the policy; treat the programmer-pack and SwiftPM copies as generated snapshots.
- Enforce three-copy parity and synchronize the programmer-pack `FOOL_COMBAT_IMPLEMENTATION_SPEC_v1.2.md` and `fool_combat_test_vectors.v1.1.json` snapshots when the accepted decision changes names, cooldown semantics, descriptions, or expected vectors.
- Add semantic validation and negative fixtures.
- Preserve all frozen deterministic vector results unless an explicitly approved authority change requires an updated expectation.

### Batch 1.2 — Party AI contract execution

- Decode and validate `party_ai_config.v1.json`.
- Inject budgets, candidate limits, weights, tactics, revive, and hard-rule settings into planner behavior.
- Remove duplicated hard-coded numbers where the JSON is authoritative.
- Add contract-to-code mapping tests and deterministic vectors.

### Batch 1.3 — Numeric/content safety boundary

- Define safe fixed-point input bounds and checked arithmetic.
- Validate duplicate IDs, cross-references, enum tokens, ranges, and schema versions before runtime.
- Replace content-driven traps with typed preflight failures.
- Run mutation/property tests while preserving exact canonical outputs.

### Phase 1 acceptance gate

- Canonical design, programmer-pack, and runtime-resource contract hashes match; related programmer-pack spec/vector snapshots are current.
- Every executable contract has versioned typed loading and semantic validation.
- Intentionally changing either a contract or mapping fails tests.
- Duplicate/malformed/out-of-range content returns typed errors, never a process trap.
- Existing canonical deterministic vectors remain bit-identical.
- Reported 100-test baseline is superseded by a stored new test report.

### Dependencies

Phase 0 canonical paths and ownership. The collaboration-package checksum manifest is not a product dependency.

## Phase 2 — Save, migration, recovery, and progression integrity

**Goal:** Protect player time and make updates/recovery deterministic.

### Batch 2.1 — Versioned save envelope

- Introduce one authoritative `Codable` save envelope with `schemaVersion`, content version, write generation, and validation result.
- Use atomic file replacement and previous-good backup.
- Keep existing `UserDefaults` keys only as a one-time migration source.
- Separate game save, user settings, and StoreKit entitlement cache.

### Batch 2.2 — Migration/recovery fixtures

- Add migrations for current legacy keys.
- Add fresh, old, partial, corrupt, and future-version fixtures.
- Add quarantine/recovery messaging and diagnostic ID.
- Validate all restored content IDs and clamp only through documented migrations, not ad hoc reads.

### Batch 2.3 — Progression correctness

- Fix restart to clear all campaign-owned evidence.
- Replace rank mutation with an explicit advancement state machine.
- Make mission/reward/consumable updates exactly-once and transactionally saved.
- Persist deterministic venue cadence/seed.

### Batch 2.4 — Battle continuity policy

- Select turn-boundary checkpoint/resume or explicit abandon/retry policy.
- Serialize authoritative core state/event cursor, not animation state.
- Integrate `scenePhase`, process termination, and navigation handling.

### Phase 2 acceptance gate

- Every migration fixture produces the expected canonical save.
- Interrupted write restores previous-good data.
- Reset equals the documented new-game fixture.
- Boss clear cannot bypass ritual requirements.
- Rewards, consumables, purchases, and rank changes apply exactly once across relaunch.
- Force-quit at every battle boundary follows the documented continuity policy.

### Dependencies

Phase 1 validated IDs/configuration.

## Phase 3 — One shipping combat simulation

**Goal:** Make `MistportCombatCore` authoritative for every launch encounter.

### Batch 3.1 — Core encounter/presenter protocol

- Define immutable commands, events, snapshots, error taxonomy, and replay format.
- Include command/event IDs and content/schema versions.
- Ensure animation timing cannot influence result.

### Batch 3.2 — SpriteKit presenter migration

- Convert `DungeonScene` to consume core snapshots/events.
- Remove authoritative HP, cooldown, resource, AI, reward, and victory mutation from shipping SpriteKit paths.
- Preserve presentation-only VFX methods where valuable.

### Batch 3.3 — Route migration

- Route every launch district/path mission through the core encounter factory.
- Add coverage asserting no fallback to a prototype engine.
- Keep tutorial party sizes (player-only, then one AI, then two AI) within the v0.5 boundary.

### Batch 3.4 — Legacy removal

- Remove v0.4 combat files from the Release target.
- Move debug/test harnesses out of shipping source membership or behind explicit Debug compilation.
- Rename/split `ChapterOneTestView` so the shipping bridge is clearly owned.

### Phase 3 acceptance gate

- Every launch mission has a core encounter test.
- Headless, SpriteKit, Unity, 30/60 FPS, and animation-skip runs produce the same core result/event hash.
- No presentation target mutates gameplay state.
- No v0.4 combat symbols are present in the Release binary.
- Normal, elite, boss, defeat, retry, and reward flows pass app UI smoke tests.

### Dependencies

Phases 1 and 2.

## Phase 4 — Unity presenter lifecycle and 3D production pipeline

**Goal:** Make Unity optional, bounded, data-driven, and recoverable.

### Batch 4.1 — Versioned native/Unity protocol

- Strict JSON/serializable envelope with version, command ID, event type, payload, and error.
- Readiness handshake, ordered queue, accepted/completed/error callbacks, timeout, duplicate suppression, and compatibility fallback.
- Retain and link the existing `MistportUnityBattleEvent(const char *)` plugin callback; add the missing Swift `NotificationCenter` observer/consumer, event decoding, command correlation, and acknowledgement/readiness state.

### Batch 4.2 — Lifecycle/memory policy

- Integrate native scene/background state with Unity `pause`.
- Define when to retain versus `unloadApplication`.
- Add load/error/timeout states and SpriteKit/static fallback.
- Test repeated attach/detach/unload/reload and memory warnings.

### Batch 4.3 — Remove Unity simulation

- Move editor/demo self-simulation to a non-shipping assembly/scene or delete it.
- Production presenter accepts core events only.
- Exclude editor GUI/HUD/prototype assets from iOS export.

### Batch 4.4 — Enemy visual pipeline phase 1

- Implement `EnemyVisualProfile`, standard prefab hierarchy/anchors, formation slots, `EnemyPresenter`, and `EnemySpawner`.
- Migrate Clock Guard/Core and delete special transforms from `BattlePrototype`.
- Fix pose-capture ownership so final spawn pose is explicit.

### Batch 4.5 — Calibration and regression

- Add import validator, calibration window, iPhone portrait aspect switcher, EditMode/PlayMode tests, and screenshots.
- Gate Unity export on profile/test/screenshot approval.

### Phase 4 acceptance gate

- Every Unity command is acknowledged and ordered.
- Unity unavailable/timeout produces a playable fallback with unchanged core result.
- Twenty enter/exit cycles meet memory-stability gate.
- Background/foreground during load/action recovers.
- Production Unity code contains no gameplay simulation.
- Every shipping enemy meets `ENEMY_3D_PIPELINE.md:303-315`.

### Dependencies

Phase 3 event protocol; Phase 0 asset/export recipe.

## Phase 5 — Game UX, accessibility, and localization

**Goal:** Make the complete player journey understandable and operable under failure and assistive settings.

### Batch 5.1 — Loading/error/retry UX

- Explicit loading, content error, Unity fallback, Store unavailable, save recovery, offline, and purchase pending states.
- Safe exit/abandon confirmations and exactly-once reward transitions.
- Clear progression/ritual requirements and save/checkpoint status.

### Batch 5.2 — Accessibility architecture

- Semantic battle model for combatants, intents, HP/status, skills, targets, timeline, AI recommendation, and results.
- 44×44 effective hit targets.
- Dynamic Type styles and reflow.
- Propagate Reduce Motion/Reduce Transparency/contrast decisions to SpriteKit and Unity.
- Add accessibility identifiers only where stable and useful.

### Batch 5.3 — Localization

- String catalog and stable keys/comments.
- Localize UI, errors, accessibility labels, combat logs, and store copy.
- Locale-aware numbers/plurals and proper-noun glossary.
- Pseudolocale and expansion screenshots.

### Batch 5.4 — Onboarding/failure/progression clarity

- Validate first-session sequence, party introduction, combat failure analysis, retry, mission completion, ritual eligibility, and store transition.
- Align “20 main quests” versus “100 stages” terminology.

### Phase 5 acceptance gate

- Core journey completes with VoiceOver and with animations reduced.
- Automated accessibility audit has no high-severity failures.
- Primary targets meet effective size requirement.
- Every launch locale and pseudolocale completes the journey without clipping/overlap.
- Every loading/error/save/purchase state has a recoverable action and diagnostic code.

### Dependencies

Phases 2–4 stable state/presenter contracts.

## Phase 6 — Performance, memory, thermal, asset, and visual acceptance

**Goal:** Turn visual quality into measurable device evidence.

### Batch 6.1 — Instrumentation and baselines

- Add XCTest launch/hitch/memory tests and headless core performance tests.
- Record SpriteKit/Unity load, texture decode, scene transition, and save times.
- Add privacy-minimal on-device performance diagnostics.

### Batch 6.2 — Asset/loading optimization

- Validate dimensions, formats, atlas packing, texture compression, audio, shader variants, and app size.
- Prewarm/stream at controlled points; remove runtime image normalization from critical action paths where possible.
- Define cache eviction and memory-warning response.

### Batch 6.3 — Frame/thermal policy

- Confirm 60 FPS target or define adaptive 30/60 policy.
- Ensure simulation is independent of display frame rate.
- Adapt nonessential effects under thermal/low-power conditions without hiding gameplay information.

### Batch 6.4 — Visual regression and manual matrix

- Screenshot baselines for smallest/widest supported devices, all major combat states, accessibility sizes, localization, shields, selection, and all 3D enemies.
- Physical-device acceptance for touch, safe areas, display zoom, and long-session stability.

### Phase 6 acceptance gate

- p95 frame/hitch/memory/thermal gates from the audit pass on the agreed device set.
- No missing/blurred/cropped asset or shader fallback.
- App size and cold/warm load budgets are approved.
- Screenshot regressions are reviewed and signed off.
- Thirty-minute device run has no jetsam, sustained serious/critical thermal state, desync, or unbounded memory growth.

### Dependencies

Final-ish assets and stable presenters; do not optimize a duplicate simulation.

## Phase 7 — StoreKit, privacy, observability, and Release engineering

**Goal:** Produce a reviewable, diagnosable, policy-compliant Release candidate.

### Batch 7.1 — StoreKit lifecycle

- App-lifetime transaction update listener.
- Pending/cancelled/refunded/revoked/interrupted state model.
- Idempotent entitlement delivery independent of game save.
- StoreKit test configuration and automated matrix.

### Batch 7.2 — Privacy/security boundary

- Final archive privacy report and required-reason analysis.
- SBOM/dependency/license scan and SDK signature checks.
- Save/content validation and integrity checks appropriate to offline-first play; do not add invasive DRM or depend on the network for combat.
- Log redaction and data-retention documentation.

### Batch 7.3 — Crash/performance observability

- Symbolicated crash reports, build/save/content version tags, and privacy-minimal diagnostics.
- On-device performance payload/runbook.
- Verify no real user data in test/diagnostic pipelines.

### Batch 7.4 — App Store Connect/TestFlight

- Production identifiers, pricing/availability, agreements, IAP review assets/notes, privacy answers, age rating, metadata, screenshots, and accessibility claims.
- Sandbox and TestFlight purchase/restore/refund tests on physical devices.
- Upgrade/install tests from prior TestFlight build.

### Phase 7 acceptance gate

- Current Apple submission requirements are rechecked on release day.
- Archive validation/privacy/signature checks are clean.
- StoreKit full matrix passes; App Store Connect product is reviewable.
- Synthetic crash is symbolicated with correct build.
- App Privacy/metadata match observed binary behavior.
- Signed TestFlight build installs, updates, launches, restores save/entitlements, and passes release smoke matrix.

### Dependencies

All prior phases; App Store Connect/signing credentials are used only by authorized owner.

## Phase 8 — Release candidate and launch gate

**Goal:** Freeze scope and require evidence, not confidence.

### Batch 8.1 — RC freeze

- Freeze executable contracts, content IDs, save schema, Unity export, assets, localization, StoreKit IDs, and release configuration.
- Only approved P0/P1 fixes after freeze; each fix reruns affected full gates.

### Batch 8.2 — Full acceptance run

- Automated CI: core, app unit/UI, accessibility, localization, StoreKit, performance, Unity EditMode/PlayMode, asset/archive validation.
- Manual matrix: device, lifecycle, audio, network/store, visual, accessibility, save migration, long-session.
- Incident runbook, rollback/release-stop criteria, customer support recovery steps.

### Phase 8 acceptance gate

- Zero open P0/P1.
- P2 exceptions have named owner, explicit customer impact, mitigation, and post-launch target.
- All unverified audit items have evidence or are removed from release scope.
- Codex independently verifies source changes and release artifacts.

## Explicit “do not start yet” items

Do **not** begin these until their prerequisite gate is closed:

1. **More paths/district combat implementations** before Phase 3 single-authority migration.
2. **Additional 3D enemies or repeated model-specific tuning** before Phase 4 profile/presenter pipeline.
3. **Cloud save, account system, live economy, or analytics expansion** before Phase 2 save schema and Phase 7 privacy design.
4. **Paid expansion submission or marketing screenshots** before StoreKit, free-scope copy, localization, and visual gates.
5. **Broad visual polish/optimization** while duplicate simulations and unstable Unity lifecycle remain.
6. **Any real-time movement combat, live multiplayer combat, five-person party, stamina/login gates, paid power, or main-story paywall** at any phase; these violate v0.5 authority.
7. **Networking Unity combat state**; Unity remains a presenter and combat remains deterministic/local.
8. **Destructive legacy deletion without parity/replay tests**; first create the safety net, then remove.

## Batch evidence template

Each completed batch should attach:

- changed-file list and authority decision;
- automated test report with configuration/tool versions;
- manual test matrix and devices;
- before/after contract/save/event hashes where applicable;
- performance/visual artifacts where applicable;
- known limitations and rollback boundary;
- confirmation that product boundaries remain unchanged.
