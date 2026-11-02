"""Grid preview of many props: python preview_grid.py out.png a.glb b.glb ..."""
import math, sys, bpy
out, models = sys.argv[1], sys.argv[2:]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
cols = 4
for i, path in enumerate(models):
    bpy.ops.import_scene.gltf(filepath=path)
    for r in [o for o in bpy.context.selected_objects if o.parent is None]:
        r.rotation_mode = "XYZ"; r.location = ((i % cols - 1.5) * 3.2, (i // cols) * 3.5, 0); r.rotation_euler.z = math.radians(-20)
bpy.ops.mesh.primitive_plane_add(size=60)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam)
cam.location = (0, -12, 9); cam.rotation_euler = (math.radians(58), 0, 0); sc.camera = cam
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun)
sun.rotation_euler = (math.radians(45), math.radians(20), math.radians(-35)); sun.data.energy = 3.5
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.7, 0.8, 1.0, 1)
sc.render.engine = "CYCLES"; sc.cycles.samples = 16
sc.render.resolution_x = 1280; sc.render.resolution_y = 800; sc.render.filepath = out
bpy.ops.render.render(write_still=True)
