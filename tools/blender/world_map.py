"""World 1's map, built and rendered in Blender, then made into pixel art to match the levels.

Run from the project folder:
    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/world_map.py
Builds a small island from code: meadows, a forest, a river, mountains, Lantern Village in the south-west and
Yuva's dark castle in the north-east, with a sandy path joining World 1's five levels. Renders it small from above
at an angle (tools/pixel_map.py then scales it up with hard pixel edges).
Writes art/worldmap/world1_render.png (the small render) and unity/Assets/Resources/Data/worldmap.json
{"levels": [{"id", "name", "x", "y"}]}  (x, y: where each level's marker goes, as fractions of the picture from
its bottom-left).
"""
import json
import math
import os
import random

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector, noise

ROOT = os.path.abspath(".")
SMALL = (480, 270)          # the render; scaled x4 to 1920 x 1080 with hard edges
random.seed(3)

LEVELS = [  # (id, name, x, y) on the island, from the village to Yuva's castle
    ("level1", "Lantern Village", -6.0, -4.2),
    ("level2", "Sunflower Meadow", -2.6, -2.4),
    ("level3", "Whispering Wood", 0.6, -0.4),
    ("level4", "River Cliffs", 3.4, 1.0),
    ("level5", "Yuva's Castle", 5.6, 3.6),
]


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, rough=0.8, emit=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = rough
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*emit, 1)
        bsdf.inputs["Emission Strength"].default_value = 3.0
    return m


def height(x, y):
    """The island: high in the north-east (the mountains), low and gentle in the south-west (the meadows)."""
    r = math.sqrt((x / 9.5) ** 2 + (y / 6.8) ** 2)
    island = max(0.0, 1.0 - r ** 2.2)                       # 1 in the middle, 0 at the shore
    hills = noise.fractal(Vector((x * 0.25, y * 0.25, 0.3)), 1.0, 2.0, 4) * 0.6
    mountains = max(0.0, (x + y) * 0.24 - 0.4) ** 1.7 * 1.6  # rising toward the north-east
    # a river from the mountains down to the southern sea, winding
    rx = 1.8 + math.sin(y * 0.55) * 1.1 + y * 0.35
    river = math.exp(-((x - rx) ** 2) / 0.05) if y < 3.6 else 0   # (narrow: a river, not a bay)
    h = island * (0.8 + hills + mountains) - river * 1.15
    return h * 1.6 - 0.25


def terrain():
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=160, y_subdivisions=120, size=1)
    ob = bpy.context.object
    ob.scale = (22, 16, 1)
    bpy.ops.object.transform_apply(scale=True)
    me = ob.data
    for v in me.vertices:
        v.co.z = height(v.co.x, v.co.y)
    me.update()
    # colour by height and steepness: sand, meadow, forest floor, rock, snow
    col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for poly in me.polygons:
        z = sum(me.vertices[i].co.z for i in poly.vertices) / len(poly.vertices)
        steep = 1 - poly.normal.z
        if z < 0.08:
            c = (0.78, 0.66, 0.42)
        elif steep > 0.32 and z > 0.8:
            c = (0.36, 0.33, 0.38)
        elif z > 2.6:
            c = (0.92, 0.92, 0.98)
        elif z > 1.5:
            c = (0.26, 0.32, 0.22)
        else: # meadow, in natural patches of lighter and darker green
            cx = sum(me.vertices[i].co.x for i in poly.vertices) / len(poly.vertices)
            cy = sum(me.vertices[i].co.y for i in poly.vertices) / len(poly.vertices)
            n = noise.noise(Vector((cx * 0.6, cy * 0.6, 1.7)))
            c = (0.20 + 0.06 * n, 0.42 + 0.08 * n, 0.14 + 0.03 * n)
        for li in poly.loop_indices:
            col.data[li].color = (*c, 1)
    m = bpy.data.materials.new("Ground")
    m.use_nodes = True
    nt = m.node_tree
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
    me.materials.append(m)
    return ob


def water():
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0.02))
    bpy.context.object.data.materials.append(material("Water", (0.06, 0.24, 0.36), rough=0.15))


def tree(x, y, kind):
    z = height(x, y)
    trunk_m = bpy.data.materials.get("Trunk") or material("Trunk", (0.30, 0.20, 0.12))
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.05, depth=0.3, location=(x, y, z + 0.15))
    bpy.context.object.data.materials.append(trunk_m)
    if kind == "pine":
        m = bpy.data.materials.get("Pine") or material("Pine", (0.06, 0.22, 0.14))
        bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=0.24, depth=0.7, location=(x, y, z + 0.6))
    else:
        m = bpy.data.materials.get("Leaf") or material("Leaf", (0.22, 0.42, 0.12))
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.26, location=(x, y, z + 0.48))
    bpy.context.object.data.materials.append(m)


def house(x, y, roof):
    z = height(x, y)
    wall = bpy.data.materials.get("Wall") or material("Wall", (0.85, 0.76, 0.58))
    bpy.ops.mesh.primitive_cube_add(size=0.34, location=(x, y, z + 0.17))
    bpy.context.object.data.materials.append(wall)
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.3, depth=0.28, location=(x, y, z + 0.48), rotation=(0, 0, math.pi / 4))
    bpy.context.object.data.materials.append(material("Roof", roof))


def castle(x, y):
    z = height(x, y)
    stone = material("Castle", (0.25, 0.20, 0.32))
    roof = material("Castle Roof", (0.45, 0.10, 0.22))
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z + 0.35))
    bpy.context.object.scale = (0.9, 0.6, 0.7)
    bpy.context.object.data.materials.append(stone)
    for dx, dy, hgt in ((-0.5, -0.35, 1.3), (0.5, -0.35, 1.3), (-0.5, 0.35, 1.0), (0.5, 0.35, 1.6)):
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.16, depth=hgt, location=(x + dx, y + dy, z + hgt / 2))
        bpy.context.object.data.materials.append(stone)
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.21, depth=0.4, location=(x + dx, y + dy, z + hgt + 0.2))
        bpy.context.object.data.materials.append(roof)
    # a glowing window: something is waiting in there
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.07, location=(x + 0.5, y - 0.5, z + 1.2))
    bpy.context.object.data.materials.append(material("Window", (1, 0.4, 0.5), emit=(1, 0.3, 0.45)))


def path():
    """A sandy path along the levels, sampled onto the ground."""
    pts = []
    for (_, _, x0, y0), (_, _, x1, y1) in zip(LEVELS, LEVELS[1:]):
        for i in range(20):
            t = i / 20
            x = x0 + (x1 - x0) * t + math.sin(t * math.pi) * 0.2   # a gentle wiggle between markers
            y = y0 + (y1 - y0) * t - math.sin(t * math.pi) * 0.3
            pts.append((x, y))
    pts.append(LEVELS[-1][2:])
    crv = bpy.data.curves.new("Path", "CURVE")
    crv.dimensions = "3D"
    crv.bevel_depth = 0.07
    crv.bevel_resolution = 1
    sp = crv.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for p, (x, y) in zip(sp.points, pts):
        p.co = (x, y, max(height(x, y), 0.05) + 0.06, 1)
    ob = bpy.data.objects.new("Path", crv)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(material("Sand", (0.92, 0.80, 0.52)))


def river_x(y):
    return 1.8 + math.sin(y * 0.55) * 1.1 + y * 0.35


def bridge():
    """A little wooden bridge where the path crosses the river."""
    wood = material("Bridge", (0.42, 0.28, 0.16))
    # where the path from level 3 to level 4 meets the river
    (_, _, x0, y0), (_, _, x1, y1) = LEVELS[2], LEVELS[3]
    best = min(((abs((x0 + (x1 - x0) * t) - river_x(y0 + (y1 - y0) * t)), t) for t in [i / 100 for i in range(101)]))
    t = best[1]
    x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
    ang = math.atan2(y1 - y0, x1 - x0)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, 0.32), rotation=(0, 0, ang))
    bpy.context.object.scale = (1.1, 0.3, 0.06)
    bpy.context.object.data.materials.append(wood)


def scenery():
    # Lantern Village around level 1
    for dx, dy, roof in ((-0.9, 0.5, (0.72, 0.30, 0.22)), (0.6, 0.7, (0.35, 0.35, 0.60)), (-0.2, 1.2, (0.72, 0.30, 0.22)),
                         (0.9, -0.3, (0.55, 0.40, 0.25))):
        house(LEVELS[0][2] + dx, LEVELS[0][3] + dy, roof)
    castle(LEVELS[4][2] + 0.4, LEVELS[4][3] + 0.6)
    # forest: pines in the middle and on the slopes, round trees in the meadows
    for _ in range(420):
        x, y = random.uniform(-9, 9), random.uniform(-6.5, 6.5)
        z = height(x, y)
        if z < 0.25 or z > 2.1:
            continue
        near = min(math.hypot(x - lx, y - ly) for _, _, lx, ly in LEVELS)
        if near < 0.7:
            continue  # (keep the level spots clear for their markers)
        in_wood = math.hypot(x - 0.8, y - 0.2) < 3.2 or z > 1.3
        if in_wood or random.random() < 0.25:
            tree(x, y, "pine" if in_wood else "round")


def light_and_camera():
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 4.5
    sun.color = (1.0, 0.78, 0.55)          # golden hour, like Level 1
    sun.angle = math.radians(3)
    so = bpy.data.objects.new("Sun", sun)
    so.rotation_euler = (math.radians(62), math.radians(8), math.radians(-60))
    bpy.context.collection.objects.link(so)
    world = bpy.data.worlds.new("Sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.42, 0.40, 0.55, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.45
    bpy.context.scene.world = world
    cam = bpy.data.cameras.new("Camera")
    cam.type = "ORTHO"
    cam.ortho_scale = 23.5
    cam.shift_y = 0.04
    co = bpy.data.objects.new("Camera", cam)
    co.location = (0, -14, 13)
    co.rotation_euler = (math.radians(47), 0, 0)
    bpy.context.collection.objects.link(co)
    bpy.context.scene.camera = co
    return co


def render(cam):
    sc = bpy.context.scene
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            sc.render.engine = engine
            break
        except TypeError:
            continue
    sc.render.resolution_x, sc.render.resolution_y = SMALL
    sc.render.resolution_percentage = 100
    try:
        sc.view_settings.view_transform = "AgX"
        sc.view_settings.look = "AgX - Punchy"
    except TypeError:
        sc.view_settings.view_transform = "Standard"
    os.makedirs(f"{ROOT}/art/worldmap", exist_ok=True)
    small = f"{ROOT}/art/worldmap/world1_render.png"
    sc.render.filepath = small
    bpy.ops.render.render(write_still=True)
    # where each level's marker goes on the picture
    out = []
    for lid, name, x, y in LEVELS:
        p = world_to_camera_view(sc, cam, Vector((x, y, max(height(x, y), 0.05))))
        out.append({"id": lid, "name": name, "x": round(p.x, 4), "y": round(p.y, 4)})
    os.makedirs(f"{ROOT}/unity/Assets/Resources/Data", exist_ok=True)
    json.dump({"levels": out}, open(f"{ROOT}/unity/Assets/Resources/Data/worldmap.json", "w"), indent=1)
    return small


clear()
terrain()
water()
path()
scenery()
bridge()
cam = light_and_camera()
small = render(cam)
print("RENDERED", small)
