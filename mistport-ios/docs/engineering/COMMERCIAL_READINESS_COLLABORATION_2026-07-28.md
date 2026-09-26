# Commercial Readiness Collaboration Record — 2026-07-28

## Purpose

This record preserves the evidence for the Codex + external ChatGPT engineering review requested on 2026-07-28. ChatGPT provides proposed analysis and code; Codex remains responsible for source review, local integration, testing, and acceptance.

The user authorized local inspection, source packaging, browser collaboration, local edits, and tests. The user did **not** authorize Git commits, pushes, pull requests, deployment, production configuration changes, database migrations, or access to real user data.

## Repository baseline

- Workspace root: `/Users/andrewlin/Downloads/DEV_Projects/mindstone-game`
- Shipping application: `mistport-ios`
- Combat authority: `mistport-ios/MistportCombatCore`
- Unity role: presentation only
- Unity version found in the project: `6000.3.20f1`
- Git baseline: unavailable. The workspace is not a Git work tree, so there is no branch or commit SHA to report.
- Existing local changes: preserved; the collaboration must not overwrite or discard them.

The current v0.5 design authority requires fixed-skill turn-based combat, the player plus at most two deterministic local AI companions, and the iOS application as the shipping runtime. Unity must not become the authoritative combat simulation.

## Local baseline checks

- `swift test` in `mistport-ios/MistportCombatCore`: passed, 100 tests in 10 suites.
- Unsigned arm64 iPhone Debug build: passed.
- Physical-device and end-to-end simulator visual acceptance: not established by these checks and must not be claimed.

## Sanitized source package

- File: `mistport-commercial-review-source-2026-07-28.zip`
- Size: `769709` bytes
- SHA-256: `01eb9067d99c67e16fb96dae35eed61dbeece82dcd06aa79ec9990f7c1deb7df`
- Source commit: unavailable because the workspace is not a Git work tree.
- Contents: task-relevant Swift, Swift Package, Xcode project metadata, Unity source and project settings, current product/design documentation, and package notes/manifests.
- Deliberate exclusions: `.git`, credentials and environment files, dependency/build output, Unity `Library`, generated Unity iOS/IL2CPP output, caches, logs, databases, browser/runtime state, binary art/models/textures/audio/video, provisioning files, and private keys.

Before upload, filename and content scans checked common credential, token, private-key, cookie, bearer-token, and secret-assignment patterns. No matches were found. No dedicated secret-scanner executable was installed, so this is a documented signature scan rather than a claim of exhaustive secret detection.

During package verification, a filtered `MistportCombatCore/build/` directory was found in the first archive candidate. It was removed, the archive was rebuilt, and the size and SHA-256 above refer only to the corrected package that was uploaded.

The uploaded ZIP's package note referenced a per-file checksum manifest that was accidentally not included in that immutable uploaded archive. This does not change the verified outer ZIP hash, but it weakens per-file comparison convenience. Codex generated the missing manifest directly from the verified ZIP after extraction and preserved it at `docs/engineering/SOURCE_PACKAGE_2026-07-28_SHA256SUMS.txt`:

- Files hashed: `444`
- Manifest SHA-256: `8fefb59d7109056ceee9d8c9c7905f192282204110fa8bc127443eb435b27a67`
- Scope: the exact contents of source ZIP SHA-256 `01eb9067d99c67e16fb96dae35eed61dbeece82dcd06aa79ec9990f7c1deb7df`
- Limitation: the manifest is persisted alongside the repository evidence, not retroactively embedded into the already-uploaded ZIP.

## External ChatGPT tasks

### Task A — Commercial readiness audit

- Task specification: `CHATGPT_TASK_A_COMMERCIAL_READINESS_AUDIT.md`
- Conversation: <https://chatgpt.com/c/6a699e18-c6b8-83e8-bf49-40efeb84c570>
- Required outputs:
  - `COMMERCIAL_READINESS_AUDIT.md`
  - `COMMERCIAL_READINESS_ROADMAP.md`
  - `FIRST_IMPLEMENTATION_BATCH.md`
  - one ZIP containing the three files, with byte size and SHA-256
- Accepted revision:
  - ZIP: `mistport-commercial-readiness-audit-revised-2026-07-29.zip`
  - Size: `36167` bytes
  - SHA-256: `4b80a10aa7a568061d05a3b86a23e236eff973e660dd58197b53b8439a58a4c8`
  - ZIP integrity: passed
  - Persisted under `docs/engineering/commercial-readiness/`
- Status: delivered, corrected, and independently reviewed.

### Task B — Production 3D enemy presentation pipeline

- Task specification: `CHATGPT_TASK_B_ENEMY_PIPELINE_IMPLEMENTATION.md`
- Conversation: <https://chatgpt.com/c/6a699ee7-60b0-83e8-9fec-578284cdc8f2>
- Required outputs:
  - unified patch relative to the supplied ZIP root
  - ZIP containing all changed/added files
  - `ENEMY_PIPELINE_IMPLEMENTATION_REPORT.md`
  - byte sizes and SHA-256 values
- Accepted revision 2:
  - Patch: `mistport-enemy-pipeline-task-b-r2.patch`, `112568` bytes, SHA-256 `0c155b846b8d4e491cc474d39e8af4248272d5df561e914fe76b117a276c0452`
  - Proposed-source ZIP: `mistport-enemy-pipeline-task-b-r2-proposed-source.zip`, `757186` bytes, SHA-256 `9352d44d56d57c323282be34a3d76476923c9b73aadc4a9f6867838420228098`
  - Report: `16131` bytes, SHA-256 `5fe83a8ea44cbd09a515c730fc5a0236028a8e61cb6454ae7549c64d75a1fc50`
  - ZIP integrity: passed
  - Applying the revision 2 patch to a fresh extraction produced a tree identical to the proposed-source ZIP.
  - Report persisted under `docs/engineering/commercial-readiness/`.
- Status: delivered, corrected, locally compiled, and independently integrated.

The browser UI identifies the signed-in account as ChatGPT Plus. High reasoning was selected. This record does not claim a subscription tier that the UI did not show.

## Local gameplay correction while external review is running

The following user-reported defects were investigated and corrected locally before any external patch is accepted:

1. **Clock Guard shield drift**
   - Cause: the guard is rendered by Unity while the authored shield effect is rendered in a separate SpriteKit overlay. A persistent overlay cannot share the Unity actor's transform and could visibly detach during movement.
   - Correction: the shield is hidden at rest and appears only for the short player-hit contact beat. Persistent movement-follow actions were removed. The control-seal break effect is still allowed to appear during its hit/break presentation.
   - Primary source: `Mistport/DungeonScene.swift`, `flashClockGuardShieldOnPlayerImpact(for:)`.

2. **Next-turn countdown starting during the enemy return animation**
   - Cause: native code waited a fixed `1.85` seconds, while the Unity enemy presentation takes about `2.57` seconds before the actor reaches its home position.
   - Correction: Unity now emits a presentation-only `presentation-complete/enemy` event after the return coroutine reaches the authored formation position. Swift waits for that event, then waits another `0.5` seconds before making the next player turn ready. A bounded timeout prevents an older or unavailable Unity export from deadlocking the turn loop.
   - Primary sources: `UnityBattleSource/Assets/Scripts/BattlePrototype.cs`, `UnityBattleSource/Assets/Scripts/UnityBattleBridge.cs`, `Mistport/UnityBattleHost.swift`, and `Mistport/ChapterOneTestView.swift`.
   - Combat authority remains in `MistportCombatCore`; this event controls presentation sequencing only.

3. **Clock Core absent from the latest application**
   - Cause: Clock Core transform/runtime code existed, and an older generated IL2CPP export contained related symbols, but the authoritative `UnityBattleSource/Assets/Scenes/BattlePrototype.unity` scene did not contain a serialized `ClockCore_Imported` object. Re-exporting that scene therefore could not show the enemy.
   - Correction: the asset installer was run successfully, producing the serialized `ClockCore_Imported` instance. The accepted enemy-presentation pipeline then replaced the one-off `ClockCoreIdle` component with `EnemyHoverMotion` on `MotionRoot`. The approved profile is preserved: world position `(-1.0, 1.15, 9.75)`, guard-height ratio `0.496`, ordered orientation correction `Euler(-15,0,0) * Euler(0,90,0) * AngleAxis(90,forward) * Euler(0,90,0)`, hover amplitude `0.055`, hover period `4.2` seconds, and no idle rotation.
   - Unity iOS export completed successfully after the scene correction. The generated app data contains `ClockGuard_Imported`, `Fool_Imported`, and `ClockCore_Imported`.

4. **Sidestep Strike residue and target-sigil alignment**
   - Cause of delayed residue: Sidestep Strike already had a complete authored phase/impact sequence, but the generic extended presentation scheduled three additional residual-arcana waves at `0.72`, `1.28`, and `1.86` seconds. Those late cyan fragments looked like shield debris after the card had finished.
   - Correction: Sidestep Strike no longer schedules the generic sustain waves; other cards retain extended presentation.
   - Cause of target-sigil drift: in the Unity overlay, the marker still used the hidden SpriteKit actor's contact-shadow position. That position is not the visible Unity actor transform. The decoration was also a five-point star despite the intended hexagram.
   - Correction: every Unity target-marker refresh first removes all old overlay markers, uses the same stable enemy ordering as the SwiftUI Unity hit regions, anchors horizontally to the visible enemy while remaining vertically at its floor-contact point, draws two opposing triangles as a true hexagram, and uses stronger but bounded line/glow values. Its projected height is compressed to the equivalent of a plane about ten degrees above the ground. Four detached diamond decorations were removed from the Unity overlay because they were visually indistinguishable from stale shield fragments.
   - Primary source: `Mistport/DungeonScene.swift`.

Independent checks after these corrections:

- `swift test` in `MistportCombatCore`: passed, 100 tests in 10 suites.
- Unity 6000.3.20f1 asset installation: succeeded.
- `EnemyPipelineSelfTest.RunBatch`: succeeded.
- Unity iOS library export: succeeded.
- Unsigned arm64 generic iPhone Debug build: succeeded.
- Built application: `/private/tmp/mistport-derived-20260728-enemy-pipeline/Build/Products/Debug-iphoneos/Mistport.app`
- Physical-device visual acceptance has not been performed by Codex and is not claimed.

## Independent acceptance protocol

External conclusions and patches are proposals only. Before acceptance, Codex will:

1. verify every delivered attachment's size and SHA-256;
2. unpack deliverables outside the working source tree;
3. compare the patch and file ZIP for identical contents;
4. review architecture boundaries, generated-file exclusions, dependencies, warnings, and migration behavior;
5. apply only accepted changes while preserving existing work;
6. run the repository's Swift tests, Unity batch validation, Unity iOS export, and unsigned Xcode device build as applicable;
7. distinguish static or simulated checks from simulator, physical-device, App Store Connect, production-service, and visual acceptance evidence;
8. send evidence-backed defects to the same ChatGPT conversation for minimal correction;
9. update this record with final deliverable hashes, corrections, local test results, residual risks, and source-control status.

## Final outcome

The external commercial-readiness audit and first enemy-presentation pipeline were accepted only after correction and local verification.

Corrections required from the external engineer:

1. The first audit incorrectly implied the native Unity event callback was absent. The revised audit now cites `MistportUnityBridge.mm` and correctly identifies the missing Swift consumer/acknowledgement boundary.
2. The source-package checksum omission was incorrectly counted as a product P2. The revised audit classifies it as review-input provenance only.
3. The first implementation batch omitted the live programmer-pack Fool JSON copy. The revised batch inventories canonical, runtime, and generated handoff copies.
4. Enemy pipeline revision 1 did not compile in Unity: `EnemyFormationProfile.cs:58` produced `CS0019` because `List<EnemyFormationSlot>` and `EnemyFormationSlot[]` were coalesced directly. Revision 2 exposes the null-safe value through `IReadOnlyList<EnemyFormationSlot>` and preserves the enemy-return completion callback.

Integrated production mechanism:

- `EnemyVisualProfile` and `EnemyFormationProfile` hold stable identity, ordered orientation, normalized height, formation slot, hover, and anchor data.
- `EnemyRoot`, `MotionRoot`, `VisualRoot`, and `Model` have separate transform ownership.
- reusable anchors now belong to `MotionRoot`;
- Clock Core hover is deterministic, bounded, and translation-only;
- installer-generated profiles and scene handles use stable battle IDs;
- a calibration window and deterministic Unity batch self-test are included.

Final verified gates:

- Swift Testing: 100 tests in 10 suites passed.
- Unity installer: passed.
- Unity enemy-pipeline self-test: passed.
- Unity iOS export: passed.
- Unsigned arm64 generic iPhone Debug build: passed.
- No build errors were emitted. The existing Unity `GameAssembly` run-script output warning and an AppIntents metadata-skip warning remain.

This is local implementation and verification only. No Git commit, push, pull request, deployment, signing, App Store Connect operation, database migration, production configuration change, or real-user-data operation was performed. Physical-device visual acceptance of the final target-sigil placement and final 3D composition remains for the user to confirm.
