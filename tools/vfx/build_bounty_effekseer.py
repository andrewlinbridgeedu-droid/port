"""Author two finite Effekseer projects; Unity's bundled importer compiles them."""
from pathlib import Path
import copy, shutil, xml.etree.ElementTree as E
root=Path(__file__).resolve().parents[2]
out=root/'UnityBattleSource/Assets/Resources/ChurchSpellArt/BountyEffekseer'
out.mkdir(parents=True,exist_ok=True)
tex=out/'Texture'; tex.mkdir(exist_ok=True)
src=root/'UnityBattleSource/Assets/Resources/Effects/Fool/Effekseer/CurtainExplosion/Texture'
for name in ['aurora01.png','Thunder01.png','Particle02.png','glow.png']:
    shutil.copy2(src/name,tex/name)
base=E.parse(root/'UnityBattleSource/Assets/Resources/ChurchSpellArt/SaltmawEffekseer/CrystalImpact.efkproj')
template=base.find('.//Node')
def setv(n,path,value):
    for part in path.split('/'):
        c=n.find(part)
        if c is None: c=E.SubElement(n,part)
        n=c
    n.text=str(value)
def span(n,path,lo,hi):
    for key,val in [('Min',lo),('Max',hi),('Center',(lo+hi)/2)]:setv(n,path+'/'+key,val)
# Silk now has its own authored texture and generator: build_silk_organic.py.
for name in ['AnchorRupture']:
    tree=copy.deepcopy(base); children=tree.find('Root/Children'); children.clear()
    # Deliberately different layer counts, sizes and motion; no rings or radial blade meshes.
    layers=([('aurora01.png',7,1.3,2.6,.065,26,(255,45,100)),('Thunder01.png',5,.22,2.9,.09,18,(255,165,205)),('Particle02.png',13,.13,.32,.13,25,(255,135,175)),('glow.png',1,2.1,2.1,0,9,(255,130,175))]
      if name=='SilkRupture' else [('Thunder01.png',5,.65,3.1,.055,20,(120,220,255)),('aurora01.png',4,1.5,.65,.1,21,(85,155,215)),('Particle02.png',19,.09,.30,.19,28,(210,235,255)),('glow.png',1,1.8,1.8,0,8,(165,220,255))])
    for i,(texture,count,sx,sy,speed,life,rgb) in enumerate(layers):
        n=copy.deepcopy(template);children.append(n)
        setv(n,'Name',name+' layer '+str(i));setv(n,'CommonValues/MaxGeneration/Value',count)
        span(n,'CommonValues/Life',life-3,life+3);span(n,'CommonValues/GenerationTime',.10,.25)
        span(n,'CommonValues/GenerationTimeOffset',0,2 if i<2 else 4)
        for axis in 'XYZ':
            span(n,'LocationValues/PVA/Location/'+axis,-.12,.12)
            span(n,'LocationValues/PVA/Velocity/'+axis,-speed if axis!='Z' else -speed*.25,speed if axis!='Z' else speed*.25)
            span(n,'RotationValues/PVA/Rotation/'+axis,0 if axis!='Z' else -165,0 if axis!='Z' else 170)
            span(n,'RotationValues/PVA/Velocity/'+axis,0 if axis!='Z' else -3,0 if axis!='Z' else 3)
            size=sx if axis=='X' else sy if axis=='Y' else 1
            span(n,'ScalingValues/PVA/Scale/'+axis,size*.65,size)
            span(n,'ScalingValues/PVA/Velocity/'+axis,.015 if i<2 else 0,.045 if i<2 else 0)
        texture='Thunder01.png' if texture in ('aurora01.png','Particle02.png') else texture
        setv(n,'RendererCommonValues/ColorTexture','Texture/'+texture)
        setv(n,'DrawingValues/Sprite/Billboard',3)
        setv(n,'RendererCommonValues/FadeOut/Frame',12 if i<3 else 7)
        sprite=n.find('DrawingValues/Sprite')
        for k in list(sprite):
            if k.tag.startswith('Position'):sprite.remove(k)
        for ch,v in zip('RGBA',(*rgb,200 if i<2 else 255)):setv(n,'DrawingValues/Sprite/ColorAll_Fixed/'+ch,v)
    setv(tree.getroot(),'EndFrame',40)
    E.indent(tree);tree.write(out/(name+'.efkproj'),encoding='utf-8',xml_declaration=True)
print(out)
