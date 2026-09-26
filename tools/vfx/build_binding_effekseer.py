"""Author B02's real Effekseer accent layers (not the binding ribbon body).

The finite .efkproj files are compiled by the project's bundled importer.
Held coordinates are world-sized around the target's chest: radius <= .8,
height +/- 1.05. Release shards fly out 3-5 units after the visual hit-stop.
Existing local textures are copied without modification.
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
              (.66, .21, -.18), (-.42, .62, -.44), (.31, .95, .37),
              (.74, .47, -.18), (-.70, .28, .32), (.48, -.64, -.44), (-.29, .87, .49)]
    sizes = [.22, .13, .19, .27, .15, .21, .12, .14, .10, .15]
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
    for i, (x, y, z) in enumerate(points[:6]):
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

    release = project(32)
    # 22 authored, uneven fragment paths; two sprites per path provide a hot
    # short shard and a separate thin orange tail. No circle, glow ball or sheet.
    # Velocity/acceleration below are per Effekseer frame (60 Hz).
    for i in range(22):
        angle = i * math.tau / 22 + .09 * math.sin(i * 2.31)
        direction = (math.cos(angle), math.sin(angle) * .91 + .22,
                     math.sin(i * 1.713) * .38)
        norm = math.sqrt(sum(v * v for v in direction))
        direction = tuple(v / norm for v in direction)
        speed = .135 + ((i * 7) % 13) * .0118
        velocity = tuple(v * speed for v in direction)
        origin = (direction[0] * .20, direction[1] * .30,
                  direction[2] * .20)
        life = 13 + ((i * 5) % 11)
        delay = ((i * 7) % 22) * 2.7 / 21
        rotation = -math.degrees(math.atan2(direction[0], direction[1]))
        gravity = -.0042 - (i % 4) * .0007
        width = .10 + (i % 4) * .032
        length = .32 + ((i * 3) % 7) * .105
        head = sprite(release, name='Release platinum shard %02d' % (i + 1),
                      texture='BindingPinlight.png', pos=origin,
                      velocity=velocity, size=(width, length), life=(life, life),
                      delay=delay, angle=rotation, fade_in=.25,
                      fade_out=life * .58, alpha=255,
                      rgb=(255, 247, 218) if i % 3 else (255, 207, 104))
        # The tail starts behind the head and follows its exact ballistic path.
        tail_length = .58 + ((i * 5) % 8) * .14
        tail_life = max(12, life - 2)
        tail_origin = tuple(origin[j] - direction[j] * tail_length * .37
                            for j in range(3))
        tail = sprite(release, name='Release orange tail %02d' % (i + 1),
                      texture='BindingPinlight.png', pos=tail_origin,
                      velocity=velocity, size=(width * .53, tail_length),
                      life=(tail_life, tail_life), delay=delay, angle=rotation,
                      fade_in=.35, fade_out=tail_life * .75,
                      rgb=(255, 172 + (i % 3) * 13, 47 + (i % 4) * 9), alpha=226)
        for node in [head, tail]:
            # Debris stays in world space if the target recoils during release.
            for key in ['LocationEffectType', 'RotationEffectType', 'ScaleEffectType']:
                setv(node, 'CommonValues/' + key, 1)
            span(node, 'LocationValues/PVA/Acceleration/Y', gravity)
            span(node, 'RotationValues/PVA/Velocity/Z', 0)
            span(node, 'ScalingValues/PVA/Velocity/X', -.0015)
            span(node, 'ScalingValues/PVA/Velocity/Y', -.012 if node is head else -.022)
    # Fine, delayed glitter between the large jets gives two readable size scales.
    # Golden-angle placement avoids a second regular radial fan.
    for i in range(36):
        a = i * 2.399963 + .17 * math.sin(i * 1.7)
        direction = (math.cos(a), math.sin(a) * .82 + .20, math.sin(i * 1.93) * .46)
        length = math.sqrt(sum(x*x for x in direction))
        direction = tuple(x/length for x in direction)
        speed = .055 + (i % 7) * .013
        pos = tuple(x*(.28+(i%3)*.11) for x in direction)
        spark = sprite(release, name='Fine drifting gold grain %02d' % i,
                       texture='BindingPinlight.png', pos=pos,
                       velocity=tuple(x*speed for x in direction),
                       size=(.032+(i%4)*.011, .09+(i%5)*.035),
                       life=(14+(i%5), 17+(i%5)), delay=1.2+(i%9)*.45,
                       angle=-math.degrees(math.atan2(direction[0], direction[1])),
                       fade_in=.2, fade_out=11, rgb=(255, 217+(i%3)*12, 118+(i%4)*22),alpha=238)
        for key in ['LocationEffectType', 'RotationEffectType', 'ScaleEffectType']:
            setv(spark, 'CommonValues/' + key, 1)
        span(spark, 'LocationValues/PVA/Acceleration/Y', -.0025)
        span(spark, 'ScalingValues/PVA/Velocity/X', -.001)
        span(spark, 'ScalingValues/PVA/Velocity/Y', -.003)
        if i % 4 == 0:
            star=sprite(release, name='Secondary fragment twinkle %02d' % i,
                        texture='BindingStar.png', pos=tuple(x*.82 for x in direction),
                        velocity=tuple(x*speed*.80 for x in direction),
                        size=(.12+(i%3)*.035, .14+(i%3)*.04),
                        life=(7,10), delay=5+(i%7)*.6, angle=i*19,
                        fade_in=1,fade_out=6,rgb=(255,242,179),alpha=245)
            for key in ['LocationEffectType', 'RotationEffectType', 'ScaleEffectType']:
                setv(star, 'CommonValues/' + key, 1)
            span(star, 'LocationValues/PVA/Acceleration/Y', -.0025)
    save(release, 'BindingReleaseBurst')


if __name__ == '__main__':
    main()
