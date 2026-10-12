"""Render helpers for reviewing poses: a small Cycles studio around the origin."""
import math
import bpy
from mathutils import Vector
from vinyl import hexc, vinyl


def studio(cam_yaw=-30, dist=6.5, height=1.6, target_z=1.0, lens=50, size=(480, 480), samples=16):
    s = bpy.context.scene
    ground = vinyl("ground", "#bfe3d0", rough=0.6, coat=0.0)
    if "Ground" not in bpy.data.objects:
        bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
        g = bpy.context.active_object
        g.name = "Ground"
        g.data.materials.append(ground)
        w = bpy.data.worlds.new("w")
        s.world = w
        w.use_nodes = True
        w.node_tree.nodes["Background"].inputs[0].default_value = hexc("#cfe9ff")
        w.node_tree.nodes["Background"].inputs[1].default_value = 0.9
        for name, loc, energy, color in (("key", (-4, -6, 6), 900, "#fff3e0"), ("rim", (4, 5, 4), 600, "#cfe0ff"),
                                          ("fill", (5, -6, 2), 250, "#ffe6f0")):
            ld = bpy.data.lights.new(name, "AREA")
            ld.energy = energy
            ld.size = 5
            ld.color = hexc(color)[:3]
            o = bpy.data.objects.new(name, ld)
            o.location = loc
            o.rotation_euler = (Vector((0, 0, 0.8)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
            s.collection.objects.link(o)
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        s.collection.objects.link(cam)
        s.camera = cam
    cam = s.camera
    cam.data.lens = lens
    a = math.radians(cam_yaw)
    cam.location = (math.sin(a) * dist, -math.cos(a) * dist, height)
    cam.rotation_euler = (Vector((0, 0, target_z)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    s.render.engine = "CYCLES"
    s.cycles.device = "CPU"
    s.cycles.samples = samples
    s.cycles.use_denoising = True
    s.render.resolution_x, s.render.resolution_y = size
    s.view_settings.view_transform = "AgX"
    s.view_settings.look = "AgX - Medium High Contrast"


def shot(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
