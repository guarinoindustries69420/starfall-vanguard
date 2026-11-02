# Blender preview renderer for Starfall Vanguard models.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
import bpy,sys,os,math
IN=sys.argv[sys.argv.index('--')+1];OUT=sys.argv[sys.argv.index('--')+2]
files=sorted(f for f in os.listdir(IN) if f.endswith('.glb'))
for f in files:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(IN,f))
    sc=bpy.context.scene;sc.render.engine='BLENDER_WORKBENCH';sc.display.shading.light='STUDIO';sc.display.shading.color_type='MATERIAL'
    sc.render.resolution_x=sc.render.resolution_y=400;sc.render.film_transparent=False
    cam=bpy.data.objects.new('cam',bpy.data.cameras.new('cam'));sc.collection.objects.link(cam);sc.camera=cam
    cam.data.type='ORTHO';cam.data.ortho_scale=3.0 if 'heavy' in f and 'compact' in f else 2.2
    cam.location=(1.8,-2.6,2.6);cam.rotation_euler=(math.radians(55),0,math.radians(35))
    sc.render.filepath=os.path.join(OUT,f.replace('.glb','.png'));bpy.ops.render.render(write_still=True)
