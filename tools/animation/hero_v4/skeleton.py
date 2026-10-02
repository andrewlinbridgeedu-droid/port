"""Shared 28-bone hero skeleton. Names match v3 so the Unity controller and
runtime keep working; the arms rest in a symmetric A-pose for clean tailoring."""
from mathutils import Vector

SPEC = {
    'Hips': ((0, 5, 94), (0, 5, 105), None),
    'Spine02': ((0, 5, 105), (0, 6, 118), 'Hips'),
    'Spine01': ((0, 6, 118), (0, 7, 130), 'Spine02'),
    'Spine': ((0, 7, 130), (0, 8, 141), 'Spine01'),
    'neck': ((0, 8, 141), (0, 8, 152), 'Spine'),
    'Head': ((0, 8, 152), (0, 8, 173), 'neck'),
}

# Upper arm 27 cm, forearm 26 cm, hand 10 cm, hanging 32 degrees from vertical.
for _side, _s in (('Left', 1), ('Right', -1)):
    SPEC[_side + 'Shoulder'] = ((_s * 3, 8, 140), (_s * 15, 8, 140), 'Spine')
    SPEC[_side + 'Arm'] = ((_s * 15, 8, 140), (_s * 29.3, 8, 117.1), _side + 'Shoulder')
    SPEC[_side + 'ForeArm'] = ((_s * 29.3, 8, 117.1), (_s * 43.1, 6.4, 95.1), _side + 'Arm')
    SPEC[_side + 'Hand'] = ((_s * 43.1, 6.4, 95.1), (_s * 48.1, 5.9, 86.4), _side + 'ForeArm')
    SPEC[_side + 'UpLeg'] = ((_s * 8, 5, 94), (_s * 12, 4, 49), 'Hips')
    SPEC[_side + 'Leg'] = ((_s * 12, 4, 49), (_s * 16, 6, 12), _side + 'UpLeg')
    SPEC[_side + 'Foot'] = ((_s * 16, 6, 12), (_s * 16, -6, 3), _side + 'Leg')
    SPEC[_side + 'Toe'] = ((_s * 16, -6, 3), (_s * 16, -14, 3), _side + 'Foot')

# Coat tails and the hip ornaments (sash on the left, chain on the right).
for _side, _s in (('L', 1), ('R', -1)):
    SPEC['Coat.' + _side] = ((_s * 8, 15, 100), (_s * 19, 22, 62), 'Hips')
    SPEC['CoatTip.' + _side] = ((_s * 19, 22, 62), (_s * 29, 26, 26), 'Coat.' + _side)
    SPEC['Ribbon.' + _side] = ((_s * 14, 13, 100), (_s * 18, 17, 60), 'Hips')


def head(name):
    return Vector(SPEC[name][0])


def tail(name):
    return Vector(SPEC[name][1])


def side_name(sign):
    return 'Left' if sign > 0 else 'Right'
