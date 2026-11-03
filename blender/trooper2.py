# Starfall Vanguard trooper, second pass: anatomical undersuit, layered armor kits, helmets and weapons.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
# Everything is modelled in game coordinates (x right, y up, z forward) and converted to Blender (x, -z, y).
# Each exported top-level empty is a rig joint ("thigh") or a kit piece on that joint ("torso__chest_M").
# Ambient occlusion is baked into vertex colours (COLOR_0) so creases and overlaps read at sprite size.
import bpy, bmesh, math, sys, os, random
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
OUT=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else '/tmp/out'
os.makedirs(OUT,exist_ok=True)
MATS=['base','trim','acc','dark','under','visor','metal','cape','glow','gold','leather','cloth','eye']
def G(x,y,z):return Vector((x,-z,y))
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for k in MATS:bpy.data.materials.new(k)
GROUP={}   # object name -> group key
def tag(o,grp):GROUP[o.name]=grp;return o
def link_mesh(name,bm):
    me=bpy.data.meshes.new(name);bm.to_mesh(me);bm.free();o=bpy.data.objects.new(name,me);bpy.context.scene.collection.objects.link(o);return o
def finish(o,mat,grp,thick=0,bevel=0,angle=40,subd=0):
    o.data.materials.append(bpy.data.materials[mat])
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    if thick:md=o.modifiers.new('t','SOLIDIFY');md.thickness=thick;md.offset=-1;md.use_even_offset=False
    if bevel and not thick:md=o.modifiers.new('b','BEVEL');md.width=bevel;md.segments=1 if (thick or angle<=30) else 2;md.limit_method='ANGLE';md.angle_limit=math.radians(35)
    if subd:md=o.modifiers.new('s','SUBSURF');md.levels=subd
    for md in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle))
    o.select_set(False);return tag(o,grp)
def cut(bm,cuts):
    for (p,n) in cuts:
        geom=bm.verts[:]+bm.edges[:]+bm.faces[:]
        pc=G(*p)+G(*n).normalized()*1.37e-4   # nudge off exact vertex rings so the cut is the same on every run
        bmesh.ops.bisect_plane(bm,geom=geom,plane_co=pc,plane_no=G(*n),clear_outer=True)
def ell(name,c,r,mat,grp,seg=10,rings=6,cuts=(),thick=0,bevel=0,angle=60):
    bm=bmesh.new();bmesh.ops.create_uvsphere(bm,u_segments=seg,v_segments=rings,radius=1)
    bmesh.ops.scale(bm,vec=Vector((r[0],r[2],r[1])),verts=bm.verts);bmesh.ops.translate(bm,vec=G(*c),verts=bm.verts)
    cut(bm,cuts);return finish(link_mesh(name,bm),mat,grp,thick=thick,bevel=bevel,angle=angle)
def plate(name,c,r,mat,grp,sq=.6,taper=0,rot=(0,0,0),cuts=(),thick=.02,seg=11,rings=7,angle=50,dz=0):
    # superellipsoid shell: sq<1 squares it off (rounded box), taper widens the top; cuts are relative to the centre, before rotation
    bm=bmesh.new();bmesh.ops.create_uvsphere(bm,u_segments=seg,v_segments=rings,radius=1)
    for v in bm.verts:
        x,y,z=v.co.x,-v.co.y,v.co.z   # game x, z(fwd), y(up) of the unit sphere -> use game naming gx,gz,gy
        gx,gz,gy=x,y,z
        f=lambda t:math.copysign(abs(t)**sq,t)
        gx,gy,gz=f(gx),f(gy),f(gz)
        gx*=r[0]*(1+taper*gy);gy*=r[1];gz*=r[2]
        gz+=dz*(1-gx*gx/(r[0]*r[0]+1e-9))   # optional forward bulge along the centre line
        v.co=G(gx,gy,gz)
    cut(bm,cuts)
    R=Matrix.Rotation(rot[0],3,'X')@Matrix.Rotation(-rot[2],3,'Y')@Matrix.Rotation(rot[1],3,'Z')
    bmesh.ops.rotate(bm,verts=bm.verts,cent=Vector(),matrix=R);bmesh.ops.translate(bm,vec=G(*c),verts=bm.verts)
    return finish(link_mesh(name,bm),mat,grp,thick=thick,angle=angle)
def tube(name,a,b,r1,r2,mat,grp,verts=12,cuts=(),thick=0,bevel=0,caps=True,bulge=0,sx=1,sz=1,rings=6,angle=60):
    a=G(*a);b=G(*b);d=b-a;L=d.length
    bm=bmesh.new();bmesh.ops.create_cone(bm,cap_ends=caps,cap_tris=False,segments=verts,radius1=1,radius2=1,depth=1)
    # add rings for bulge
    if rings>1:
        edges=[e for e in bm.edges if abs(e.verts[0].co.z-e.verts[1].co.z)>.5]
        bmesh.ops.subdivide_edges(bm,edges=edges,cuts=rings-1,use_grid_fill=True)
    for v in bm.verts:
        t=.5-v.co.z  # 0 at a (top, z=+.5) .. 1 at b
        rr=r1+(r2-r1)*t+bulge*math.sin(t*math.pi)
        v.co.x*=rr*sx;v.co.y*=rr*sz;v.co.z=-t*L
    q=Vector((0,0,-1)).rotation_difference(d.normalized())
    bmesh.ops.rotate(bm,verts=bm.verts,cent=Vector(),matrix=q.to_matrix());bmesh.ops.translate(bm,vec=a,verts=bm.verts)
    cut(bm,cuts);return finish(link_mesh(name,bm),mat,grp,thick=thick,bevel=bevel,angle=angle)
def box(name,c,s,mat,grp,bevel=.012,rot=(0,0,0)):
    bm=bmesh.new();bmesh.ops.create_cube(bm,size=1)
    bmesh.ops.scale(bm,vec=Vector((s[0],s[2],s[1])),verts=bm.verts)
    R=Matrix.Rotation(rot[0],3,'X')@Matrix.Rotation(-rot[1],3,'Z')@Matrix.Rotation(-rot[2],3,'Y')  # game x / y / z rotations
    bmesh.ops.rotate(bm,verts=bm.verts,cent=Vector(),matrix=R);bmesh.ops.translate(bm,vec=G(*c),verts=bm.verts)
    return finish(link_mesh(name,bm),mat,grp,bevel=bevel,angle=30)
def ring(name,c,rx,rz,h,t,mat,grp,axis='y',verts=16):
    # open band (belt, collar, cuff) of height h and thickness t
    bm=bmesh.new();bmesh.ops.create_cone(bm,cap_ends=False,segments=verts,radius1=1,radius2=1,depth=h)
    for v in bm.verts:v.co.x*=rx;v.co.y*=rz
    if axis=='x':bmesh.ops.rotate(bm,verts=bm.verts,cent=Vector(),matrix=Matrix.Rotation(math.pi/2,3,'Y'))
    if axis=='zf':bmesh.ops.rotate(bm,verts=bm.verts,cent=Vector(),matrix=Matrix.Rotation(math.pi/2,3,'X'))
    bmesh.ops.translate(bm,vec=G(*c),verts=bm.verts)
    o=link_mesh(name,bm);o.data.materials.append(bpy.data.materials[mat])
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    md=o.modifiers.new('t','SOLIDIFY');md.thickness=t;md.offset=1;bpy.ops.object.modifier_apply(modifier='t')
    md=o.modifiers.new('b','BEVEL');md.width=t*.35;md.segments=2;bpy.ops.object.modifier_apply(modifier='b')
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(50));o.select_set(False);return tag(o,grp)
def cylz(name,c,r,h,mat,grp,axis='z',verts=14,r2=None,bevel=.004):
    # straight cylinder along a game axis
    bm=bmesh.new();bmesh.ops.create_cone(bm,cap_ends=True,cap_tris=False,segments=verts,radius1=r,radius2=r2 if r2 is not None else r,depth=h)
    rot={'y':Matrix.Identity(3),'z':Matrix.Rotation(-math.pi/2,3,'X'),'x':Matrix.Rotation(math.pi/2,3,'Y')}[axis]
    bmesh.ops.rotate(bm,verts=bm.verts,cent=Vector(),matrix=rot);bmesh.ops.translate(bm,vec=G(*c),verts=bm.verts)
    return finish(link_mesh(name,bm),mat,grp,bevel=bevel,angle=35)

reset()
# ---------------- joints (game coords). Limbs are built on the right side and mirrored in game.
J={'pelvis':(0,.98,0),'torso':(0,1.05,0),'head':(0,1.82,.02),'thigh':(.13,.95,0),'shin':(.13,.51,0),'boot':(.13,.09,0),
   'upperarm':(.31,1.6,0),'forearm':(.31,1.3,0),'hand':(.31,1.03,0),'gun':(0,0,0)}
X=.13;AX=.31
# ---------------- undersuit (fabric bodysuit with padding)
ell('u_pelvis',(0,.97,0),(.165,.1,.115),'under','pelvis')
ell('u_glute',(0,.93,-.04),(.15,.08,.09),'under','pelvis')
ell('u_chest',(0,1.43,-.005),(.2,.16,.125),'under','torso')
ell('u_lat',(0,1.3,-.01),(.18,.13,.115),'under','torso')
ell('u_abd',(0,1.15,.0),(.155,.13,.105),'under','torso')
tube('u_neck',(0,1.66,0),(0,1.79,.01),.06,.055,'under','torso',verts=14,rings=1)
for s in(-1,1):ell('u_trap%d'%s,(s*.13,1.6,-.02),(.1,.05,.08),'under','torso')
tube('u_thigh',(X,.97,0),(X,.53,.0),.098,.068,'under','thigh',bulge=.012,sz=1.05)
ell('u_knee',(X,.51,.012),(.07,.07,.07),'under','shin')
tube('u_shin',(X,.5,0),(X,.12,0),.066,.046,'under','shin',bulge=.004)
ell('u_calf',(X,.37,-.022),(.056,.1,.058),'under','shin')
# boots (dark leather/composite)
tube('b_shaft',(X,.24,0),(X,.07,.0),.064,.06,'dark','boot',rings=2)
box('b_foot',(X,.05,.045),(.11,.085,.25),'dark','boot',bevel=.035)
ell('b_toe',(X,.045,.15),(.06,.045,.06),'dark','boot',cuts=[((0,.02,0),(0,-1,0))])
box('b_sole',(X,.012,.04),(.122,.024,.29),'dark','boot',bevel=.008)
box('b_heel',(X,.03,-.07),(.11,.04,.07),'dark','boot',bevel=.01)
ring('b_cuff',(X,.235,0),.066,.066,.03,.008,'trim','boot')
ell('b_toecap',(X,.06,.13),(.058,.04,.06),'trim','boot',cuts=[((0,.05,0),(0,-1,0)),((0,0,.09),(0,0,-1))],thick=.006)
# arms
ell('u_shoulder',(AX,1.6,0),(.075,.075,.08),'under','upperarm')
tube('u_upper',(AX,1.6,0),(AX,1.31,0),.067,.055,'under','upperarm',bulge=.008)
ell('u_elbow',(AX,1.3,0),(.052,.052,.052),'under','forearm')
tube('u_fore',(AX,1.3,0),(AX,1.05,0),.056,.042,'under','forearm',bulge=.006)
# glove: fist gripping (palm faces -x, fingers curled forward)
box('g_palm',(AX,.985,.0),(.04,.075,.075),'dark','hand',bevel=.015)
box('g_fingers',(AX-.028,.975,.022),(.04,.075,.045),'dark','hand',bevel=.012)
cylz('g_thumb',(AX-.03,1.0,.04),.012,.04,'dark','hand',axis='x',verts=6)
box('g_knuckle',(AX+.005,.975,.04),(.03,.06,.03),'trim','hand',bevel=.008)
ring('g_cuff',(AX,1.04,0),.05,.05,.03,.01,'dark','hand')

# ---------------- chest kits
def rivets(objname,pts,grp,mat='metal',d=(0,0,-1),r=.0075):
    o=bpy.data.objects.get(objname)
    if not o:return
    dv=G(*d).normalized()
    for n,(x,y,z0) in enumerate(pts):
        org=G(x,y,z0)-dv*0.6
        ok,loc,nor,_=o.ray_cast(org,dv)
        if not ok:continue
        p=loc+nor*.002;gx,gy,gz=p.x,p.z,-p.y
        ell('%s_rv%d'%(objname,n),(gx,gy,gz),(r,r,r),mat,grp,seg=6,rings=4)
def chest(k,rx,ry,rz,th):
    g='torso__chest_'+k;cy=1.43
    plate('c%s_front'%k,(0,cy,0),(rx,ry,rz),'base',g,sq=.55,taper=.18,dz=.02,cuts=[((0,0,.02),(0,0,-1)),((0,ry*.88,0),(0,1,0)),((0,-ry*.78,0),(0,-1,0))],thick=th)
    plate('c%s_back'%k,(0,cy,-.005),(rx*.97,ry*.95,rz*.9),'base',g,sq=.55,taper=.15,cuts=[((0,0,-.03),(0,0,1)),((0,ry*.85,0),(0,1,0)),((0,-ry*.8,0),(0,-1,0))],thick=th)
    box('c%s_seam'%k,(0,cy+.01,rz+.022),(.01,ry*1.2,.01),'trim',g,bevel=.003)
    bpy.context.view_layer.update();rivets('c%s_front'%k,[(sx*rx*.78,cy+dy,0) for sx in(-1,1) for dy in(-.08,0,.08)]+[(sx*rx*.35,cy+ry*.78,0) for sx in(-1,1)],g)
    box('c%s_emb'%k,(0,cy+.07,rz+.008),(.065,.04,.02),'acc',g,bevel=.006,rot=(-.3,0,0))
    n=3 if k=='H' else 2
    for i in range(n):
        y=cy-ry*.78-.035-i*.058
        plate('c%s_lame%d'%(k,i),(0,y,-.005),(rx*.8-i*.012,.045,rz*.88),'base' if i%2==0 else 'trim',g,sq=.5,cuts=[((0,0,.0),(0,0,-1)),((0,.03,0),(0,1,0)),((0,-.03,0),(0,-1,0))],thick=th*.7,seg=15,rings=7)
    for s in(-1,1):box('c%s_strap%d'%(k,s),(s*rx*.95,cy-.02,-.005),(.022,.15,.11),'trim',g,bevel=.006)
    ring('c%s_collar'%k,(0,1.665 if k!='H' else 1.67,0),.1 if k!='H' else .115,.085 if k!='H' else .1,.075 if k!='H' else .1,.016,'trim',g)
    if k=='H':
        for s in(-1,1):plate('cH_rib%d'%s,(s*(rx-.02),cy-.06,0),(.05,.12,rz*.8),'base',g,sq=.55,cuts=[((-s*.0,0,0),(-s,0,0))],thick=.02,seg=11,rings=7)
chest('M',.215,.175,.135,.024)
chest('H',.245,.19,.16,.032)
# light: plate carrier over the suit
g='torso__chest_L'
ell('cL_plate',(0,1.43,0),(.215,.17,.15),'base','torso__chest_L',seg=17,rings=11,cuts=[((0,0,.05),(0,0,-1)),((.13,0,0),(1,0,0)),((-.13,0,0),(-1,0,0)),((0,1.57,0),(0,1,0)),((0,1.28,0),(0,-1,0))],thick=.025,bevel=.005)
box('cL_back',(0,1.43,-.13),(.26,.28,.03),'base',g,bevel=.01)
ring('cL_collar',(0,1.665,0),.095,.08,.07,.014,'trim',g)
for s in(-1,1):
    box('cL_strap%d'%s,(s*.1,1.64,-.005),(.05,.018,.22),'trim',g,bevel=.005)
    box('cL_side%d'%s,(s*.195,1.37,0),(.02,.14,.22),'trim',g,bevel=.005)
for i,x in enumerate((-.09,0,.09)):box('cL_pouch%d'%i,(x,1.25,.135),(.075,.09,.045),'trim',g,bevel=.012);box('cL_flap%d'%i,(x,1.29,.155),(.078,.025,.03),'acc' if i==1 else 'trim',g,bevel=.006)
# belt and pouches (every kit)
g='torso__belt'
ring('belt',(0,1.03,0),.17,.125,.05,.014,'trim',g,verts=20)
box('buckle',(0,1.03,.14),(.06,.045,.02),'acc',g,bevel=.006)
for s in(-1,1):
    box('bp_a%d'%s,(s*.13,1.02,.1),(.06,.07,.04),'trim',g,bevel=.012,rot=(0,s*.55,0))
    box('bp_b%d'%s,(s*.17,1.02,-.03),(.04,.07,.06),'trim',g,bevel=.012)
box('bp_back',(0,1.02,-.135),(.12,.065,.04),'trim',g,bevel=.012)
box('holster',(.2,.92,.0),(.045,.15,.075),'dark',g,bevel=.012)
box('holster_strap',(.2,.98,.0),(.05,.02,.08),'trim',g,bevel=.004)
# backpack / power unit
g='torso__pack'
box('pk_main',(0,1.4,-.215),(.32,.36,.13),'trim',g,bevel=.03)
box('pk_lid',(0,1.58,-.21),(.3,.04,.14),'dark',g,bevel=.012)
cylz('pk_roll',(0,1.63,-.2),.045,.3,'acc',g,axis='x',verts=16)
cylz('pk_cell',(-.1,1.36,-.3),.042,.26,'metal',g,axis='y',verts=16)
ring('pk_glow',(-.1,1.36,-.3),.044,.044,.03,.006,'glow',g)
box('pk_side',(.1,1.35,-.29),(.08,.16,.04),'dark',g,bevel=.01)
cylz('pk_ant',(.12,1.72,-.25),.007,.22,'metal',g,axis='y',verts=6)
cylz('pk_antb',(.12,1.61,-.25),.016,.04,'dark',g,axis='y',verts=10)
# tabard (Warden)
g='torso__tabard'
plate('tab',(0,.8,.135),(.095,.2,.02),'cape',g,sq=.25,rot=(.12,0,0),cuts=[((0,0,0),(0,0,-1))],thick=.008,seg=11,rings=8)
box('tab_band',(0,1.0,.15),(.25,.03,.02),'trim',g,bevel=.005)
# ---------------- pauldrons (on the torso, both sides)
def pauld(k,r,tiers):
    g='torso__pauld_'+k
    for s in(-1,1):
        for t in range(tiers):
            rr=(r[0]*(1-.08*t),r[1],r[2]*(1-.06*t))
            plate('p%s%d_%d'%(k,s,t),(s*(.34+.02*t+r[0]*.2),1.62-t*.048,0),rr,'base' if t%2==0 else 'trim',g,sq=.62,
                  rot=(0,0,-s*(.42+.12*t)),cuts=[((0,-r[1]*.25,0),(0,-1,0)),((-s*r[0]*.55,0,0),(-s,0,0))],thick=.02,seg=14,rings=8)
        bpy.context.view_layer.update();rivets('p%s%d_0'%(k,s),[(s*(.33+r[0]*.2+dx),1.75,dz) for dx in(-.04,.03) for dz in(-.06,.06)],g,d=(0,-1,0))
        if k=='H':box('pH_ridge%d'%s,(s*.36,1.69,0),(.018,.025,r[2]*1.5),'acc',g,bevel=.006,rot=(0,0,-s*.42))
pauld('L',(.08,.04,.095),1)
pauld('M',(.105,.05,.125),2)
pauld('H',(.13,.06,.155),3)
# ---------------- thigh plates
tube('tM',(X,.9,.0),(X,.62,.0),.112,.092,'base','thigh__plate_M',cuts=[((0,0,-.01),(0,0,-1))],thick=.018,bevel=.004,caps=False,rings=4)
ring('tM_strap',(X,.66,0),.075,.075,.025,.008,'trim','thigh__plate_M')
tube('tH',(X,.92,.0),(X,.6,.0),.125,.1,'base','thigh__plate_H',cuts=[((0,0,-.06),(0,0,-1))],thick=.024,bevel=.004,caps=False,rings=4)
tube('tH2',(X+.05,.92,0),(X+.06,.68,0),.07,.06,'trim','thigh__plate_H',cuts=[((X+.03,0,0),(-1,0,0))],thick=.02,bevel=.004,caps=False,rings=3)
ring('tH_strap',(X,.64,0),.078,.078,.03,.01,'trim','thigh__plate_H')
box('tL_pouch',(X+.085,.76,.02),(.04,.11,.085),'trim','thigh__pouch_L',bevel=.012)
ring('tL_strap',(X,.74,0),.08,.08,.022,.008,'dark','thigh__pouch_L')
# ---------------- greaves and knee pads
for k,rs,wrap,kp in(('L',(.07,.06),.03,(.07,.075,.06)),('M',(.084,.068),-.02,(.078,.085,.065)),('H',(.095,.078),-.05,(.09,.1,.075))):
    g='shin__greave_'+k
    if k!='L':tube('sh'+k,(X,.47,0),(X,.15,.0),rs[0],rs[1],'base',g,cuts=[((0,0,wrap),(0,0,-1))],thick=.018 if k=='M' else .024,bevel=.004,caps=False,rings=4)
    else:box('shL',(X,.32,.06),(.06,.2,.018),'base',g,bevel=.008)
    plate('kp'+k,(X,.51,.045),(kp[0]*.85,kp[1],kp[2]*.75),'acc' if k=='L' else 'trim',g,sq=.55,rot=(-.15,0,0),cuts=[((0,0,0),(0,0,-1))],thick=.018,seg=12,rings=8)
# ---------------- forearm bracers and upper-arm plates
tube('brL',(AX,1.1,0),(AX,1.05,0),.05,.046,'trim','forearm__bracer_L',caps=False,thick=.01,rings=1)
for k,r in(('M',(.066,.058)),('H',(.078,.066))):
    g='forearm__bracer_'+k
    tube('br'+k,(AX,1.26,0),(AX,1.07,0),r[0],r[1],'base',g,caps=False,thick=.016,bevel=.004,rings=1,sx=1.0,sz=1.1,verts=10)
    ring('br%s_w'%k,(AX,1.07,0),r[1]+.006,(r[1]+.006)*1.1,.025,.008,'trim',g)
    plate('ep'+k,(AX,1.3,-.03),(.045,.05,.04) if k=='M' else (.055,.06,.045),'trim',g,sq=.55,cuts=[((0,0,0),(0,0,1))],thick=.014,seg=11,rings=7)
    g='upperarm__plate_'+k
    tube('ua'+k,(AX,1.52,0),(AX,1.37,0),r[0]+.012,r[1]+.012,'base',g,cuts=[((AX-.01,0,0),(-1,0,0))],thick=.016,bevel=.004,caps=False,rings=2)
# ---------------- helmets (head joint at 1.82)
HC=(0,1.855,.02)
def helm(grp,r=(.132,.148,.158),slit=False):
    plate(grp+'_shell',HC,r,'base',grp,sq=.86,taper=.07,dz=.01,cuts=[((0,-.135,0),(0,-1,0))],thick=.018,seg=22,rings=14)
    plate(grp+'_neck',(0,1.755,-.035),(r[0]*1.08,.05,r[2]*1.05),'trim',grp,sq=.7,rot=(.38,0,0),cuts=[((0,0,-.01),(0,0,1)),((0,.0,0),(0,-1,0))],thick=.014,seg=16,rings=8)
    for s in(-1,1):plate(grp+'_cheek%d'%s,(s*r[0]*.86,1.785,.045),(.03,.055,.075),'base',grp,sq=.6,rot=(0,0,-s*.18),cuts=[((-s*.0,0,0),(-s,0,0))],thick=.012,seg=12,rings=8)
    box(grp+'_ridge',(0,HC[1]+r[1]*.97,HC[2]-.02),(.016,.016,r[2]*1.5),'trim',grp,bevel=.005)
    bpy.context.view_layer.update();rivets(grp+'_shell',[(s*r[0]*.8,1.875,.06) for s in(-1,1)]+[(s*r[0]*.55,1.93,.1) for s in(-1,1)],grp)
    band=lambda nm,k,lo,hi,zc,mat,th:plate(grp+nm,HC,(r[0]*k,r[1]*k,r[2]*k),mat,grp,sq=.86,taper=.07,dz=.01*k,cuts=[((0,hi,0),(0,1,0)),((0,lo,0),(0,-1,0)),((0,0,zc),(0,0,-1))],thick=th,seg=24,rings=18)
    band('_brow',1.045,.042,.07,.0,'trim',.01)
    if slit:band('_visor',1.03,.0,.022,.03,'visor',.008)
    else:band('_visor',1.03,-.028,.036,.045,'visor',.01)
    band('_chin',1.05,-.135,-.045,.035,'trim',.014)
    for s in(-1,1):cylz(grp+'_ear%d'%s,(s*r[0]*1.02,1.84,.0),.042,.024,'trim',grp,axis='x',verts=16)
    box(grp+'_rear',(0,1.8,-r[2]*.97),(.12,.05,.03),'trim',grp,bevel=.008)
helm('head__visor')
box('cr_fin',(0,1.975,-.01),(.022,.075,.2),'acc','head__crest',bevel=.01)
box('an_box',(.15,1.86,-.03),(.045,.08,.1),'trim','head__antenna',bevel=.01)
cylz('an_mast',(.16,2.06,-.05),.006,.34,'metal','head__antenna',axis='y',verts=6)
ell('an_tip',(.16,2.23,-.05),(.018,.018,.018),'glow','head__antenna',seg=10,rings=6)
# hood: field cap under a cloth hood
helm('head__hood',r=(.118,.13,.14))
ell('hd_hood',(0,1.87,-.02),(.165,.175,.18),'cape','head__hood',seg=15,rings=9,cuts=[((0,0,.08),(0,0,-1)),((0,1.69,0),(0,-1,0))],thick=.014)
ell('hd_drape',(0,1.72,-.1),(.17,.09,.1),'cape','head__hood',cuts=[((0,0,-.02),(0,0,-1)),((0,1.76,0),(0,1,0))],thick=.012)
# respirator mask
g='head__mask'
plate('mk_shell',HC,(.135,.15,.16),'base',g,sq=.88,cuts=[((0,-.13,0),(0,-1,0))],thick=.018,seg=20,rings=12)
plate('mk_face',HC,(.142,.157,.168),'trim',g,sq=.88,cuts=[((0,-.005,0),(0,1,0)),((0,-.125,0),(0,-1,0)),((0,0,.06),(0,0,-1))],thick=.012,seg=24,rings=18)
ell('mk_snout',(0,1.79,.185),(.055,.045,.045),'dark',g)
for s in(-1,1):
    cylz('mk_can%d'%s,(s*.078,1.775,.17),.032,.05,'metal',g,axis='z',verts=16).rotation_euler=(0,0,0)
    ell('mk_lens%d'%s,(s*.052,1.875,.168),(.036,.028,.02),'visor',g,seg=12,rings=8)
    cylz('mk_ear%d'%s,(s*.135,1.84,0),.04,.02,'trim',g,axis='x',verts=16)
# siege dome
g='head__dome'
helm(g,r=(.17,.165,.185),slit=True)
for s in(-1,1):box('dm_side%d'%s,(s*.175,1.82,0),(.03,.13,.2),'trim',g,bevel=.01)
ring('dm_collar',(0,1.735,0),.15,.15,.03,.014,'trim',g)
# neck seal shown under every helmet
tube('hn_neck',(0,1.77,.01),(0,1.71,0),.065,.07,'under','head__neck',verts=14,rings=1)
# ---------------- weapons (gun local space: grip near origin, barrel toward +z)
def rifle(g,scale=1.0,scope=True):
    s=scale
    box(g+'_rcv',(0,0,.05),(.055,.085,.34),'dark',g,bevel=.01)
    box(g+'_top',(0,.05,.06),(.035,.018,.3),'metal',g,bevel=.004)
    box(g+'_hg',(0,-.003,.31*s),(.06,.065,.22*s),'trim',g,bevel=.012)
    for i in range(3):box(g+'_vent%d'%i,(0,.03,.25*s+i*.045*s),(.062,.008,.02),'dark',g,bevel=.002)
    cylz(g+'_brl',(0,.012,(.42+.15*(s-1))+.1*s),.015,.2*s,'metal',g,verts=12)
    cylz(g+'_muz',(0,.012,(.42+.15*(s-1))+.21*s),.022,.05,'dark',g,verts=12)
    box(g+'_stock',(0,-.02,-.2),(.04,.075,.16),'trim',g,bevel=.014)
    box(g+'_butt',(0,-.03,-.285),(.045,.1,.02),'dark',g,bevel=.006)
    box(g+'_grip',(0,-.075,-.03),(.035,.085,.04),'dark',g,bevel=.01,rot=(.3,0,0))
    box(g+'_trig',(0,-.05,.02),(.012,.035,.035),'metal',g,bevel=.002)
    box(g+'_mag',(0,-.1,.09),(.032,.12,.06),'trim',g,bevel=.008,rot=(-.18,0,0))
    box(g+'_fg',(0,-.065,.25*s),(.03,.06,.03),'dark',g,bevel=.008)
    if scope:
        cylz(g+'_scope',(0,.085,.06),.019,.15*(1.2 if s>1.05 else 1),'dark',g,verts=14)
        ell(g+'_lens',(0,.085,.06+.075*(1.2 if s>1.05 else 1)),(.016,.016,.006),'visor',g,seg=10,rings=6)
        box(g+'_mount',(0,.065,.06),(.02,.02,.05),'metal',g,bevel=.003)
rifle('gun__rifle',1.0)
for i in range(3):ring('coil%d'%i,(0,.012,.4+i*.05),.024,.024,.02,.007,'glow','gun__coils',axis='zf',verts=10)
g='gun__pistol'
box('ps_slide',(0,.02,.06),(.036,.042,.2),'dark',g,bevel=.008)
box('ps_frame',(0,-.008,.05),(.034,.025,.17),'trim',g,bevel=.006)
box('ps_grip',(0,-.06,-.015),(.032,.09,.045),'dark',g,bevel=.01,rot=(.28,0,0))
cylz('ps_muz',(0,.02,.165),.012,.02,'metal',g,verts=10)
box('ps_sight',(0,.045,.13),(.008,.01,.015),'acc',g,bevel=.002)
g='gun__heavy'
box('hv_body',(0,0,.12),(.1,.12,.42),'dark',g,bevel=.014)
box('hv_shroud',(0,.01,.48),(.08,.08,.3),'trim',g,bevel=.012)
for a in range(3):
    ang=a*2*math.pi/3;cylz('hv_b%d'%a,(math.cos(ang)*.022,.01+math.sin(ang)*.022,.7),.011,.22,'metal',g,verts=10)
cylz('hv_drum',(-.075,-.04,.1),.06,.05,'trim',g,axis='x',verts=20)
ring('hv_handle',(0,.09,.15),.05,.03,.02,.008,'metal',g,axis='x',verts=16)
box('hv_grip',(0,-.08,-.03),(.035,.09,.04),'dark',g,bevel=.01,rot=(.3,0,0))
box('hv_stock',(0,-.02,-.17),(.05,.08,.12),'trim',g,bevel=.012)
box('hv_fg',(0,-.08,.3),(.035,.08,.035),'dark',g,bevel=.008)
g='gun__tube'
cylz('tb_tube',(0,.03,.2),.065,.95,'trim',g,verts=16)
cylz('tb_bell',(0,.03,.7),.075,.07,'dark',g,verts=22,r2=.068)
cylz('tb_rear',(0,.03,-.28),.07,.05,'dark',g,verts=16)
box('tb_sight',(-.075,.07,.25),(.03,.05,.1),'dark',g,bevel=.008)
ell('tb_lens',(-.075,.07,.3),(.014,.014,.006),'visor',g,seg=10,rings=6)
box('tb_grip',(0,-.07,-.03),(.035,.09,.04),'dark',g,bevel=.01,rot=(.3,0,0))
box('tb_fg',(0,-.06,.25),(.035,.07,.035),'dark',g,bevel=.008)
ring('tb_band',(0,.03,.45),.068,.068,.03,.008,'acc',g,axis='zf',verts=16)


# ---------------- Drakeguard, second pass: built to match the Drakeguard concept (original design) ----------------
# Heavy navy plate with gold rims along every edge, gold roundels and rivets, big layered pauldrons, a dragon-snout
# helm with red eyes, a maroon tabard, leather pouches, a backpack canister, large knee cops and armoured sabatons.
def band(name,c,r,mat,grp,keep,sq=.55,taper=0,dz=0,rot=(0,0,0),thick=.008,k=1.03,seg=22,rings=16):
    # a gold rim: the same shell as a plate, a little larger, cut down to a narrow strip along one of its edges
    return plate(name,c,(r[0]*k,r[1]*k,r[2]*k),mat,grp,sq=sq,taper=taper,dz=dz*k,rot=rot,cuts=keep,thick=thick,seg=seg,rings=rings,angle=40)
def surf(objname,x,y,z0,d):
    # where a ray from (x,y,z0) along d meets a mesh: point and normal in game coordinates
    o=bpy.data.objects.get(objname)
    if not o:return None
    dv=G(*d).normalized();ok,loc,nor,_=o.ray_cast(G(x,y,z0)-dv*.6,dv)
    if not ok:return None
    return (Vector((loc.x,loc.z,-loc.y)),Vector((nor.x,nor.z,-nor.y)).normalized())
def roundel(name,objname,x,y,z0,grp,r=.028,d=(0,0,-1)):
    # a gold disc with a raised boss, laid flat on the surface of a plate
    hit=surf(objname,x,y,z0,d)
    if not hit:return
    p,n=hit
    a=p-n*.002;b=p+n*.008;tube(name,(a.x,a.y,a.z),(b.x,b.y,b.z),r,r*.94,'gold',grp,verts=18,rings=1,bevel=.002,angle=50)
    b2=p+n*.016;tube(name+'b',(b.x,b.y,b.z),(b2.x,b2.y,b2.z),r*.5,r*.38,'gold',grp,verts=14,rings=1,angle=50)
def studs(objname,pts,grp,d=(0,0,-1),r=.0085):rivets(objname,pts,grp,'gold',d=d,r=r)
DK='D'
# breastplate
g='torso__chest_D';cy=1.43;rx,ry,rz=.238,.188,.16
FRONT=dict(sq=.55,taper=.2,dz=.03)
plate('cD_front',(0,cy,0),(rx,ry,rz),'base',g,cuts=[((0,0,.02),(0,0,-1)),((0,ry*.88,0),(0,1,0)),((0,-ry*.8,0),(0,-1,0))],thick=.028,seg=20,rings=14,**FRONT)
plate('cD_back',(0,cy,-.005),(rx*.97,ry*.95,rz*.92),'base',g,sq=.55,taper=.15,cuts=[((0,0,-.03),(0,0,1)),((0,ry*.85,0),(0,1,0)),((0,-ry*.8,0),(0,-1,0))],thick=.026)
band('cD_rimTop',(0,cy,0),(rx,ry,rz),'gold',g,[((0,0,.02),(0,0,-1)),((0,ry*.9,0),(0,1,0)),((0,ry*.77,0),(0,-1,0))],**FRONT)
band('cD_rimBot',(0,cy,0),(rx,ry,rz),'gold',g,[((0,0,.02),(0,0,-1)),((0,-ry*.68,0),(0,1,0)),((0,-ry*.82,0),(0,-1,0))],**FRONT)
band('cD_rimSide',(0,cy,0),(rx,ry,rz),'gold',g,[((0,0,.02),(0,0,-1)),((0,0,.052),(0,0,1)),((0,ry*.88,0),(0,1,0)),((0,-ry*.8,0),(0,-1,0))],**FRONT)
plate('cD_keel',(0,cy-.01,rz+.015),(.02,ry*.7,.018),'trim',g,sq=.5,cuts=[((0,0,0),(0,0,-1))],thick=.008,seg=10,rings=8)
bpy.context.view_layer.update()
roundel('cD_rdL','cD_front',-.12,cy+.07,.0,g,r=.034);roundel('cD_rdR','cD_front',.12,cy+.07,.0,g,r=.034)
roundel('cD_rdC','cD_front',0,cy-.05,.0,g,r=.03)
studs('cD_front',[(sx*rx*.8,cy+dy,0) for sx in(-1,1) for dy in(-.09,0,.09)],g)
# abdomen lames, each with a gold lower edge
for i in range(3):
    y=cy-ry*.8-.034-i*.056;lr=(rx*.8-i*.014,.044,rz*.9)
    plate('cD_lame%d'%i,(0,y,-.005),lr,'base',g,sq=.5,cuts=[((0,0,0),(0,0,-1)),((0,.03,0),(0,1,0)),((0,-.03,0),(0,-1,0))],thick=.02,seg=16,rings=8)
    band('cD_lameG%d'%i,(0,y,-.005),lr,'gold',g,[((0,0,0),(0,0,-1)),((0,-.019,0),(0,1,0)),((0,-.032,0),(0,-1,0))],sq=.5,seg=18,rings=10,k=1.02)
for s in(-1,1):box('cD_strap%d'%s,(s*rx*.96,cy-.02,-.005),(.024,.16,.12),'leather',g,bevel=.006)
# maroon gorget and a gold collar
ring('cD_gorget',(0,1.672,0),.108,.094,.08,.02,'cloth',g,verts=20)
ring('cD_collarG',(0,1.715,0),.113,.099,.012,.007,'gold',g,verts=20)
# pauldrons: two big rounded tiers with gold rims, a roundel and studs
g='torso__pauld_D'
for sx in(-1,1):
    for t in range(2):
        pr=(.15*(1-.1*t),.085*(1-.1*t),.17*(1-.07*t));pc=(sx*(.36+.025*t),1.635-t*.06,0);rot=(0,0,-sx*(.46+.18*t))
        cutp=[((0,-pr[1]*.15,0),(0,-1,0)),((-sx*pr[0]*.6,0,0),(-sx,0,0))]
        plate('pD%d_%d'%(sx,t),pc,pr,'base',g,sq=.7,rot=rot,cuts=cutp,thick=.024,seg=18,rings=12)
        band('pDg%d_%d'%(sx,t),pc,pr,'gold',g,[((0,-pr[1]*.15,0),(0,-1,0)),((0,pr[1]*.12,0),(0,1,0)),((-sx*pr[0]*.6,0,0),(-sx,0,0))],sq=.7,rot=rot,thick=.009)
    bpy.context.view_layer.update()
    roundel('pDr%d'%sx,'pD%d_0'%sx,sx*.43,1.7,0,g,r=.03,d=(-sx*.6,-1,0))
    studs('pD%d_0'%sx,[(sx*(.38+dx),1.75,dz) for dx in(-.05,.02) for dz in(-.1,.1)],g,d=(0,-1,0))
# upper arm plate, elbow cop and bracer, all gold-banded
g='upperarm__plate_D'
tube('uaD',(AX,1.53,0),(AX,1.36,0),.083,.072,'base',g,cuts=[((AX-.012,0,0),(-1,0,0))],thick=.018,bevel=.004,caps=False,rings=2)
ring('uaD_g',(AX,1.37,0),.075,.075,.014,.006,'gold',g)
g='forearm__bracer_D'
tube('brD',(AX,1.27,0),(AX,1.07,0),.074,.064,'base',g,caps=False,thick=.018,rings=1,verts=14,sz=1.1)
ring('brD_g1',(AX,1.262,0),.079,.086,.016,.007,'gold',g)
ring('brD_g2',(AX,1.08,0),.069,.075,.016,.007,'gold',g)
ell('epD',(AX,1.3,-.035),(.06,.065,.05),'base',g,cuts=[((0,0,-.01),(0,0,1))],thick=.016)
ring('epD_g',(AX,1.3,-.04),.062,.05,.012,.006,'gold',g,axis='zf')
# leather belt gear: pouch, holster, buckle
g='torso__belt_D'
ring('blD',(0,1.03,0),.178,.132,.055,.014,'leather',g,verts=22)
box('blD_buckle',(0,1.03,.15),(.062,.05,.02),'gold',g,bevel=.008)
box('blD_pouch',(-.19,.97,.06),(.06,.1,.075),'leather',g,bevel=.014,rot=(0,.4,0))
box('blD_flap',(-.19,1.015,.075),(.064,.03,.08),'leather',g,bevel=.008,rot=(0,.4,0))
box('blD_holster',(.2,.9,.02),(.05,.17,.085),'leather',g,bevel=.014)
box('blD_hstrap',(.2,.96,.02),(.056,.02,.09),'gold',g,bevel=.004)
box('blD_rear',(0,1.0,-.14),(.13,.07,.045),'leather',g,bevel=.012)
# backpack canister standing up behind the shoulders
g='torso__pack_D'
box('pkD_frame',(0,1.42,-.2),(.26,.3,.07),'trim',g,bevel=.02)
cylz('pkD_can',(-.04,1.55,-.28),.095,.34,'base',g,axis='y',verts=22)
ring('pkD_g1',(-.04,1.71,-.28),.097,.097,.016,.007,'gold',g,verts=22)
ring('pkD_g2',(-.04,1.4,-.28),.097,.097,.016,.007,'gold',g,verts=22)
cylz('pkD_cap',(-.04,1.73,-.28),.07,.03,'trim',g,axis='y',verts=18)
cylz('pkD_cell',(.12,1.4,-.27),.04,.2,'metal',g,axis='y',verts=14)
ring('pkD_glow',(.12,1.4,-.27),.042,.042,.026,.006,'glow',g)
# maroon tabard from the belt to the knees, with a darker hem
g='pelvis__tabard_D'
plate('cD_tab',(0,.77,.155),(.105,.24,.022),'cloth',g,sq=.25,rot=(.08,0,0),cuts=[((0,0,0),(0,0,-1))],thick=.012,seg=12,rings=12)
box('cD_tabHem',(0,.545,.178),(.2,.018,.012),'dark',g,bevel=.003)
# thigh tassets with gold hems
g='thigh__plate_D'
tube('tD',(X,.93,.0),(X,.62,.0),.136,.112,'base',g,cuts=[((0,0,-.05),(0,0,-1))],thick=.024,caps=False,rings=3)
ring('tD_g',(X,.63,0),.115,.115,.016,.007,'gold',g)
for k in range(2):                           # two layered tassets over the front of the thigh, gold along the hem
    tc=(X,.9-k*.1,.11-k*.01);tr=(.12-k*.01,.075,.05)
    plate('tDt%d'%k,tc,tr,'base',g,sq=.55,rot=(.1,0,0),cuts=[((0,0,0),(0,0,-1)),((0,-.04,0),(0,-1,0))],thick=.018,seg=14,rings=10)
    band('tDtg%d'%k,tc,tr,'gold',g,[((0,0,0),(0,0,-1)),((0,-.04,0),(0,-1,0)),((0,-.026,0),(0,1,0))],sq=.55,rot=(.1,0,0),thick=.008)
# knee cops, greaves and sabatons
g='shin__greave_D'
tube('shD',(X,.47,0),(X,.13,.0),.1,.084,'base',g,cuts=[((0,0,-.05),(0,0,-1))],thick=.024,caps=False,rings=3)
ring('shD_gt',(X,.46,0),.103,.103,.016,.007,'gold',g);ring('shD_gb',(X,.14,0),.088,.088,.016,.007,'gold',g)
sc,sr=(X,.31,.075),(.072,.13,.04)            # a raised shin guard down the front, gold-rimmed, with a roundel
plate('shDf',sc,sr,'base',g,sq=.55,rot=(-.05,0,0),cuts=[((0,0,0),(0,0,-1))],thick=.016,seg=14,rings=12)
band('shDfg',sc,sr,'gold',g,[((0,0,0),(0,0,-1)),((0,0,.016),(0,0,1))],sq=.55,rot=(-.05,0,0),thick=.007)
bpy.context.view_layer.update();roundel('shDr','shDf',X,.31,0,g,r=.022)
plate('kpD',(X,.515,.055),(.085,.095,.06),'base',g,sq=.62,rot=(-.12,0,0),cuts=[((0,0,0),(0,0,-1))],thick=.02,seg=16,rings=12)
band('kpDg',(X,.515,.055),(.085,.095,.06),'gold',g,[((0,0,0),(0,0,-1)),((0,0,.022),(0,0,1))],sq=.62,rot=(-.12,0,0),thick=.008)
bpy.context.view_layer.update();roundel('kpDr','kpD',X,.515,.0,g,r=.026)
g='boot__sabaton_D'
plate('sbD',(X,.065,.075),(.07,.055,.14),'base',g,sq=.6,cuts=[((0,-.02,0),(0,-1,0)),((0,0,-.05),(0,0,-1))],thick=.016,seg=16,rings=10)
band('sbDg',(X,.065,.075),(.07,.055,.14),'gold',g,[((0,-.02,0),(0,-1,0)),((0,0,-.05),(0,0,-1)),((0,.0,0),(0,1,0))],sq=.6,thick=.008)
ring('sbD_ank',(X,.2,0),.07,.07,.016,.007,'gold',g)
# Dragon helm: navy dome, dark visor with red eyes, a dragon snout and brow over the face, swept horns and fins
g='head__dragon'
plate('hD_shell',HC,(.14,.155,.165),'base',g,sq=.86,taper=.06,cuts=[((0,-.135,0),(0,-1,0))],thick=.02,seg=22,rings=14)
plate('hD_face',HC,(.146,.161,.172),'visor',g,sq=.86,taper=.06,cuts=[((0,.03,0),(0,1,0)),((0,-.115,0),(0,-1,0)),((0,0,.05),(0,0,-1))],thick=.01,seg=26,rings=18)
for sx in(-1,1):
    box('hD_eye%d'%sx,(sx*.05,1.875,.172),(.052,.016,.012),'eye',g,bevel=.004,rot=(0,0,sx*.22))
    plate('hD_cheek%d'%sx,(sx*.12,1.79,.06),(.035,.06,.08),'base',g,sq=.6,rot=(0,0,-sx*.2),cuts=[((0,0,0),(-sx,0,0))],thick=.014,seg=12,rings=8)
    plate('hD_brow%d'%sx,(sx*.065,1.915,.16),(.08,.03,.06),'base',g,sq=.6,rot=(-.25,0,sx*.38),cuts=[((0,0,0),(0,0,-1))],thick=.016,seg=12,rings=8)
    box('hD_browG%d'%sx,(sx*.068,1.905,.205),(.11,.008,.01),'gold',g,bevel=.002,rot=(0,0,sx*.38))
plate('hD_snout',(0,1.94,.13),(.07,.055,.16),'base',g,sq=.6,taper=-.25,rot=(-.38,0,0),cuts=[((0,-.016,0),(0,-1,0))],thick=.02,seg=18,rings=12)
band('hD_snoutG',(0,1.94,.13),(.07,.055,.16),'gold',g,[((0,-.016,0),(0,-1,0)),((0,.004,0),(0,1,0))],sq=.6,taper=-.25,rot=(-.38,0,0),thick=.009)
box('hD_ridge',(0,2.0,-.01),(.018,.024,.28),'gold',g,bevel=.006,rot=(-.12,0,0))
for sx in(-1,1):
    ell('hD_nos%d'%sx,(sx*.026,1.9,.275),(.012,.01,.012),'dark',g,seg=8,rings=6)
    tube('hD_horn%d'%sx,(sx*.09,1.99,-.04),(sx*.16,2.07,-.22),.024,.004,'gold',g,verts=10,rings=3,bulge=.008)
    hx,hy,hz=sx*.13,1.92,-.04
    for k in range(3):                       # three swept fins on each side, gold-edged
        L=.16+k*.05;a=.9+k*.22;tilt=sx*(.4+k*.06)
        R=Matrix.Rotation(-a,3,'X')@Matrix.Rotation(-tilt,3,'Y');d=R@Vector((0,0,1))
        cx,cy2,cz=hx+d.x*L/2,hy+d.z*L/2,hz-d.y*L/2
        box('hD_w%d_%d'%(sx,k),(cx,cy2,cz),(.012,L,.056-k*.008),'base',g,bevel=.004,rot=(-a,0,tilt))
        box('hD_we%d_%d'%(sx,k),(cx+sx*.008,cy2,cz),(.004,L*.96,.014),'gold',g,bevel=.0015,rot=(-a,0,tilt))
    cylz('hD_ear%d'%sx,(sx*.148,1.84,0),.044,.024,'gold',g,axis='x',verts=18)
plate('hD_chin',HC,(.15,.165,.176),'trim',g,sq=.86,taper=.06,cuts=[((0,-.06,0),(0,1,0)),((0,-.135,0),(0,-1,0)),((0,0,.04),(0,0,-1))],thick=.014,seg=24,rings=18)
for k in range(4):box('hD_grill%d'%k,(0,1.76+k*.016,.178),(.06,.005,.008),'dark',g,bevel=.001)

# ---------------- ambient occlusion into vertex colours
dg=bpy.context.evaluated_depsgraph_get()
def bvh_of(objs):
    verts=[];polys=[]
    for o in objs:
        me=o.data;mw=o.matrix_world;base=len(verts)
        verts+= [mw@v.co for v in me.vertices];polys+=[[base+i for i in p.vertices] for p in me.polygons]
    return BVHTree.FromPolygons(verts,polys)
under=[o for o in bpy.data.objects if o.type=='MESH' and '__' not in GROUP[o.name] and GROUP[o.name]!='gun']
random.seed(7)
DIRS=[]
for i in range(20):
    u=random.random();v=random.random();th=2*math.pi*u;z=math.sqrt(v)  # cosine-weighted
    DIRS.append(Vector((math.cos(th)*math.sqrt(1-z*z),math.sin(th)*math.sqrt(1-z*z),z)))
groups={}
for o in bpy.data.objects:
    if o.type=='MESH':groups.setdefault(GROUP[o.name],[]).append(o)
for gname,objs in groups.items():
    ctx=objs+([] if gname.startswith('gun') else [u for u in under if u not in objs])
    tree=bvh_of(ctx)
    for o in objs:
        me=o.data;mw=o.matrix_world;nm=mw.to_3x3().inverted().transposed()
        ca=me.color_attributes.new('Col','FLOAT_COLOR','POINT')
        for v in me.vertices:
            p=mw@v.co;n=(nm@v.normal).normalized()
            Q=n.to_track_quat('Z','Y').to_matrix();hit=0
            for d in DIRS:
                dd=Q@d;loc,_,_,dist=tree.ray_cast(p+n*.002,dd,.22)
                if loc is not None:hit+=1-(dist/.22)*.5
            a=max(.35,1-hit/len(DIRS)*1.1)
            ca.data[v.index].color=(a,a,a,1)
        me.color_attributes.active_color=ca
# ---------------- parent to joint empties and export
emp={}
for gname in groups:
    j=gname.split('__')[0];loc=J[j]
    e=bpy.data.objects.new(gname,None);e.location=G(*loc);bpy.context.scene.collection.objects.link(e);emp[gname]=e
bpy.context.view_layer.update()
for o in bpy.data.objects:
    if o.type=='MESH':
        e=emp[GROUP[o.name]];mw=o.matrix_world.copy();o.parent=e;o.matrix_world=mw
nv=sum(len(o.data.vertices) for o in bpy.data.objects if o.type=='MESH')
print('groups',len(groups),'verts',nv)
fn=os.path.join(OUT,'trooper_kit.glb')
bpy.ops.export_scene.gltf(filepath=fn,export_format='GLB',export_yup=True,export_apply=True,export_materials='EXPORT',export_normals=True,export_texcoords=False,export_vertex_color='ACTIVE',export_draco_mesh_compression_enable=False)
print('exported',fn,os.path.getsize(fn))
