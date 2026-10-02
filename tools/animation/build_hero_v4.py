"""Hero v4: a re-tailored long-coat hero built in Blender from parametric,
quad-based garments, painted textures and the shared 28-bone skeleton.
Three outfits share the body, hair, hands, trousers, boots, skeleton and clips.

Blender -b --python tools/animation/build_hero_v4.py -- <repository>
    [--preview <dir>]      review renders (Blender toon preview, not Unity, not iPhone)
    [--outfits night,...]  subset for quick iterations
    [--textures <dir>]     where painted atlases go (default: the v4 doc folder)
    [--export]             rig, animate and write the Unity FBX + material manifest
"""
import bpy, sys, math, json, importlib, hashlib, shutil
from pathlib import Path
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
ROOT = Path(argv[0]).resolve()
sys.path.insert(0, str(ROOT / 'tools/animation'))
import hero_v4
from hero_v4 import (geom, skeleton, coat, lower, looks, hair, hands, details, paint, filigree, atlas,
                     textures, rig as rigmod)
for m in (geom, skeleton, coat, lower, looks, hair, hands, details, paint, filigree, atlas, textures, rigmod):
    importlib.reload(m)


def arg(name, default=None):
    return argv[argv.index(name) + 1] if name in argv else default


DOC = ROOT / 'docs/development/hero-refinement-20261001/v4'
PREVIEW = arg('--preview')
EXPORT = '--export' in argv
UNITY_OUT = Path(arg('--unity-out', str(ROOT / 'UnityBattleSource/Assets/Resources/CombatTempo/RefinedHeroV4')))
DETAIL = '--detail' in argv
TEX = Path(arg('--textures', str(DOC / 'textures')))
TEX.mkdir(parents=True, exist_ok=True)

# Back tails end in a point at their outer edge (as in the character art); the hem
# rises toward the vent, where the lining is turned back.
BASE_TAIL = dict(tip_z=15.0, hem_rise=20.0, vent_open=math.radians(42), out_deg=101.0, side_hem=23.0,
                 flare_x=41.0, flare_back=31.0, flare_front=22.0, fold=3.4, tip_swing=4.0, hang=3.6,
                 turnback=16.0, hem_vent=(10.0, 20.0), hem_outer=(36.0, 9.0), hem_bulge=4.0, side_flare=32.0)
STYLES = {
    'night': dict(BASE_TAIL, id='mistport-night', coat=(0.11, 0.10, 0.135), lining=(0.47, 0.30, 0.72),
                  gem=(0.62, 0.24, 0.86), sash=(0.20, 0.58, 0.58), coat_shade=(0.50, 0.45, 0.66)),
    'starlight': dict(BASE_TAIL, id='starlight-magician', coat=(0.93, 0.90, 0.84), lining=(0.47, 0.32, 0.74),
                      gem=(0.22, 0.47, 0.92), sash=(0.22, 0.62, 0.62), coat_shade=(0.74, 0.74, 0.88),
                      glove=(0.93, 0.92, 0.90), tip_z=10.0, hem_rise=24.0, flare_x=39.0, flare_back=30.0,
                      fold=3.8, tip_swing=8.0, capelet=True),
    'carnival': dict(BASE_TAIL, id='midnight-carnival', coat=(0.12, 0.08, 0.09), lining=(0.88, 0.82, 0.70),
                     gem=(0.86, 0.14, 0.18), sash=(0.66, 0.09, 0.12), coat_shade=(0.52, 0.44, 0.60),
                     tip_z=18.0, hem_rise=17.0, flare_x=43.0, flare_back=33.0, fold=4.4, tip_swing=10.0,
                     second_u=0.55, second_z=26.0, second_slope=0.5, epaulettes=True),
}
ONLY = arg('--outfits')
OUTFITS = ONLY.split(',') if ONLY else list(STYLES)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

P = looks.painted
common_mat = {
    'skin': P('V4 Skin', (0.97, 0.84, 0.76), shade=(0.88, 0.66, 0.66), kind='skin'),
    'trousers': P('V4 Trousers', (0.13, 0.12, 0.15), shade=(0.48, 0.44, 0.64), kind='cloth'),
    'leather': P('V4 Leather', (0.07, 0.06, 0.075), shade=(0.48, 0.44, 0.62), kind='leather'),
    'sole': P('V4 Sole', (0.22, 0.15, 0.12), shade=(0.56, 0.46, 0.56), kind='leather', gloss=0.2),
    'glove': P('V4 Glove', (0.14, 0.12, 0.15), shade=(0.50, 0.45, 0.62), kind='leather', gloss=0.35),
    'lace': P('V4 Lace', (0.96, 0.94, 0.91), shade=(0.74, 0.72, 0.86), kind='cloth'),
    'gold': P('V4 Gold', (0.80, 0.60, 0.26), shade=(0.58, 0.42, 0.36), kind='metal'),
}
hair_img = textures.paint_hair(TEX / 'hair.png')
common_mat['hair'] = P('V4 Hair', (1, 1, 1), shade=(0.50, 0.50, 0.72), image=hair_img, kind='hair')
common_mat['hair_cap'] = P('V4 HairCap', (0.07, 0.07, 0.11), shade=(0.50, 0.50, 0.72), kind='hair')

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
    hand_obs, _ = hands.build_hand(sign, common_mat['skin'])
    common.extend(hand_obs)
    ruffle = hands.build_ruffle(sign, common_mat['lace'])
    geom.solidify(ruffle, 0.12, offset=0.0)
    common.append(ruffle)
    common.append(lower.build_trouser_leg(sign, common_mat['trousers']))
    common.append(lower.build_boot_foot(sign, common_mat['leather']))
    shaft, shaft_pts = lower.build_boot_shaft(sign, common_mat['leather'])
    common.append(shaft)
    common.extend(details.boot_hardware(sign, common_mat, shaft_pts))
    common.extend(lower.build_sole(sign, common_mat['sole']))
common.extend(details.thigh_strap(1, common_mat))
for ob in common:
    ob.name = 'Common ' + ob.name

# ------------------------------------------------------------------ outfits
outfit_parts = {}
for key in OUTFITS:
    style = STYLES[key]
    pre = f'Outfit-{key}-'
    mat = dict(common_mat)
    mat['coat'] = P(f'V4 {key} Coat', style['coat'], shade=style['coat_shade'])
    mat['lining'] = P(f'V4 {key} Lining', style['lining'], shade=(0.62, 0.55, 0.80), kind='satin')
    mat['gem'] = remember(P(f'V4 {key} Gem', style['gem'], shade=(0.50, 0.42, 0.72), kind='gem'))
    mat['sash'] = remember(P(f'V4 {key} Sash', style['sash'], shade=(0.56, 0.60, 0.80), kind='satin'))
    parts = []
    torso, rings = coat.build_torso(mat['coat'])
    parts.append(torso)
    col, col_top, col_fl, col_fr = coat.collar(mat['coat'])
    col.data.materials.append(mat['lining'])
    geom.solidify(col, 0.45, offset=-1.0, material_offset=1)
    parts.append(col)
    parts.append(geom.tube('Collar piping', col_top, 0.22, mat['gold'], sides=6))
    tails = {}
    turnback_uv = None
    for side in ('L', 'R'):
        tail, edges, shape = coat.build_tail(side, style, mat['coat'])
        tails[side] = (tail, edges)
        tail.data.materials.append(mat['lining'])
        # Heavy cloth: a visible edge thickness instead of a paper-thin sheet.
        geom.solidify(tail, 0.75, offset=-1.0, material_offset=1)
        parts.append(tail)
        for k in ('vent', 'hem', 'outer'):
            parts.append(geom.tube('Tail piping', edges[k], 0.3, mat['gold'], sides=7))
        parts.append(geom.tube('Waist seam', edges['waist'], 0.24, mat['gold'], sides=6))
        skirt, s_edges = coat.build_side_skirt(side, style, mat['coat'])
        skirt.data.materials.append(mat['lining'])
        geom.solidify(skirt, 0.6, offset=-1.0, material_offset=1)
        parts.append(skirt)
        for k in ('hem', 'front'):
            parts.append(geom.tube('Skirt piping', s_edges[k], 0.26, mat['gold'], sides=6))
        facing, f_outer, f_fold, f_bottom = coat.build_facing(side, style, mat['lining'])
        if side == 'L':
            turnback_uv = facing['lower_uv']
        geom.solidify(facing, 0.45, offset=-1.0)
        parts.append(facing)
        parts.append(geom.tube('Facing piping', f_outer, 0.26, mat['gold'], sides=6))
    holes, cuff_points, sleeves = {}, {}, {}
    for sign in (1, -1):
        sl, path, end_ring, hole_ring = coat.build_sleeve(sign, mat['coat'])
        holes[sign] = hole_ring
        sleeves[sign] = sl
        parts.append(sl)
        cuff, rim, root = coat.build_cuff(sign, mat['coat'])
        cuff_points[sign] = root[len(root) // 2]
        cuff.data.materials.append(mat['coat'])
        geom.solidify(cuff, 0.35, offset=-1.0, material_offset=1)
        parts.append(cuff)
        parts.append(geom.tube('Cuff piping', rim, 0.22, mat['gold'], sides=6))
        parts.append(geom.tube('Cuff piping', root, 0.22, mat['gold'], sides=6))
    parts.extend(details.build_details(parts, mat, style, torso, tails, holes, key))
    parts.extend(details.earrings(mat))
    parts.extend(details.cuff_pendants(mat, cuff_points))
    for sign in (1, -1):
        parts.extend(details.boot_pendants(sign, mat))
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
    else:
        strap_mat = remember(P(f'V4 {key} Strap', style['coat'], shade=style['coat_shade'], kind='cloth'))
        parts.extend(details.shoulder_straps(mat, torso, sleeves, strap_mat))
    if key in ('carnival', 'starlight'):
        parts.extend(details.trouser_lines(mat, key))
    # Painted atlases replace the flat coat and lining colours.
    coat_png, lining_png = f'{key}-coat.png', f'{key}-lining.png'
    tail_uv = {k: [tuple(p) for p in tails['L'][0][k + '_uv']] for k in ('hem', 'end', 'start')}
    coat_img = textures.paint_coat(key, tail_uv, TEX / coat_png, cape_hem_uv=cape_hem_uv)
    lining_img = textures.paint_lining(key, TEX / lining_png, turnback=turnback_uv)
    coat_tex = remember(P(f'V4 {key} CoatAtlas', (1, 1, 1), shade=style['coat_shade'], image=coat_img,
                          kind='cloth'), coat_png)
    lining_tex = remember(P(f'V4 {key} LiningAtlas', (1, 1, 1), shade=(0.62, 0.55, 0.80), image=lining_img,
                            kind='satin'), lining_png)
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


# ------------------------------------------------------------------ rig
rig = rigmod.build_armature('HeroV4')
rigmod.skin(rig, [o for o in scene.objects if o.type == 'MESH'])
rigmod.pose(rig, 'BattleIdle', 0.0)


def show_only(key):
    for k, obs in outfit_parts.items():
        for ob in obs:
            ob.hide_render = k != key
            ob.hide_viewport = k != key


def preview(out_dir):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    meshes = [o for o in scene.objects if o.type == 'MESH']
    thin = ('piping', 'fringe', 'seam', 'chain', 'ring', 'frame', 'setting', 'scroll', 'bezel')
    mods = [(o, looks.add_outline(o, 0.05 if any(k in o.name.lower() for k in thin)
                                  else 0.06 if 'Hair' in o.name else 0.12)) for o in meshes]
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
    fill = bpy.data.lights.new('Fill', 'SUN')
    fill.energy = 0.7
    fill.color = (0.78, 0.84, 1.0)
    fo = bpy.data.objects.new('Fill', fill)
    scene.collection.objects.link(fo)
    fo.rotation_euler = (math.radians(70), math.radians(30), math.radians(-30))
    cam_d = bpy.data.cameras.new('Preview')
    cam = bpy.data.objects.new('Preview', cam_d)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam_d.lens = 85
    full = Vector((0, 4, 92))
    views = {'rear': (Vector((0, 560, 150)), full), 'quarter': (Vector((330, 460, 140)), full),
             'side': (Vector((560, 30, 120)), full)}
    if DETAIL:
        # Close-ups (target, camera offset) for detail review.
        views = {
            'd-head-rear': (Vector((0, 175, 175)), Vector((0, 8, 160))),
            'd-head-quarter': (Vector((120, 125, 172)), Vector((0, 8, 160))),
            'd-head-side': (Vector((175, 0, 165)), Vector((0, 6, 160))),
            'd-shoulders': (Vector((60, 220, 160)), Vector((0, 8, 132))),
            'd-hand': (Vector((95, 120, 105)), Vector((24, 0, 95))),
            'd-waist': (Vector((0, 230, 115)), Vector((0, 10, 96))),
            'd-hem': (Vector((60, 250, 60)), Vector((14, 14, 32))),
            'd-boots': (Vector((110, 150, 40)), Vector((0, 0, 12))),
        }
    for key in outfit_parts:
        show_only(key)
        for name, (loc, target) in views.items():
            cam.location = loc
            cam.rotation_euler = (target - loc).to_track_quat('-Z', 'Y').to_euler()
            scene.render.filepath = str(out / f'{key}-{name}.png')
            bpy.ops.render.render(write_still=True)
    for o, m in mods:
        o.modifiers.remove(m)
    for o in [so, fo, cam]:
        bpy.data.objects.remove(o)
    print('HERO_V4_PREVIEW', out)


def export(out_dir):
    """One skinned mesh per group (shared body and each outfit), 14 baked clips,
    the painted atlases and the material manifest Unity's importer reads."""
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    groups = {'Common Body': [o for o in scene.objects if o.type == 'MESH' and o.name.startswith('Common ')]}
    for key in outfit_parts:
        groups[f'Outfit-{key}-Body'] = [o for o in scene.objects if o.type == 'MESH' and o.name.startswith(f'Outfit-{key}-')]
    for name, obs in groups.items():
        for o in obs:
            o.hide_viewport = o.hide_render = False
        body = geom.join(obs, name)
        # Crease shading baked into vertex colour (Unity has no real-time AO here).
        body.data.color_attributes.new('AO', 'BYTE_COLOR', 'POINT')
        body.data.color_attributes.active_color = body.data.color_attributes['AO']
        with bpy.context.temp_override(active_object=body, object=body, selected_objects=[body],
                                       selected_editable_objects=[body]):
            bpy.context.view_layer.objects.active = body
            try:
                bpy.ops.paint.vertex_color_dirt(blur_strength=1.0, blur_iterations=2, clean_angle=3.14,
                                                dirt_angle=0.0, dirt_only=True, normalize=True)
            except Exception as error:
                print('HERO_V4_AO_SKIPPED', name, error)
    rigmod.bake_clips(rig)
    for png in TEX.glob('*.png'):
        shutil.copy2(png, out / png.name)
    items = [dict(spec, name=name) for name, spec in sorted(MATERIAL_SPECS.items())]
    (out / 'materials.json').write_text(json.dumps({'items': items}, indent=2) + '\n')
    fbx = out / 'HeroV4.fbx'
    bpy.ops.export_scene.fbx(filepath=str(fbx), object_types={'MESH', 'ARMATURE'}, add_leaf_bones=False,
                             bake_anim=True, bake_anim_use_all_actions=True, bake_anim_use_nla_strips=False,
                             bake_anim_simplify_factor=0, bake_anim_step=1, axis_forward='-Z', axis_up='Y',
                             global_scale=0.01, apply_unit_scale=True, mesh_smooth_type='FACE', path_mode='STRIP',
                             colors_type='LINEAR')
    meshes = [o for o in scene.objects if o.type == 'MESH']
    stats = {'fbx': fbx.name, 'bones': len(rig.data.bones), 'clips': [n for n, _ in rigmod.CLIPS],
             'renderers': [o.name for o in meshes],
             'triangles': {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes},
             'materials': sorted(MATERIAL_SPECS), 'outfits': [STYLES[k]['id'] for k in outfit_parts],
             'userVisualApproval': False}
    (DOC / 'manifest.json').write_text(json.dumps(stats, indent=2, ensure_ascii=False) + '\n')
    print('HERO_V4_EXPORTED', json.dumps({k: stats[k] for k in ('bones', 'renderers')}), sum(stats['triangles'].values()))


if PREVIEW:
    preview(PREVIEW)

(TEX / 'materials.json').write_text(json.dumps(MATERIAL_SPECS, indent=2, sort_keys=True) + '\n')
if EXPORT:
    export(UNITY_OUT)
