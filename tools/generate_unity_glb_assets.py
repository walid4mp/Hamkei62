import json, os, re, subprocess, hashlib
import numpy as np
import trimesh

ROOT='/mnt/data/socialnova_work/unity-gifts/Assets/StreamingAssets/GiftModels'
manifest='/mnt/data/socialnova_work/unity-gifts/Assets/Resources/gift_manifest.json'
os.makedirs(ROOT, exist_ok=True)
data=json.load(open(manifest,encoding='utf-8'))

# Deterministic stylized 3D prototypes. They are intentionally lightweight so the
# Unity runtime remains usable on mid-range Android devices. Replace individual GLBs
# later with production artist assets without changing gift IDs or runtime code.
def mat_color(seed, rarity):
    h=int(hashlib.sha256(seed.encode()).hexdigest()[:6],16)
    # HSV-ish palette converted manually through trimesh ColorVisuals; use RGBA.
    base=[(h>>16)&255,(h>>8)&255,h&255]
    scale={'COMMON':0.72,'RARE':0.82,'EPIC':0.9,'LEGENDARY':1.0,'MYTHIC':1.0}.get(rarity,0.8)
    return np.array([min(255,int(x*scale+255*(1-scale)*0.2)) for x in base]+[255],dtype=np.uint8)

def make_mesh(g):
    slug=g['id']; fam=g['effectKey']; seed=slug
    rng=np.random.default_rng(int(hashlib.sha256(seed.encode()).hexdigest()[:8],16))
    meshes=[]
    def add(m, t=None):
        if t is not None: m.apply_transform(t)
        meshes.append(m)
    c=mat_color(seed,g['rarity'])
    # Distinct silhouettes by animation family.
    if fam=='heart':
        a=trimesh.creation.icosphere(subdivisions=2,radius=.55)
        b=trimesh.creation.icosphere(subdivisions=2,radius=.55)
        b.apply_translation([.48,0,0]); a.apply_translation([-.48,0,0]); add(a); add(b)
        cone=trimesh.creation.cone(radius=.72,height=1.1,sections=24); cone.apply_translation([0,-.65,0]); add(cone)
    elif fam=='diamond' or fam=='crystal':
        add(trimesh.creation.icosphere(subdivisions=2,radius=.75))
        # compress into gem shape
        meshes[-1].apply_scale([.7,1.1,.7])
    elif fam=='rocket':
        add(trimesh.creation.cylinder(radius=.32,height=1.5,sections=24))
        nose=trimesh.creation.cone(radius=.32,height=.65,sections=24); nose.apply_translation([0,.98,0]); add(nose)
        for x in (-.34,.34):
            fin=trimesh.creation.box(extents=[.18,.65,.08]); fin.apply_translation([x,-.35,0]); add(fin)
    elif fam=='car':
        add(trimesh.creation.box(extents=[1.5,.45,.75]))
        body=trimesh.creation.box(extents=[.9,.4,.65]); body.apply_translation([.1,.42,0]); add(body)
        for x in (-.55,.55):
            for z in (-.4,.4):
                w=trimesh.creation.cylinder(radius=.18,height=.12,sections=16); w.apply_transform(trimesh.transformations.rotation_matrix(np.pi/2,[1,0,0])); w.apply_translation([x,-.18,z]); add(w)
    elif fam in ('plane','yacht'):
        add(trimesh.creation.capsule(radius=.25,height=1.8,count=[12,12] if False else None))
        wing=trimesh.creation.box(extents=[1.8,.08,.35]); add(wing)
        tail=trimesh.creation.box(extents=[.45,.35,.12]); tail.apply_translation([0,.72,0]); add(tail)
    elif fam=='crown':
        add(trimesh.creation.torus(major_radius=.58,minor_radius=.12,major_sections=32,minor_sections=10))
        for i in range(5):
            ang=-.8+i*.4; x=.55*np.sin(ang); z=.55*np.cos(ang)
            spike=trimesh.creation.cone(radius=.12,height=.75,sections=12); spike.apply_translation([x,.35,z]); add(spike)
    elif fam in ('dragon','lion'):
        add(trimesh.creation.icosphere(subdivisions=2,radius=.6))
        head=trimesh.creation.icosphere(subdivisions=2,radius=.38); head.apply_translation([0,.55,.05]); add(head)
        for x in (-.48,.48):
            leg=trimesh.creation.cylinder(radius=.13,height=.65,sections=12); leg.apply_translation([x,-.5,.25]); add(leg)
    elif fam in ('fireworks','fire','lightning','galaxy','stars','snow','sakura'):
        # layered orb + radial shards gives a strong animated silhouette.
        add(trimesh.creation.icosphere(subdivisions=2,radius=.45))
        n=12 if fam!='galaxy' else 24
        for i in range(n):
            ang=2*np.pi*i/n
            r=.8+rng.random()*.4
            p=np.array([np.cos(ang)*r, np.sin(ang)*r, (rng.random()-.5)*.5])
            shard=trimesh.creation.cone(radius=.05,height=.35,sections=8)
            shard.apply_transform(trimesh.transformations.rotation_matrix(ang,[0,0,1])); shard.apply_translation(p); add(shard)
    elif fam in ('trophy','coins','music','food','sport','balloon'):
        add(trimesh.creation.cylinder(radius=.42,height=.85,sections=20))
        for i in range(3):
            ring=trimesh.creation.torus(major_radius=.43+i*.05,minor_radius=.045,major_sections=24,minor_sections=8); ring.apply_translation([0,.25*i,0]); add(ring)
    else:
        # Unique geometric collectible fallback.
        add(trimesh.creation.icosphere(subdivisions=2,radius=.55))
        for i in range(4):
            s=.18+.08*i
            box=trimesh.creation.box(extents=[s,.8,.18]); box.apply_transform(trimesh.transformations.rotation_matrix(i*np.pi/4,[0,1,0])); box.apply_translation([0,(i-1.5)*.22,0]); add(box)
    mesh=trimesh.util.concatenate(meshes)
    mesh.visual.face_colors=np.tile(c,(len(mesh.faces),1))
    return mesh

for g in data['gifts']:
    out=os.path.join(ROOT,g['id']+'.glb')
    if os.path.exists(out): continue
    mesh=make_mesh(g)
    mesh.export(out,file_type='glb')
print('generated',len(data['gifts']),'GLBs')
