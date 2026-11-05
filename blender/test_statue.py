# Test helper for skin_model.py: merges the current Drakeguard kit into one A-posed statue, as an image-to-3D model
# would deliver it, so the skinning can be checked against a known answer.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
import bpy, sys, math
from mathutils import Matrix, Vector
argv = sys.argv[sys.argv.index('--') + 1:]; SRC, DST, ARM = argv[0], argv[1], math.radians(float(argv[2]))
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=SRC)
want = ['pelvis', 'pelvis__frame', 'thigh', 'thigh__plate_D', 'shin', 'shin__greave_D', 'boot', 'boot__sabaton_D', 'torso',
        'torso__chest_D', 'torso__belt', 'torso__belt_D', 'torso__pauld_D', 'torso__spine', 'upperarm', 'upperarm__plate_D',
        'forearm', 'forearm__bracer_D', 'hand', 'head__neck', 'head__dragon']
limbs = {'thigh', 'shin', 'boot', 'upperarm', 'forearm', 'hand'}
keep = []
for name in want:
    e = bpy.data.objects.get(name)
    if not e: print('missing', name); continue
    for c in e.children_recursive:
        if c.type != 'MESH': continue
        for side in ([1, -1] if name.split('__')[0] in limbs else [1]):
            d = c.copy(); d.data = c.data.copy(); bpy.context.scene.collection.objects.link(d)
            d.parent = None; d.matrix_world = c.matrix_world.copy()
            if side < 0: d.matrix_world = Matrix.Scale(-1, 4, Vector((1, 0, 0))) @ d.matrix_world
            if name.split('__')[0] in ('upperarm', 'forearm', 'hand'):        # swing the arm out into an A-pose
                sh = Vector((.31 * side, 0, 1.6)); R = Matrix.Translation(sh) @ Matrix.Rotation(-ARM * side, 4, 'Y') @ Matrix.Translation(-sh)
                d.matrix_world = R @ d.matrix_world
            keep.append(d)
for o in list(bpy.data.objects):
    if o not in keep: bpy.data.objects.remove(o)
bpy.ops.object.select_all(action='DESELECT')
for o in keep: o.select_set(True)
bpy.context.view_layer.objects.active = keep[0]; bpy.ops.object.transform_apply(location=True, rotation=True, scale=True); bpy.ops.object.join()
print('STATUE faces', len(bpy.context.view_layer.objects.active.data.polygons))
bpy.ops.export_scene.gltf(filepath=DST, export_format='GLB', export_yup=True, export_apply=True)
