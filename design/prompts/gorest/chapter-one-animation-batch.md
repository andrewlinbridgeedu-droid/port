# Chapter One Gorest Animation Batch

Use these prompts inside Codex while working in `tools/gorest`. Generate one complete spritesheet per prompt, then preview it in gorest before importing it into the iOS project.

Global art rule:

Bright Japanese fantasy mobile game painting, clear anime linework, rich but controlled color, brass clockwork details, teal and violet accents, warm amber highlights, restrained magical glow under 5 percent of the composition. Transparent background for spritesheets. No UI, no labels, no scenery, no poster composition.

Global technical rule:

Generate the full sheet in one pass. Keep every frame the same size. Use a stable bottom-center foot anchor. Keep the character scale, head direction, costume, silhouette, and palette consistent across every frame.

## Player: Fool Path

### fool.idle.south.v1

Create a 4-frame transparent PNG spritesheet, 4 columns by 1 row, 256x256 per frame. Character: young adult male fantasy trickster adventurer, black coat with restrained purple lining, small tarot-mask ornament at waist, dark boots, slim but athletic build. Facing south / camera-front three-quarter. Idle animation: almost still, only subtle breathing, coat edge and hair move slightly. Feet must stay locked. No walking, no swaying side to side.

### fool.walk.south.v1

Create an 8-frame transparent PNG spritesheet, 4 columns by 2 rows, 256x256 per frame. Same character and outfit as `fool.idle.south.v1`. Facing south / camera-front three-quarter. Natural walk cycle, not floating, visible alternating foot contact, knees bend slightly, coat follows the step. Head stays facing the walking direction. Feet must contact the same ground anchor line.

### fool.attack.card.south.v1

Create an 8-frame transparent PNG spritesheet, 4 columns by 2 rows, 256x256 per frame. Same character. Facing south / camera-front three-quarter. Action: draws a tarot card from one hand, pivots shoulders, flicks card forward, coat snaps lightly, then recovers. Keep the magic restrained: a tiny violet-gold edge glow on the card only.

### fool.skill.misdirect.south.v1

Create a 12-frame transparent PNG spritesheet, 4 columns by 3 rows, 256x256 per frame. Same character. Facing south / camera-front three-quarter. Action: raises one hand, creates two faint afterimages, steps diagonally half a body width, then points forward. Make the illusion readable but subtle, no large screen-filling effects.

### fool.hit.south.v1

Create a 4-frame transparent PNG spritesheet, 4 columns by 1 row, 256x256 per frame. Same character. Facing south / camera-front three-quarter. Action: brief recoil from a hit, shoulder turns, one foot slides back slightly, coat reacts, then stabilizes. Feet still use the same anchor line.

### fool.death.south.v1

Create an 8-frame transparent PNG spritesheet, 4 columns by 2 rows, 256x256 per frame. Same character. Facing south / camera-front three-quarter. Action: loses balance, drops to one knee, coat settles, card falls from hand. Keep it game-readable and non-gory.

## Enemies

### enemy.clockhound.cast.v1

Create an 8-frame transparent PNG spritesheet, 4 columns by 2 rows, 256x256 per frame. Enemy: brass-and-blue clockwork hound, low mechanical body, glass lens eyes, small gear spine. Fixed-position cast animation: paws lock to ground, chest gear spins, muzzle emits a tiny amber clock glyph, then releases. No locomotion.

### enemy.clockhound.hit.v1

Create a 4-frame transparent PNG spritesheet, 4 columns by 1 row, 256x256 per frame. Same clockwork hound. Fixed-position hit reaction: body compresses, gear sparks briefly, head dips, then returns. No movement across the frame.

### enemy.clockhound.death.v1

Create an 8-frame transparent PNG spritesheet, 4 columns by 2 rows, 256x256 per frame. Same clockwork hound. Death animation: gears stall, body lowers, blue light fades, small parts loosen. No explosion, no gore.

### enemy.mirrorshade.cast.v1

Create an 8-frame transparent PNG spritesheet, 4 columns by 2 rows, 256x256 per frame. Enemy: elegant mirror-shadow humanoid silhouette, silver mask, violet-blue translucent cloak. Fixed-position cast animation: raises one arm, mirror shard forms in front of hand, shard launches. Keep body mostly still.

## Combat Effects

### fx.cardProjectile.v1

Create a 12-frame transparent PNG spritesheet, 4 columns by 3 rows, 192x192 per frame. A spinning tarot card projectile with thin gold edge, violet trail, small spark particles. The card travels left-to-right inside each frame but remains centered enough for SpriteKit positioning. No text, no character.

### fx.cardImpact.v1

Create an 8-frame transparent PNG spritesheet, 4 columns by 2 rows, 192x192 per frame. A small tarot-card impact burst: warning glint, sharp violet-gold flash, tiny paper-card fragments, then fading circular glyph residue. Keep glow restrained and readable.

### fx.clockWarningCircle.v1

Create an 8-frame transparent PNG spritesheet, 4 columns by 2 rows, 192x192 per frame. A clockwork warning circle on transparent background: brass ring, small ticking marks, faint blue inner glow, pulse once, then fade. No text.

## Venue Props

### prop.cafeSteam.v1

Create a 16-frame transparent PNG spritesheet, 4 columns by 4 rows, 192x192 per frame. Subtle magical coffee steam loop, warm white steam with tiny violet star motes and two faint butterfly shapes. Very soft motion. No cup, no table, no background.

### prop.potionBottleGlow.v1

Create a 16-frame transparent PNG spritesheet, 4 columns by 4 rows, 192x192 per frame. Small glass potion bottle glow loop, amber liquid, teal rim light, tiny bubbles rising inside, restrained sparkle. Transparent background.
