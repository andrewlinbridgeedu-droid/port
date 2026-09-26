# Enemy Pipeline Implementation Report

Status: **revision 2 proposed patch for independent Codex review**
Source package SHA-256: `01eb9067d99c67e16fb96dae35eed61dbeece82dcd06aa79ec9990f7c1deb7df`
Source package size: `769709` bytes
Unity baseline: `6000.3.20f1`

## Revision 2 corrective change

Codex independently ran Unity 6000.3.20f1 against revision 1. Script compilation stopped before installer execution with CS0019 at `EnemyFormationProfile.Slots` because the null-coalescing operands had static types `List<EnemyFormationSlot>` and `EnemyFormationSlot[]`. Revision 2 explicitly casts the nullable list to `IReadOnlyList<EnemyFormationSlot>` before coalescing to `Array.Empty<EnemyFormationSlot>()`. The property therefore remains null-safe and exposes only `IReadOnlyList` semantics.

Revision 2 also preserves the newer bridge integration requirement by calling `UnityBattleBridge.ReportPresentationComplete("enemy")` immediately after the enemy finishes returning to `enemyHome`. The source-package baseline did not contain the corresponding static bridge helper, so this proposal adds that source-compatible reporting method without removing or renaming any existing bridge entry point.

No Clock Core orientation step, height ratio, formation position, hover amplitude, hover period, or idle-rotation setting changed from revision 1.

## Scope and authority boundary

This patch implements the first compact production version of the data-driven Unity enemy presentation pipeline. Unity remains presentation-only. No Swift combat formulas, `MistportCombatCore` logic, JSON contracts, package manifest, generated `UnityBuild`, IL2CPP output, signing configuration, or production service was changed. Existing public native bridge entry points were not removed or renamed; revision 2 adds only the completion-reporting helper required by the preserved enemy-return callback.

The workspace supplied for this review is not a Git repository. No branch or commit SHA is asserted.

## Architecture

### Runtime data

- `EnemyVisualProfile` stores a stable profile enemy ID, model prefab, optional animator controller, ordered orientation steps, reference-height ratio, default formation slot, per-enemy slot offset, hover configuration, and five anchor positions.
- `EnemyFormationProfile` stores a reference world height and stable slots. Slots explicitly distinguish grounded and airborne semantics.
- `EnemyOrientationStep` stores one axis and one angle. Steps are multiplied from left to right in listed order, so non-commutative corrections are explicit and do not depend on an ambiguous Euler conversion.
- `EnemyHoverConfiguration` and profile/formation validation reject non-finite or unsafe values.

### Standard hierarchy and ownership

`EnemyPresenter` creates or adopts this hierarchy:

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

Ownership is intentionally exclusive:

- `EnemyRoot`: formation placement, encounter switching, and combat movement.
- `MotionRoot`: procedural presentation motion such as hover.
- `VisualRoot`: permanent model orientation, normalized scale, and renderer-bottom alignment.
- `Model`: imported prefab instance; no battle position is written to it.
- Anchor transforms: direct children of `MotionRoot`, so they follow formation, combat motion, and hover without maintaining approximate duplicate positions.

`EnemyHandle` returns the stable `battleEnemyId`, profile ID, active formation-slot ID, profile/formation references, all hierarchy transforms, all anchors, and the reusable hover component.

### Presenter sequence

The presenter:

1. validates the request and assets;
2. creates or reuses `EnemyRoot`;
3. creates the standard child hierarchy;
4. adopts a supplied model or instantiates the profile prefab;
5. resets presenter-owned transforms to canonical values;
6. applies the ordered orientation correction to `VisualRoot`;
7. calculates bounds from all child renderers, including inactive renderers;
8. normalizes height against `formation.referenceWorldHeight * profile.referenceHeightRatio`;
9. aligns the lowest renderer point to the slot plane;
10. places `EnemyRoot` at the formation slot plus profile offset;
11. creates or rebinds all anchors;
12. binds `EnemyHandle` references;
13. captures the final motion baseline and only then enables hover.

A repeated build detaches and deactivates the retired model before runtime `Destroy`, preventing deferred destruction from contaminating same-frame renderer bounds. `Reposition` always resets `EnemyRoot`/`MotionRoot` from canonical values rather than multiplying the previous encounter pose.

### Motion

`EnemyHoverMotion` replaces `ClockCoreIdle`.

- It writes only its own `transform.localPosition`; the installer attaches it to `MotionRoot`.
- It records the final baseline explicitly.
- Every evaluation is `baseline + sin(phase) * amplitude`; no frame-to-frame accumulation occurs.
- X/Z, local rotation, and local scale are never written.
- Enable, stop/reset, and deterministic elapsed-time evaluation are explicit.
- Zero, negative, non-finite, or effectively zero periods produce no displacement rather than division by zero.
- `Update` creates no managed collections, strings, delegates, or LINQ queries.

## Clock Guard / Clock Core migration mapping

The generated assets are created or updated by `Install3DAssets.Install` under `Assets/Generated/`.

| Approved behavior | Data-driven representation |
|---|---|
| Clock Guard stable battle identity | `clock-guard-primary` on `EnemyHandle` |
| Clock Core stable battle identity | `clock-core-primary` on `EnemyHandle` |
| Guard-only position | `FrontCenter = (0, 0, 9.2)` |
| Guard position in guard-plus-core encounter | `FrontRight = (0.75, 0, 9.0)` |
| Core formation semantic | `AirRearLeft`, marked `Airborne` |
| Core world position | `(-1.0, 1.15, 9.75)` |
| Guard normalized reference height | `2.88` world units |
| Core height relative to guard | `referenceHeightRatio = 0.496` |
| Core ordered orientation | `X -15`, then `Y 90`, then `Z 90`, then `Y 90` |
| Exact rotation composition | `Euler(-15,0,0) * Euler(0,90,0) * AngleAxis(90,forward) * Euler(0,90,0)` |
| Core hover | enabled, amplitude `0.055`, period `4.2s` |
| Core idle rotation | none |

`BattlePrototype` retains the existing public bridge methods, including `UseClockCoreModel` and `UseClockGuardModel`. Its normal path resolves exact `EnemyHandle.battleEnemyId` values, then requests `FrontCenter`, `FrontRight`, or `AirRearLeft`; it no longer owns Clock Core orientation, height-ratio, or hover constants. Name-based discovery and old placement math are isolated in `LegacyEnemyPresentationFallback` for pre-profile scenes only. After the presented enemy attack returns to `enemyHome`, `BattlePrototype` calls `UnityBattleBridge.ReportPresentationComplete("enemy")`; revision 2 explicitly preserves this integration callback.

The old Clock Core-specific `ClockCoreIdle` script and meta file are deleted. A newly installed scene uses `EnemyHoverMotion` on `MotionRoot`.

## Editor calibration

Menu: **Mindstone > Enemy Calibration**

The compact calibration window:

- selects an `EnemyVisualProfile` and `EnemyFormationProfile`;
- selects any stable formation slot;
- builds the formal hierarchy through the same `EnemyPresenter` used by runtime/installation;
- exposes the ordered orientation steps, height ratio, slot offset, hover settings, and anchor positions through serialized profile fields;
- previews hover at a deterministic phase without Play Mode;
- supports **Reset Preview** and **Save Assets**;
- shows profile, formation, presenter, and anchor-parenting validation errors;
- marks preview objects `DontSaveInEditor` and removes them when the window closes.

This first version intentionally does not add a second placement algorithm, a custom rendering framework, screenshot regression capture, device-aspect presets, anchor Gizmos, or automatic FBX postprocessing.

## Deterministic validation

Menu: **Mindstone > Validate Enemy Pipeline**
Batch entry point: `EnemyPipelineSelfTest.RunBatch`

The self-test throws `InvalidOperationException` when any invariant fails. In Unity batch mode, an execute-method exception is intended to fail the process/nonzero CI step.

Covered checks:

- same-root repeated setup preserves normalized scale, visual alignment, and formation position;
- ten guard-only / airborne-slot round trips do not accumulate scale or root offset;
- normalized renderer height and renderer-bottom alignment remain within tolerance;
- inactive child renderers participate in bounds normalization;
- hover preserves X/Z, local rotation, and local scale;
- sampled hover displacement never exceeds the configured amplitude;
- zero-period hover safely remains at baseline;
- all five anchors exist as direct `MotionRoot` children;
- formation validation catches invalid reference height, empty slot IDs, duplicate slot IDs, and invalid airborne height;
- visual-profile validation catches empty and duplicate enemy IDs, missing prefab, invalid height ratio, missing slot, and invalid hover period;
- installed Clock Guard/Core assets match all approved migration values and ordered rotation composition;
- the installed battle scene contains both exact stable battle IDs and valid anchor ownership.

## Files added

- `UnityBattleSource/Assets/Scripts/EnemyPresentation.meta`
- `UnityBattleSource/Assets/Scripts/EnemyPresentation/EnemyVisualProfile.cs`
- `UnityBattleSource/Assets/Scripts/EnemyPresentation/EnemyVisualProfile.cs.meta`
- `UnityBattleSource/Assets/Scripts/EnemyPresentation/EnemyFormationProfile.cs`
- `UnityBattleSource/Assets/Scripts/EnemyPresentation/EnemyFormationProfile.cs.meta`
- `UnityBattleSource/Assets/Scripts/EnemyPresentation/EnemyHandle.cs`
- `UnityBattleSource/Assets/Scripts/EnemyPresentation/EnemyHandle.cs.meta`
- `UnityBattleSource/Assets/Scripts/EnemyPresentation/EnemyHoverMotion.cs`
- `UnityBattleSource/Assets/Scripts/EnemyPresentation/EnemyHoverMotion.cs.meta`
- `UnityBattleSource/Assets/Scripts/EnemyPresentation/EnemyPresenter.cs`
- `UnityBattleSource/Assets/Scripts/EnemyPresentation/EnemyPresenter.cs.meta`
- `UnityBattleSource/Assets/Scripts/EnemyPresentation/LegacyEnemyPresentationFallback.cs`
- `UnityBattleSource/Assets/Scripts/EnemyPresentation/LegacyEnemyPresentationFallback.cs.meta`
- `UnityBattleSource/Assets/Editor/EnemyPresentation.meta`
- `UnityBattleSource/Assets/Editor/EnemyPresentation/EnemyCalibrationWindow.cs`
- `UnityBattleSource/Assets/Editor/EnemyPresentation/EnemyCalibrationWindow.cs.meta`
- `UnityBattleSource/Assets/Editor/EnemyPresentation/EnemyPipelineSelfTest.cs`
- `UnityBattleSource/Assets/Editor/EnemyPresentation/EnemyPipelineSelfTest.cs.meta`
- `ENEMY_PIPELINE_IMPLEMENTATION_REPORT.md`

## Files modified

- `UnityBattleSource/Assets/Scripts/BattlePrototype.cs`
- `UnityBattleSource/Assets/Scripts/UnityBattleBridge.cs`
- `UnityBattleSource/Assets/Editor/Install3DAssets.cs`

## Files deleted

- `UnityBattleSource/Assets/Scripts/ClockCoreIdle.cs`
- `UnityBattleSource/Assets/Scripts/ClockCoreIdle.cs.meta`

## Commands Codex should run

Run from the modified ZIP root on macOS with Unity 6000.3.20f1 installed. Adjust only the Unity executable path if Unity Hub is installed elsewhere.

```bash
set -euo pipefail

ROOT="$PWD"
UNITY="/Applications/Unity/Hub/Editor/6000.3.20f1/Unity.app/Contents/MacOS/Unity"
PROJECT="$ROOT/UnityBattleSource"

# 1. Import/compile and generate the model prefabs, profiles, formation asset,
#    standard hierarchy, and saved BattlePrototype scene.
"$UNITY" \
  -batchmode -nographics -quit \
  -projectPath "$PROJECT" \
  -executeMethod Install3DAssets.Install \
  -logFile "$ROOT/unity-enemy-install.log"

# 2. Reopen/compile and fail the process if deterministic or migration checks fail.
"$UNITY" \
  -batchmode -nographics -quit \
  -projectPath "$PROJECT" \
  -executeMethod EnemyPipelineSelfTest.RunBatch \
  -logFile "$ROOT/unity-enemy-self-test.log"
```

Review both logs for compiler errors and warnings even when the process exits successfully.

After Unity editor inspection and visual approval, export the iOS library to the existing integration location:

```bash
export MISTPORT_UNITY_IOS_OUTPUT="$PWD/mistport-ios/UnityBuild"
"$UNITY" \
  -batchmode -nographics -quit \
  -projectPath "$PWD/UnityBattleSource" \
  -executeMethod ExportIOSLibrary.Export \
  -logFile "$PWD/unity-ios-export.log"
```

Then run the existing combat-core and unsigned iOS build checks:

```bash
(
  cd mistport-ios/MistportCombatCore
  swift test
)

xcodebuild \
  -project mistport-ios/Mistport.xcodeproj \
  -scheme Mistport \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Codex should additionally open `BattlePrototype.unity`, switch between guard-only and guard-plus-core repeatedly, compare Guard/Core screenshots against the approved baseline, inspect every anchor in Scene view, and run on the supported simulator/device configurations before accepting the patch.

## Known limitations and binary-asset assumptions

- FBX, texture, and other binary model files were intentionally absent from the supplied reduced ZIP. `Install3DAssets.Install` therefore cannot complete against this reduced package alone. The patch assumes Codex applies it to the full workspace containing the existing paths referenced by the installer.
- Generated `Assets/Generated/*.asset`, model prefabs, controllers, materials, and the migrated serialized scene are produced by the installer and are not embedded in this source-only proposal.
- The compact calibration window uses the current Scene view. It does not yet provide the broader design document's dedicated iPhone portrait camera/background, aspect-ratio switching, screenshots, bounds overlays, or anchor Gizmos.
- Automatic renderer bounds are used. A manual bounds override/collider-generation path is not included in this first version.
- Legacy pre-profile scenes retain isolated name-based fallback placement. They must be reinstalled/migrated to receive the standard hierarchy and reusable hover component.
- Existing bridge command methods remain source-compatible. Revision 2 adds `ReportPresentationComplete` for the preserved enemy-return callback, but Swift-to-Unity anchor screen-coordinate transport is outside this patch; the handle/anchor ownership required for that work is now available.

## Verification actually performed for this proposal

The supplied ZIP's byte size and SHA-256 were recomputed and matched the user-provided values. Revision 2 was compared against revision 1 to confirm that the approved Clock Core orientation, height ratio, formation position, hover amplitude, hover period, and no-idle-rotation values are unchanged. The exact `ReportPresentationComplete("enemy")` call was checked after the enemy return coroutine step. The source was compared against a fresh extraction, C# delimiter/string/comment lexical balance was checked across the source scripts, no runtime enemy-presentation script references `UnityEditor`, no `ClockCoreIdle` reference remains, and `Packages/manifest.json` plus `ProjectVersion.txt` remain unchanged. The reduced package contains no `UnityBuild`, `Library`, or `Temp` output to modify. The revised unified patch was apply-checked against a fresh extraction, and the patched tree and extracted delivery ZIP were compared file-for-file.

Codex's revision-1 Unity run is external evidence that the earlier proposal failed compilation at the documented CS0019 error before installer execution. No Unity executable or Unity-compatible C# compiler is available in this environment. I did **not** run Unity compilation for revision 2, the installer, Unity batch validation, Play Mode, iOS export, `swift test`, Xcode build, simulator/device execution, signing, or visual-equivalence comparison. Codex must rerun those checks using the full binary-asset workspace.
