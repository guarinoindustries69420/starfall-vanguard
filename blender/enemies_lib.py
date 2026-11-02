# Starfall Vanguard enemy models, built in Blender (bpy) and exported as GLB.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G³), a department of Guarino Industries LLC. Blender coords: X right, -Y forward (exports to glTF +Z), Z up.
import bpy, bmesh, math, sys, os
from mathutils import Vector, Matrix
OUT=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else '/tmp/out'
os.makedirs(OUT,exist_ok=True)
COL={'base':(0.55,0.6,0.3,1),'trim':(0.25,0.3,0.15,1),'acc':(0.7,0.85,0.4,1),'glow':(0.8,1,0.5,1),'dark':(0.12,0.13,0.15,1)}
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for k,c in COL.items():
        m=bpy.data.materials.new(k);m.diffuse_color=c
def empty(name,loc=(0,0,0),parent=None):
    e=bpy.data.objects.new(name,None);e.location=loc;bpy.context.scene.collection.objects.link(e)
    if parent:e.parent=parent
    return e
def finish(o,mat,parent,smooth=True,bevel=0,subd=0):
    o.data.materials.append(bpy.data.materials[mat])
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    if bevel:
        md=o.modifiers.new('b','BEVEL');md.width=bevel;md.segments=2;md.limit_method='ANGLE'
    if subd:
        md=o.modifiers.new('s','SUBSURF');md.levels=subd;md.render_levels=subd
    for md in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=md.name)
    if smooth:bpy.ops.object.shade_smooth()
    else:bpy.ops.object.shade_flat()
    o.select_set(False)
    if parent:
        mw=o.matrix_world.copy();o.parent=parent;o.matrix_world=mw
    return o
def ell(name,loc,scale,mat,parent,seg=18,rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,radius=1,location=loc)
    o=bpy.context.active_object;o.name=name;o.scale=scale;bpy.ops.object.transform_apply(scale=True)
    return finish(o,mat,parent)
def box(name,loc,size,mat,parent,rot=(0,0,0),bevel=.02):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc,rotation=rot)
    o=bpy.context.active_object;o.name=name;o.scale=size;bpy.ops.object.transform_apply(scale=True)
    return finish(o,mat,parent,smooth=False,bevel=bevel)
def cyl(name,loc,r1,r2,h,mat,parent,rot=(0,0,0),verts=12,smooth=True):
    bpy.ops.mesh.primitive_cone_add(vertices=verts,radius1=r1,radius2=r2,depth=h,location=loc,rotation=rot)
    o=bpy.context.active_object;o.name=name;return finish(o,mat,parent,smooth=smooth)
def seg(name,a,b,r1,r2,mat,parent,verts=8):
    a=Vector(a);b=Vector(b);d=b-a;mid=(a+b)/2
    bpy.ops.mesh.primitive_cone_add(vertices=verts,radius1=r1,radius2=r2,depth=d.length,location=mid)
    o=bpy.context.active_object;o.name=name
    o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(d.normalized())
    finish(o,mat,parent);ell(name+'_j',a,(r1*1.15,r1*1.15,r1*1.15),mat,parent,seg=10,rings=6);return o
def torus(name,loc,R,r,mat,parent):
    bpy.ops.mesh.primitive_torus_add(major_radius=R,minor_radius=r,major_segments=32,minor_segments=8,location=loc)
    o=bpy.context.active_object;o.name=name;return finish(o,mat,parent)
def rig():
    root=empty('root');body=empty('body',parent=root);L=empty('legL',parent=root);R=empty('legR',parent=root);return root,body,L,R
def export(fn):
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,fn),export_format='GLB',export_yup=True,export_apply=True,export_materials='EXPORT',export_normals=True,export_texcoords=False,export_draco_mesh_compression_enable=False)
    print('exported',fn,os.path.getsize(os.path.join(OUT,fn)))

