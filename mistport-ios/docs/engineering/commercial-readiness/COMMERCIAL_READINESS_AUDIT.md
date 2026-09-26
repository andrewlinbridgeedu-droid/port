# Mistport Commercial iOS Game Readiness Audit

**Review date:** 2026-07-28  
**Reviewer role:** External principal iOS/Unity game engineer  
**Review method:** Static source/document cross-check only  
**Input snapshot:** `mistport-commercial-review-source-2026-07-28.zip`  
**Verified input SHA-256:** `01eb9067d99c67e16fb96dae35eed61dbeece82dcd06aa79ec9990f7c1deb7df`  
**Verified input byte size:** `769709`  
**Revision date:** 2026-07-29

> **Snapshot scope:** This audit is tied exclusively to source ZIP SHA-256 `01eb9067d99c67e16fb96dae35eed61dbeece82dcd06aa79ec9990f7c1deb7df`. Later local changes may supersede individual implementation-status findings; those later changes were not reviewed and are not claimed by this audit.

## Executive assessment

The project is **not commercially ready for iOS release**. The supplied baseline is useful—100 Swift package tests reportedly pass and an unsigned arm64 iPhone Debug build reportedly passes—but those results validate only a subset of combat-core behavior and basic compilation. They do not close the current launch risks in authority consistency, save recovery, Unity lifecycle, app-level testing, StoreKit, accessibility, localization, performance, binary-asset integration, or App Store release evidence.

No verified P0 issue was found in this reduced source snapshot. There are, however, multiple P1 launch-critical issues:

1. The declared executable Fool combat contract is not identical to the JSON actually bundled into `MistportCombatCore`; one changed value is gameplay-relevant (`fool_skill_01.reuse_delay_actions`: authority copy `0`, runtime copy `1`).
2. The shipping app routes only Fool/Old Clock missions through `MistportCombatCore`; other launch combat paths enter a separate `DungeonScene` simulation that calculates damage, cooldowns, turns, victory, and auto-play.
3. A normal mission bootstrap uses `try!`, so a content/configuration mismatch can terminate the app instead of producing a recoverable error.
4. Progress is persisted as independent `UserDefaults` keys with no schema version, migration transaction, backup, corruption quarantine, or atomic commit; restart also leaves campaign evidence behind.
5. Unity still contains its own HP/damage/round simulation. The included iOS plugin implements the native `MistportUnityBattleEvent(const char *)` callback and posts `Notification.Name("MistportUnityBattleEvent")`, but `UnityBattleHost.swift` has no observer/consumer or acknowledgement state; readiness handshake, background pause, unload policy, timeout, and fallback remain incomplete.
6. The current 3D enemy production specification explicitly requires data-driven profiles and tests, but the supplied Unity code still carries enemy-specific transforms and no Unity test assemblies were found.
7. The Xcode project has only the application target, no app unit/UI test target, placeholder release identity, and hard dependencies on an omitted Unity export and binary assets. The reduced package therefore cannot reproduce or visually validate the shipping runtime.
8. StoreKit code exists and includes purchase verification and restore UI, but production product configuration, transaction-update handling, sandbox/TestFlight behavior, refunds/revocations, App Store Connect state, and review metadata are not verified.

### Commercial-readiness verdict

| Area | Verdict | Reason |
|---|---|---|
| v0.5 product boundary | **Fail** | Multiple active combat simulations; executable contract drift. |
| Runtime correctness/recovery | **Fail** | Fatal mission bootstrap; unversioned/non-atomic save; verified reset defect. |
| Combat determinism | **Partial** | Core has deterministic tests, but not all shipping combat uses it and AI JSON is not loaded. |
| Unity presentation boundary | **Fail** | Unity contains combat state/resolution and lacks a complete native lifecycle/protocol boundary. |
| App-level test evidence | **Fail** | No app unit/UI test target; simulator E2E explicitly incomplete. |
| Performance/thermal/memory | **Unverified** | Source hotspots exist; no Instruments/device evidence or performance gates. |
| Accessibility | **Partial** | Some labels and Reduce Motion handling exist, but fixed layouts, small targets, SpriteKit semantics, and no audits remain. |
| Localization | **Fail** | No string catalog/strings files found; extensive hard-coded Chinese and fixed dimensions. |
| Privacy/compliance | **Unverified** | No manifest/archive privacy report or App Store Connect evidence in package. |
| StoreKit | **Partial** | Basic StoreKit 2 flow exists; lifecycle, product availability, and production validation are incomplete. |
| Release reproducibility | **Fail for supplied package** | Required binaries/Unity export are omitted, so the supplied review package cannot assemble or validate the shipping archive. |
| Visual/art/3D acceptance | **Unverified** | All referenced binary art is omitted; simulator/device acceptance is explicitly not complete. |

## Authority and scope used

The review followed the declared v0.5 precedence in `mistport-ios/docs/game-design/README.md:21-32` and `DOCUMENTATION_GUIDE.md:24-37`. The source facts below are evaluated against these non-negotiable boundaries:

- player plus up to two deterministic local AI companions;
- fixed-skill turn-based launch combat;
- no live multiplayer combat, real-time movement combat, five-person party, stamina gate, login reward mandate, paid power, or main-story paywall;
- iOS is the shipping runtime;
- `MistportCombatCore` is authoritative for combat rules;
- Unity is presentation only;
- JSON contracts and deterministic behavior remain compatible.

## Evidence classification

- **Verified source fact:** Directly observed in included text source/project metadata.
- **Reasonable inference:** Consequence strongly indicated by source, but runtime/device execution is required to confirm.
- **Unverified external/runtime item:** Requires omitted assets, generated Unity export, Xcode/Unity execution, physical device, credentials, App Store Connect, StoreKit sandbox/TestFlight, or production dashboards.

## Review-input limitation — not a product finding

**RI-001 — Promised per-file collaboration manifest omitted.** `SOURCE_PACKAGE_NOTES.md:3-6` states that `SOURCE_FILE_SHA256SUMS.txt` is the surrogate baseline, but the reduced review ZIP omitted that file. This is a provenance limitation of the collaboration/review package, not a commercial game runtime or release-quality defect. It is excluded from P0/P1/P2/P3 counts and from game launch gates. A future review package should include a sorted relative-path SHA-256 manifest, packaging-script/version metadata, and a clean-room verification command so reviewers can compare packages and extracted files. The verified outer ZIP SHA above still identifies the exact snapshot reviewed here.

## Evidence table

| ID | Severity | Evidence class | Source evidence | Finding and commercial impact |
|---|---|---|---|---|
| CR-001 | P1 | Verified source fact | `docs/game-design/IMPLEMENTATION_STATUS.md:15-22`; canonical design JSON, `docs/game-design/programmer-pack/fool_combat_config.v1.1.json`, and `MistportCombatCore/.../Resources/fool_combat_config.v1.1.json` | Executable Fool contract drift. The canonical design copy and bundled runtime copy have SHA-256 `77514b...cca` and `41d298...5b0`; Skill 1 cooldown differs (`0` vs `1`). A third live programmer-pack snapshot must be included in parity enforcement so documentation, handoff files, runtime, and player behavior cannot disagree. |
| CR-002 | P1 | Verified source fact | `Mistport/ContentView.swift:133-155`; `Mistport/DungeonScene.swift:14-42,813-856,1600-1625` | Shipping combat authority is split. Only Fool/Old Clock uses the core bridge; other routes use a second simulator with its own HP, cooldowns, damage, turn flow, and victory state. |
| CR-003 | P1 | Verified source fact | `Mistport/ChapterOneTestView.swift:2385-2408` | Mission initialization uses `try!`; a bad encounter, party, loadout, or content reference can crash instead of showing a recoverable error. |
| CR-004 | P1 | Verified source fact | `Mistport/GameStore.swift:83-103,142-212,1011-1032` | Save data is a set of independent `UserDefaults` keys with no schema version, migration registry, atomic envelope, backup, validation report, or corruption recovery. Partial writes or future schema changes can create impossible progression states. |
| CR-005 | P1 | Verified source fact | `Mistport/GameStore.swift:315-323,964-1009` | `restart()` does not clear `chapterOneBehaviorTags` or `chapterOneComboRecords`, although the Debug reset does. A new game can inherit prior campaign evidence. |
| CR-006 | P1 | Verified source fact | `Mistport/GameStore.swift:737-753,771-783`; `GAME_BLUEPRINT.md:170-174`; `PROGRESSION_SYSTEM.md:87` | Clearing `mist-crown-20` directly sets sequence 8, bypassing the explicit material and ritual checks in `performAdvancement()`. This breaks progression clarity and the authoritative ritual sequence. |
| CR-007 | P1 | Verified source fact | `UnityBattleBridge.cs:5-7`; `BattlePrototype.cs:25-28,388-457,1000-1015`; `UnityBattleSource/README.md:3-5` | Unity claims presentation-only status but contains its own HP, damage, defense, enemy turn, win/loss, and automatic-attack prototype. This is a latent second authority and regression source. |
| CR-008 | P1 | Verified source fact + inference | `UnityBattleSource/Assets/Plugins/iOS/MistportUnityBridge.mm`, symbol `MistportUnityBattleEvent(const char *)`; `Mistport/UnityBattleHost.swift:9-109`; `UnityBattleBridge.cs:73-100` | The native callback exists and posts `Notification.Name("MistportUnityBattleEvent")`, but `UnityBattleHost.swift` has no `NotificationCenter` observer/consumer, decoded event state, command-ID acknowledgement tracking, or readiness event handshake. Commands remain fire-and-forget, are silently dropped before `isReady`, and `isReady` is set immediately after `runEmbedded`; lifecycle/fallback gaps remain. |
| CR-009 | P1 | Verified source fact | `mistport-ios/ENEMY_3D_PIPELINE.md:31-47,257-287,303-317,321-357`; `BattlePrototype.cs:182-213,289-330`; `ClockCoreIdle.cs:12-19` | The current production spec requires `EnemyVisualProfile`, shared presenter/spawner, anchors, EditMode/PlayMode/screenshot tests, and removal of hardcoding. Supplied code still hardcodes names, rotations, scale, position, and OnEnable pose capture; no Unity tests were found. |
| CR-010 | P1 | Verified source fact + unverified external item | `Mistport.xcodeproj/project.pbxproj:444-500`; `:113-118,211-232,277-287`; `SOURCE_PACKAGE_NOTES.md:17-24` | Release identity remains `com.yourcompany.mistport`, version `0.1.0`/build `1`, and the app target requires an omitted `UnityBuild`, Unity Data, audio, and binary art. The package cannot reproduce an archive. Signing, archive export, dSYMs, licenses, and current-SDK compliance are unverified. |
| CR-011 | P1 | Verified source fact | `Mistport.xcodeproj/project.pbxproj:211-234`; shared scheme `Mistport.xcscheme:26-32`; `IMPLEMENTATION_STATUS.md:58-68` | The Xcode project contains only the app target; no app unit/UI test target is declared and the scheme TestAction has no explicit testable. Simulator E2E visual acceptance is explicitly incomplete. |
| CR-012 | P1 | Verified source fact + unverified external item | `Mistport/Storefront.swift:20-95`; `GameViews.swift:939-1085` | StoreKit 2 purchase verification, entitlement refresh, price display, and restore UI are positive. However, no long-lived `Transaction.updates` listener exists; pending is reduced to idle; refunds/revocations and interrupted delivery are not handled. Product ID/App Store Connect availability, agreements, review assets, sandbox/TestFlight, and production behavior are unverified. |
| CR-013 | P1 launch gate | Unverified runtime item | Asset catalog scan; `SOURCE_PACKAGE_NOTES.md:22-23,26-30` | 314 asset filenames are referenced by `Contents.json` and all binary files are deliberately absent; three MP3s and the Unity export are also absent. Visual correctness, memory footprint, compression, licensing, shader inclusion, app icon validity, and device-aspect behavior cannot be accepted from this package. |
| CR-014 | P2 | Verified source fact | `PartyAIPlanner.swift:175-184,293-352`; `Resources/party_ai_config.v1.json:1-61`; `IMPLEMENTATION_STATUS.md:15-16` | `party_ai_config.v1.json` is declared executable, but no runtime loader was found. Candidate limits and score weights are hard-coded, so JSON changes do not control behavior and contract drift will not fail tests. |
| CR-015 | P2 | Verified source fact | `FoolCombatConfiguration.swift:3-118`; `PartyAIPlanner.swift:150-163`; `FixedPointCombatMath.swift:48-100` | Decoding does not perform semantic validation of enums, ranges, uniqueness, cross-references, or safe numeric bounds. `Dictionary(uniqueKeysWithValues:)` can trap on duplicate unit IDs; malformed future data can crash or silently diverge. |
| CR-016 | P2 | Reasonable inference from source | `FixedPointCombatMath.swift:48-73,97-100` | Multiple unguarded `Int64` multiplications and doubled numerator arithmetic can overflow if corrupted or future-tuned inputs exceed current assumptions. The current content likely stays safe, but the boundary is undocumented and untested. |
| CR-017 | P2 | Verified source fact | `Mistport/GameStore.swift:103-140`; `ChapterOneTestView.swift:2377-2410`; no `scenePhase` references found | Active battle/session state is held in view state and is not checkpointed. No background/termination lifecycle hook was found. A 3–12 minute battle can be lost on process termination, memory pressure, or some navigation paths. |
| CR-018 | P2 | Verified source fact + unverified runtime item | `DungeonView.swift:84-88`; `DungeonScene.swift:794-810`; runtime texture creation/normalization symbols around `DungeonScene.swift:5161+` and `7108+`; `BattlePrototype.cs:39-72` | Both SpriteKit and Unity target 60 FPS and perform continuous updates; SpriteKit publishes state at 10 Hz and creates/normalizes textures at runtime. No performance tests, memory gates, thermal strategy, adaptive frame policy, or device traces are supplied. |
| CR-019 | P2 | Verified source fact + unverified runtime item | `DungeonView.swift:43,148,166-167,399-406,919-925`; `ChapterOneTestView.swift:572,718,929,1073,1370`; `ChapterOneOnboarding.swift:429-531`; no app UI tests | Accessibility work has begun, but several actionable controls are 26–36 points, large parts of SpriteKit are represented as a single container, fixed-size typography/layout is common, and system Reduce Motion is not proven across all custom SpriteKit/Unity animation. No automated accessibility audit or VoiceOver task matrix exists. |
| CR-020 | P2 | Verified source fact | No `.xcstrings`, `.strings`, or `.stringsdict` files found; `project.pbxproj:251-257`; hard-coded strings throughout app | The project declares English/Base/Simplified Chinese regions but ships no localization resources in the snapshot. Text is extensively hard-coded in Chinese with fixed widths and small absolute font sizes. Translation, pluralization, pseudolocalization, and expansion testing are not ready. |
| CR-021 | P2 | Verified source fact + unverified external item | No `PrivacyInfo.xcprivacy` or entitlements files found; `UnityConnectSettings.asset:7-40` | Unity analytics, ads, crash reporting, and services are disabled in source, which is positive. However, the final archive privacy manifest/required-reason report, App Privacy answers, network inspection, third-party SDK signatures, and privacy policy are not supplied. Compliance cannot be concluded from source alone. |
| CR-022 | P2 | Verified source fact | No Swift logger/analytics/crash SDK integration found; `HomeMusicController.swift:33-49`; `Storefront.swift:28-37,62-75` | User-facing failures are often collapsed to generic text or silently ignored. There is no structured event taxonomy, save-recovery diagnostic, crash reporting evidence, or on-device performance diagnostics. Launch regressions would be difficult to triage. |
| CR-023 | P2 | Verified source fact | `GameStore.swift:140`; venue generation around `GameStore.prepareVenue`; persistence keys omit visit counts | `venueVisitCounts` is in-memory only. Relaunch can reset visit cadence/pity behavior and permit offer rerolls. Even without paid power, this undermines predictable offline economy and test reproducibility. |
| CR-024 | P2 | Verified source fact | `IMPLEMENTATION_STATUS.md:70-75`; `project.pbxproj:302-337`; source metrics: `DungeonScene.swift` 7,340 lines, `ChapterOneTestView.swift` 2,692 lines | Explicitly obsolete v0.4 combat files remain compiled, the shipping bridge lives in a file named `ChapterOneTestView`, and large monolithic presentation/simulation files mix responsibilities. This raises accidental-use, review, and migration risk. |
| CR-025 | P2 | Verified source fact + unverified runtime item | `HomeMusicController.swift:12-49`; no scene lifecycle hooks | Audio failures are silently discarded, playback uses a `.playback` session with `mixWithOthers`, and there is no interruption/route/background handling in the included code. Actual behavior with calls, headphones, silent mode, backgrounding, and Unity audio is unverified. |
| CR-027 | P2 | Verified source fact | `GameViews.swift:986-1004`; `Storefront.swift:98-160` | Commerce copy says “20 项主任务,” while the economy policy asserts five districts × twenty missions = 100 free missions. This may be a wording distinction, but it is not explicit and can create review/customer expectation risk. |
| CR-028 | P3 | Verified source fact | `Mistport.xcscheme:54-59`; `GameStore.swift:150-177` | The shared Debug scheme always passes `--reset-tutorial`, clearing test-account progression on every normal scheme launch. This can mask persistence regressions and confound manual QA. |
| CR-029 | P3 | Verified source fact | `UnityBattleBridge.cs:83-96`; `UnityBattleHost.swift:37-44` | Bridge messages are hand-built JSON and parsed by substring matching, with no protocol version, command ID, strict decoder, escaping contract, ordering guarantee, or duplicate suppression. |
| CR-030 | P3 | Verified source fact | `MistportApp.swift:19-23`; `GameViews.swift:1071` | Dark appearance is forced globally and again in the store. This may match art direction, but there is no documented contrast audit or alternative appearance strategy; it should remain an explicit product decision, not an accidental default. |

## Detailed findings

### CR-001 — Executable Fool contract drift

- **Severity:** P1 launch-critical
- **Evidence:** Verified source fact.
- **Exact evidence:**
  - `mistport-ios/docs/game-design/IMPLEMENTATION_STATUS.md:15-16` declares `fool_combat_config.v1.1.json` an executable program contract, and `:22` declares a programmer-pack copy.
  - Canonical design contract: `mistport-ios/docs/game-design/fool_combat_config.v1.1.json`, SHA-256 `77514b1bb8ce7bd90a9039e4ee8cad42f9ff8945fc942811913d0a309fa02cca`.
  - Generated/runtime snapshot: `mistport-ios/MistportCombatCore/Sources/MistportCombatCore/Resources/fool_combat_config.v1.1.json`, SHA-256 `41d298316ad69305fee16b7680397b54240bc084269fbfc0211797ef4ef815b0`.
  - Additional live handoff snapshot: `mistport-ios/docs/game-design/programmer-pack/fool_combat_config.v1.1.json`; it must be inventoried and included in parity enforcement rather than left as an independently editable same-version copy.
  - Diff between the canonical design and bundled runtime copies includes `fool_skill_01.reuse_delay_actions` authority `0` versus runtime `1`, plus five display-name changes.
  - `CombatMathTests.swift:42-53` checks version/counts but not parity or the changed value.
- **Observed fact:** Multiple files carry the same contract name/version across canonical design, programmer handoff, and runtime-resource locations; at least the canonical design and bundled runtime bytes differ, and runtime loads its bundled copy.
- **Commercial impact:** Balance, cooldown UI, documentation, programmer handoff, QA vectors, support responses, and future migrations can disagree. A passing test suite can certify the wrong contract while a generated snapshot remains stale.
- **Minimum complete remediation:** Resolve values through the declared authority order; designate `docs/game-design/fool_combat_config.v1.1.json` as the canonical executable config unless the authority decision explicitly changes that policy; treat the programmer-pack and SwiftPM resource copies as generated snapshots; regenerate/copy them deterministically and fail tests/CI on byte or semantic mismatch; keep the corresponding programmer-pack specification and vector snapshots synchronized whenever the authority decision changes names, cooldown semantics, or expected vectors; add typed semantic validation.
- **Objective acceptance criteria:**
  1. Canonical design, programmer-pack, and bundled runtime contract hashes match.
  2. Canonical/programmer-pack copies of `FOOL_COMBAT_IMPLEMENTATION_SPEC_v1.2.md` and `fool_combat_test_vectors.v1.1.json` match whenever this decision changes their encoded names, cooldown rules, descriptions, or expected outputs.
  3. A test asserts all gameplay fields, not only version/count.
  4. Any duplicate ID, unsupported enum, invalid range, cross-reference failure, or schema mismatch returns a typed error.
  5. `swift test` or the repository parity check fails after intentionally changing any generated snapshot or the skill-1 cooldown.
- **Automated tests:** Three-copy contract parity; programmer-pack spec/vector snapshot parity; valid load; schema mismatch; duplicate skill/enemy IDs; negative/overflow-prone values; unsupported pipeline tokens; canonical cooldown/name assertions.
- **Manual tests:** Confirm skill name/cooldown in the app UI matches the accepted authority document for a fresh battle and restored battle; inspect the generated programmer pack before external handoff.
- **Dependencies/sequencing:** First engineering batch. Do not migrate more combat content until this is locked.

### CR-002 — Shipping combat uses multiple authorities

- **Severity:** P1 launch-critical
- **Evidence:** Verified source fact.
- **Exact evidence:** `ContentView.swift:133-155` uses `ChapterOneMissionBridgeView` only when path is Fool and district is `old-clock`; all other dungeon entries use `DungeonPrototypeView`. `DungeonScene.swift:14-42` owns combat state; `:813-856` applies basic-attack damage; `:1600-1625` owns cooldowns and action completion. `DungeonController.automaticScore` at `:98-132` also owns auto-play decisions.
- **Observed fact:** Launch routes can resolve combat outside `MistportCombatCore`.
- **Commercial impact:** Determinism tests do not cover all shipping battles. Balance fixes, save migration, AI behavior, replay, failure analysis, and Unity presentation can diverge by district/path.
- **Minimum complete remediation:** Define a single core session protocol for every launch encounter. Convert SpriteKit and Unity to event-driven presenters. Keep `DungeonScene` presentation helpers but remove or compile-gate authoritative HP, cooldown, turn, reward, and AI logic.
- **Objective acceptance criteria:**
  1. Every launch mission creates an authoritative core encounter/session.
  2. No shipping presenter mutates gameplay HP, cooldowns, resources, rewards, or victory state.
  3. The same input command log produces the same core event log with SpriteKit, Unity, animations skipped, and headless execution.
  4. Source/static gate rejects calls to gameplay mutation symbols from presentation targets.
- **Automated tests:** Route coverage for all launch mission IDs; deterministic replay hashes; presenter-contract tests; reward exactly-once tests; skip-animation equivalence.
- **Manual tests:** Fresh install through all required normal/elite/boss/defeat/retry paths; compare displayed result to core debug event trace.
- **Dependencies/sequencing:** After CR-001 and before broad content/visual expansion.

### CR-003 — Fatal mission bootstrap

- **Severity:** P1 launch-critical
- **Evidence:** Verified source fact.
- **Exact evidence:** `ChapterOneTestView.swift:2385-2408`, especially `try!` at line 2402.
- **Observed fact:** `MPCChapterOneEncounterSession.start` errors are converted into a process-terminating trap.
- **Commercial impact:** A stale save, malformed loadout, missing encounter, migration mistake, or content update can crash at the moment a user enters battle, with no recovery path.
- **Minimum complete remediation:** Store a `Result`/load state in the bridge; show a recoverable error with safe return and diagnostic code; validate content and save-derived loadout before constructing the view.
- **Objective acceptance criteria:** Every authored launch mission starts successfully; every declared start error produces an error screen, never a crash; user can return to the map; no reward/progress is consumed.
- **Automated tests:** Start every mission with canonical campaign states; missing encounter; invalid companion; invalid/locked skill; duplicate IDs; corrupted restored loadout.
- **Manual tests:** Launch a deliberately invalid debug fixture and verify readable recovery and unchanged save.
- **Dependencies/sequencing:** Can follow CR-001 in the same stabilization milestone; no asset dependency.

### CR-004 — Save data has no migration or atomic recovery boundary

- **Severity:** P1 launch-critical
- **Evidence:** Verified source fact.
- **Exact evidence:** Persistence keys in `GameStore.swift:83-101`; independent restore at `:142-212`; independent writes at `:1011-1032`; decode failure silently returns at `:315-323`.
- **Observed fact:** There is no single versioned save envelope, transaction, backup, migration registry, checksum, or explicit quarantine/default decision.
- **Commercial impact:** Updates can strand or partially reset paying players, duplicate rewards, bypass progression, or make support unable to diagnose a save. `UserDefaults` writes are not a substitute for a coherent save transaction.
- **Minimum complete remediation:** Introduce a versioned `Codable` save envelope with validation, atomic file replacement, previous-good backup, explicit migrations, idempotent reward/progression state, and a documented recovery policy. Migrate existing keys once and retain rollback read support for one release.
- **Objective acceptance criteria:**
  1. Fresh, prior-version, partially missing, malformed, and future-version saves have deterministic outcomes.
  2. A simulated interrupted write restores the previous-good save.
  3. Invalid content IDs are repaired or quarantined with a user-visible recovery message.
  4. Mission rewards and IAP entitlements remain exactly once across relaunch.
- **Automated tests:** Migration fixtures for every schema; corruption/fuzz fixtures; interrupted-write simulation; idempotence; downgrade/future-version rejection; reset isolation.
- **Manual tests:** Install old build, create progress, upgrade; force-quit during save; low-storage simulation; relaunch after crash; verify continuity.
- **Dependencies/sequencing:** Before cloud save, analytics-driven progression changes, or paid expansion gating.

### CR-005 — New game inherits old campaign evidence

- **Severity:** P1 launch-critical data-integrity defect
- **Evidence:** Verified source fact.
- **Exact evidence:** Evidence restoration at `GameStore.swift:315-323`; `restart()` removals at `:994-1008` omit behavior tags and combo records; Debug reset at `:170-171` removes both.
- **Observed fact:** Production restart and Debug reset have different data-clearing semantics.
- **Commercial impact:** Tutorials, conclusions, achievements, or progression checks can be satisfied by a previous playthrough after the user selected a full restart.
- **Minimum complete remediation:** Centralize reset by save schema/domain and clear all campaign-owned fields atomically; define whether account-level unlocks survive separately.
- **Objective acceptance criteria:** After restart, a serialized save equals the documented new-game fixture except explicitly retained account entitlements/settings.
- **Automated tests:** Populate every persistence field, restart, compare to canonical initial state; repeat restart for idempotence.
- **Manual tests:** Complete a combo/behavior milestone, restart, confirm no inherited evidence.
- **Dependencies/sequencing:** Include in save-system phase; safe small hotfix after regression test exists.

### CR-006 — Advancement ritual can be bypassed

- **Severity:** P1 launch-critical product/progression defect
- **Evidence:** Verified source fact.
- **Exact evidence:** `GameStore.performAdvancement()` validates mission, ingredients, and sequence at `:737-753`; `completeDungeon()` directly sets sequence 8 at `:781-783`. Authority flow is `GAME_BLUEPRINT.md:170-174` and `PROGRESSION_SYSTEM.md:87`.
- **Observed fact:** Boss completion grants the final rank before the explicit ritual function and its requirements.
- **Commercial impact:** The central first-chapter payoff and progression explanation become inconsistent; saves may record sequence 8 without materials/ritual completion; future content gates become ambiguous.
- **Minimum complete remediation:** Represent advancement as an explicit state machine (eligible → ritual started → ritual completed → rank applied). Boss completion grants eligibility/evidence only.
- **Objective acceptance criteria:** Sequence remains 9 after boss clear; advancement fails until all requirements are met; successful ritual applies sequence 8 once; relaunch at every intermediate state is stable.
- **Automated tests:** Requirement matrix; repeated boss clear; repeated ritual; migration of existing prematurely advanced saves; reward exactly once.
- **Manual tests:** Complete chapter with and without all materials and verify messaging/navigation.
- **Dependencies/sequencing:** After save schema is specified; before progression copy and store claims are finalized.

### CR-007 — Unity retains an authoritative-like combat prototype

- **Severity:** P1 launch-critical architecture risk
- **Evidence:** Verified source fact.
- **Exact evidence:** Presentation-only claim in `UnityBattleBridge.cs:5-7`; HP state at `BattlePrototype.cs:25-28`; standalone resolution at `:388-457`; damage/HUD at `:1000-1015`; README advertises automatic attacks at `UnityBattleSource/README.md:3-5`.
- **Observed fact:** The same runtime component supports both presentation commands and a local rules simulation.
- **Commercial impact:** It is easy for editor, native, or future code to invoke the wrong entry points and display a result different from the core. It also expands QA surface and obscures ownership.
- **Minimum complete remediation:** Split editor/demo prototype into a non-shipping assembly/scene or delete it; production presenter accepts immutable core events only and has no gameplay HP/reward/win state.
- **Objective acceptance criteria:** Production Unity assemblies contain no damage, HP, cooldown, AI, reward, or win/loss calculation; all visible values arrive from the native/core event stream; editor demo is excluded from iOS builds.
- **Automated tests:** Assembly-definition/build inclusion test; event-to-animation mapping; no forbidden production symbols; event replay visual-state snapshot.
- **Manual tests:** Compare a headless event log and Unity display through win, defeat, defend, skip, and interruption.
- **Dependencies/sequencing:** After the core presenter protocol is defined; before adding more 3D combatants.

### CR-008 — Unity bridge readiness, acknowledgement, and lifecycle are incomplete

- **Severity:** P1 launch-critical
- **Evidence:** Verified source fact plus runtime inference.
- **Exact evidence:**
  - `UnityBattleSource/Assets/Plugins/iOS/MistportUnityBridge.mm` implements the native `MistportUnityBattleEvent(const char *)` callback and posts `Notification.Name("MistportUnityBattleEvent")`.
  - `Mistport/UnityBattleHost.swift:9-109` contains no `NotificationCenter` observer for that name, no callback payload decoder, no received-event state, and no pending-command/acknowledgement state.
  - `UnityBattleHost.swift:37-45` silently drops pre-ready commands; `:53-75` sets `isReady = true` immediately after `runEmbedded` rather than from a Unity readiness event; `:31-35,105-109` detaches the view and handles unload notification but defines no pause/unload/background policy or failure fallback.
  - `UnityBattleBridge.cs:73-100` declares/sends Unity-side events, but the supplied Swift host does not consume them.
- **Observed fact:** The native callback implementation is present, but the event path terminates at the iOS notification bus: Swift does not subscribe, decode, correlate command IDs, update acknowledgement/completion/error state, or derive readiness from the callback. The host therefore cannot prove a command was accepted or presented, cannot queue before actual Unity readiness, and does not manage Unity through screen/background lifecycle.
- **Commercial impact:** First actions can disappear, animation ordering can drift, failure can remain invisible, the app can retain large Unity memory after battle, and background/foreground transitions can produce black/frozen surfaces.
- **Minimum complete remediation:** Keep and link the existing plugin callback; register/remove a Swift observer at a defined runtime lifetime; decode a versioned event envelope on the main actor; track command IDs and accepted/completed/error states; derive readiness from an explicit Unity event; add ordered queue, timeout, idempotency, scene-phase pause/resume, explicit unload policy, and SpriteKit/static fallback.
- **Objective acceptance criteria:**
  1. The existing native callback symbol is linked and a posted `MistportUnityBattleEvent` notification reaches exactly one live Swift consumer.
  2. Every command receives accepted/completed/error for the same ID and updates deterministic Swift acknowledgement state.
  3. Pre-ready commands queue in order and flush only after the explicit readiness event.
  4. Unknown/malformed/duplicate/stale events are rejected deterministically without mutating combat state.
  5. Twenty enter/exit cycles show no unbounded memory growth.
  6. Background/foreground during load and animation recovers without changing core state.
- **Automated tests:** Native plugin callback/link-symbol check; notification-to-Swift-consumer delivery; event decode and command correlation; queue/order; timeout; duplicate/stale event handling; readiness state machine; observer lifetime; unload/reload state machine.
- **Manual tests:** Rapid navigation, force background, incoming interruption, memory warning, low-power mode, Unity load failure, callback timeout, device rotation attempt, oldest supported device.
- **Dependencies/sequencing:** Swift event consumption/acknowledgement boundary first; then lifecycle; then visual expansion.

### CR-009 — 3D enemy pipeline specification is not implemented

- **Severity:** P1 launch-critical for any Unity-backed release
- **Evidence:** Verified source fact.
- **Exact evidence:** Required profile/presenter/test workflow in `ENEMY_3D_PIPELINE.md:31-47,257-317,321-357`; hard-coded object names/transforms at `BattlePrototype.cs:182-213,289-330`; pose capture at `ClockCoreIdle.cs:12-19` reproduces a documented root cause.
- **Observed fact:** The “current production specification” describes future work, not the supplied implementation.
- **Commercial impact:** Every new enemy can require code edits and repeated exports; preview can differ from device; anchor/selection/shield regressions are likely; asset throughput is not commercially scalable.
- **Minimum complete remediation:** Implement `EnemyVisualProfile`, standardized prefab roots/anchors, `EnemyPresenter`/`EnemySpawner`, calibration window, import validator, EditMode/PlayMode tests, and screenshot baselines; migrate Clock Guard/Core and remove special transforms.
- **Objective acceptance criteria:** Meet every Definition of Done item at `ENEMY_3D_PIPELINE.md:303-315`; no enemy-specific transform branch in production controller; narrow/wide iPhone screenshots approved.
- **Automated tests:** Profile uniqueness/reference validation; anchor validation; idle drift; return-to-slot; shield/target mapping; screenshot regression.
- **Manual tests:** Unity portrait previews plus physical-device visual/touch validation for every shipping enemy.
- **Dependencies/sequencing:** Do not add additional 3D enemies before phase-one migration is complete.

### CR-010 — Release identity and archive reproducibility are not established

- **Severity:** P1 launch-critical
- **Evidence:** Verified source fact plus external verification required.
- **Exact evidence:** Target settings at `project.pbxproj:444-500`; placeholder bundle ID at `:463,491`; Unity/audio/resources at `:113-118,277-287`; generated export deliberately omitted per `SOURCE_PACKAGE_NOTES.md:22-23`.
- **Observed fact:** The reduced package cannot assemble the Xcode project; release identity/versioning are placeholder-level.
- **Commercial impact:** No reviewer can reproduce the archive, verify embedded frameworks/data, inspect privacy/signature reports, or symbolicate crashes. Product IDs and bundle identity may not align.
- **Minimum complete remediation:** Define canonical release identifiers/configuration; pin toolchain/Unity versions; script deterministic Unity export and asset assembly; produce unsigned Release archive in CI; preserve dSYMs/map files; inventory licenses and asset provenance.
- **Objective acceptance criteria:** Clean machine builds an unsigned Release archive from documented inputs; second build produces an explained reproducibility report; archive validates with current Apple tooling; no placeholder IDs; correct Unity Data/framework embedding; symbols retained.
- **Automated tests:** Clean checkout/package build; missing-asset fail-fast; Unity export checksum; archive inspection; duplicate symbols; privacy report; app-icon validation.
- **Manual tests:** Signed TestFlight installation and launch using production-like configuration.
- **Dependencies/sequencing:** Artifact inventory can begin immediately; final archive gate follows source stabilization.

### CR-011 — No app-level automated gate; visual acceptance incomplete

- **Severity:** P1 launch-critical
- **Evidence:** Verified source fact.
- **Exact evidence:** One PBX native target at `project.pbxproj:211-234`; empty/autocreated TestAction at scheme `:26-32`; explicit incomplete simulator acceptance at `IMPLEMENTATION_STATUS.md:58-68`.
- **Observed fact:** Swift package tests do not exercise SwiftUI routing, `GameStore`, persistence, SpriteKit, Unity host, StoreKit UI, or accessibility.
- **Commercial impact:** Compilation plus core tests can pass while launch flow, save migration, purchase UI, controls, layouts, and device integration fail.
- **Minimum complete remediation:** Add app unit and UI test targets; deterministic launch fixtures; screenshot/performance/accessibility tests; CI gates and a manual acceptance matrix.
- **Objective acceptance criteria:** Required smoke suite passes from fresh/migrated/corrupt saves; UI accessibility audit has no high-severity failures; all release gates in the roadmap are green on a Release configuration.
- **Automated tests:** App launch/navigation; every combat route; save migration/recovery; retry; StoreKit configuration; Unity unavailable fallback; localization/pseudolocalization; accessibility audit; performance baselines.
- **Manual tests:** Device/OS/aspect/accessibility/network/thermal matrix in this audit.
- **Dependencies/sequencing:** Test harness should be added before large migration work so it protects each phase.

### CR-012 — StoreKit path is incomplete and externally unverified

- **Severity:** P1 launch-critical if the store is visible in the release
- **Evidence:** Verified source fact plus App Store Connect/sandbox required.
- **Exact evidence:** Product ID and flow at `Storefront.swift:20-95`; store UI and localized price at `GameViews.swift:939-1085`.
- **Observed fact:** Purchase verification and restore are present, but there is no continuous transaction listener or explicit revocation/refund/pending state model.
- **Commercial impact:** Purchases completed outside the immediate call path can remain undelivered until relaunch/refresh; revoked content can remain unlocked; reviewers can encounter unavailable products with weak diagnostics.
- **Minimum complete remediation:** Add app-lifetime `Transaction.updates` handling; model pending/cancelled/revoked/refunded states; make entitlement application idempotent; add StoreKit configuration tests; verify App Store Connect product, agreements, availability, screenshot, review notes, and TestFlight.
- **Objective acceptance criteria:** Purchase, cancel, pending approval, interrupted completion, restore, reinstall, new device, refund/revoke, offline launch, and unavailable-store cases produce correct entitlement/UI with no duplicate grant.
- **Automated tests:** StoreKit Test session matrix; idempotency; transaction update during app run; product unavailable; verified/unverified transaction; revoked entitlement.
- **Manual tests:** Sandbox and TestFlight on physical device; App Review account/notes; storefront/currency variation.
- **Dependencies/sequencing:** Save/entitlement separation first; production ASC checks late in release phase.

### CR-013 — Binary assets and visual acceptance are not reviewable

- **Severity:** P1 launch gate, not a claim that the omitted production assets are defective
- **Evidence:** Unverified runtime item.
- **Exact evidence:** Static scan found 314 filenames referenced in asset catalogs and zero included binary files; package notes explicitly exclude binary art/audio/models/Unity export and state simulator/device acceptance is not claimed.
- **Observed fact:** Source contains metadata and code only.
- **Commercial impact:** The largest contributors to app size, memory, loading, frame pacing, visual correctness, licensing, and App Store presentation cannot be audited.
- **Minimum complete remediation:** Provide a controlled review build or asset manifest with dimensions, formats, sizes, licenses, compression/import settings, and generated Unity export; run visual/performance/device gates.
- **Objective acceptance criteria:** No missing asset at build/runtime; all asset references resolve; app icon passes validation; no unintended 1x-only blur on supported devices; memory/app-size budgets pass; provenance documented.
- **Automated tests:** Asset reference checker; duplicate/oversized texture report; atlas/frame dimensions; audio decode; shader inclusion; app-size report; screenshot baselines.
- **Manual tests:** Narrow/wide devices, display zoom, Reduce Motion, VoiceOver, light/dark decision, low-memory device, 30-minute play.
- **Dependencies/sequencing:** Required before visual/performance verdict; do not confuse missing review evidence with a source-code defect.

### CR-014 — Party AI JSON is not executable at runtime

- **Severity:** P2 important
- **Evidence:** Verified source fact.
- **Exact evidence:** `party_ai_config.v1.json:1-61` defines budgets/weights/rules; `PartyAIPlanner.swift:175-184,293-352` hard-codes limits and weights; search found no loader.
- **Observed fact:** The file declared executable is currently documentary/test collateral.
- **Commercial impact:** Designers can change a signed-off JSON without changing gameplay; tests can pass against hard-coded values; balance provenance is weak.
- **Minimum complete remediation:** Decode a typed validated configuration and inject it into planner/scoring; freeze schema/version; assert parity with authority copy.
- **Objective acceptance criteria:** Changing any supported weight in a test fixture changes the selected plan predictably; unsupported/missing fields fail validation; authority/runtime copies match.
- **Automated tests:** Full JSON decode; every weight/rule mapping; deterministic vectors using loaded config; invalid fixtures; budget edge cases.
- **Manual tests:** AI explanation UI shows reasons consistent with loaded weights/tactics.
- **Dependencies/sequencing:** After CR-001 pattern is established; before AI tuning.

### CR-015 — Configuration/content validation is incomplete and some invalid input traps

- **Severity:** P2 important
- **Evidence:** Verified source fact.
- **Exact evidence:** Stringly typed fields and decode-only loader in `FoolCombatConfiguration.swift:3-118`; duplicate unit dictionary at `PartyAIPlanner.swift:150-163`; content precondition at `ChapterModels.swift:375-395`.
- **Observed fact:** Syntax-valid JSON/content is not necessarily semantically valid or safely recoverable.
- **Commercial impact:** Content updates can crash or create hidden balance errors. External/save-derived IDs can enter invalid states.
- **Minimum complete remediation:** Central validation report with typed errors, safe bounded numerics, uniqueness/cross-reference checks, release preflight, and user-safe runtime handling.
- **Objective acceptance criteria:** All authored content validates before app launch/archive; no external/content error reaches `precondition`, `fatalError`, `try!`, or duplicate-key trap in Release.
- **Automated tests:** Mutation/fuzz testing of configs; duplicate IDs; missing references; empty party; out-of-range values; exactly-once validation at startup.
- **Manual tests:** Debug content-error screen and release fail-fast build tooling.
- **Dependencies/sequencing:** Contract phase, before migration/content expansion.

### CR-016 — Fixed-point arithmetic lacks explicit overflow bounds

- **Severity:** P2 important
- **Evidence:** Reasonable inference.
- **Exact evidence:** `FixedPointCombatMath.swift:66-73` multiplies four `Int64` values; `:97-100` doubles numerator without checked arithmetic.
- **Observed fact:** Current canonical values appear modest, but the safe input domain is neither encoded nor tested.
- **Commercial impact:** A corrupted save/config or future balance scale can produce a runtime trap rather than a validation error.
- **Minimum complete remediation:** Define maximum input domain; validate before calculation; use reporting-overflow operations or a staged formula preserving required rounding.
- **Objective acceptance criteria:** All boundary values return a result/error without trapping; canonical vectors remain bit-identical.
- **Automated tests:** Maximum/minimum valid inputs; just-over-bound inputs; randomized property tests; no overflow under declared domain.
- **Manual tests:** Not required beyond verifying diagnostics in a debug fixture.
- **Dependencies/sequencing:** Same contract-safety phase; preserve deterministic rounding.

### CR-017 — No active-battle continuity policy

- **Severity:** P2 important
- **Evidence:** Verified source fact.
- **Exact evidence:** `ChapterOneMissionBridgeView` holds campaign/session in `@State` at `ChapterOneTestView.swift:2377-2410`; no `scenePhase`/background checkpoint code was found.
- **Observed fact:** Mid-encounter state is ephemeral.
- **Commercial impact:** Calls, OS termination, memory pressure, or navigation can discard up to a boss fight’s progress. Players cannot know whether quit means resume, retry, or abandon.
- **Minimum complete remediation:** Choose and implement a documented policy: deterministic turn-boundary checkpoint/resume, or explicit abandon confirmation with safe restart. Serialize authoritative core state, never animation state.
- **Objective acceptance criteria:** Background/terminate/relaunch at every action boundary resumes or restarts exactly as documented, with no duplicated consumable/reward and no presenter dependence.
- **Automated tests:** Session encode/decode/replay; checkpoint after each event type; corrupted checkpoint fallback; exactly-once consumption/reward.
- **Manual tests:** Force-quit during normal, AI, enemy, boss phase change, reward, and conclusion screens.
- **Dependencies/sequencing:** Save envelope first; then app lifecycle.

### CR-018 — Performance, memory, frame pacing, and thermal behavior are unmeasured

- **Severity:** P2 important
- **Evidence:** Verified source hotspots; runtime outcome unverified.
- **Exact evidence:** 60 FPS SpriteView at `DungeonView.swift:84-88`; per-frame work and 10 Hz state publication at `DungeonScene.swift:794-810`; Unity 60 FPS and continuous material updates at `BattlePrototype.cs:39-72`; runtime image/texture processing occurs in the large SpriteKit scene.
- **Observed fact:** No test target, trace, budget, memory-warning strategy, thermal adaptation, prewarm policy, or long-session evidence is included.
- **Commercial impact:** Jank, thermal throttling, audio/animation desync, and jetsam may appear only on older devices or after repeated Unity transitions.
- **Minimum complete remediation:** Instrument cold start, combat, Unity load/unload, texture decode, memory, hitches, and energy; move expensive image work out of action paths; cache with explicit lifetime; define adaptive quality/frame policy.
- **Objective acceptance criteria (proposed release gate):**
  - 60 FPS target: p95 frame time ≤16.7 ms in representative combat and no sustained >33.3 ms frame-time band;
  - hitch ratio ≤1% in scripted 10-minute combat;
  - no memory growth >10% after 20 enter/exit cycles after returning to steady state;
  - no jetsam, thermal `.serious`/`.critical` sustained during 30-minute acceptance run;
  - core outcomes identical at 60/30 FPS and with animations skipped.
- **Automated tests:** XCTest launch/hitch/memory metrics; Unity load/unload loop; texture decode budget; headless simulation performance; event backlog tests.
- **Manual tests:** Instruments on oldest/current supported phones, Low Power Mode, warm device, background/foreground, long boss loop.
- **Dependencies/sequencing:** Architecture/lifecycle stabilization before final optimization; establish baselines early.

### CR-019 — Accessibility is partial, not release-gated

- **Severity:** P2 important
- **Evidence:** Verified source fact plus device testing required.
- **Exact evidence:** Positive labels and Reduce Motion use in `DungeonView.swift` and `ChapterOneTestView.swift`; 26-point close control at `DungeonView.swift:919-925`; 34–36 point exit controls at `DungeonView.swift:399-406` and `MissionBoardView.swift:285-291`; fixed layout/typography at `ChapterOneOnboarding.swift:429-531`.
- **Observed fact:** Some semantics exist, but the end-to-end game cannot be shown operable with VoiceOver, Larger Text, Voice Control, Switch Control, reduced motion, sufficient contrast, and non-color cues.
- **Commercial impact:** Players can be blocked from combat/navigation; App Store accessibility claims would be unsupported; fixed layouts can clip translated or larger text.
- **Minimum complete remediation:** Accessibility architecture for battle entities/actions/status; 44×44 point effective targets; Dynamic Type styles; Reduce Motion propagated to SpriteKit/Unity; contrast/non-color validation; accessibility UI tests.
- **Objective acceptance criteria:** Core journey is completable with VoiceOver; automated accessibility audit has no high-severity issues; all primary controls have ≥44×44 effective hit area; text remains usable through an agreed accessibility size; motion setting disables/replaces nonessential motion in both presenters.
- **Automated tests:** `performAccessibilityAudit`; identifiers and focus order; large-content screenshots; target-size static check; reduced-motion launch fixture.
- **Manual tests:** VoiceOver, Voice Control, Switch Control, Larger Text, Bold Text, Increase Contrast, Reduce Transparency, Reduce Motion, color filters.
- **Dependencies/sequencing:** Begin with test harness and shared design tokens; finalize after localization and visual assets.

### CR-020 — Localization and text-layout readiness are absent

- **Severity:** P2 important
- **Evidence:** Verified source fact.
- **Exact evidence:** Project declares `en`, `Base`, `zh-Hans` at `project.pbxproj:251-257`, but no localization files exist in the snapshot; hard-coded Chinese appears throughout UI/core-facing source; onboarding uses fixed 326-point bubble and 10–15 point text.
- **Observed fact:** There is no extractable localization catalog or locale test strategy.
- **Commercial impact:** English region declaration is misleading, translations require source edits, text can truncate, and StoreKit/error/accessibility text can be inconsistent.
- **Minimum complete remediation:** Create a string catalog with stable keys/comments; localize gameplay and accessibility strings; format numbers/plurals; isolate proper nouns; add pseudolocalization and expansion tests; decide launch locales explicitly.
- **Objective acceptance criteria:** Zero shipping user-visible string literals outside approved exceptions; pseudolocalized UI completes core journey without clipping/overlap; 30–40% expansion and largest supported text size pass.
- **Automated tests:** Missing-key/unused-key check; pseudolocale screenshots; plural/format tests; accessibility-label localization.
- **Manual tests:** Every launch locale on narrow/wide devices; StoreKit price/currency; CJK and Latin line breaks.
- **Dependencies/sequencing:** Shared UI layout/accessibility work; before App Store metadata/screenshots.

### CR-021 — Privacy and App Store compliance evidence is incomplete

- **Severity:** P2 important; may become P1 when archive contents are known
- **Evidence:** Verified source facts plus external/archive verification required.
- **Exact evidence:** No `PrivacyInfo.xcprivacy` or entitlements file found. Unity services are disabled in `UnityConnectSettings.asset:7-40`. No obvious Swift networking/analytics code was found.
- **Observed fact:** Source appears offline-first, but the final Unity framework and Apple archive reports are absent.
- **Commercial impact:** Required-reason APIs or SDK declarations can block submission; App Privacy answers can be inaccurate; privacy policy/review metadata can diverge from binary behavior.
- **Minimum complete remediation:** Generate final archive privacy report; inspect native/Unity binaries and network behavior; add a truthful manifest if required; document data inventory/retention; align App Privacy and privacy policy; verify SDK signatures.
- **Objective acceptance criteria:** Archive validation has no privacy-manifest/signature errors; packet capture shows only documented endpoints; App Privacy answers match code and services; no secret/user data in logs.
- **Automated tests:** Privacy manifest lint; dependency/SBOM scan; forbidden endpoint/secret scan; archive report check.
- **Manual tests:** App Store Connect privacy/review checklist; offline/no-network use; inspect support/crash payloads once selected.
- **Dependencies/sequencing:** Final archive available; before TestFlight external beta/submission.

### CR-022 — Observability is insufficient for a commercial launch

- **Severity:** P2 important
- **Evidence:** Verified source fact.
- **Exact evidence:** Store/audio errors are generalized or silently ignored; no structured logger, crash reporter, MetricKit/MetricManager integration, save diagnostic ID, or analytics event schema was found.
- **Observed fact:** Production failures cannot be correlated to version, save schema, encounter, device, or Unity state from supplied code.
- **Commercial impact:** Crashes, purchase failures, save recovery, and performance regressions will be expensive to diagnose and may require user reproduction.
- **Minimum complete remediation:** Privacy-minimal structured logging, crash diagnostics, on-device performance reports, build/version/save-schema tags, and opt-in/declared analytics only where justified.
- **Objective acceptance criteria:** A synthetic crash and save-recovery event are symbolicated and searchable by build; no personal/content data is logged; performance reports identify hitches/memory; offline play remains functional.
- **Automated tests:** Log redaction; diagnostic payload schema; symbol upload verification; crash test in non-production environment.
- **Manual tests:** Dashboard/runbook drill after TestFlight crash and StoreKit failure.
- **Dependencies/sequencing:** Privacy decision first; do not add analytics merely to compensate for missing deterministic tests.

### CR-023 — Venue offer cadence is not persisted

- **Severity:** P2 important
- **Evidence:** Verified source fact.
- **Exact evidence:** `venueVisitCounts` is memory-only at `GameStore.swift:140` and has no persistence key/write.
- **Observed fact:** Relaunch resets offer visit history.
- **Commercial impact:** Players can reroll, pity cadence is inconsistent, QA cannot reproduce offers, and future commerce/economy changes may become exploitable.
- **Minimum complete remediation:** Define deterministic offer seed/history semantics and persist relevant state in the versioned save; keep it independent of paid power.
- **Objective acceptance criteria:** Relaunch preserves next-offer outcome; clock changes/reinstall behavior are documented; no duplicate purchase/reward.
- **Automated tests:** Deterministic seed; relaunch; corrupted count; max bounds; repeated visit distribution.
- **Manual tests:** Visit/relaunch cycle and device-time changes.
- **Dependencies/sequencing:** Save phase; before economy tuning.

### CR-024 — Legacy prototypes and monoliths remain in the shipping target

- **Severity:** P2 important
- **Evidence:** Verified source fact.
- **Exact evidence:** Legacy status at `IMPLEMENTATION_STATUS.md:70-75`; active source membership at `project.pbxproj:302-337`; `DungeonScene.swift` has 7,340 lines and `ChapterOneTestView.swift` 2,692 lines.
- **Observed fact:** Explicitly obsolete rules compile beside current code and some current shipping UI is embedded in “Test/Prototype” files.
- **Commercial impact:** Accidental invocation and conflicting fixes are likely; ownership and review are difficult; test seams are weak.
- **Minimum complete remediation:** Freeze/remove old engine from Release target; split shipping adapters/presenters from debug harness; separate scene rendering, asset loading, animation, and state publication; use feature compilation for debug tools.
- **Objective acceptance criteria:** No v0.4 engine in Release binary/source phase; debug harness unavailable in Release; modules have one ownership purpose; route tests prove no legacy entry.
- **Automated tests:** Release symbol scan; build-setting test; forbidden-import/symbol check; source-size/lint thresholds as advisory.
- **Manual tests:** Verify debug menus/preview launch arguments cannot appear in Release.
- **Dependencies/sequencing:** After parity tests protect behavior; remove incrementally.

### CR-025 — Audio lifecycle and failure handling are unverified

- **Severity:** P2 important
- **Evidence:** Verified source fact plus device behavior required.
- **Exact evidence:** `HomeMusicController.swift:12-49` starts/stops based only on game phase, sets `.playback` with `.mixWithOthers`, and suppresses all errors.
- **Observed fact:** No interruption, route-change, scene/background, media-services-reset, or Unity-audio coordination code is included.
- **Commercial impact:** Audio may continue or fail unexpectedly, conflict with other audio, or not recover after calls/headphone changes; failures are invisible.
- **Minimum complete remediation:** Product audio policy; interruption/route/background handling; unified native/Unity mixer ownership; user volume controls; structured non-sensitive diagnostics.
- **Objective acceptance criteria:** Correct behavior for silent switch policy, backgrounding, phone interruption, headphones/Bluetooth, other audio, and Unity transition; no duplicate music.
- **Automated tests:** Controller state-machine unit tests using protocolized audio session/player.
- **Manual tests:** Physical-device audio matrix.
- **Dependencies/sequencing:** Unity lifecycle decision and final audio assets.

### CR-027 — Free-campaign commerce copy is ambiguous

- **Severity:** P2 important
- **Evidence:** Verified source fact.
- **Exact evidence:** `GameViews.swift:986-1004` says “20 项主任务”; `GameEconomyPolicy` at `Storefront.swift:102-107` asserts five districts × twenty missions = 100 free missions.
- **Observed fact:** The store page can be read as promising only 20 missions while the code enforces 100 stages.
- **Commercial impact:** Customer expectation, review notes, screenshots, and support language can conflict even if both phrases were intended to mean different content units.
- **Minimum complete remediation:** Establish a canonical content taxonomy and use it consistently across UI, metadata, design docs, and review notes.
- **Objective acceptance criteria:** Every surface states the same free scope or clearly distinguishes “20 main quests” from “100 stages,” with content inventory evidence.
- **Automated tests:** Copy snapshot/approved terminology lint where practical.
- **Manual tests:** Product/legal/localization review.
- **Dependencies/sequencing:** After final launch scope is locked; before App Store metadata.

### CR-028 — Shared scheme resets progression on every Debug launch

- **Severity:** P3 polish/tooling
- **Evidence:** Verified source fact.
- **Exact evidence:** `Mistport.xcscheme:54-59`; reset behavior `GameStore.swift:150-177`.
- **Observed fact:** Normal scheme launches do not exercise realistic persistent-state continuity.
- **Commercial impact:** Developers can miss migration/relaunch defects and misinterpret disappearing progress.
- **Minimum complete remediation:** Disable by default; create named reset test plan/scheme or explicit launch configuration.
- **Objective acceptance criteria:** Default Debug launch preserves state; reset fixture remains one-click and isolated.
- **Automated tests:** Scheme/static check.
- **Manual tests:** Relaunch default and reset configurations.
- **Dependencies/sequencing:** Immediate low-risk tooling fix after persistence test fixture exists.

### CR-029 — Unity protocol parsing is permissive and unversioned

- **Severity:** P3 polish now; can become P1 as command surface grows
- **Evidence:** Verified source fact.
- **Exact evidence:** Manual JSON construction at `UnityBattleHost.swift:37-44`; substring parser at `UnityBattleBridge.cs:83-96`.
- **Observed fact:** Strings containing known substrings can be accepted as commands; payload cannot evolve safely.
- **Commercial impact:** Hard-to-reproduce command collisions, escaping errors, and incompatible native/Unity builds.
- **Minimum complete remediation:** Codable/serializable versioned envelope, strict enum decoder, command IDs, compatibility negotiation, validation, and clear unknown-version response.
- **Objective acceptance criteria:** Malformed/unknown payloads never trigger actions; compatible versions round-trip; incompatible versions fail to fallback.
- **Automated tests:** Cross-language golden vectors, malformed corpus, escaping, duplicate/order tests.
- **Manual tests:** Mismatched native/Unity debug builds show clear fallback.
- **Dependencies/sequencing:** Part of CR-008.

### CR-030 — Appearance policy is implicit

- **Severity:** P3 polish
- **Evidence:** Verified source fact.
- **Exact evidence:** Forced dark scheme at `MistportApp.swift:19-23` and `GameViews.swift:1071`.
- **Observed fact:** Art direction is enforced in code without a documented accessibility/contrast acceptance decision.
- **Commercial impact:** Not inherently wrong, but contrast and system-setting expectations can be overlooked.
- **Minimum complete remediation:** Document dark-only decision; test contrast, Smart Invert, Increase Contrast, Reduce Transparency, and screenshots; avoid relying on color alone.
- **Objective acceptance criteria:** Approved contrast/non-color matrix and App Store accessibility claims match tested behavior.
- **Automated tests:** Screenshot/contrast lint where feasible.
- **Manual tests:** Accessibility display settings on representative devices.
- **Dependencies/sequencing:** Accessibility/visual phase.

## Launch blockers

A release candidate should not be declared until all of the following are closed with evidence:

1. **One combat authority:** CR-001, CR-002, CR-007, CR-014, CR-015.
2. **No fatal content/save entry path:** CR-003, CR-004, CR-005, CR-006.
3. **Unity is an optional, recoverable presenter:** CR-008 and CR-009.
4. **Reproducible Release archive:** CR-010 and CR-013.
5. **App-level release gates:** CR-011, including E2E, accessibility, localization, performance, and visual matrices.
6. **Validated commercial path:** CR-012 and CR-027, with App Store Connect/TestFlight evidence.
7. **Archive privacy/compliance evidence:** CR-021 and selected observability under CR-022.

## Positive evidence worth preserving

- Authority ordering and forbidden product boundaries are unusually explicit.
- `MistportCombatCore` is isolated as a Swift package with no external package dependencies.
- The supplied baseline reports 100 passing tests in 10 suites.
- Core code includes deterministic tie-breaking and fixed-point math.
- Runtime and authority copies of `party_ai_config.v1.json` and both test-vector files are byte-identical in this snapshot.
- StoreKit uses verified transactions and exposes restore UI.
- Unity services/ads/analytics/cloud diagnostics are disabled in `UnityConnectSettings.asset`.
- Several SwiftUI screens already contain accessibility labels/identifiers and some Reduce Motion support.
- The 3D production document contains a concrete target architecture and Definition of Done; the risk is implementation gap, not missing direction.

## Risks that remain unverified

The following cannot be concluded from the reduced package and must remain open:

- signed Archive/TestFlight/App Store installation;
- production bundle ID, team, provisioning, entitlements, export compliance, dSYMs, symbols, Bitcode-equivalent/current archive reports;
- current App Store Connect app record, in-app purchase configuration/availability, agreements, review screenshots/notes, age rating, privacy policy, App Privacy answers;
- final archive privacy manifests, required-reason APIs, third-party SDK signatures, SBOM, and actual network traffic;
- binary art/model/audio licenses and provenance;
- asset dimensions, compression, texture formats, atlases, shader variants, runtime missing assets, app icon correctness, app size;
- Unity generated Xcode export, IL2CPP link behavior, native callback symbol, embedded framework/Data consistency;
- simulator and physical-device visual interaction for normal, elite, boss, conclusion, training, retry, and store;
- frame pacing, memory, thermal, battery, loading time, jetsam, background recovery, audio interruptions;
- VoiceOver/Voice Control/Switch Control/Larger Text/contrast/Reduce Motion on device;
- localization quality and translated layouts;
- crash/analytics/operations dashboards and incident response.

## Required release acceptance matrix

| Dimension | Minimum matrix |
|---|---|
| Save state | Fresh; current; every prior schema; partial/corrupt; future schema; reset; interrupted write; low storage. |
| Combat | Every authored normal/elite/boss; win; loss; retry; abandon; animation skip; 30/60 FPS; relaunch checkpoint; deterministic replay. |
| Party | Player only tutorial; one AI; two AI; override; revive; lethal boss intent; duplicate/invalid content rejected. |
| Presentation | SpriteKit; Unity; Unity unavailable; Unity load timeout; background during action; repeated enter/exit; narrow/wide devices. |
| Devices | Oldest supported physical iPhone; current small; current large; at least one 60 Hz and one high-refresh device if supported. |
| Accessibility | VoiceOver; Voice Control; Switch Control; Larger Text; Bold Text; Increase Contrast; Reduce Transparency; Reduce Motion; color filters. |
| Locale | Every launch locale; pseudolocale; 30–40% expansion; CJK/Latin; StoreKit currency/price variants. |
| Network/store | Offline; slow/lossy; Store unavailable; purchase/cancel/pending/restore/refund/revoke/reinstall/new device. |
| Lifecycle | Cold/warm launch; background/foreground; OS termination; memory warning; audio interruption; Low Power Mode; thermal run. |
| Release | Clean Release archive; privacy validation; symbols; crash symbolication; asset/license inventory; TestFlight install/update. |

## Current official platform references

Recommendations below depend on changing platform rules and must be rechecked at release time. Checked on **2026-07-28**:

- Apple submission requirements: https://developer.apple.com/app-store/submitting/  
  Current page states that uploads from 2026-04-28 require the iOS/iPadOS 26 SDK or later.
- Apple App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple privacy manifest files: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- Apple required-reason APIs: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- Apple App Privacy details: https://developer.apple.com/app-store/app-privacy-details/
- Apple StoreKit purchase guidance: https://developer.apple.com/in-app-purchase/
- Apple StoreKit transaction updates: https://developer.apple.com/documentation/storekit/transaction/updates
- Apple StoreKit sandbox testing: https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox
- Apple accessibility HIG: https://developer.apple.com/design/human-interface-guidelines/accessibility
- Apple accessibility testing: https://developer.apple.com/documentation/accessibility/performing-accessibility-testing-for-your-app
- Apple automated accessibility audits: https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app
- Apple XCTest performance tests: https://developer.apple.com/documentation/xcode/writing-and-running-performance-tests
- Apple performance/metrics: https://developer.apple.com/documentation/xcode/performance-and-metrics
- Apple localization: https://developer.apple.com/documentation/xcode/localization
- Unity 6.3 LTS, Unity as a Library for iOS: https://docs.unity3d.com/6000.3/Documentation/Manual/UnityasaLibrary-iOS.html  
  This version documents `pause`, `unloadApplication`, lifecycle listeners, and the native integration structure used by this project.
