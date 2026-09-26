# Veiled Wanderer — Rodin single-image trial

Reference: `reference.png` (user-supplied, unchanged). Rodin workbench:
https://hyper3d.ai/workspace/rodin/03b62c22-c7db-48cc-a578-41828e618885

- `rodin-export.zip` is the original downloaded package.
- `base_basic_pbr.glb` is the preferred, unchanged Rodin model with embedded 2K diffuse, metallic/roughness and normal maps.
- `base_basic_shaded.glb` is Rodin's alternate baked-shaded export.
- `VeiledWanderer_Rodin.blend` is the PBR GLB imported and saved with Blender 5.2 for editing.
- `generation-record.json` records generation options and observed credit use.
- `inspect_rodin.py` reimports either GLB and renders four verification views.
- Review: `../../output/veiled-wanderer-rodin-20260922/index.html`.

Blender reimport found 96,310 triangles, one UV layer, three embedded 2048² PBR images, no armature and no animation. The character reads clearly from the front and oblique views, but the brim occludes the face and its pale projection artifacts need manual cleanup. The back is inferred from one frontal reference. This is a visual trial, not an approved game asset or a replacement for the earlier Blender trial.
