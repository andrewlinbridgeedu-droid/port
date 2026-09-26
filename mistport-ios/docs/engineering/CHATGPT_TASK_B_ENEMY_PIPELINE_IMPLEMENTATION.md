# ChatGPT Pro Task B — Production 3D Enemy Pipeline Implementation

## Role

Act as a senior Unity 6 / iOS integration engineer. Implement the first production-ready version of the data-driven 3D enemy presentation pipeline described in `mistport-ios/ENEMY_3D_PIPELINE.md`.

Codex will independently review, apply, compile, test, and visually validate your work. Your output is a proposed patch, not an approved merge.

## Package and baseline

The attached reduced source ZIP contains the relevant Unity scripts, editor tooling, scene text, project settings, iOS integration source, and current documentation. Binary FBX and texture files were intentionally excluded for size and credential safety, but their paths and installer references remain visible.

The workspace is not a Git repository. Do not invent a commit SHA.

Known baseline:

- Unity editor: 6000.3.20f1;
- Unity is presentation-only;
- the iOS/Swift combat core is authoritative;
- the current Clock Guard and Clock Core are installed by `Assets/Editor/Install3DAssets.cs`;
- current Clock Core approved reference:
  - formation semantic: `AirRearLeft`;
  - world position: `(-1.0, 1.15, 9.75)`;
  - height ratio relative to guard: `0.496`;
  - ordered visual rotation:
    `Euler(-15,0,0) * Euler(0,90,0) * AngleAxis(90,forward) * Euler(0,90,0)`;
  - hover amplitude: `0.055`;
  - hover period: `4.2s`;
  - no idle rotation;
- the Clock Guard remains at the approved front-right battle position;
- current `BattlePrototype.cs` contains enemy-specific transform hardcoding that must be migrated without changing visible behavior.

## Boundaries

- Do not move combat rules into Unity.
- Do not change Swift combat formulas or JSON contracts.
- Do not add third-party Unity packages.
- Do not require binary model changes.
- Do not edit generated `mistport-ios/UnityBuild` or IL2CPP files.
- Do not change approved Clock Guard/Core visual results.
- Do not commit, push, deploy, sign, or access production services.

## Required implementation

### Runtime data model

Implement:

- `EnemyVisualProfile : ScriptableObject`;
- `EnemyFormationProfile : ScriptableObject` with stable slot IDs;
- serializable ordered model-orientation correction that avoids ambiguous Euler order;
- hover configuration with safe validation;
- stable `battleEnemyId`;
- anchor configuration for shield, target, health bar, damage text, and effects.

### Standard hierarchy and handle

Implement a generated runtime hierarchy equivalent to:

```text
EnemyRoot
└── MotionRoot
    ├── VisualRoot
    │   └── Model
    ├── ShieldAnchor
    ├── TargetAnchor
    ├── HealthBarAnchor
    ├── DamageTextAnchor
    └── EffectAnchor
```

Return an `EnemyHandle` exposing stable IDs and Transform references. Clearly define Transform ownership.

### Runtime presenter

Implement `EnemyPresenter` or equivalent that:

1. creates or adopts a model instance;
2. applies ordered orientation correction;
3. normalizes height using renderer bounds;
4. applies a formation slot;
5. creates or binds anchors;
6. enables motion only after the final pose is complete;
7. supports grounded and airborne slots;
8. safely handles inactive renderers and missing optional anchors;
9. prevents cumulative scale and position drift when switching encounters repeatedly.

### Motion

Replace the Clock Core-specific behavior with a reusable hover component:

- operates only on `MotionRoot.localPosition`;
- captures the final baseline pose;
- computes from baseline every frame;
- does not rotate or scale;
- supports deterministic enable/reset;
- validates zero/negative periods;
- current Clock Core remains amplitude `0.055`, period `4.2s`.

### Migration

Migrate `BattlePrototype.cs` and `Install3DAssets.cs` so that:

- approved Clock Guard/Core orientation, size, position, depth, and hover remain unchanged;
- repeated switching between guard-only and guard-plus-core encounters does not accumulate scale or offset;
- existing public bridge entry points remain source-compatible;
- model discovery no longer depends solely on object-name guessing when a profile/handle exists;
- legacy fallback behavior is retained only where necessary and clearly isolated.

### Editor calibration

Implement a practical first calibration window under `Mindstone/Enemy Calibration`:

- selects an `EnemyVisualProfile` and formation slot;
- previews the formal runtime hierarchy using the same presenter;
- exposes orientation steps, height ratio, slot offset, hover amplitude, and hover period;
- supports Reset Preview and Save Assets;
- displays validation errors;
- does not duplicate a second placement algorithm;
- does not require entering Play Mode for static calibration.

Keep the first version compact and maintainable. Do not build a large custom framework.

### Tests

The current manifest does not include Unity Test Framework. Do not silently add a package. Provide editor-callable deterministic validation code or a minimal self-test command that can run in Unity batch mode and fail with an exception/nonzero result when invariants fail.

Required invariants:

- repeated setup is idempotent;
- height normalization stays within tolerance;
- hover never changes X/Z, rotation, or scale;
- hover displacement does not exceed configured amplitude;
- anchors remain children of `MotionRoot`;
- profile validation catches duplicate/empty enemy IDs, missing prefabs, invalid slots, invalid height ratios, and invalid hover periods;
- approved Clock Core migration values match the documented baseline.

## Code-quality requirements

- Unity 6000.3-compatible C#;
- no reflection for core behavior;
- no global name scans in the new normal path;
- no per-frame allocations in hover Update;
- clear serialized-field validation;
- no hidden dependence on editor-only classes in runtime assemblies;
- no new warnings from unused fields or unreachable compatibility branches;
- comments explain ownership and non-obvious rotation ordering, not obvious syntax.

## Deliverables

Return:

1. a unified patch relative to the ZIP root;
2. all added/modified source files in a downloadable ZIP;
3. `ENEMY_PIPELINE_IMPLEMENTATION_REPORT.md` containing:
   - architecture;
   - migration mapping;
   - changed files;
   - test/validation entry points;
   - commands Codex should run;
   - known limitations and binary-asset assumptions.

State the ZIP byte size and SHA-256. Ensure the patch and ZIP describe the same file contents.

## Required honesty

You cannot run this repository’s Unity editor or physical-device checks. Do not claim that compilation, Unity batch validation, iOS export, Xcode build, or visual equivalence passed. State exactly what you inspected and what Codex must verify locally.

## Acceptance criteria

The implementation is acceptable only if:

- `BattlePrototype` no longer owns Clock Core-specific orientation/size/hover constants in its normal path;
- profile + formation data determine presentation;
- approved current visuals remain representable exactly;
- repeated encounter switching is idempotent;
- anchor ownership makes shield/target feedback follow the intended enemy;
- calibration and runtime use the same presenter;
- batch-callable validation exists;
- no generated Unity/iOS output is edited;
- Codex can apply the patch and independently compile, export, test, and visually compare it.

