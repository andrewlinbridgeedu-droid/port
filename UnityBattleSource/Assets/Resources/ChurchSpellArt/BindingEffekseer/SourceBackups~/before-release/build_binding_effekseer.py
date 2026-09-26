"""Author B02's real Effekseer accent layers (not the binding ribbon body).

The two finite .efkproj files are compiled by the project's bundled importer.
All coordinates are world-sized around the target's chest: radius <= .8,
height +/- 1.05. Existing local textures are copied without modification.
"""
from pathlib import Path
import copy
import math
import shutil
import xml.etree.ElementTree as E


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'UnityBattleSource/Assets/Resources/ChurchSpellArt/BindingEffekseer'
TEX = OUT / 'Texture'
TEMPLATE = ROOT / 'UnityBattleSource/Assets/Resources/ChurchSpellArt/SaltmawEffekseer/CrystalImpact.efkproj'


def setv(node, path, value):
    for part in path.split('/'):
        child = node.find(part)
        if child is None:
            child = E.SubElement(node, part)
        node = child
    node.text = str(value)


def span(node, path, lo, hi=None):
    if hi is None:
        hi = lo
    for key, value in [('Min', lo), ('Max', hi), ('Center', (lo + hi) / 2)]:
        setv(node, path + '/' + key, round(value, 6))


def project(end_frame):
    tree = E.parse(TEMPLATE)
    tree.find('Root/Children').clear()
    setv(tree.getroot(), 'EndFrame', end_frame)
    setv(tree.getroot(), 'IsLoop', 'False')
    return tree


def sprite(tree, *, name, texture, pos, velocity=(0, 0, 0), size=(.1, .1),
           count=1, life=(12, 16), interval=18, delay=0, rgb=(255, 231, 158),
           alpha=245, angle=0, fade_in=3, fade_out=7, scale_velocity=0):
    node = copy.deepcopy(E.parse(TEMPLATE).find('.//Node'))
    tree.find('Root/Children').append(node)
    setv(node, 'Name', name)
    setv(node, 'CommonValues/MaxGeneration/Value', count)
    for key in ['LocationEffectType', 'RotationEffectType', 'ScaleEffectType']:
        setv(node, 'CommonValues/' + key, 2)  # Already: keep attached to moving chest.
    span(node, 'CommonValues/Life', *life)
    span(node, 'CommonValues/GenerationTime', interval)
    span(node, 'CommonValues/GenerationTimeOffset', delay)
    for i, axis in enumerate('XYZ'):
        jitter = .012 if axis != 'Y' else .025
        span(node, 'LocationValues/PVA/Location/' + axis, pos[i] - jitter, pos[i] + jitter)
        span(node, 'LocationValues/PVA/Velocity/' + axis, velocity[i])
        span(node, 'LocationValues/PVA/Acceleration/' + axis, 0)
        span(node, 'RotationValues/PVA/Rotation/' + axis, angle if axis == 'Z' else 0)
        span(node, 'RotationValues/PVA/Velocity/' + axis, .28 if axis == 'Z' else 0)
        span(node, 'RotationValues/PVA/Acceleration/' + axis, 0)
        value = size[i] if i < 2 else 1
        span(node, 'ScalingValues/PVA/Scale/' + axis, value * .82, value)
        span(node, 'ScalingValues/PVA/Velocity/' + axis, scale_velocity if i < 2 else 0)
        span(node, 'ScalingValues/PVA/Acceleration/' + axis, 0)
    setv(node, 'RendererCommonValues/ColorTexture', 'Texture/' + texture)
    setv(node, 'RendererCommonValues/AlphaBlend', 2)
    setv(node, 'RendererCommonValues/ZTest', 'True')
    setv(node, 'RendererCommonValues/ZWrite', 'False')
    setv(node, 'RendererCommonValues/FadeInType', 1)
    setv(node, 'RendererCommonValues/FadeIn/Frame', fade_in)
    setv(node, 'RendererCommonValues/FadeIn/StartSpeed', 0)
    setv(node, 'RendererCommonValues/FadeIn/EndSpeed', 0)
    setv(node, 'RendererCommonValues/FadeOutType', 1)
    setv(node, 'RendererCommonValues/FadeOut/Frame', fade_out)
    setv(node, 'RendererCommonValues/FadeOut/StartSpeed', 0)
    setv(node, 'RendererCommonValues/FadeOut/EndSpeed', 0)
    draw = node.find('DrawingValues/Sprite')
    # Drop the inherited crystal's elongated/offset corners.
    for child in list(draw):
        if child.tag.startswith('Position'):
            draw.remove(child)
    setv(node, 'DrawingValues/Type', 2)
    setv(node, 'DrawingValues/Sprite/Billboard', 3)
    setv(node, 'DrawingValues/Sprite/ColorAll', 0)
    for channel, value in zip('RGBA', (*rgb, alpha)):
        setv(node, 'DrawingValues/Sprite/ColorAll_Fixed/' + channel, value)
    return node


def save(tree, name):
    E.indent(tree)
    path = OUT / (name + '.efkproj')
    tree.write(path, encoding='utf-8', xml_declaration=True)
    # Verify path resolution and bounded emission before Unity imports it.
    for node in tree.findall('.//Node'):
        texture = node.findtext('RendererCommonValues/ColorTexture')
        assert (OUT / texture).is_file(), texture
        assert 0 < int(node.findtext('CommonValues/MaxGeneration/Value')) <= 4
    print(path)


def main():
    TEX.mkdir(parents=True, exist_ok=True)
    sources = {
        'BindingStar.png': 'UnityBattleSource/Assets/Resources/Effects/HellHound/Texture/Star.png',
        'BindingPinlight.png': 'UnityBattleSource/Assets/Resources/Effects/Fool/Effekseer/CurtainExplosion/Texture/Particle01.png',
    }
    for name, source in sources.items():
        shutil.copy2(ROOT / source, TEX / name)

    held = project(75)
    # A sparse asymmetric chain of attached glints, never a ring or full aura.
    points = [(-.61, -.83, -.31), (.58, -.52, .34), (-.48, -.13, .48),
              (.66, .21, -.18), (-.42, .62, -.44), (.31, .95, .37)]
    sizes = [.22, .13, .19, .27, .15, .21]
    for i, p in enumerate(points):
        tangent = (-p[2] * .012, .0038 + i * .00035, p[0] * .012)
        sprite(held, name='Attached golden star %d' % (i + 1),
               texture='BindingStar.png', pos=p, velocity=tangent,
               size=(sizes[i], sizes[i] * (1.07 if i % 2 else .89)),
               count=3, interval=21, delay=(i * 7) % 19, life=(11, 15),
               angle=i * 17 - 22, alpha=250,
               rgb=(255, 234 if i % 2 else 215, 160 if i % 2 else 99))
        # Short sliding pinlight: small footprint, brighter white tip.
        pin = (p[0] * .94, p[1] - .075, p[2] * .94)
        sprite(held, name='Climbing binding pinlight %d' % (i + 1),
               texture='BindingPinlight.png', pos=pin,
               velocity=(tangent[0] * 1.9, .007 + i * .0005, tangent[2] * 1.9),
               size=(.055 + (i % 3) * .012, .09 + (i % 2) * .045),
               count=4, interval=13, delay=(i * 5 + 6) % 16, life=(12, 18),
               angle=-20 + i * 11, alpha=215, rgb=(255, 239, 191),
               fade_in=3, fade_out=8)
    save(held, 'BindingAttachedGlints')

    pulse = project(20)
    # Inward strokes at staggered heights: tighten into the body surface.
    # Their footprint stays thin, so the target remains readable at contact.
    for i, (x, y, z) in enumerate(points):
        p = (x * 1.17, y * .96, z * 1.17)
        sprite(pulse, name='Contact inward thread %d' % (i + 1),
               texture='BindingPinlight.png', pos=p,
               velocity=(-x * .031, -.002 if i % 2 else .002, -z * .031),
               size=(.042, .30 + (i % 3) * .065), life=(8, 11),
               angle=-math.degrees(math.atan2(-x, .14 if i % 2 else -.14)),
               delay=i % 3, fade_in=1, fade_out=5, rgb=(255, 231, 142), alpha=245)
        sprite(pulse, name='Contact knot star %d' % (i + 1),
               texture='BindingStar.png', pos=(x * .9, y, z * .9),
               size=(.23 + (i % 3) * .045, .24 + (i % 2) * .07),
               life=(7, 10), delay=3 + i % 2, angle=i * 19,
               fade_in=1, fade_out=5, rgb=(255, 246, 205),
               scale_velocity=-.008)
    save(pulse, 'BindingContactTighten')


if __name__ == '__main__':
    main()
