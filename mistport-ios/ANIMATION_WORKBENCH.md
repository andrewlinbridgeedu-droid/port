# Mistport Animation Workbench

> This document defines the generic workbench pipeline. Character-specific contracts override its generic frame counts. For the Fool, follow [`FOOL_ANIMATION_CONTRACT.md`](FOOL_ANIMATION_CONTRACT.md), including 3 hit frames and 8 death frames.

This project uses `tools/gorest` as a local 2D animation workbench. The iOS game remains the shipping runtime; gorest is only for generating, previewing, checking, and organizing spritesheets before they are imported into SpriteKit.

## Start

```bash
cd /Users/andrewlin/Downloads/DEV_Projects/mindstone-game
scripts/start_gorest_workbench.sh
```

Open:

```text
http://localhost:3000
```

If port 3000 is busy:

```bash
PORT=3001 scripts/start_gorest_workbench.sh
```

## Role In The Pipeline

Use gorest for:

- player and NPC spritesheet previews
- enemy cast, hit, death, and teleport-strike clips
- restrained animated props such as coffee steam, lamps, potion glow, shop signs
- scene-level preview of scale, anchor, and animation readability

Do not use gorest as:

- the iOS runtime
- the source of final copyrighted sample assets
- a replacement for SpriteKit combat logic

## Mistport Sprite Standard

Player and important NPC action clips:

- 8 frames for walk and run
- 4 frames for idle, hit, and death
- 8 to 12 frames for attack and skill clips
- transparent PNG spritesheet
- fixed frame size per sheet
- shared bottom-center foot anchor
- one action and one direction per clip

Combat effects:

- 8 to 16 frames
- transparent PNG
- no UI text or labels
- restrained glow; supernatural bloom should stay under 5 percent of the visible composition unless it is the hit frame

Static venue props:

- 8 to 16 frames for subtle loops
- no camera motion baked into the sprite
- no large brightness pulsing

## Required Metadata

Every imported spritesheet needs a metadata JSON based on:

```text
tools/gorest/mistport-export-template.json
```

The minimum fields that SpriteKit cares about are:

- `assetId`
- `sprite.sheet`
- `sprite.frameWidth`
- `sprite.frameHeight`
- `sprite.frameCount`
- `sprite.fps`
- `sprite.anchor`
- `gameplay.assetRole`
- `gameplay.clipName`
- `gameplay.direction`
- `gameplay.loopMode`
- `gameplay.triggerType`

## Quality Gate

Before importing the approved runtime export into `mistport-ios/Mistport/Assets.xcassets/`, check:

- the feet stay on the same anchor line
- the head faces the actual movement or attack direction
- the silhouette does not change size between frames
- the first and last frames loop cleanly
- the asset reads clearly at phone scale
- the background is transparent
- the file is original or licensed for commercial use

## First Chapter Asset Batch

Build these first:

- `fool.idle.south`
- `fool.walk.south`
- `fool.attack.south`
- `fool.skill.card.south`
- `fool.hit.south`
- `fool.death.south`
- `enemy.clockHound.cast`
- `enemy.clockHound.hit`
- `enemy.clockHound.death`
- `enemy.mirrorShade.cast`
- `fx.cardProjectile`
- `fx.cardImpact`
- `prop.cafeSteam`
- `prop.potionBottleGlow`
