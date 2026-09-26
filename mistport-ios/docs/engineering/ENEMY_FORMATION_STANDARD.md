# Enemy Formation Standard

Clock Plaza is the reference battlefield for enemy placement. Every later
battle background must preserve enough clear ground for the same formation.

## Fixed rows

| Row | Unity Z | Purpose |
| --- | ---: | --- |
| Front | `12.0` | attackers, tanks, melee enemies |
| Rear | `17.0` | healers, supports, ranged enemies |

All slots in one row share exactly the same Z depth. A model profile must not
use a positional offset to move an enemy between rows.

## Fixed lanes

| Slot | Unity position |
| --- | --- |
| FrontLeft | `(-1.45, 0, 12)` |
| FrontCenter | `(0, 0, 12)` |
| FrontRight | `(1.45, 0, 12)` |
| RearLeft | `(-1.8, 0, 17)` |
| RearCenter | `(0, 0, 17)` |
| RearRight | `(1.8, 0, 17)` |
| AirRearLeft | `(-1.8, 1.15, 17)` |
| AirRearRight | `(1.8, 1.15, 17)` |

Airborne slots reuse the rear-row X/Z coordinates. Their Y value only supplies
the authored hover baseline.

## Model authoring contract

Each new enemy supplies only:

1. orientation correction;
2. normalized reference-height ratio;
3. grounded or airborne classification;
4. model-relative health, target, damage, shield and effect anchors;
5. optional hover amplitude and period.

The formation system supplies all world positions. `SlotOffset` remains zero
for production models.

Grounded models are aligned from renderer bounds through `EnemyGroundAnchor`.
This makes differently shaped models put their lowest valid contact point on
the row plane without per-enemy Y adjustments.

## Current first-background assignment

- Clock Guard: `FrontCenter`
- Clock Core: `AirRearLeft`
- Hell Hound when alone: `FrontCenter`

Single enemies default to `FrontCenter`. In a two-enemy attacker/support team,
the attacker uses `FrontCenter` and the support uses `RearLeft`.

## UI alignment

Health bars, target hit regions and combat effects follow Unity-reported model
anchors. They do not infer positions from enemy array indexes. The native
SpriteKit fallback mirrors the same Clock Plaza projected slot coordinates.

## Validation

`EnemyPipelineSelfTest` rejects:

- front slots with different Z depths;
- rear and airborne-rear slots with different Z depths;
- missing fixed slots;
- model hierarchy, grounding, scale or anchor regressions.

Reference preview:
`docs/engineering/visual-previews/clock-encounter-strict-front-rear-v1.png`.
