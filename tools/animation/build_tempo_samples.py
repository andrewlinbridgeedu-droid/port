"""Original keyframe animation, authored in Blender; no downloaded motion.

Blender -b --python tools/animation/build_tempo_samples.py -- <repo-root>
Keeps the existing skin/rest hierarchy. FBX contains an animation library;
Unity's sample-only controller consumes it, leaving other battles unchanged.
"""
import bpy
import math
import json
import sys
from pathlib import Path
from mathutils import Vector, Quaternion

FPS = 60
ROOT = Path(sys.argv[sys.argv.index('--') + 1]).resolve()
OUT = ROOT / 'UnityBattleSource/Assets/Resources/CombatTempo/Animation'
AUTHOR = ROOT / 'docs/development/combat-tempo-20261001/animation'
SOURCES = {
    'Hound': 'Models/HellHound/Meshy_AI_Emberwolf_quadruped/Meshy_AI_Emberwolf_quadruped_Animation_Walking_frame_rate_60.fbx',
    'Stonejaw': 'Resources/Enemies/Signature/Stonehide/Stonehide_Combat.fbx',
    'Hollow': 'Resources/Enemies/Signature/BountyB01/B01_Combat.fbx',
    'Hero': 'Models/Fool/Meshy_AI_battle_magician_rig_biped_Animation_Combat_Stance_frame_rate_60.fbx',
}


def turn(rig, name, pitch=0, yaw=0, roll=0):
    """Rotate around the rig's anatomical axes, converted to each bone's basis."""
    bone = rig.pose.bones.get(name)
    if not bone:
        return
    basis = bone.bone.matrix_local.to_quaternion()
    delta = (Quaternion(Vector((1, 0, 0)), math.radians(pitch)) @
             Quaternion(Vector((0, 0, 1)), math.radians(yaw)) @
             Quaternion(Vector((0, 1, 0)), math.radians(roll)))
    bone.rotation_mode = 'QUATERNION'
    bone.rotation_quaternion = basis.inverted() @ delta @ basis


def shift(rig, name, amount):
    bone = rig.pose.bones[name]
    bone.location = bone.bone.matrix_local.to_quaternion().inverted() @ Vector(amount)


def jaw(rig):
    # The imported quadruped has no jaw joint. Split the lower muzzle's existing
    # head weights, without changing vertices or torso/leg weights.
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    bone = rig.data.edit_bones.new('Jaw')
    bone.head = (0, .238, .136)
    bone.tail = (0, .219, .17)
    bone.parent = rig.data.edit_bones['head']
    bpy.ops.object.mode_set(mode='OBJECT')
    count = 0
    for mesh in [x for x in bpy.context.scene.objects if x.type == 'MESH']:
        group = mesh.vertex_groups.new(name='Jaw')
        mapping = rig.matrix_world.inverted() @ mesh.matrix_world
        for vertex in mesh.data.vertices:
            p = mapping @ vertex.co
            if p.z < .127 or p.y > .240 or p.y < .197:
                continue
            donors = [(g.group, g.weight) for g in vertex.groups
                      if mesh.vertex_groups[g.group].name in ('head', 'headend')]
            weight = sum(w for _, w in donors)
            if weight < .2:
                continue
            influence = min(1, max(0, (.241 - p.y) / .015))
            for index, w in donors:
                mesh.vertex_groups[index].add([vertex.index], w * (1 - influence), 'REPLACE')
            group.add([vertex.index], weight * influence, 'REPLACE')
            count += 1
    return count


def spring_bones(rig, kind):
    if kind != 'Hero':
        return
    # A small lower-coat region gets its own two controls. The existing vertices
    # are reused; the author's skin is not replaced by a rigid prop.
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    for side, x in [('L', 12), ('R', -12)]:
        b = rig.data.edit_bones.new('Coat.' + side)
        b.head, b.tail = (x, 10, 95), (x, 12, 53)
        b.parent = rig.data.edit_bones['Hips']
    bpy.ops.object.mode_set(mode='OBJECT')
    for mesh in [x for x in bpy.context.scene.objects if x.type == 'MESH']:
        groups = {side: mesh.vertex_groups.new(name='Coat.' + side) for side in ('L', 'R')}
        mapping = rig.matrix_world.inverted() @ mesh.matrix_world
        for vertex in mesh.data.vertices:
            p = mapping @ vertex.co
            if not (53 < p.z < 93 and p.y > 14):
                continue
            donors = [(g.group, g.weight) for g in vertex.groups
                      if mesh.vertex_groups[g.group].name == 'Hips']
            for index, w in donors:
                influence = min(.7, (93 - p.z) / 48)
                mesh.vertex_groups[index].add([vertex.index], w * (1 - influence), 'REPLACE')
                groups['L' if p.x > 0 else 'R'].add([vertex.index], w * influence, 'REPLACE')


def shape(t, center, width):
    return max(0, 1 - abs(t - center) / width)


def pose(rig, kind, clip, t, duration):
    p = t / duration
    for b in rig.pose.bones:
        b.location = (0, 0, 0)
        b.rotation_mode = 'QUATERNION'
        b.rotation_quaternion = (1, 0, 0, 0)
        b.scale = (1, 1, 1)
    idle = clip == 'BattleIdle'
    wind = shape(p, .27, .27)
    hit = shape(p, .58, .20)
    recoil = shape(p, .80, .18)
    if clip == 'HeavyPrepare':
        wind, hit, recoil = min(1, p / .35), 0, 0
    if clip == 'HitAdditive' or clip == 'Hit':
        wind, hit, recoil = 0, shape(p, .18, .18), shape(p, .65, .34)
    breath = math.sin(p * math.tau)
    if kind == 'Hound':
        # Anatomical rig is Y-up/Z-forward before FBX object conversion.
        if idle:
            turn(rig, 'chest', breath * 1.6)
            turn(rig, 'head', -2 + breath * .9)
            for i in range(1, 4):
                turn(rig, 'tail' + str(i), 0, 0, math.sin(p * math.tau - i * .7) * 4)
            return
        if clip == 'Opening':
            turn(rig, 'head', 0, 0, math.sin(t * 5) * 13 * math.sin(p * math.pi))
            turn(rig, 'chest', 4, 0, math.sin(p * math.pi) * 5)
            turn(rig, 'frontleg', 0, 0, -8 * math.sin(p * math.pi))
            turn(rig, 'R_frontleg', 0, 0, 8 * math.sin(p * math.pi))
            return
        heavy = clip in ('HeavyPrepare', 'HeavyRelease', 'HeavyReleaseSecond', 'Pounce')
        probe = clip == 'Probe'
        turn(rig, 'chest', -9 * wind + 12 * hit - 3 * recoil)
        turn(rig, 'head', (-15 if probe else -20) * wind + 20 * hit - 5 * recoil)
        turn(rig, 'Jaw', (25 if probe else 30) * max(wind * .75, hit))
        if clip == 'HeavyReleaseSecond':
            turn(rig, 'chest', -9 * wind + 17 * hit, 0, 5 * hit)
            turn(rig, 'head', -20 * wind + 24 * hit, 0, -7 * hit)
        for name in ('frontleg', 'R_frontleg'):
            turn(rig, name, 17 * wind - 12 * hit + 4 * recoil)
            turn(rig, name + '0', -23 * wind + 15 * hit)
        for name in ('backleg', 'R_backleg'):
            turn(rig, name, -8 * wind + 11 * hit)
            turn(rig, name + '0', 12 * wind - 15 * hit)
        # Actual root motion curve; Unity extracts it onto the visual child only.
        shift(rig, 'Hips', (0, -.008 * wind + .005 * hit,
              (.045 if heavy else .022) * hit - .008 * recoil))
        for i in range(1, 4):
            turn(rig, 'tail' + str(i), -8 * wind + 5 * recoil, 0, 2 * recoil)
        if clip == 'HitAdditive':
            turn(rig, 'head', -12 * hit)
            turn(rig, 'chest', -8 * hit, 0, 3 * hit)
        return
    if kind in ('Stonejaw', 'Hollow'):
        stone = kind == 'Stonejaw'
        if idle:
            turn(rig, 'Chest', breath * (1.4 if stone else .7))
            turn(rig, 'Head', -breath * .8)
            return
        turn(rig, 'Pelvis', -5 * wind + 6 * hit)
        turn(rig, 'Chest', (-12 if stone else -7) * wind + (23 if stone else 9) * hit,
             (7 if stone else 19) * wind - (5 if stone else 26) * hit)
        turn(rig, 'Head', 8 * wind - 9 * hit)
        for side, sign in [('L', 1), ('R', -1)]:
            amplitude = 1 if stone or side == 'R' else .42
            turn(rig, 'UpperArm.' + side, (-54 * wind + 31 * hit) * amplitude,
                 0, sign * (12 * wind - 8 * hit))
            turn(rig, 'Forearm.' + side, -34 * wind + 21 * hit)
            turn(rig, 'Thigh.' + side, 9 * wind - 7 * hit)
            turn(rig, 'Shin.' + side, -13 * wind + 10 * hit)
        shift(rig, 'Root', (0, -.10 * hit + .025 * recoil, 0))
        if clip == 'HitAdditive':
            turn(rig, 'Chest', -11 * hit, 4 * hit)
            turn(rig, 'Head', -8 * hit)
        return
    # Hero uses the imported centimetre rig. The three basics have different
    # torso/arm sequencing, rather than recolouring one generic cast.
    if idle:
        turn(rig, 'Spine', breath * 1.1)
        turn(rig, 'Head', breath * .4)
        for side, sign in [('L', 1), ('R', -1)]:
            turn(rig, 'Coat.' + side, math.sin(p * math.tau - sign * .6) * 2)
        return
    slash, thrust, card = clip == 'BasicSlash', clip == 'Thrust', clip == 'Card'
    parry, cast = clip == 'Parry', clip == 'CastPrepare'
    turn(rig, 'Spine', -5 * wind + 7 * hit,
         (24 if slash else 10) * wind - (38 if slash else 16) * hit)
    turn(rig, 'RightArm', (-38 if thrust else -24) * wind + (51 if thrust else 18) * hit,
         (16 if slash else -10) * wind, -28 * wind + (47 if card else 20) * hit)
    turn(rig, 'RightForeArm', -36 * wind + (48 if thrust else 26) * hit)
    turn(rig, 'RightHand', 0, 12 * wind - 28 * hit, 14 * hit)
    turn(rig, 'LeftArm', -18 * wind + 9 * hit, 0, 12 * wind)
    turn(rig, 'LeftForeArm', -26 * wind + 10 * hit)
    shift(rig, 'Hips', (0, -3 * hit + .8 * recoil, -1.5 * wind))
    if parry or cast:
        hold = shape(p, .50, .48)
        turn(rig, 'LeftArm', -48 * hold, -18 * hold, 24 * hold)
        turn(rig, 'LeftForeArm', -57 * hold)
        turn(rig, 'RightArm', -31 * hold, 12 * hold, -15 * hold)
        turn(rig, 'RightForeArm', -39 * hold)
    if clip == 'Hit':
        turn(rig, 'Spine', -13 * hit, 0, -4 * hit)
        turn(rig, 'Head', -9 * hit)
        turn(rig, 'RightArm', -9 * hit)
    for side, sign in [('L', 1), ('R', -1)]:
        turn(rig, 'Coat.' + side, -6 * hit + 3 * recoil, 0, sign * 4 * recoil)


def build(kind, source):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(ROOT / 'UnityBattleSource/Assets' / source))
    rig = next(x for x in bpy.context.scene.objects if x.type == 'ARMATURE')
    walking = rig.animation_data.action.copy() if kind == 'Hound' and rig.animation_data else None
    rig.animation_data_clear()
    for action in list(bpy.data.actions):
        if action != walking:
            bpy.data.actions.remove(action)
    if walking:
        walking.name = 'Walking'
        walking.use_fake_user = True
    if kind == 'Stonejaw':
        # Original feet were Root children: repair the two-bone chains while
        # preserving their rest coordinates and all skin groups for foot IK.
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.mode_set(mode='EDIT')
        for side in ('L', 'R'):
            rig.data.edit_bones['Foot.' + side].parent = rig.data.edit_bones['Shin.' + side]
        bpy.ops.object.mode_set(mode='OBJECT')
    jaw_vertices = jaw(rig) if kind == 'Hound' else 0
    spring_bones(rig, kind)
    clips = [('BattleIdle', 2.4), ('Light', .60), ('HeavyPrepare', 2),
             ('HeavyRelease', .78), ('HitAdditive', .42)]
    if kind == 'Hound':
        clips += [('Pounce', .90), ('Probe', .65), ('Opening', 3), ('HeavyReleaseSecond', .78)]
    if kind == 'Hero':
        clips = [('BattleIdle', 2.4), ('BasicSlash', .70), ('Thrust', .70),
                 ('Card', .70), ('Hit', .42), ('Parry', .45), ('CastPrepare', .80)]
    bpy.context.scene.render.fps = FPS
    manifest = []
    for name, duration in clips:
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        rig.animation_data_create().action = action
        end = round(duration * FPS)
        for frame in range(end + 1):
            bpy.context.scene.frame_set(frame)
            pose(rig, kind, name, frame / FPS, duration)
            for bone in rig.pose.bones:
                bone.keyframe_insert('rotation_quaternion', frame=frame, group=bone.name)
                bone.keyframe_insert('location', frame=frame, group=bone.name)
        # Unity's Light clip is speed-adjusted so this authored contact pose
        # lands at exactly the shared rules' scheduled landsAtTick.
        manifest.append({'clip': name, 'frames': end + 1, 'seconds': duration,
                         'contactNormalized': .58 if name not in ('BattleIdle', 'HeavyPrepare', 'Opening') else None})
    rig.animation_data.action = bpy.data.actions['BattleIdle']
    bpy.context.scene.frame_start, bpy.context.scene.frame_end = 0, 144
    bpy.context.scene.frame_set(0)
    AUTHOR.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(AUTHOR / (kind + '.blend')))
    bpy.ops.export_scene.fbx(filepath=str(OUT / (kind + '.fbx')),
        object_types={'ARMATURE', 'MESH'}, add_leaf_bones=False,
        bake_anim=True, bake_anim_use_all_actions=True, bake_anim_use_nla_strips=False,
        bake_anim_simplify_factor=0, bake_anim_step=1, path_mode='AUTO',
        use_custom_props=False, axis_forward='-Z', axis_up='Y')
    return {'kind': kind, 'source': source, 'jawWeightedVertices': jaw_vertices,
            'bones': len(rig.data.bones), 'clips': manifest}


if __name__ == '__main__':
    report = [build(kind, source) for kind, source in SOURCES.items()]
    (AUTHOR / 'manifest.json').write_text(json.dumps(report, indent=2) + '\n')
    print('TEMPO_ANIMATION_COMPLETE', [(x['kind'], len(x['clips'])) for x in report])
