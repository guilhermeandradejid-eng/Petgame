"""Renders a turnaround preview of the generated glb files (Cycles, CPU).
Usage: python preview.py out.png model1.glb [model2.glb ...]"""
import math, sys
import bpy
from mathutils import Vector

out, models = sys.argv[1], sys.argv[2:]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
x = -len(models) * 0.8 + 0.8
for path in models:
    for ang in (0, 1):
        bpy.ops.import_scene.gltf(filepath=path)
        roots = [o for o in bpy.context.selected_objects if o.parent is None]
        for r in roots:
            r.rotation_mode = "XYZ"
            r.location.x = x
            r.rotation_euler.z = math.radians(-30 if ang == 0 else 150)
        x += 0.95
floor = bpy.data.meshes.new("f"); 
bpy.ops.mesh.primitive_plane_add(size=30)
pm = bpy.data.materials.new("floor"); pm.use_nodes = True
pm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.75, 0.9, 1)
bpy.context.active_object.data.materials.append(pm)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam)
cam.location = (0, -6.2, 1.5); cam.rotation_euler = (math.radians(83), 0, 0)
cam.data.lens = 50 if len(models) > 1 else 70
sc.camera = cam
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun)
sun.rotation_euler = (math.radians(45), math.radians(20), math.radians(-35)); sun.data.energy = 3.5
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.7, 0.8, 1.0, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
sc.render.engine = "CYCLES"; sc.cycles.samples = 24; sc.cycles.device = "CPU"
sc.render.resolution_x = 1280; sc.render.resolution_y = 560
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
