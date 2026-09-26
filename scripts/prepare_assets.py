"""Prepare this portrait's normalized model and UV-space makeup masks.

Run: uv run --no-project --with usd-core --with pillow --with numpy --with numba --with trimesh python scripts/prepare_assets.py SOURCE.usdz
"""
from pathlib import Path
import argparse
import io
import json
import shutil
import tempfile
import hashlib
import zipfile
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from numba import njit
from pxr import Usd, UsdGeom, UsdShade, UsdUtils, Sdf, Vt
import trimesh

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / 'Sources/MakeupFace/Resources'

# Coordinates are traced on the inspected 1024-pixel orthographic front reference.
# ponytail: masks are authored for this supplied portrait only; another model needs new region traces.
LIP = [(443,488),(461,478),(487,474),(503,478),(517,470),(537,476),(555,483),(571,487),(555,493),(543,505),(525,514),(510,518),(492,516),(474,507),(459,496)]
MOUTH = [(452,487),(479,485),(501,487),(519,486),(540,486),(561,488),(540,492),(518,496),(502,495),(482,491)]
LEFT_EYE = [(395,342),(414,331),(432,328),(450,332),(469,347),(455,354),(434,356),(414,352)]
RIGHT_EYE = [(550,347),(565,331),(585,326),(602,329),(624,339),(611,349),(586,355),(564,355)]
LEFT_BROW = [(370,307),(382,289),(403,281),(423,286),(446,296),(476,305),(480,317),(451,308),(422,300),(400,291),(385,296)]
RIGHT_BROW = [(549,305),(570,298),(595,286),(613,280),(628,284),(643,297),(649,310),(632,297),(615,291),(596,297),(574,309),(548,317)]


def region_masks():
    masks = {}
    def shape(name, polygons=(), ellipses=(), lines=(), blur=0):
        im = Image.new('L',(1024,1024))
        draw=ImageDraw.Draw(im)
        for polygon in polygons: draw.polygon(polygon,fill=255)
        for ellipse in ellipses: draw.ellipse(ellipse,fill=255)
        for path,width in lines: draw.line(path,fill=255,width=width,joint='curve')
        if blur: im=im.filter(ImageFilter.GaussianBlur(blur))
        masks[name]=im
        return im
    skin=shape('foundation',polygons=[[(353,327),(359,289),(391,259),(429,236),(485,211),(535,184),(567,175),(590,213),(619,245),(654,286),(672,329),(668,380),(653,446),(647,499),(624,537),(590,565),(547,586),(514,596),(476,585),(436,564),(408,538),(392,501),(384,455),(363,397)]],blur=7)
    exclusions=Image.new('L',(1024,1024)); d=ImageDraw.Draw(exclusions)
    for p in [LEFT_EYE,RIGHT_EYE,LEFT_BROW,RIGHT_BROW,LIP]: d.polygon(p,fill=255)
    exclusions=exclusions.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(2))
    masks['foundation']=Image.fromarray((np.asarray(skin,dtype=float)*(1-np.asarray(exclusions)/255)).astype('uint8'))
    shape('concealer',polygons=[[(398,365),(440,366),(473,355),(465,387),(437,400),(411,389)],[(549,361),(584,365),(624,358),(616,389),(580,400),(558,385)]],blur=8)
    shape('blush',ellipses=[(378,381,465,437),(563,380,651,438)],blur=14)
    shape('bronzer',polygons=[[(364,367),(394,384),(440,421),(439,449),(403,435),(377,407)],[(654,365),(626,387),(588,426),(586,446),(627,432),(650,402)]],blur=14)
    shape('cheekContour',polygons=[[(373,418),(390,422),(443,452),(449,469),(423,461),(386,439)],[(650,414),(630,423),(579,451),(574,470),(600,460),(636,439)]],blur=9)
    shape('noseContour',polygons=[[(486,356),(494,361),(491,397),(485,422),(494,436),(483,443),(472,428),(481,393)],[(535,353),(527,362),(530,396),(540,421),(531,435),(542,441),(551,425),(540,393)]],blur=5)
    shape('jawContour',lines=[([(405,529),(436,556),(474,578),(511,589),(547,579),(588,559),(620,530)],13)],blur=8)
    shape('templeContour',polygons=[[(353,315),(367,307),(373,345),(365,380),(350,361)],[(655,304),(671,319),(673,362),(659,382),(650,344)]],blur=9)
    shape('cheekHighlight',polygons=[[(384,365),(401,367),(453,388),(450,399),(414,387),(381,377)],[(637,361),(650,371),(611,387),(572,398),(570,387),(617,372)]],blur=7)
    shape('noseHighlight',ellipses=[(506,354,520,410),(503,419,524,432)],blur=5)
    shape('cupidBowHighlight',lines=[([(495,469),(504,473),(515,465),(528,469)],4)],blur=3)
    shape('eyeshadow',polygons=[[(390,336),(399,321),(416,317),(437,316),(455,324),(470,342),(455,334),(433,327),(412,332)],[(547,340),(558,321),(580,315),(601,317),(618,324),(632,335),(614,333),(593,325),(569,329)]],blur=4)
    # No blur: liners need defined boundaries (PRD §4). Soft treatments keep Gaussian blur.
    shape('eyeliner',lines=[([(390,334),(401,337),(416,332),(432,329),(449,332),(462,340),(469,347)],4), ([(550,346),(564,333),(581,327),(597,329),(615,335),(629,332)],4)],blur=0)
    shape('browFill',polygons=[LEFT_BROW,RIGHT_BROW],blur=1)
    lip=shape('lipstick',polygons=[LIP],blur=1)
    hole=Image.new('L',(1024,1024));ImageDraw.Draw(hole).polygon(MOUTH,fill=255)
    masks['lipstick']=Image.fromarray((np.asarray(lip,dtype=float)*(1-np.asarray(hole)/255)).astype('uint8'))
    # No blur: lip liner needs a defined border (PRD §4), same as eyeliner.
    shape('lipLiner',lines=[(LIP+[LIP[0]],3)],blur=0)
    lash_lines=[]
    for start,end in [((399,337),(391,328)),((406,334),(400,324)),((414,331),(410,320)),((423,330),(421,320)),((435,329),(435,319)),((447,332),(450,322)),((568,331),(565,321)),((579,328),(578,317)),((590,328),(591,317)),((601,331),(606,320)),((612,335),(619,324)),((620,336),(630,326))]:
        lash_lines.append(([start,end],2))
    shape('mascara',lines=lash_lines,blur=.5)
    # Eye exclusions protect sclera/iris even when soft shadows or complexion feather.
    eye_hole=Image.new('L',(1024,1024)); d=ImageDraw.Draw(eye_hole)
    for eye in [LEFT_EYE,RIGHT_EYE]: d.polygon(eye,fill=255)
    for name in ['concealer','eyeshadow']:
        masks[name]=Image.fromarray((np.asarray(masks[name],dtype=float)*(1-np.asarray(eye_hole)/255)).astype('uint8'))
    return masks


def export_usdz(points,triangles,uv):
    with tempfile.TemporaryDirectory() as temp:
        folder=Path(temp)
        shutil.copy2(RESOURCES/'base-color.jpg',folder/'base-color.jpg')
        stage=Usd.Stage.CreateNew(str(folder/'Face.usdc'))
        root=UsdGeom.Xform.Define(stage,'/Face')
        stage.SetDefaultPrim(root.GetPrim())
        UsdGeom.SetStageUpAxis(stage,UsdGeom.Tokens.y)
        UsdGeom.SetStageMetersPerUnit(stage,1)
        mesh=UsdGeom.Mesh.Define(stage,'/Face/Portrait')
        mesh.CreatePointsAttr(Vt.Vec3fArray.FromNumpy(points))
        mesh.CreateFaceVertexIndicesAttr(Vt.IntArray.FromNumpy(triangles.ravel()))
        mesh.CreateFaceVertexCountsAttr(Vt.IntArray.FromNumpy(np.full(len(triangles),3,dtype=np.int32)))
        mesh.CreateSubdivisionSchemeAttr(UsdGeom.Tokens.none)
        mesh.CreateExtentAttr([tuple(float(x) for x in points.min(0)),tuple(float(x) for x in points.max(0))])
        UsdGeom.PrimvarsAPI(mesh).CreatePrimvar('st',Sdf.ValueTypeNames.TexCoord2fArray,UsdGeom.Tokens.vertex).Set(Vt.Vec2fArray.FromNumpy(uv))
        material=UsdShade.Material.Define(stage,'/Face/Material')
        shader=UsdShade.Shader.Define(stage,'/Face/Material/Surface')
        shader.CreateIdAttr('UsdPreviewSurface')
        shader.CreateInput('roughness',Sdf.ValueTypeNames.Float).Set(1)
        sampler=UsdShade.Shader.Define(stage,'/Face/Material/Texture')
        sampler.CreateIdAttr('UsdUVTexture')
        sampler.CreateInput('file',Sdf.ValueTypeNames.Asset).Set('base-color.jpg')
        sampler.CreateInput('sourceColorSpace',Sdf.ValueTypeNames.Token).Set('sRGB')
        sampler.CreateOutput('rgb',Sdf.ValueTypeNames.Float3)
        reader=UsdShade.Shader.Define(stage,'/Face/Material/UV')
        reader.CreateIdAttr('UsdPrimvarReader_float2')
        reader.CreateInput('varname',Sdf.ValueTypeNames.String).Set('st')
        reader.CreateOutput('result',Sdf.ValueTypeNames.Float2)
        sampler.CreateInput('st',Sdf.ValueTypeNames.Float2).ConnectToSource(reader.ConnectableAPI(),'result')
        shader.CreateInput('diffuseColor',Sdf.ValueTypeNames.Color3f).ConnectToSource(sampler.ConnectableAPI(),'rgb')
        material.CreateSurfaceOutput().ConnectToSource(shader.ConnectableAPI(),'surface')
        UsdShade.MaterialBindingAPI.Apply(mesh.GetPrim()).Bind(material)
        stage.GetRootLayer().Save()
        destination=RESOURCES/'Face.usdz'
        if destination.exists(): destination.unlink()
        assert UsdUtils.CreateNewUsdzPackage(str(folder/'Face.usdc'),str(destination))


def bake_masks(points,triangles,uv,depth):
    atlas_points=np.c_[uv[:,0]*2048,(1-uv[:,1])*2048,np.zeros(len(uv))].astype(np.float32)
    occupied, surface=rasterize(atlas_points,triangles,points,2048)
    x=np.clip(((surface[:,:,0]/2.2+.5)*1024).astype(int),0,1023)
    y=np.clip(((.5-surface[:,:,1]/2.2)*1024).astype(int),0,1023)
    visible=(occupied > -1e9) & (abs(surface[:,:,2]-depth[y,x]) < .012)
    masks=region_masks()
    folder=RESOURCES/'masks'; folder.mkdir(exist_ok=True)
    for name,mask in masks.items():
        coverage=np.asarray(mask)[y,x].copy()
        coverage[~visible]=0
        # One texel of padding hides bilinear cracks at the atlas seams.
        baked=Image.fromarray(coverage).filter(ImageFilter.MaxFilter(3))
        # Liners need defined boundaries (PRD §4): lift the core to fully opaque
        # while keeping a thin anti-aliased rim so verify_assets' 50% rule passes.
        if name in ('eyeliner', 'lipLiner'):
            arr = np.asarray(baked).copy()
            arr[arr >= 48] = 255
            arr[arr < 8] = 0
            baked = Image.fromarray(arr)
        baked.save(folder/f'{name}.png',optimize=True)
    # A review sheet is separate from runtime resources.
    reference=Image.open(RESOURCES/'front-reference.png').convert('RGB')
    sheet=Image.new('RGB',(5*256,4*282),(245,242,236))
    draw=ImageDraw.Draw(sheet)
    for i,(name,mask) in enumerate(masks.items()):
        tint=Image.new('RGB',reference.size,(210,45,120))
        colored=Image.composite(tint,reference,mask.point(lambda value:int(value*.65)))
        sheet.paste(colored.resize((256,256)),((i%5)*256,(i//5)*282))
        draw.text(((i%5)*256+8,(i//5)*282+258),name,fill=(20,20,20))
    sheet.save(ROOT/'docs/mask-regions.png')
    return list(masks)


@njit
def rasterize(points, triangles, attributes, size):
    """Orthographic z-buffer; attributes interpolate across each visible triangle."""
    depth = np.full((size, size), -1e10, np.float32)
    result = np.zeros((size, size, attributes.shape[1]), np.float32)
    for face in triangles:
        a, b, c = points[face[0]], points[face[1]], points[face[2]]
        denom = (b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        if abs(denom) < 1e-12:
            continue
        x0 = max(0, int(np.floor(min(a[0], b[0], c[0]))))
        x1 = min(size-1, int(np.ceil(max(a[0], b[0], c[0]))))
        y0 = max(0, int(np.floor(min(a[1], b[1], c[1]))))
        y1 = min(size-1, int(np.ceil(max(a[1], b[1], c[1]))))
        for y in range(y0, y1+1):
            for x in range(x0, x1+1):
                w0 = ((b[1]-c[1])*(x+.5-c[0])+(c[0]-b[0])*(y+.5-c[1]))/denom
                w1 = ((c[1]-a[1])*(x+.5-c[0])+(a[0]-c[0])*(y+.5-c[1]))/denom
                w2 = 1-w0-w1
                if min(w0,w1,w2) < -1e-5:
                    continue
                z = w0*a[2]+w1*b[2]+w2*c[2]
                if z > depth[y,x]:
                    depth[y,x] = z
                    result[y,x] = w0*attributes[face[0]]+w1*attributes[face[1]]+w2*attributes[face[2]]
    return depth, result


def read_geometry(source):
    stage = Usd.Stage.Open(str(source))
    cache = UsdGeom.XformCache()
    vertices, triangles, uvs = [], [], []
    offset = 0
    for prim in stage.Traverse():
        if not prim.IsA(UsdGeom.Mesh):
            continue
        mesh = UsdGeom.Mesh(prim)
        points = np.asarray(mesh.GetPointsAttr().Get(), dtype=np.float64)
        matrix = np.asarray(cache.GetLocalToWorldTransform(prim))
        points = np.c_[points,np.ones(len(points))].dot(matrix)[:,:3]
        faces = np.asarray(mesh.GetFaceVertexIndicesAttr().Get(), dtype=np.int32)
        assert np.all(np.asarray(mesh.GetFaceVertexCountsAttr().Get()) == 3)
        uv = UsdGeom.PrimvarsAPI(prim).GetPrimvar('st0')
        assert str(uv.GetInterpolation()) == 'vertex'
        vertices.append(points)
        triangles.append(faces.reshape(-1,3)+offset)
        uvs.append(np.asarray(uv.ComputeFlattened(), dtype=np.float32))
        offset += len(points)
    points = np.concatenate(vertices)
    lo, hi = points.min(0), points.max(0)
    points = (points-(lo+hi)/2)*2/(hi[1]-lo[1])
    return points.astype(np.float32), np.concatenate(triangles), np.concatenate(uvs)


def prepare(source):
    RESOURCES.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(source) as package:
        color = package.read('0/material_0_diffuse.jpg')
    (RESOURCES/'base-color.jpg').write_bytes(color)
    texture = Image.open(io.BytesIO(color)).convert('RGB')
    points, triangles, uv = read_geometry(source)
    print('bounds',points.min(0),points.max(0),'vertices',len(points),'triangles',len(triangles))
    image_uv = uv.copy()
    image_uv[:,1] = 1-image_uv[:,1]
    visual = trimesh.visual.texture.TextureVisuals(uv=uv, image=texture)
    mesh = trimesh.Trimesh(vertices=points,faces=triangles,visual=visual,process=False)
    (RESOURCES/'face.glb').write_bytes(trimesh.Scene(mesh).export(file_type='glb'))
    export_usdz(points,triangles,uv)
    size=1024
    screen = points.copy()
    screen[:,0] = (points[:,0]/2.2+.5)*size
    screen[:,1] = (.5-points[:,1]/2.2)*size
    depth, pixels = rasterize(screen,triangles,image_uv,size)
    rgb = np.asarray(texture)
    ix = np.clip((pixels[:,:,0]*rgb.shape[1]).astype(int),0,rgb.shape[1]-1)
    iy = np.clip((pixels[:,:,1]*rgb.shape[0]).astype(int),0,rgb.shape[0]-1)
    front=rgb[iy,ix].copy()
    front[depth < -1e9] = [34,34,38]
    Image.fromarray(front).save(RESOURCES/'front-reference.png')
    treatments=bake_masks(points,triangles,uv,depth)
    metadata={'sourceSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'triangles':len(triangles),'vertices':len(points),'upAxis':'Y','frontAxis':'+Z','bounds':[points.min(0).tolist(),points.max(0).tolist()],'cameraTarget':[0,.32,0],'orthographicHeight':1.65,'textureSize':[2048,2048],'treatments':treatments,'maskChannel':'luminance','glbUV':'top-left; Three texture.flipY=false','usdUV':'bottom-left; st primvar','maskMethod':'Manually traced frontal regions, baked through mesh UVs with visibility test; original geometry unchanged.'}
    (RESOURCES/'asset-manifest.json').write_text(json.dumps(metadata,indent=2)+'\n')
    print('Prepared',len(treatments),'masks and native/browser model derivatives.')


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('source',type=Path)
    args=parser.parse_args()
    prepare(args.source)
