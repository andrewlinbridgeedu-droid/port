"""Hero v4: a re-tailored long-coat hero built in Blender from parametric,
quad-based garments, painted textures and the shared 28-bone skeleton.
Three outfits share the body, hair, hands, trousers, boots, skeleton and clips.

Blender -b --python tools/animation/build_hero_v4.py -- <repository>
    [--preview <dir>]      review renders (Blender toon preview, not Unity, not iPhone)
    [--outfits night,...]  subset for quick iterations
    [--textures <dir>]     where painted atlases go (default: the v4 doc folder)
    [--export]             rig, animate and write the Unity FBX + material manifest
"""
import bpy, sys, math, json, importlib, hashlib
from pathlib import Path
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
ROOT = Path(argv[0]).resolve()
sys.path.insert(0, str(ROOT / 'tools/animation'))
import hero_v4
from hero_v4 import (geom, skeleton, coat, lower, looks, hair, hands, details, paint, filigree, atlas,
                     textures)
for m in (geom, skeleton, coat, lower, looks, hair, hands, details, paint, filigree, atlas, textures):
    importlib.reload(m)


def arg(name, default=None):
    return argv[argv.index(name) + 1] if name in argv else default


DOC = ROOT / 'docs/development/hero-refinement-20261001/v4'
PREVIEW = arg('--preview')
TEX = Path(arg('--textures', str(DOC / 'textures')))
TEX.mkdir(parents=True, exist_ok=True)

BASE_TAIL = dict(tip_z=17.0, side_rise=24.0, vent_rise=6.0, vent_open=math.radians(44), flare_x=41.0,
                 flare_back=31.0, flare_front=18.0, fold=3.0, tip_swing=8.0, hang=4.5)
STYLES = {
    'night': dict(BASE_TAIL, id='mistport-night', coat=(0.11, 0.10, 0.135), lining=(0.43, 0.24, 0.70),
                  gem=(0.62, 0.24, 0.86), sash=(0.20, 0.58, 0.58), coat_shade=(0.52, 0.47, 0.68)),
    'starlight': dict(BASE_TAIL, id='starlight-magician', coat=(0.92, 0.89, 0.83), lining=(0.15, 0.21, 0.47),
                      gem=(0.22, 0.47, 0.92), sash=(0.42, 0.68, 0.90), coat_shade=(0.78, 0.79, 0.90),
                      glove=(0.93, 0.92, 0.90),
                      tip_z=13.0, side_rise=26.0, flare_x=38.0, flare_back=29.0, fold=2.6, tip_swing=6.5,
                      capelet=True),
    'carnival': dict(BASE_TAIL, id='midnight-carnival', coat=(0.12, 0.07, 0.08), lining=(0.66, 0.10, 0.14),
                     gem=(0.86, 0.14, 0.18), sash=(0.70, 0.12, 0.14), coat_shade=(0.55, 0.45, 0.62),
                     tip_z=22.0, side_rise=19.0, flare_x=43.0, flare_back=33.0, fold=3.2, tip_swing=9.0,
                     second_phi=92.0, second_z=30.0, second_slope=0.55, epaulettes=True),
}
ONLY = arg('--outfits')
OUTFITS = ONLY.split(',') if ONLY else list(STYLES)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

common_mat = {
    'skin': looks.toon('V4 Skin', (0.96, 0.82, 0.74), shade=(0.86, 0.68, 0.70), rim=0.1),
    'trousers': looks.toon('V4 Trousers', (0.12, 0.11, 0.14), shade=(0.52, 0.47, 0.68)),
    'leather': looks.toon('V4 Leather', (0.10, 0.08, 0.09), shade=(0.55, 0.50, 0.65), gloss=0.35),
    'sole': looks.toon('V4 Sole', (0.20, 0.14, 0.11), shade=(0.6, 0.5, 0.6)),
    'glove': looks.toon('V4 Glove', (0.13, 0.11, 0.14), shade=(0.55, 0.50, 0.65), gloss=0.12, rim=0.12),
    'lace': looks.toon('V4 Lace', (0.95, 0.93, 0.90), shade=(0.72, 0.70, 0.82)),
    'gold': looks.toon('V4 Gold', (0.86, 0.66, 0.30), shade=(0.62, 0.48, 0.42), gloss=0.55),
}
hair_img = textures.paint_hair(TEX / 'hair.png')
common_mat['hair'] = looks.toon('V4 Hair', (1, 1, 1), shade=(0.55, 0.48, 0.78), rim=0.3, image=hair_img)
common_mat['hair_cap'] = looks.toon('V4 HairCap', (0.09, 0.08, 0.15), shade=(0.55, 0.48, 0.78), rim=0.2)

MATERIAL_SPECS = {}


def remember(m, texture=None):
    spec = m['toon'].to_dict()
    if texture:
        spec['texture'] = texture
    MATERIAL_SPECS[m.name] = spec
    return m


for m in common_mat.values():
    remember(m, 'hair.png' if m.name == 'V4 Hair' else None)

# ------------------------------------------------------------------ common body
common = []
common.append(lower.build_head(common_mat['skin']))
clumps, scalp = hair.build_hair(common_mat['hair'])
for c in clumps:
    geom.solidify(c, 0.32, offset=-1.0)
common.extend(clumps)
scalp.data.materials[0] = common_mat['hair_cap']
common.append(scalp)
common.append(lower.build_neck(common_mat['skin']))
common.extend(lower.build_ears(common_mat['skin']))
common.append(lower.build_pelvis(common_mat['trousers']))
for sign in (1, -1):
    ruffle = hands.build_ruffle(sign, common_mat['lace'])
    geom.solidify(ruffle, 0.12, offset=0.0)
    common.append(ruffle)
    common.append(lower.build_trouser_leg(sign, common_mat['trousers']))
    common.append(lower.build_boot_foot(sign, common_mat['leather']))
    shaft, shaft_pts = lower.build_boot_shaft(sign, common_mat['leather'])
    common.append(shaft)
    common.extend(details.boot_hardware(sign, common_mat, shaft_pts))
    common.append(lower.build_sole(sign, common_mat['sole']))
common.extend(details.thigh_strap(1, common_mat))
for ob in common:
    ob.name = 'Common ' + ob.name

# ------------------------------------------------------------------ outfits
outfit_parts = {}
for key in OUTFITS:
    style = STYLES[key]
    pre = f'Outfit-{key}-'
    mat = dict(common_mat)
    mat['coat'] = looks.toon(f'V4 {key} Coat', style['coat'], shade=style['coat_shade'], rim=0.22)
    mat['lining'] = looks.toon(f'V4 {key} Lining', style['lining'], shade=(0.62, 0.55, 0.80))
    mat['gem'] = remember(looks.toon(f'V4 {key} Gem', style['gem'], shade=(0.55, 0.45, 0.75), gloss=0.8,
                                     gloss_color=(1, 0.92, 1)))
    mat['sash'] = remember(looks.toon(f'V4 {key} Sash', style['sash'], shade=(0.60, 0.62, 0.80)))
    parts = []
    if 'glove' in style:
        glove = remember(looks.toon(f'V4 {key} Glove', style['glove'], shade=(0.74, 0.74, 0.86), rim=0.1))
    else:
        glove = common_mat['glove']
    for sign in (1, -1):
        hand_obs, _ = hands.build_hand(sign, glove)
        parts.extend(hand_obs)
    torso, rings = coat.build_torso(mat['coat'])
    parts.append(torso)
    col, col_top, col_fl, col_fr = coat.collar(mat['coat'])
    col.data.materials.append(mat['lining'])
    geom.solidify(col, 0.45, offset=-1.0, material_offset=1)
    parts.append(col)
    parts.append(geom.tube('Collar piping', col_top, 0.22, mat['gold'], sides=6))
    tails = {}
    for side in ('L', 'R'):
        tail, edges, shape = coat.build_tail(side, style, mat['coat'])
        tails[side] = (tail, edges)
        tail.data.materials.append(mat['lining'])
        geom.solidify(tail, 0.38, offset=-1.0, material_offset=1)
        parts.append(tail)
        for k in ('vent', 'hem', 'front'):
            parts.append(geom.tube('Tail piping', edges[k], 0.26, mat['gold'], sides=6))
        parts.append(geom.tube('Waist seam', edges['waist'], 0.22, mat['gold'], sides=6))
        facing, f_outer, f_fold = coat.build_facing(side, style, mat['lining'])
        geom.solidify(facing, 0.25, offset=-1.0)
        parts.append(facing)
        parts.append(geom.tube('Facing piping', f_outer, 0.22, mat['gold'], sides=6))
    holes = {}
    for sign in (1, -1):
        sl, path, end_ring, hole_ring = coat.build_sleeve(sign, mat['coat'])
        holes[sign] = hole_ring
        parts.append(sl)
        cuff, rim, root = coat.build_cuff(sign, mat['coat'])
        cuff.data.materials.append(mat['coat'])
        geom.solidify(cuff, 0.35, offset=-1.0, material_offset=1)
        parts.append(cuff)
        parts.append(geom.tube('Cuff piping', rim, 0.22, mat['gold'], sides=6))
        parts.append(geom.tube('Cuff piping', root, 0.22, mat['gold'], sides=6))
    parts.extend(details.build_details(parts, mat, style, torso, tails, holes, key))
    parts.extend(details.earrings(mat))
    cape_hem_uv = None
    if style.get('capelet'):
        cape, cape_hem, cape_sides = coat.build_capelet(mat['coat'])
        cape.data.materials.append(mat['lining'])
        geom.solidify(cape, 0.32, offset=-1.0, material_offset=1)
        cape_hem_uv = cape['hem_uv']
        parts.append(cape)
        parts.append(geom.tube('Cape piping', cape_hem, 0.24, mat['gold'], sides=6))
        for edge in cape_sides:
            parts.append(geom.tube('Cape piping', edge, 0.22, mat['gold'], sides=6))
    if style.get('epaulettes'):
        parts.extend(details.epaulettes(mat, holes))
    # Painted atlases replace the flat coat and lining colours.
    coat_png, lining_png = f'{key}-coat.png', f'{key}-lining.png'
    coat_img = textures.paint_coat(key, tails['L'][0]['hem_uv'], TEX / coat_png, cape_hem_uv=cape_hem_uv)
    lining_img = textures.paint_lining(key, TEX / lining_png)
    coat_tex = remember(looks.toon(f'V4 {key} CoatAtlas', (1, 1, 1), shade=style['coat_shade'], rim=0.22,
                                   image=coat_img), coat_png)
    lining_tex = remember(looks.toon(f'V4 {key} LiningAtlas', (1, 1, 1), shade=(0.62, 0.55, 0.80),
                                     image=lining_img), lining_png)
    for ob in parts:
        for i, m in enumerate(ob.data.materials):
            if m == mat['coat']:
                ob.data.materials[i] = coat_tex
            elif m == mat['lining']:
                ob.data.materials[i] = lining_tex
    bpy.data.materials.remove(mat['coat'])
    bpy.data.materials.remove(mat['lining'])
    for ob in parts:
        ob.name = pre + ob.name
    outfit_parts[key] = parts


def show_only(key):
    for k, obs in outfit_parts.items():
        for ob in obs:
            ob.hide_render = k != key
            ob.hide_viewport = k != key


def preview(out_dir):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    meshes = [o for o in scene.objects if o.type == 'MESH']
    mods = [(o, looks.add_outline(o, 0.20 if 'piping' not in o.name.lower() and 'fringe' not in o.name.lower()
                                  else 0.07)) for o in meshes]
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 900
    scene.render.resolution_y = 1350
    scene.view_settings.view_transform = 'Standard'
    world = bpy.data.worlds.new('Preview')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs[0].default_value = (0.42, 0.44, 0.48, 1)
    scene.world = world
    sun = bpy.data.lights.new('Key', 'SUN')
    sun.energy = 3.0
    so = bpy.data.objects.new('Key', sun)
    scene.collection.objects.link(so)
    so.rotation_euler = (math.radians(50), math.radians(-25), math.radians(200))
    cam_d = bpy.data.cameras.new('Preview')
    cam = bpy.data.objects.new('Preview', cam_d)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam_d.lens = 85
    target = Vector((0, 4, 92))
    views = {'rear': Vector((0, 560, 150)), 'quarter': Vector((330, 460, 140)), 'side': Vector((560, 30, 120))}
    for key in outfit_parts:
        show_only(key)
        for name, loc in views.items():
            cam.location = loc
            cam.rotation_euler = (target - loc).to_track_quat('-Z', 'Y').to_euler()
            scene.render.filepath = str(out / f'{key}-{name}.png')
            bpy.ops.render.render(write_still=True)
    for o, m in mods:
        o.modifiers.remove(m)
    for o in [so, cam]:
        bpy.data.objects.remove(o)
    print('HERO_V4_PREVIEW', out)


if PREVIEW:
    preview(PREVIEW)

(TEX / 'materials.json').write_text(json.dumps(MATERIAL_SPECS, indent=2, sort_keys=True) + '\n')
