"""Make four editable Blender harbor citizens from the existing walking rigs.

The original skinned walk cycles remain intact. Added costumes and props are
real mesh geometry; each character is saved as a .blend and .glb, then rendered
as eight transparent map frames from the same camera.
"""

import bpy
import math
import sys
from pathlib import Path
from mathutils import Vector


variant = sys.argv[sys.argv.index("--") + 1]
root = Path(__file__).resolve().parents[2]
characters = root / "mistport-ios/Mistport/WisteriaMap/characters"
sources = root / "ArtSource/HarborCitizens20260925"
renders = root / "output/harbor-map-daynight-20260925/render"
sources.mkdir(parents=True, exist_ok=True)
renders.mkdir(parents=True, exist_ok=True)

designs = {
    "harbor_lamplighter": ("postman-user-walking", 0.62, "lantern"),
    "harbor_flower_seller": ("courier-walking", 0.26, "flowers"),
    "harbor_sailor": ("postman-user-walking", 0.53, "sailor"),
    "harbor_archive_apprentice": ("courier-walking", 0.91, "archive"),
}
stem, hue, costume = designs[variant]

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(characters / f"{stem}.gltf"))
scene = bpy.context.scene
body_meshes = [o for o in scene.objects if o.type == "MESH"]
assert body_meshes


def material(name, color, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = 0.48
    return mat


navy = material("ink navy wool", (0.07, 0.14, 0.24))
ivory = material("ivory canvas", (0.83, 0.80, 0.66))
gold = material("brushed brass", (0.84, 0.57, 0.21), 0.35)
violet = material("violet cloth", (0.40, 0.20, 0.55))
green = material("leaf green", (0.22, 0.39, 0.27))
burgundy = material("burgundy wool", (0.48, 0.10, 0.18))
brown = material("leather", (0.31, 0.16, 0.08))
red = material("red flower", (0.85, 0.19, 0.28))
blue = material("harbor blue", (0.16, 0.35, 0.62))

# Shift the inherited full-color uniform texture so the four original rigs
# read as different people before the modeled costume pieces are added.
for obj in body_meshes:
    for index, original in enumerate(obj.data.materials):
        if not original or not original.use_nodes:
            continue
        changed = original.copy()
        changed.name = f"{variant} recolored cloth"
        nodes = changed.node_tree.nodes
        links = changed.node_tree.links
        bsdf = next((node for node in nodes if node.type == "BSDF_PRINCIPLED"), None)
        if bsdf:
            old_links = list(bsdf.inputs["Base Color"].links)
            if old_links:
                old = old_links[0]
                source_socket = old.from_socket
                links.remove(old)
                tint = nodes.new("ShaderNodeHueSaturation")
                tint.inputs["Hue"].default_value = hue
                tint.inputs["Saturation"].default_value = 1.12
                tint.inputs["Value"].default_value = 0.91
                links.new(source_socket, tint.inputs["Color"])
                links.new(tint.outputs["Color"], bsdf.inputs["Base Color"])
        obj.data.materials[index] = changed


def cylinder(name, loc, radius, depth, mat, vertices=20):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                        location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new("soft tailored edge", "BEVEL")
    bevel.width = min(radius * 0.13, 0.025)
    bevel.segments = 2
    obj.modifiers.new("weighted normals", "WEIGHTED_NORMAL")
    return obj


def box(name, loc, scale, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new("rounded case", "BEVEL")
    bevel.width = 0.025
    bevel.segments = 2
    obj.modifiers.new("weighted normals", "WEIGHTED_NORMAL")
    return obj


def ball(name, loc, radius, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8,
                                         radius=radius, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def coat_tails(mat, z=0.61):
    for side in (-1, 1):
        box("split walking coat tail", (side * 0.13, 0.11, z),
            (0.20, 0.075, 0.52), mat)


if costume == "lantern":
    coat_tails(navy)
    cylinder("watchman's broad hat brim", (0, 0, 1.69), 0.26, 0.035, navy)
    cylinder("watchman's high hat", (0, 0, 1.78), 0.145, 0.18, navy)
    cylinder("hat band", (0, 0, 1.73), 0.149, 0.025, gold)
    cylinder("brass lantern housing", (0.36, -0.04, 0.60), 0.10, 0.18, gold)
    cylinder("lantern glow", (0.36, -0.04, 0.61), 0.076, 0.13,
             material("warm glass", (1, 0.72, 0.25)))
    cylinder("lantern handle", (0.36, -0.04, 0.75), 0.045, 0.08, brown)
elif costume == "flowers":
    bpy.ops.mesh.primitive_cone_add(vertices=18, radius1=0.28, radius2=0.15,
                                    depth=0.57, location=(0, 0.02, 0.65))
    bpy.context.object.name = "layered violet street skirt"
    bpy.context.object.data.materials.append(violet)
    box("green florist apron", (0, -0.20, 0.79), (0.32, 0.04, 0.51), green)
    box("woven flower basket", (0.37, -0.03, 0.70), (0.27, 0.20, 0.20), brown)
    for index in range(7):
        angle = index * math.tau / 7
        ball("basket blossom", (0.37 + 0.09 * math.cos(angle),
                                 -0.03 + 0.06 * math.sin(angle), 0.85),
             0.047, [red, violet, ivory][index % 3])
    cylinder("florist ribbon cap", (0, 0, 1.71), 0.20, 0.035, violet)
elif costume == "sailor":
    coat_tails(blue, 0.65)
    cylinder("sailor cap brim", (0, 0, 1.68), 0.24, 0.04, ivory)
    cylinder("sailor cap crown", (0, 0, 1.75), 0.17, 0.13, ivory)
    cylinder("blue cap ribbon", (0, 0, 1.70), 0.174, 0.032, blue)
    box("rolled chart", (0.34, -0.05, 0.76), (0.14, 0.14, 0.37), ivory)
    cylinder("brass chart ring", (0.34, -0.05, 0.89), 0.078, 0.026, gold)
    box("sailor neckcloth", (0, -0.18, 1.30), (0.31, 0.05, 0.12), blue)
elif costume == "archive":
    coat_tails(burgundy)
    cylinder("archive apprentice cap brim", (0, 0, 1.68), 0.18, 0.03, brown)
    cylinder("archive apprentice cap", (0, 0, 1.74), 0.14, 0.13, burgundy)
    box("book satchel", (0.34, -0.06, 0.86), (0.29, 0.16, 0.32), brown)
    box("brass satchel clasp", (0.34, -0.15, 0.89), (0.065, 0.02, 0.08), gold)
    box("sealed ledger", (-0.31, -0.05, 0.87), (0.11, 0.18, 0.25), ivory)
    box("ledger spine", (-0.38, -0.05, 0.87), (0.03, 0.18, 0.25), burgundy)

# Export actual editable 3D assets before introducing studio camera/lights.
scene.frame_set(1)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(sources / f"{variant}.blend"))
bpy.ops.export_scene.gltf(filepath=str(sources / f"{variant}.glb"), export_format="GLB",
                          export_animations=True)

scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 256
scene.render.resolution_y = 256
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast"
scene.world.color = (0.84, 0.88, 1.0)

camera_data = bpy.data.cameras.new("harbor citizen orthographic")
camera = bpy.data.objects.new("harbor citizen orthographic", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.type = "ORTHO"
lamp_data = bpy.data.lights.new("softbox", "AREA")
lamp = bpy.data.objects.new("softbox", lamp_data)
scene.collection.objects.link(lamp)
lamp_data.energy = 850
lamp_data.shape = "DISK"
lamp_data.size = 5

mesh_objects = [o for o in scene.objects if o.type == "MESH"]
action = max(bpy.data.actions, key=lambda a: a.frame_range[1] - a.frame_range[0])
start, end = action.frame_range
for index in range(8):
    scene.frame_set(round(start + (end - start) * index / 8))
    bpy.context.view_layer.update()
    points = [o.matrix_world @ Vector(corner) for o in mesh_objects for corner in o.bound_box]
    low = Vector(tuple(min(p[axis] for p in points) for axis in range(3)))
    high = Vector(tuple(max(p[axis] for p in points) for axis in range(3)))
    center = (low + high) / 2
    size = high - low
    distance = max(size.length, 2)
    camera.location = center + Vector((distance * 3.0, -distance * 0.30,
                                       distance * 0.55))
    target = center + Vector((0, 0, size.z * 0.12))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.ortho_scale = max(size.z * 0.82, size.x * 1.45, size.y * 1.45)
    lamp.location = center + Vector((3, -4, 6))
    scene.render.filepath = str(renders / f"{variant}-{index:02d}.png")
    bpy.ops.render.render(write_still=True)

print(f"Created {variant}: editable blend, GLB, and eight rendered walk frames")
