# Existing-combat preparation probe

288 deterministic runtime trials: 3 encounters × 2 earned equipment sets × 4 passive relic choices × 2 medicine inventories × 2 active-medal choices × 3 timing seeds.
No new NPC content, human playtest, or probabilistic real-player win-rate claim. Existing B03/B06/F90 are isolated mechanical fixtures.
Four Q30 skills/talents. Active life medal and passive relic choice vary. Gear is earned through tower floor 30 or 100. Timing jitter ±0.25s; automatic medicine below half normal max HP. Timeout 360s.
No forced damage in these runs. Settlement unit tests use forced victory fixtures separately and are excluded.

|Encounter|Earned gear through floor|Passive|Carried medicine|Active medal|Wins / 3|Timeouts|Mean winning seconds|Mean consumed doses|Mean ordinary repair copper|
|---|---:|---|---:|---|---:|---:|---:|---:|---:|
|church_bounty_b03|30|none|0|False|3|0|34.80|0.00|0.00|
|church_bounty_b03|30|none|0|True|3|0|32.32|0.00|0.00|
|church_bounty_b03|30|none|3|False|3|0|34.80|1.67|0.00|
|church_bounty_b03|30|none|3|True|3|0|32.32|2.00|0.00|
|church_bounty_b03|30|relic_return_gift_clasp|0|False|3|0|37.70|0.00|2.00|
|church_bounty_b03|30|relic_return_gift_clasp|0|True|3|0|34.98|0.00|2.00|
|church_bounty_b03|30|relic_return_gift_clasp|3|False|3|0|37.70|0.33|2.00|
|church_bounty_b03|30|relic_return_gift_clasp|3|True|3|0|34.98|1.00|2.00|
|church_bounty_b03|30|relic_salt_sealed_breathing_bag|0|False|3|0|34.80|0.00|2.00|
|church_bounty_b03|30|relic_salt_sealed_breathing_bag|0|True|3|0|32.32|0.00|2.00|
|church_bounty_b03|30|relic_salt_sealed_breathing_bag|3|False|3|0|34.80|1.67|2.00|
|church_bounty_b03|30|relic_salt_sealed_breathing_bag|3|True|3|0|32.32|2.00|2.00|
|church_bounty_b03|30|relic_sealed_paperweight|0|False|3|0|37.05|0.00|4.00|
|church_bounty_b03|30|relic_sealed_paperweight|0|True|3|0|34.98|0.00|4.00|
|church_bounty_b03|30|relic_sealed_paperweight|3|False|3|0|37.05|1.33|4.00|
|church_bounty_b03|30|relic_sealed_paperweight|3|True|3|0|34.98|1.00|4.00|
|church_bounty_b03|100|none|0|False|3|0|34.80|0.00|0.00|
|church_bounty_b03|100|none|0|True|3|0|25.70|0.00|0.00|
|church_bounty_b03|100|none|3|False|3|0|34.80|1.00|0.00|
|church_bounty_b03|100|none|3|True|3|0|25.70|1.00|0.00|
|church_bounty_b03|100|relic_return_gift_clasp|0|False|3|0|34.80|0.00|2.00|
|church_bounty_b03|100|relic_return_gift_clasp|0|True|3|0|28.02|0.00|2.00|
|church_bounty_b03|100|relic_return_gift_clasp|3|False|3|0|34.80|0.00|2.00|
|church_bounty_b03|100|relic_return_gift_clasp|3|True|3|0|28.02|0.00|2.00|
|church_bounty_b03|100|relic_salt_sealed_breathing_bag|0|False|3|0|34.80|0.00|2.00|
|church_bounty_b03|100|relic_salt_sealed_breathing_bag|0|True|3|0|25.70|0.00|2.00|
|church_bounty_b03|100|relic_salt_sealed_breathing_bag|3|False|3|0|34.80|1.00|2.00|
|church_bounty_b03|100|relic_salt_sealed_breathing_bag|3|True|3|0|25.70|1.00|2.00|
|church_bounty_b03|100|relic_sealed_paperweight|0|False|3|0|34.80|0.00|4.00|
|church_bounty_b03|100|relic_sealed_paperweight|0|True|3|0|34.98|0.00|4.00|
|church_bounty_b03|100|relic_sealed_paperweight|3|False|3|0|34.80|0.33|4.00|
|church_bounty_b03|100|relic_sealed_paperweight|3|True|3|0|34.98|1.00|4.00|
|church_bounty_b06|30|none|0|False|3|0|32.42|0.00|0.00|
|church_bounty_b06|30|none|0|True|3|0|27.18|0.00|0.00|
|church_bounty_b06|30|none|3|False|3|0|32.42|0.00|0.00|
|church_bounty_b06|30|none|3|True|3|0|27.18|1.00|0.00|
|church_bounty_b06|30|relic_return_gift_clasp|0|False|3|0|37.00|0.00|2.00|
|church_bounty_b06|30|relic_return_gift_clasp|0|True|3|0|36.38|0.00|2.00|
|church_bounty_b06|30|relic_return_gift_clasp|3|False|3|0|37.00|0.00|2.00|
|church_bounty_b06|30|relic_return_gift_clasp|3|True|3|0|36.38|0.00|2.00|
|church_bounty_b06|30|relic_salt_sealed_breathing_bag|0|False|3|0|32.42|0.00|2.00|
|church_bounty_b06|30|relic_salt_sealed_breathing_bag|0|True|3|0|27.18|0.00|2.00|
|church_bounty_b06|30|relic_salt_sealed_breathing_bag|3|False|3|0|32.42|0.00|2.00|
|church_bounty_b06|30|relic_salt_sealed_breathing_bag|3|True|3|0|27.18|1.00|2.00|
|church_bounty_b06|30|relic_sealed_paperweight|0|False|3|0|37.00|0.00|4.00|
|church_bounty_b06|30|relic_sealed_paperweight|0|True|3|0|36.38|0.00|4.00|
|church_bounty_b06|30|relic_sealed_paperweight|3|False|3|0|37.00|0.00|4.00|
|church_bounty_b06|30|relic_sealed_paperweight|3|True|3|0|36.38|1.00|4.00|
|church_bounty_b06|100|none|0|False|3|0|26.20|0.00|0.00|
|church_bounty_b06|100|none|0|True|3|0|27.18|0.00|0.00|
|church_bounty_b06|100|none|3|False|3|0|26.20|0.00|0.00|
|church_bounty_b06|100|none|3|True|3|0|27.18|0.00|0.00|
|church_bounty_b06|100|relic_return_gift_clasp|0|False|3|0|32.42|0.00|2.00|
|church_bounty_b06|100|relic_return_gift_clasp|0|True|3|0|27.18|0.00|2.00|
|church_bounty_b06|100|relic_return_gift_clasp|3|False|3|0|32.42|0.00|2.00|
|church_bounty_b06|100|relic_return_gift_clasp|3|True|3|0|27.18|0.00|2.00|
|church_bounty_b06|100|relic_salt_sealed_breathing_bag|0|False|3|0|26.20|0.00|2.00|
|church_bounty_b06|100|relic_salt_sealed_breathing_bag|0|True|3|0|27.18|0.00|2.00|
|church_bounty_b06|100|relic_salt_sealed_breathing_bag|3|False|3|0|26.20|0.00|2.00|
|church_bounty_b06|100|relic_salt_sealed_breathing_bag|3|True|3|0|27.18|0.00|2.00|
|church_bounty_b06|100|relic_sealed_paperweight|0|False|3|0|36.73|0.00|4.00|
|church_bounty_b06|100|relic_sealed_paperweight|0|True|3|0|27.18|0.00|4.00|
|church_bounty_b06|100|relic_sealed_paperweight|3|False|3|0|36.73|0.00|4.00|
|church_bounty_b06|100|relic_sealed_paperweight|3|True|3|0|27.18|0.00|4.00|
|church_tower_090|30|none|0|False|3|0|74.98|0.00|0.00|
|church_tower_090|30|none|0|True|3|0|66.57|0.00|0.00|
|church_tower_090|30|none|3|False|3|0|74.98|0.00|0.00|
|church_tower_090|30|none|3|True|3|0|66.57|2.00|0.00|
|church_tower_090|30|relic_return_gift_clasp|0|False|3|0|79.85|0.00|2.00|
|church_tower_090|30|relic_return_gift_clasp|0|True|3|0|67.10|0.00|2.00|
|church_tower_090|30|relic_return_gift_clasp|3|False|3|0|79.85|0.00|2.00|
|church_tower_090|30|relic_return_gift_clasp|3|True|3|0|67.10|1.00|2.00|
|church_tower_090|30|relic_salt_sealed_breathing_bag|0|False|3|0|74.98|0.00|2.00|
|church_tower_090|30|relic_salt_sealed_breathing_bag|0|True|3|0|66.57|0.00|2.00|
|church_tower_090|30|relic_salt_sealed_breathing_bag|3|False|3|0|74.98|0.00|2.00|
|church_tower_090|30|relic_salt_sealed_breathing_bag|3|True|3|0|66.57|2.00|2.00|
|church_tower_090|30|relic_sealed_paperweight|0|False|3|0|82.80|0.00|4.00|
|church_tower_090|30|relic_sealed_paperweight|0|True|3|0|80.28|0.00|4.00|
|church_tower_090|30|relic_sealed_paperweight|3|False|3|0|82.80|0.00|4.00|
|church_tower_090|30|relic_sealed_paperweight|3|True|3|0|80.28|2.00|4.00|
|church_tower_090|100|none|0|False|3|0|73.85|0.00|0.00|
|church_tower_090|100|none|0|True|3|0|64.80|0.00|0.00|
|church_tower_090|100|none|3|False|3|0|73.85|0.00|0.00|
|church_tower_090|100|none|3|True|3|0|64.80|1.67|0.00|
|church_tower_090|100|relic_return_gift_clasp|0|False|3|0|73.85|0.00|2.00|
|church_tower_090|100|relic_return_gift_clasp|0|True|3|0|64.80|0.00|2.00|
|church_tower_090|100|relic_return_gift_clasp|3|False|3|0|73.85|0.00|2.00|
|church_tower_090|100|relic_return_gift_clasp|3|True|3|0|64.80|1.00|2.00|
|church_tower_090|100|relic_salt_sealed_breathing_bag|0|False|3|0|73.85|0.00|2.00|
|church_tower_090|100|relic_salt_sealed_breathing_bag|0|True|3|0|64.80|0.00|2.00|
|church_tower_090|100|relic_salt_sealed_breathing_bag|3|False|3|0|73.85|0.00|2.00|
|church_tower_090|100|relic_salt_sealed_breathing_bag|3|True|3|0|64.80|1.67|2.00|
|church_tower_090|100|relic_sealed_paperweight|0|False|3|0|79.28|0.00|4.00|
|church_tower_090|100|relic_sealed_paperweight|0|True|3|0|72.72|0.00|4.00|
|church_tower_090|100|relic_sealed_paperweight|3|False|3|0|79.28|0.00|4.00|
|church_tower_090|100|relic_sealed_paperweight|3|True|3|0|72.72|2.00|4.00|

Repair uses the existing owned-relic ledger on a pristine ordinary item after each trial. Full repair after each battle includes rounding and is not an optimized multi-battle maintenance policy. Special medal is outside ordinary wear.
Medicine stock is an isolated fixture; no player wallet is charged. Multiply actual doses by candidate craft price 16 or existing system price 30 only for sensitivity, not guaranteed market cost.
No target copper sink, price elasticity, real player decision, relic purchase demand or campaign success rate can be inferred from these trials alone.
