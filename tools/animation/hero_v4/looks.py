"""Painted-anime preview materials for Blender renders. Unity uses
Mistport/HeroToonV4 with the same parameters (base, shade tint, rim, gloss)."""
import bpy


def srgb(c):
    """Display colour (0..1 sRGB) -> linear for Blender colour sockets."""
    def ch(x):
        return x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4
    return tuple(ch(x) for x in c[:3])


def toon(name, color, shade=(0.62, 0.55, 0.78), image=None, gloss=0.0, gloss_color=(1, 0.95, 0.85),
         rim=0.18, step=0.42, soft=0.08, vertex_ao=False):
    """color/shade are display sRGB. shade multiplies the colour in shadow."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    n, l = nt.nodes, nt.links
    for node in list(n):
        n.remove(node)
    out = n.new('ShaderNodeOutputMaterial')
    diff = n.new('ShaderNodeBsdfDiffuse')
    s2r = n.new('ShaderNodeShaderToRGB')
    l.new(diff.outputs[0], s2r.inputs[0])
    bw = n.new('ShaderNodeRGBToBW')
    l.new(s2r.outputs[0], bw.inputs[0])
    ramp = n.new('ShaderNodeValToRGB')
    ramp.color_ramp.interpolation = 'EASE'
    e = ramp.color_ramp.elements
    e[0].position = max(0.0, step - soft)
    e[0].color = (*srgb(shade), 1)
    e[1].position = min(1.0, step + soft)
    e[1].color = (1, 1, 1, 1)
    l.new(bw.outputs[0], ramp.inputs[0])
    if image is not None:
        tex = n.new('ShaderNodeTexImage')
        tex.image = image
        tex.interpolation = 'Cubic'
        base = tex.outputs['Color']
    else:
        rgb = n.new('ShaderNodeRGB')
        rgb.outputs[0].default_value = (*srgb(color), 1)
        base = rgb.outputs[0]
    mul = n.new('ShaderNodeMix')
    mul.data_type = 'RGBA'
    mul.blend_type = 'MULTIPLY'
    mul.inputs['Factor'].default_value = 1.0
    l.new(base, mul.inputs['A'])
    l.new(ramp.outputs[0], mul.inputs['B'])
    col = mul.outputs['Result']
    if vertex_ao:
        attr = n.new('ShaderNodeVertexColor')
        attr.layer_name = 'AO'
        ao = n.new('ShaderNodeMix')
        ao.data_type = 'RGBA'
        ao.blend_type = 'MULTIPLY'
        ao.inputs['Factor'].default_value = 1.0
        l.new(col, ao.inputs['A'])
        l.new(attr.outputs['Color'], ao.inputs['B'])
        col = ao.outputs['Result']
    if gloss > 0:
        g = n.new('ShaderNodeBsdfGlossy')
        g.inputs['Roughness'].default_value = 0.28
        gs = n.new('ShaderNodeShaderToRGB')
        l.new(g.outputs[0], gs.inputs[0])
        gbw = n.new('ShaderNodeRGBToBW')
        l.new(gs.outputs[0], gbw.inputs[0])
        gr = n.new('ShaderNodeValToRGB')
        gr.color_ramp.elements[0].position = 0.55
        gr.color_ramp.elements[1].position = 0.70
        l.new(gbw.outputs[0], gr.inputs[0])
        gm = n.new('ShaderNodeMix')
        gm.data_type = 'RGBA'
        gm.blend_type = 'ADD'
        l.new(gr.outputs[0], gm.inputs['Factor'])
        gm.inputs['Factor'].default_value = gloss
        l.new(col, gm.inputs['A'])
        gm.inputs['B'].default_value = (*srgb(gloss_color), 1)
        scale = n.new('ShaderNodeMath')
        scale.operation = 'MULTIPLY'
        scale.inputs[1].default_value = gloss
        l.new(gr.outputs[0], scale.inputs[0])
        l.new(scale.outputs[0], gm.inputs['Factor'])
        col = gm.outputs['Result']
    if rim > 0:
        lw = n.new('ShaderNodeLayerWeight')
        lw.inputs['Blend'].default_value = 0.35
        rr = n.new('ShaderNodeValToRGB')
        rr.color_ramp.elements[0].position = 0.55
        rr.color_ramp.elements[1].position = 0.75
        l.new(lw.outputs['Facing'], rr.inputs[0])
        rmul = n.new('ShaderNodeMath')
        rmul.operation = 'MULTIPLY'
        rmul.inputs[1].default_value = rim
        l.new(rr.outputs[0], rmul.inputs[0])
        lit = n.new('ShaderNodeMath')
        lit.operation = 'MULTIPLY'
        l.new(rmul.outputs[0], lit.inputs[0])
        l.new(bw.outputs[0], lit.inputs[1])
        rm = n.new('ShaderNodeMix')
        rm.data_type = 'RGBA'
        rm.blend_type = 'SCREEN'
        l.new(lit.outputs[0], rm.inputs['Factor'])
        l.new(col, rm.inputs['A'])
        rm.inputs['B'].default_value = (1.0, 0.93, 0.85, 1)
        col = rm.outputs['Result']
    em = n.new('ShaderNodeEmission')
    l.new(col, em.inputs['Color'])
    l.new(em.outputs[0], out.inputs['Surface'])
    m['toon'] = dict(color=list(color), shade=list(shade), gloss=gloss, rim=rim, step=step, soft=soft)
    return m


def outline_material(color=(0.09, 0.06, 0.12)):
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


def add_outline(ob, width=0.22):
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
