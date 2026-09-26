# Mindstone VFX V1 contract

## Runtime ownership

- Swift resolves combat. Unity presents `skill:<id>` and showcase requests.
- `SpellRegistry` resolves a V1 ID. Unknown IDs fall through to the legacy presentation path.
- `SpellRuntime` advances V1 spells at a fixed 1/60-second step. Effekseer handles and particle systems are manually sampled for deterministic review.
- Every active spell must support interrupt, immediate cleanup, replay, and natural completion without leaving roots, lights, materials, particles, or Effekseer handles alive.

## Anchors

Use semantic runtime anchors: `source`, `target`, `weapon`, `mouth`, `impact`, `ground`, or `motion`. Never tune against screenshot pixels. Re-resolve moving anchors every fixed step.

## Legacy locks

`fireball` and `sword` are not V1 specs. They remain in `MistportSpellShowcaseVFX` and are routed through the existing fallback. Their five-frame review times are:

- Fireball: `0.12, 0.36, 0.60, 0.84, 1.28`
- Sword qi: `0.10, 0.52, 0.96, 1.18, 1.82`

Changing screenshot timing does not authorize changing playback, textures, materials, scales, motion, or impact composition.

## Render and device assumptions

- Unity Built-in Render Pipeline.
- Portrait composition, perspective camera, 60-fps target.
- iPhone 13 is the acceptance baseline; desktop capture is a candidate review, not device-performance proof.
- Foreground impact layers may overwhelm the actor visually, but the actor renderer stays enabled.

## Safe file ownership

The scaffolder owns only files listed in `generated.manifest.json`. It refuses overwrite after a hash mismatch. Never edit generated Unity iOS output in `mistport-ios/UnityBuild/`; regenerate it after source approval.
