"""Painted (thick-paint anime) preview materials for Blender renders.

The look follows the 2D character art: a smooth light-to-shadow gradient with a
coloured shadow, darker creases (ambient occlusion), a satin sheen on cloth,
sharp highlights on leather, metal highlights on gold and a soft rim. Unity's
Mistport/HeroPaintedV4 shader uses the same parameters (materials.json)."""
import bpy


def srgb(c):
    """Display colour (0..1 sRGB) -> linear for Blender colour sockets."""
    def ch(x):
        return x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4
    return tuple(ch(x) for x in c[:3])


# kind -> (specular roughness, specular threshold low/high, specular strength, rim, highlight tint)
# Cloth and hair highlights are soft and tinted (wool, brocade, hair sheen); only
# leather, gold and stones get bright, crisp highlights.
KINDS = {
    'cloth': (0.55, 0.60, 1.00, 0.10, 0.16, (0.46, 0.43, 0.58)),
    'satin': (0.32, 0.55, 0.92, 0.20, 0.18, (0.86, 0.78, 1.00)),
    'leather': (0.18, 0.62, 0.80, 0.55, 0.14, (1.00, 0.97, 0.94)),
    'metal': (0.20, 0.45, 0.75, 0.90, 0.10, None),
    'gem': (0.08, 0.50, 0.70, 1.00, 0.10, (1.00, 0.95, 1.00)),
    'skin': (0.50, 0.80, 1.00, 0.04, 0.12, (1.00, 0.92, 0.88)),
    'hair': (0.30, 0.62, 0.90, 0.16, 0.20, (0.58, 0.55, 0.86)),
}


def painted(name, color, shade=(0.60, 0.52, 0.76), image=None, kind='cloth', spec_color=None,
            ao=0.75, gloss=None, rim=None):
    """color/shade are display sRGB; shade tints the shadow side of the colour."""
    rough, lo, hi, strength, rim_k, tint_default = KINDS[kind]
    if spec_color is None:
        spec_color = tint_default or (1.0, 0.96, 0.90)
    if gloss is not None:
        strength = gloss
    if rim is not None:
        rim_k = rim
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    n, l = nt.nodes, nt.links
    for node in list(n):
        n.remove(node)
    out = n.new('ShaderNodeOutputMaterial')

    def mix(a, b, fac=None, blend='MIX', fac_value=1.0):
        node = n.new('ShaderNodeMix')
        node.data_type = 'RGBA'
        node.blend_type = blend
        node.inputs['Factor'].default_value = fac_value
        if fac is not None:
            l.new(fac, node.inputs['Factor'])
        for sock, val in (('A', a), ('B', b)):
            if isinstance(val, tuple):
                node.inputs[sock].default_value = (*val, 1)
            else:
                l.new(val, node.inputs[sock])
        return node.outputs['Result']

    # Light value from a white diffuse surface.
    diff = n.new('ShaderNodeBsdfDiffuse')
    s2r = n.new('ShaderNodeShaderToRGB')
    l.new(diff.outputs[0], s2r.inputs[0])
    lum = n.new('ShaderNodeRGBToBW')
    l.new(s2r.outputs[0], lum.inputs[0])
    # Smooth painted gradient: deep coloured shadow -> shadow -> lit -> slight lift.
    ramp = n.new('ShaderNodeValToRGB')
    cr = ramp.color_ramp
    cr.interpolation = 'B_SPLINE'
    deep = tuple(max(0.0, c * 0.72) for c in shade)
    cr.elements[0].position = 0.0
    cr.elements[0].color = (*srgb(deep), 1)
    cr.elements[1].position = 0.62
    cr.elements[1].color = (1, 1, 1, 1)
    e = cr.elements.new(0.26)
    e.color = (*srgb(shade), 1)
    e = cr.elements.new(0.95)
    e.color = (1.06, 1.05, 1.03, 1)
    l.new(lum.outputs[0], ramp.inputs[0])
    if image is not None:
        tex = n.new('ShaderNodeTexImage')
        tex.image = image
        tex.interpolation = 'Cubic'
        base = tex.outputs['Color']
    else:
        rgb = n.new('ShaderNodeRGB')
        rgb.outputs[0].default_value = (*srgb(color), 1)
        base = rgb.outputs[0]
    col = mix(base, ramp.outputs[0], blend='MULTIPLY')
    # Creases and contact shadows, tinted like the shadow colour.
    if ao > 0:
        aon = n.new('ShaderNodeAmbientOcclusion')
        aon.inputs['Distance'].default_value = 5.0
        aon.samples = 16
        ao_tint = tuple(c * 0.55 for c in srgb(shade))
        darken = mix(ao_tint, (1.0, 1.0, 1.0), fac=aon.outputs['AO'])
        strength_mix = mix((1.0, 1.0, 1.0), darken, fac_value=ao)
        col = mix(col, strength_mix, blend='MULTIPLY')
    # Highlight: a thresholded glossy lobe, broad on cloth, crisp on leather and gold.
    if strength > 0:
        g = n.new('ShaderNodeBsdfGlossy')
        g.inputs['Roughness'].default_value = rough
        gs = n.new('ShaderNodeShaderToRGB')
        l.new(g.outputs[0], gs.inputs[0])
        gbw = n.new('ShaderNodeRGBToBW')
        l.new(gs.outputs[0], gbw.inputs[0])
        gr = n.new('ShaderNodeMapRange')
        gr.inputs['From Min'].default_value = lo
        gr.inputs['From Max'].default_value = hi
        gr.interpolation_type = 'SMOOTHSTEP'
        l.new(gbw.outputs[0], gr.inputs['Value'])
        sc = n.new('ShaderNodeMath')
        sc.operation = 'MULTIPLY'
        sc.inputs[1].default_value = strength
        l.new(gr.outputs['Result'], sc.inputs[0])
        tint = spec_color if kind != 'metal' else tuple(min(1.0, 0.55 + c * 0.5) for c in color)
        col = mix(col, tuple(srgb(tint)), fac=sc.outputs[0], blend='ADD')
    if rim_k > 0:
        lw = n.new('ShaderNodeLayerWeight')
        lw.inputs['Blend'].default_value = 0.3
        rr = n.new('ShaderNodeMapRange')
        rr.inputs['From Min'].default_value = 0.55
        rr.inputs['From Max'].default_value = 0.85
        rr.interpolation_type = 'SMOOTHSTEP'
        l.new(lw.outputs['Facing'], rr.inputs['Value'])
        rk = n.new('ShaderNodeMath')
        rk.operation = 'MULTIPLY'
        rk.inputs[1].default_value = rim_k
        l.new(rr.outputs['Result'], rk.inputs[0])
        col = mix(col, (1.0, 0.92, 0.86), fac=rk.outputs[0], blend='SCREEN')
    em = n.new('ShaderNodeEmission')
    l.new(col, em.inputs['Color'])
    l.new(em.outputs[0], out.inputs['Surface'])
    m['toon'] = dict(color=list(color), shade=list(shade), kind=kind, ao=ao, rough=rough, spec_lo=lo, spec_hi=hi,
                     spec=strength, rim=rim_k)
    return m


def toon(name, color, shade=(0.62, 0.55, 0.78), image=None, gloss=0.0, gloss_color=(1, 0.95, 0.85),
         rim=0.18, step=0.42, soft=0.08, vertex_ao=False, kind=None):
    """Compatibility wrapper: older call sites pass gloss; map them onto material kinds."""
    if kind is None:
        kind = 'metal' if gloss >= 0.5 else 'leather' if gloss >= 0.3 else 'cloth'
    return painted(name, color, shade=shade, image=image, kind=kind, rim=rim if rim != 0.18 else None)


def outline_material(color=(0.11, 0.08, 0.13)):
    m = bpy.data.materials.get('Outline')
    if m:
        return m
    m = bpy.data.materials.new('Outline')
    m.use_nodes = True
    n = m.node_tree.nodes
    for node in list(n):
        n.remove(node)
    out = n.new('ShaderNodeOutputMaterial')
    em = n.new('ShaderNodeEmission')
    em.inputs['Color'].default_value = (*srgb(color), 1)
    m.node_tree.links.new(em.outputs[0], out.inputs['Surface'])
    m.use_backface_culling = True
    return m


def add_outline(ob, width=0.12):
    """Inverted hull. Kept as a modifier: preview only, never exported."""
    mat = outline_material()
    if mat.name not in [m.name for m in ob.data.materials if m]:
        ob.data.materials.append(mat)
    idx = [m.name if m else '' for m in ob.data.materials].index(mat.name)
    mod = ob.modifiers.new('Outline', 'SOLIDIFY')
    mod.thickness = width
    mod.offset = 1.0
    mod.use_flip_normals = True
    mod.use_rim = False
    mod.material_offset = idx
    mod.use_quality_normals = True
    return mod
