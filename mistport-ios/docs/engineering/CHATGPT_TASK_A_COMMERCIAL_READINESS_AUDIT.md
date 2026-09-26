# ChatGPT Pro Task A — Commercial Game Readiness Audit

## Role

Act as a principal iOS/Unity game engineer performing an evidence-based commercial-readiness audit. You are an external reviewer. Codex remains the technical owner and will independently verify every conclusion.

## Package and baseline

The attached ZIP is a deliberately reduced, credential-scanned source snapshot. It contains:

- the current SwiftUI/SpriteKit iOS app source without binary art;
- `MistportCombatCore`, its JSON contracts, and Swift Testing suites;
- current v0.5 game-design authority documents;
- Unity battle scripts, editor tooling, scene text, package manifest, and project settings;
- Xcode project metadata and the 3D enemy production specification.

The workspace is not a Git repository. There is no branch or commit SHA. Do not invent one. Codex will provide the ZIP SHA-256 separately.

Known baseline before review:

- `swift test` passes 100 tests in 10 suites;
- an unsigned arm64 iPhone Debug build passes;
- simulator end-to-end visual acceptance is explicitly not complete;
- Unity is a presentation layer; `MistportCombatCore` remains authoritative for combat rules.

## Product boundaries that must not be broken

The v0.5 documents in `mistport-ios/docs/game-design/` are authoritative in their declared order. In particular:

- launch combat is fixed-skill turn-based;
- the party is the player plus up to two deterministic local AI companions;
- do not reintroduce real-time movement combat, live multiplayer combat, a five-person party, paid power, stamina gates, mandatory login rewards, or main-story paywalls;
- the iOS app is the shipping runtime;
- Unity handles 3D presentation only and must not become the authoritative combat simulation;
- existing JSON contracts and deterministic combat behavior must remain compatible.

## Goal

Determine what prevents the current project from meeting a realistic commercial iOS game quality bar, then produce a prioritized and testable delivery plan. “Commercial quality” must be translated into concrete evidence and acceptance checks, not aesthetic opinion.

## Required review areas

1. Product and architecture consistency with v0.5 authority documents.
2. Runtime correctness, crash resilience, persistence, migration, and recoverability.
3. SwiftUI/SpriteKit/Unity lifecycle and integration boundaries.
4. Combat-core determinism, configuration validation, and test coverage gaps.
5. Performance, memory, asset loading, thermal behavior, and frame pacing.
6. Accessibility, Dynamic Type, VoiceOver, motion reduction, contrast, input target sizes.
7. Localization and text layout readiness.
8. Privacy, data handling, logging, analytics readiness, StoreKit, and App Store compliance.
9. Security and integrity boundaries appropriate to an offline-first premium game.
10. Build, signing, release configuration, crash reporting, observability, and reproducibility.
11. Game UX: onboarding, failure/retry, loading/error states, save continuity, progression clarity.
12. Art/animation pipeline, 3D enemy pipeline, visual regression, and device-aspect validation.
13. Automated tests, UI tests, performance tests, release gates, and manual acceptance matrix.
14. Dead code, legacy prototype boundaries, duplicate systems, and migration risks.

## Evidence requirements

Every finding must include:

- severity: P0 blocker, P1 launch-critical, P2 important, or P3 polish;
- exact file path and line or symbol when source evidence exists;
- observed behavior or architectural fact;
- commercial impact;
- minimum complete remediation;
- objective acceptance criteria;
- required automated and manual tests;
- dependencies and sequencing constraints.

Clearly distinguish:

- verified source facts;
- reasonable inferences;
- items that cannot be verified from the reduced package;
- items requiring App Store Connect, signing credentials, analytics dashboards, a physical device, or the omitted binary assets.

## Deliverables

Return files, not only chat prose:

1. `COMMERCIAL_READINESS_AUDIT.md`
   - executive assessment;
   - evidence table;
   - P0/P1/P2/P3 findings;
   - launch blockers;
   - risks that remain unverified.
2. `COMMERCIAL_READINESS_ROADMAP.md`
   - dependency-ordered phases;
   - estimated engineering batches;
   - acceptance gates for each phase;
   - explicit “do not start yet” items.
3. `FIRST_IMPLEMENTATION_BATCH.md`
   - the smallest high-leverage batch that can be independently completed and tested now;
   - exact files expected to change;
   - proposed tests and rollback boundary.

Package those three Markdown files into one downloadable ZIP. Also provide the ZIP byte size and SHA-256 in your response.

## Required checks

Perform static cross-checks across the supplied source and documents. You may use official Apple and Unity documentation for current API facts, but cite direct official links and clearly label any recommendation that depends on a currently changing platform rule.

Do not claim to have run Xcode, Unity, a simulator, a device, App Store Connect, or production services. You do not have this local environment.

## Forbidden operations and claims

- Do not request or expose credentials.
- Do not commit, push, deploy, create a PR, change production configuration, or operate real user data.
- Do not add dependencies or edit source code in Task A.
- Do not treat historical documents as current authority.
- Do not claim the app is commercially ready merely because unit tests and a Debug build pass.
- Do not claim visual, performance, accessibility, privacy, payment, or release validation without evidence.
- Do not return generic best-practice lists without mapping them to this source.

## Acceptance standard

The audit passes only if it is source-specific, correctly respects the product boundaries, identifies the most consequential launch risks, and turns “commercial quality” into a practical sequence of verifiable engineering gates.

