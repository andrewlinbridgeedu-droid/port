"""Armature, rule-based skin weights and the shared 14-clip action library.

Bone names, clip names and timings match v3 so Unity's controller and the runtime
(release at 0.58 of each cast) keep working. Units are centimetres; the FBX export
applies the 0.01 scale."""
import bpy, math
from mathutils import Vector, Quaternion
from . import skeleton as sk
from .geom import smoothstep

SPINE_KEYS = [(94.0, 'Hips'), (106.0, 'Spine02'), (119.0, 'Spine01'), (131.0, 'Spine'), (144.0, 'neck'),
              (156.0, 'Head')]


def build_armature(name='HeroV4'):
    data = bpy.data.armatures.new(name + ' shared skeleton')
    rig = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(rig)
    with bpy.context.temp_override(active_object=rig, object=rig, selected_objects=[rig],
                                   selected_editable_objects=[rig]):
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.mode_set(mode='EDIT')
        for bname, (h, t, parent) in sk.SPEC.items():
            b = data.edit_bones.new(bname)
            b.head, b.tail = h, t
            if parent:
                b.parent = data.edit_bones[parent]
        bpy.ops.object.mode_set(mode='OBJECT')
    return rig


# ---------------------------------------------------------------- weights
def _seg(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return t, (p - (a + ab * t)).length


def spine_w(z):
    if z <= SPINE_KEYS[0][0]:
        return {'Hips': 1.0}
    for (z0, a), (z1, b) in zip(SPINE_KEYS, SPINE_KEYS[1:]):
        if z <= z1:
            t = smoothstep(z0, z1, z)
            return {a: 1 - t, b: t}
    return {'Head': 1.0}


def chain_w(p, chain, blend=3.5):
    """Nearest bone of a limb chain, blended across each joint over `blend` cm."""
    best, best_d, best_t = 0, 1e9, 0.0
    for i, name in enumerate(chain):
        t, d = _seg(p, sk.head(name), sk.tail(name))
        if d < best_d - 1e-6:
            best, best_d, best_t = i, d, t
    name = chain[best]
    length = (sk.tail(name) - sk.head(name)).length
    s = best_t * length
    w = {name: 1.0}
    if best > 0 and s < blend:
        f = 0.5 - 0.5 * s / blend
        w = {chain[best - 1]: f, name: 1 - f}
    elif best < len(chain) - 1 and length - s < blend:
        f = 0.5 - 0.5 * (length - s) / blend
        w = {name: 1 - f, chain[best + 1]: f}
    return w


def _mix(a, b, k):
    out = {n: v * (1 - k) for n, v in a.items()}
    for n, v in b.items():
        out[n] = out.get(n, 0.0) + v * k
    return out


def _side(x):
    return 'Left' if x >= 0 else 'Right'


def _lr(x):
    return 'L' if x >= 0 else 'R'


def tail_w(p, hem_z=18.0):
    t = max(0.0, min(1.0, (100.5 - p.z) / (100.5 - hem_z)))
    s = _lr(p.x)
    hips = 1 - smoothstep(0.0, 0.3, t)
    tip = smoothstep(0.45, 0.85, t)
    coat = max(0.0, 1 - hips - tip)
    return {'Hips': hips, 'Coat.' + s: coat, 'CoatTip.' + s: tip}


def weights_for(ob, p):
    name = ob.name
    bind = ob.get('bind')
    x, z = p.x, p.z
    side = _side(x)
    arm = [side + 'Shoulder', side + 'Arm', side + 'ForeArm', side + 'Hand']
    leg = [side + 'UpLeg', side + 'Leg', side + 'Foot', side + 'Toe']
    if bind:
        if bind == 'spine':
            return spine_w(z)
        if bind == 'hips':
            return {'Hips': 1.0}
        if bind == 'head':
            return {'Head': 1.0}
        if bind.startswith('shoulder'):
            s = 'Left' if bind.endswith('L') else 'Right'
            return {s + 'Shoulder': 0.45, s + 'Arm': 0.55}
        if bind.startswith('tip'):
            return {'CoatTip.' + bind[-1]: 1.0}
        if bind.startswith('ribbon'):
            k = smoothstep(100.0, 88.0, z)
            return _mix({'Hips': 1.0}, {'Ribbon.' + bind[-1]: 1.0}, k)
        if bind.startswith('leg'):
            return chain_w(p, [s + n for s in ['Left' if bind.endswith('L') else 'Right'] for n in ('Leg', 'Foot', 'Toe')])
        if bind.startswith('upleg'):
            return {('Left' if bind.endswith('L') else 'Right') + 'UpLeg': 1.0}
        if bind.startswith('upperarm'):
            return {('Left' if bind.endswith('L') else 'Right') + 'Arm': 1.0}
        if bind.startswith('swag'):
            # From the yoke (torso) to the arm medallion (upper arm).
            s = 'Left' if bind.endswith('L') else 'Right'
            k = smoothstep(14.0, 21.0, abs(x))
            return _mix(spine_w(z), {s + 'Arm': 1.0}, k)
        if bind.startswith('strap'):
            s = 'Left' if bind.endswith('L') else 'Right'
            return _mix(spine_w(z), {s + 'Shoulder': 0.5, s + 'Arm': 0.5}, smoothstep(11.0, 18.0, abs(x)))
        if bind.startswith('legline'):
            s = 'Left' if bind.endswith('L') else 'Right'
            return _mix(chain_w(p, [s + 'UpLeg', s + 'Leg']), {'Hips': 1.0}, 0.5 * smoothstep(88.0, 96.0, z))
        if bind.startswith('forearm'):
            return {('Left' if bind.endswith('L') else 'Right') + 'ForeArm': 1.0}
    for key in ('Head', 'Hair', 'Ear'):
        if key in name:
            return {'Head': 1.0}
    if 'Neck' in name:
        return spine_w(z)
    if 'collar' in name.lower():
        return {'neck': 0.65, 'Spine': 0.35}
    if 'torso' in name or 'capelet' in name or 'Cape piping' in name or 'Princess' in name:
        w = spine_w(z)
        k = smoothstep(11.0, 17.5, abs(x)) * smoothstep(124.0, 138.0, z) * 0.7
        return _mix(w, {side + 'Shoulder': 0.6, side + 'Arm': 0.4}, k)
    if any(k in name for k in ('Sleeve', 'cuff', 'Cuff', 'ruffle', 'Glove', 'Hand', 'hand')):
        w = chain_w(p, arm, blend=4.0)
        # The sleeve head shares the torso near the armhole.
        k = smoothstep(17.5, 14.0, abs(x)) * smoothstep(126.0, 136.0, z) * 0.45
        return _mix(w, spine_w(z), k)
    if any(k in name for k in ('Coat tail', 'Facing', 'Tail piping', 'Facing piping', 'Waist seam', 'Pendant')):
        return tail_w(p)
    if 'Coat skirt' in name or 'Skirt piping' in name:
        return _mix({'Hips': 1.0}, {side + 'UpLeg': 1.0}, 0.55 * smoothstep(98.0, 60.0, z))
    if 'Trouser seat' in name:
        return _mix({'Hips': 1.0}, {side + 'UpLeg': 1.0}, 0.5 * smoothstep(92.0, 84.0, z))
    if 'Trouser leg' in name or 'Thigh' in name or 'Strap buckle' in name:
        w = chain_w(p, leg[:2])
        return _mix(w, {'Hips': 1.0}, 0.5 * smoothstep(88.0, 96.0, z))
    if any(k in name for k in ('Boot', 'Sole', 'Buckle')):
        return chain_w(p, leg[1:])
    return spine_w(z)


def skin(rig, objects):
    for ob in objects:
        if ob.type != 'MESH':
            continue
        groups = {}
        for v in ob.data.vertices:
            w = weights_for(ob, v.co)
            total = sum(w.values()) or 1.0
            for n, val in w.items():
                if val / total < 0.002:
                    continue
                g = groups.get(n) or ob.vertex_groups.new(name=n)
                groups[n] = g
                g.add([v.index], val / total, 'REPLACE')
        ob.parent = rig
        # Garment modifiers are already applied, so the armature deforms first and
        # preview outlines (added later) follow the posed surface.
        mod = ob.modifiers.new('Shared armature deformation', 'ARMATURE')
        mod.object = rig


# ---------------------------------------------------------------- posing
def turn(rig, name, pitch=0, yaw=0, roll=0):
    b = rig.pose.bones[name]
    basis = b.bone.matrix_local.to_quaternion()
    q = Quaternion(Vector((1, 0, 0)), math.radians(pitch)) @ Quaternion(Vector((0, 0, 1)), math.radians(yaw)) \
        @ Quaternion(Vector((0, 1, 0)), math.radians(roll))
    b.rotation_mode = 'QUATERNION'
    b.rotation_quaternion = basis.inverted() @ q @ basis


def aim(rig, name, target):
    b = rig.pose.bones[name]
    direction = Vector(target) - b.head
    q = (b.tail - b.head).normalized().rotation_difference(direction.normalized())
    m = (q @ b.matrix.to_quaternion()).to_matrix().to_4x4()
    m.translation = b.head
    b.matrix = m
    bpy.context.view_layer.update()


def arm(rig, side, target):
    s = 'Left' if side == 'L' else 'Right'
    a, b = rig.pose.bones[s + 'Arm'], rig.pose.bones[s + 'ForeArm']
    start = a.head.copy()
    d = Vector(target) - start
    dist = max(1.0, min(d.length, a.bone.length + b.bone.length - 0.2))
    axis = d.normalized()
    along = (a.bone.length ** 2 - b.bone.length ** 2 + dist ** 2) / (2 * dist)
    h = math.sqrt(max(0.0, a.bone.length ** 2 - along ** 2))
    # Elbows bend outward and a little back, as a relaxed arm does.
    hint = Vector((0.45 if side == 'L' else -0.45, 1.0, -0.2))
    hint = hint - axis * hint.dot(axis)
    aim(rig, s + 'Arm', start + axis * along + hint.normalized() * h)
    aim(rig, s + 'ForeArm', start + axis * dist)


def curve(points, p):
    keys = [0, .20, .34, .58, .72, 1]
    for i in range(5):
        if p <= keys[i + 1]:
            u = max(0, (p - keys[i]) / (keys[i + 1] - keys[i]))
            a, b = Vector(points[i]), Vector(points[i + 1])
            prev, nxt = Vector(points[max(0, i - 1)]), Vector(points[min(5, i + 2)])
            m0 = (b - prev) * .33 if i else Vector()
            m1 = (nxt - a) * .33 if i < 4 else Vector()
            return (2 * u ** 3 - 3 * u * u + 1) * a + (u ** 3 - 2 * u * u + u) * m0 + (-2 * u ** 3 + 3 * u * u) * b \
                + (u ** 3 - u * u) * m1
    return Vector(points[-1])


# Relaxed, ready stance: hands hang beside the thighs, the casting hand a little forward.
R = (-22.5, -1.5, 90.0)
L = (22.5, 3.5, 88.5)
GESTURES = {
    'CastMaskFlick': ([R, (-18, -8, 117), (-9, -16, 132), (-22, -29, 140), (-26, -19, 132), R],
                      [L, (20, 0, 106), (11, -9, 123), (16, -21, 132), (23, -9, 113), L]),
    'CastMaskTurn': ([R, (-25, -2, 121), (-5, -15, 137), (9, -24, 141), (-11, -21, 127), R],
                     [L, (21, 2, 103), (20, -7, 120), (25, -22, 134), (24, -7, 111), L]),
    'CastTwinSweep': ([R, (-10, -12, 128), (4, -14, 142), (-30, -18, 144), (-29, -5, 131), R],
                      [L, (9, -12, 125), (-5, -16, 139), (29, -19, 139), (27, 0, 115), L]),
    'CastTwinCross': ([R, (-25, -5, 125), (-25, -17, 145), (9, -27, 137), (-5, -19, 128), R],
                      [L, (24, -2, 114), (26, -17, 141), (-9, -28, 133), (5, -17, 119), L]),
    'CastFinaleLift': ([R, (-17, -8, 122), (-11, -17, 149), (-15, -6, 165), (-24, -18, 150), R],
                       [L, (15, -7, 112), (11, -14, 142), (17, -7, 157), (27, -13, 137), L]),
    'CastFinaleThrow': ([R, (-20, -5, 122), (-22, 1, 155), (-6, -29, 146), (-21, -23, 130), R],
                        [L, (22, -2, 103), (21, -12, 132), (27, -22, 140), (22, -7, 114), L]),
    'CastCardFan': ([R, (-14, -7, 120), (-11, -18, 137), (-29, -20, 140), (-27, -11, 125), R],
                    [L, (21, -1, 106), (10, -14, 125), (22, -21, 129), (25, -3, 110), L]),
    'BasicSlash': ([R, (-23, 2, 122), (-27, -9, 138), (20, -27, 129), (9, -22, 121), R], [L, L, (18, -3, 112), (23, -5, 110), L, L]),
    'Thrust': ([R, (-18, 2, 123), (-16, -4, 137), (-14, -31, 138), (-20, -22, 131), R], [L, L, (19, -4, 110), (21, -8, 109), L, L]),
    'Card': ([R, (-19, -2, 120), (-12, -15, 131), (-25, -29, 133), (-27, -16, 125), R], [L, L, (16, -4, 107), (22, -9, 112), L, L]),
    'Parry': ([R, (-14, -12, 126), (-7, -25, 134), (-9, -26, 139), (-18, -15, 131), R],
              [L, (16, -10, 116), (10, -22, 132), (11, -24, 134), (20, -13, 122), L]),
}
CLIPS = [('BattleIdle', 2.4), ('BasicSlash', .70), ('Thrust', .70), ('Card', .70), ('Parry', .60), ('Hit', .42),
         ('CastPrepare', .70)] + [(n, .68 if 'Mask' in n or n == 'CastCardFan' else .90 if 'Twin' in n else 1.12)
                                   for n in list(GESTURES)[:7]]


# Whole-body casting. Each clip coils the body away during the wind-up, drives it
# through the release (contact at 0.58), overshoots and settles; hips sink, the
# torso leans in, some casts step, the head keeps the enemy, the feet stay planted.
# coil/drive: torso yaw (deg, + brings the right shoulder forward); lean: forward
# pitch at release; crouch: hip drop (cm); step: (foot, forward cm) or None.
BODY = {
    'CastMaskFlick': dict(coil=-18, drive=24, lean=7, crouch=3.0, step=None),
    'CastMaskTurn': dict(coil=-26, drive=36, lean=5, crouch=2.5, step=None),
    'CastTwinSweep': dict(coil=22, drive=-30, lean=9, crouch=4.5, step=('L', -8.0)),
    'CastTwinCross': dict(coil=-16, drive=28, lean=11, crouch=5.0, step=('L', 13.0)),
    'CastFinaleLift': dict(coil=10, drive=-8, lean=-9, crouch=6.0, step=None, rise=True),
    'CastFinaleThrow': dict(coil=-32, drive=42, lean=13, crouch=5.5, step=('R', 17.0)),
    'CastCardFan': dict(coil=-12, drive=20, lean=6, crouch=2.5, step=None),
    'CastPrepare': dict(coil=-10, drive=12, lean=4, crouch=2.0, step=None),
    'BasicSlash': dict(coil=-22, drive=32, lean=9, crouch=3.5, step=('L', 10.0)),
    'Thrust': dict(coil=-10, drive=14, lean=13, crouch=4.5, step=('R', 16.0)),
    'Card': dict(coil=-15, drive=22, lean=7, crouch=2.5, step=None),
    'Parry': dict(coil=12, drive=-6, lean=-5, crouch=5.0, step=None),
    'Hit': dict(coil=0, drive=-6, lean=-11, crouch=3.0, step=None),
}
PHASE = [0.0, 0.34, 0.58, 0.72, 1.0]


def phased(values, p, keys=PHASE):
    """Ease between key values (smoothstep per segment)."""
    for i in range(len(keys) - 1):
        if p <= keys[i + 1]:
            u = (p - keys[i]) / (keys[i + 1] - keys[i])
            u = u * u * (3 - 2 * u)
            return values[i] + (values[i + 1] - values[i]) * u
    return values[-1]


def leg(rig, side, ankle, toe):
    """Two-bone leg IK: hip -> knee -> ankle, knee bending forward; the foot
    then aims at its toe target so it stays flat on the ground."""
    s = 'Left' if side == 'L' else 'Right'
    a, b = rig.pose.bones[s + 'UpLeg'], rig.pose.bones[s + 'Leg']
    start = a.head.copy()
    d = Vector(ankle) - start
    dist = max(1.0, min(d.length, a.bone.length + b.bone.length - 0.05))
    axis = d.normalized()
    along = (a.bone.length ** 2 - b.bone.length ** 2 + dist ** 2) / (2 * dist)
    h = math.sqrt(max(0.0, a.bone.length ** 2 - along ** 2))
    hint = Vector((0.12 if side == 'L' else -0.12, -1.0, 0.0))
    hint = hint - axis * hint.dot(axis)
    aim(rig, s + 'UpLeg', start + axis * along + hint.normalized() * h)
    aim(rig, s + 'Leg', start + axis * dist)
    aim(rig, s + 'Foot', Vector(toe))


def pose(rig, clip, p):
    for b in rig.pose.bones:
        b.matrix_basis.identity()
        b.rotation_mode = 'QUATERNION'
    bpy.context.view_layer.update()
    rest_ankle = {k: rig.pose.bones[n + 'Foot'].head.copy() for k, n in (('L', 'Left'), ('R', 'Right'))}
    rest_toe = {k: rig.pose.bones[n + 'Toe'].head.copy() for k, n in (('L', 'Left'), ('R', 'Right'))}
    idle = clip == 'BattleIdle'
    wave = math.sin(p * math.tau)
    body = BODY.get(clip)
    if idle or body is None:
        # Breathing, a slow weight shift and a little sway in the coat.
        yaw, lean, crouch, side_shift = 2.0 * wave, 0.8 * math.sin(p * math.tau * 2), 0.6 + 0.4 * wave, 0.8 * wave
        step = None
        energy = 0.0
    else:
        yaw = phased([0, body['coil'], body['drive'], body['drive'] * 1.08, 0], p)
        lean = phased([0, -0.35 * abs(body['lean']), body['lean'], body['lean'] * 0.8, 0], p)
        dip = phased([0, 0.7, 1.0, 0.85, 0], p)
        crouch = body['crouch'] * dip
        if body.get('rise'):
            crouch = phased([0, body['crouch'], -1.5, 0.5, 0], p)
        side_shift = phased([0, 1.2, -1.6, -1.0, 0], p) * (1 if yaw >= 0 else -1)
        step = body['step']
        energy = math.sin(p * math.pi) ** 2
    # Hips carry part of the turn, shift the weight and drop; the spine winds up the rest.
    turn(rig, 'Hips', -lean * 0.25, yaw * 0.25)
    rig.pose.bones['Hips'].location = Vector((side_shift, 0.0, 0.0))
    bpy.context.view_layer.update()
    hb = rig.pose.bones['Hips']
    m = hb.matrix.copy()
    m.translation = m.translation + Vector((0, -0.12 * max(0.0, lean), -crouch))
    hb.matrix = m
    bpy.context.view_layer.update()
    turn(rig, 'Spine02', -lean * 0.25, yaw * 0.2)
    turn(rig, 'Spine01', -lean * 0.3, yaw * 0.25)
    turn(rig, 'Spine', -lean * 0.3 + (wave * 0.6 if idle else 0), yaw * 0.3)
    # The head keeps the enemy in view.
    turn(rig, 'neck', lean * 0.2, -yaw * 0.25)
    turn(rig, 'Head', lean * 0.25 - 1 + energy * 1.5, -yaw * 0.35)
    bpy.context.view_layer.update()
    # Feet stay planted unless the clip steps.
    for k in ('L', 'R'):
        ankle, toe = rest_ankle[k].copy(), rest_toe[k].copy()
        if step and step[0] == k:
            fwd = phased([0, -0.15, 1.0, 1.0, 0], p) * step[1]
            lift = 3.0 * max(0.0, math.sin(min(1.0, p / 0.58) * math.pi)) if p < 0.58 else \
                2.0 * max(0.0, math.sin(min(1.0, (p - 0.72) / 0.28) * math.pi)) if p > 0.72 else 0.0
            ankle += Vector((0, -fwd, lift))
            toe += Vector((0, -fwd, lift))
        leg(rig, k, ankle, toe)
    pair = GESTURES.get(clip, GESTURES['CastCardFan'] if clip == 'CastPrepare' else None)
    if pair:
        amplitude = 1.10 if clip.startswith('Cast') else 1
        arm(rig, 'R', Vector(R) + (curve(pair[0], p) - Vector(R)) * amplitude + Vector((0, 0, -crouch * 0.7)))
        arm(rig, 'L', Vector(L) + (curve(pair[1], p) - Vector(L)) * amplitude + Vector((0, 0, -crouch * 0.7)))
    else:
        arm(rig, 'R', Vector(R) + Vector((0, .3 * wave, .45 * wave - crouch * 0.7)))
        arm(rig, 'L', Vector(L) + Vector((0, .2 * wave, .4 * wave - crouch * 0.7)))
    turn(rig, 'RightHand', 7.7 * energy, -8.8 * wave * energy, 13.2 * wave * energy)
    turn(rig, 'LeftHand', -6.6 * energy, 8.8 * wave * energy, -7.7 * wave * energy)
    # Coat tails trail the turn and flare at the release, then swing back.
    for side, sign in [('L', 1), ('R', -1)]:
        if idle or body is None:
            turn(rig, 'Coat.' + side, wave * .8, 0, sign * .7 * wave)
            turn(rig, 'CoatTip.' + side, wave * 1.4, 0, sign * 1.6 * wave)
            turn(rig, 'Ribbon.' + side, 1.6 * wave, sign * 1.8 * wave)
            continue
        lag = phased([0, 0.2, -1.0, 0.6, 0], max(0.0, p - 0.06))
        flare = phased([0, 0.3, 1.0, 0.7, 0], max(0.0, p - 0.04))
        turn(rig, 'Coat.' + side, -10 * flare, -sign * 0.35 * yaw * 0.3, sign * (4 + 4 * flare) * flare)
        turn(rig, 'CoatTip.' + side, -14 * flare + 6 * lag, -sign * 0.3 * yaw * 0.3, sign * 5 * flare)
        turn(rig, 'Ribbon.' + side, -12 * flare + 8 * lag, sign * 2.5 * lag)
    bpy.context.view_layer.update()


def bake_clips(rig, fps=60):
    for name, duration in CLIPS:
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        rig.animation_data_create().action = act
        count = round(duration * fps)
        for frame in range(count + 1):
            bpy.context.scene.frame_set(frame)
            pose(rig, name, frame / count)
            for b in rig.pose.bones:
                b.keyframe_insert('rotation_quaternion', frame=frame, group=b.name)
                b.keyframe_insert('location', frame=frame, group=b.name)
    rig.animation_data.action = bpy.data.actions['BattleIdle']
    bpy.context.scene.frame_set(0)
