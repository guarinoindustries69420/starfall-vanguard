# Pack trooper_kit.glb into a compact quantized binary (int16 positions, int8 normals, uint8 AO, uint16 indices), base64.
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3).
import struct,json,sys,base64,numpy as np
src,dst=sys.argv[1],sys.argv[2]
b=open(src,'rb').read();l=struct.unpack('<I',b[12:16])[0];j=json.loads(b[20:20+l]);o=20+l;bl=struct.unpack('<I',b[o:o+4])[0];BIN=b[o+8:o+8+bl]
CT={5126:np.float32,5123:np.uint16,5125:np.uint32,5121:np.uint8};NC={'SCALAR':1,'VEC3':3,'VEC4':4}
def acc(i):
    a=j['accessors'][i];bv=j['bufferViews'][a['bufferView']];t=CT[a['componentType']];n=NC[a['type']]
    off=bv.get('byteOffset',0)+a.get('byteOffset',0);arr=np.frombuffer(BIN,dtype=t,count=a['count']*n,offset=off).reshape(a['count'],n).astype(np.float64)
    if a.get('normalized'):arr/=np.iinfo(t).max
    return arr
def qmat(q):
    x,y,z,w=q;return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
groups=[];blobs=[]
roots=sorted(j['scenes'][0]['nodes'],key=lambda i:j['nodes'][i].get('name',''))
for r in roots:
    g=j['nodes'][r];meshes=[]
    for c in sorted(g.get('children',[]),key=lambda i:j['nodes'][i].get('name','')):   # stable order so rebuilds pack identically
        n=j['nodes'][c];R=qmat(n.get('rotation',[0,0,0,1]));S=np.array(n.get('scale',[1,1,1]));T=np.array(n.get('translation',[0,0,0]))
        for pr in j['meshes'][n['mesh']]['primitives']:
            P=acc(pr['attributes']['POSITION']);N=acc(pr['attributes']['NORMAL']);A=acc(pr['attributes']['COLOR_0'])[:,0] if 'COLOR_0' in pr['attributes'] else np.ones(len(P))
            I=acc(pr['indices']).astype(np.int64).ravel()
            P=(R@(P*S).T).T+T;N=(R@(N/S).T).T;N/=np.linalg.norm(N,axis=1,keepdims=True)
            P=np.round(P,5);N=np.round(N,3);A=np.round(A,3)   # absorb float noise between Blender runs
            mn=np.round(P.min(0),5);mx=np.round(P.max(0),5);sc=np.round(np.maximum(mx-mn,1e-5),5)
            qp=np.round((P-mn)/sc*65535).astype(np.uint16);qn=np.round(N*127).astype(np.int8);qa=np.round(np.clip(A,0,1)*255).astype(np.uint8)
            # canonical vertex and triangle order, so two Blender runs of the same model pack to identical bytes
            key=np.concatenate([qp.astype(np.int64),qn.astype(np.int64),qa[:,None].astype(np.int64)],1)
            order=np.lexsort(key.T[::-1]);inv=np.empty_like(order);inv[order]=np.arange(len(order))
            qp,qn,qa=qp[order],qn[order],qa[order];T=inv[I].reshape(-1,3)
            r=np.argmin(T,1);T=np.stack([T[np.arange(len(T)),(r+k)%3] for k in range(3)],1)   # rotate so the smallest index leads (keeps winding)
            T=T[np.lexsort(T.T[::-1])];I=T.ravel()
            mat=j['materials'][pr['material']]['name'] if 'material' in pr else 'base'
            meshes.append({'m':mat,'v':len(P),'i':len(I),'o':[round(float(x),6) for x in mn],'s':[round(float(x),6) for x in sc]})
            blobs+= [qp.tobytes(),qn.tobytes(),qa.tobytes(),I.astype(np.uint16).tobytes()]
            assert I.max()<65536
    groups.append({'n':g['name'],'ms':meshes})
hdr=json.dumps(groups,separators=(',',':')).encode();data=struct.pack('<I',len(hdr))+hdr+b''.join(blobs)
open(dst,'w').write(base64.b64encode(data).decode());print('packed',len(data),'b64',len(base64.b64encode(data)))
