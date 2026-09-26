# SpellSpec v1

The JSON schema is in `assets/spell-spec-v1.schema.json`. Runtime parsing uses Unity `JsonUtility`, so keep the schema typed and avoid maps, polymorphic JSON, comments, and unknown fields.

## Required shape

- `schema`: `1`
- `id`, `displayName`, `archetype`, deterministic `seed`
- `timeline`: nonnegative `windup`, `travel`, `impact`, `decay`; total must be positive
- `anchors`: semantic anchor names and optional XYZ offsets
- `behavior`: the selected archetype’s motion values
- `layers`: one or more typed backend layers
- `capture`: exactly five strictly increasing times inside total duration plus `iPhone 13` and `60`
- `cleanupSeconds`: bounded tail lifetime
- `showcase`: actor and source/target positions for the isolated review board

## Layer backends

- `effekseer`: `asset` must resolve to `EffekseerEffectAsset` under Resources.
- `prefab`: `asset` must resolve to a Resources prefab. Particle seeds are forced from spell seed plus `seedOffset`.
- `spriteSequence`: `asset` resolves to sprites or a texture. Use for authored transparent flipbooks, never a static concept-art panel.
- `ribbon`: generated continuous line; `asset` is optional. Use `width`, `pointCount`, and a directional role.
- `extension`: `extensionType` must name a project type implementing `ISpellExtension`. Use only when typed layers cannot express the silhouette.

Place a spell-specific extension under `UnityBattleSource/Assets/Mindstone/VFXV1/Extensions/<id>/`, keep it presentation-only, record it in provenance, and add it to `generated.manifest.json`. Do not extend the legacy showcase class.

`start` and `end` are normalized over the full spell duration. `anchor` is one of `source`, `target`, `weapon`, `mouth`, `impact`, `ground`, or `motion`. Roles such as `impact-front` and `impact-back` establish depth around the target.

## Determinism

Use one spell seed. Derive each particle or procedural seed from `seed + seedOffset`; do not use global random state. Do not drive motion by coroutine jumps or screenshot count. The runtime samples smooth curves at 60 Hz.
