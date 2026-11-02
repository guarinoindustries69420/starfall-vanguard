# Blender preview renderer for Starfall Vanguard models.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
import bpy,sys,os,math
IN=sys.argv[sys.argv.index('--')+1];OUT=sys.argv[sys.argv.index('--')+2]
for f in ['mech_jackal.glb','mech_ironclad.glb','mech_colossus.glb']:
  for view,(loc,rot) in {'side':((4,0,1.3),(math.radians(90),0,math.radians(90))),'iso':((2.6,-3.6,3.6),(math.radians(55),0,math.radians(35)))}.items():
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=os.path.join(IN,f))
    sc=bpy.context.scene;sc.render.engine='BLENDER_WORKBENCH';sc.render.resolution_x=sc.render.resolution_y=300
    cam=bpy.data.objects.new('cam',bpy.data.cameras.new('cam'));sc.collection.objects.link(cam);sc.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=3.2
    cam.location=loc;cam.rotation_euler=rot;sc.render.filepath=os.path.join(OUT,f.replace('.glb',f'_{view}.png'));bpy.ops.render.render(write_still=True)
