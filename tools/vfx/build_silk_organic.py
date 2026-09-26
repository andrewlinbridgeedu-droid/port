"""B05 organic textile effects, using the archived generated satin texture."""
from pathlib import Path
import copy, xml.etree.ElementTree as E
root=Path(__file__).resolve().parents[2]
out=root/'UnityBattleSource/Assets/Resources/ChurchSpellArt/BountyEffekseer'
base=E.parse(root/'UnityBattleSource/Assets/Resources/ChurchSpellArt/SaltmawEffekseer/CrystalImpact.efkproj')
template=base.find('.//Node')
def put(n,path,value):
    for part in path.split('/'):
        c=n.find(part)
        if c is None:c=E.SubElement(n,part)
        n=c
    n.text=str(value)
def span(n,path,low,high):
    for k,v in [('Min',low),('Max',high),('Center',(low+high)/2)]:put(n,path+'/'+k,v)
for name in ('SilkTravel','SilkRupture'):
    tree=copy.deepcopy(base);children=tree.find('Root/Children');children.clear()
    travel=name=='SilkTravel'
    # Unequal authored directions. Each cloth has its own spatial separation and timing.
    layers=[(-22,2.15,-.12,.1),(61,1.40,.20,-.23)] if travel else [(-35,1.65,-.8,.5),(77,1.35,.85,.25),(164,1.10,-.1,-.85)]
    for i,(angle,size,x,y) in enumerate(layers):
        n=copy.deepcopy(template);children.append(n)
        put(n,'Name',name+' fold '+str(i));put(n,'CommonValues/MaxGeneration/Value',1)
        span(n,'CommonValues/Life',35 if travel else 28,35 if travel else 28)
        span(n,'CommonValues/GenerationTimeOffset',i*2 if travel else i*.6,i*2 if travel else i*.6)
        for axis,offset in zip('XYZ',(x*.12,y*.12,0)):
            span(n,'LocationValues/PVA/Location/'+axis,offset,offset)
            direction=x if axis=='X' else y if axis=='Y' else 0
            velocity=0 if travel else direction*.155
            span(n,'LocationValues/PVA/Velocity/'+axis,velocity,velocity)
            span(n,'LocationValues/PVA/Acceleration/'+axis,0 if travel else -direction*.005,0 if travel else -direction*.005)
            rotation=angle if axis=='Z' else 0
            span(n,'RotationValues/PVA/Rotation/'+axis,rotation,rotation)
            spin=(.6 if i%2 else -.9) if axis=='Z' else 0
            span(n,'RotationValues/PVA/Velocity/'+axis,spin,spin)
            span(n,'ScalingValues/PVA/Scale/'+axis,size if axis!='Z' else 1,size if axis!='Z' else 1)
            span(n,'ScalingValues/PVA/Velocity/'+axis,.009 if travel else .13,.009 if travel else .13)
            span(n,'ScalingValues/PVA/Acceleration/'+axis,0 if travel else -.0035,0 if travel else -.0035)
        put(n,'RendererCommonValues/ColorTexture','Texture/CrimsonSilk.png')
        put(n,'RendererCommonValues/FadeOut/Frame',12)
        put(n,'DrawingValues/Sprite/Billboard',3)
        sprite=n.find('DrawingValues/Sprite')
        for c in list(sprite):
            if c.tag.startswith('Position'):sprite.remove(c)
        for channel in 'RGBA':put(n,'DrawingValues/Sprite/ColorAll_Fixed/'+channel,255)
        # Same surface, additive radiance passes: brighter folds without adding more flying pieces.
        for pass_index in range(2):
            bright=copy.deepcopy(n);put(bright,'Name',name+' radiance '+str(i)+' '+str(pass_index))
            put(bright,'DrawingValues/Sprite/ColorAll_Fixed/A',210 if pass_index==0 else 140)
            children.append(bright)
    if not travel:
        flash=copy.deepcopy(n);children.append(flash);put(flash,'Name','Brief torn contact flare')
        span(flash,'CommonValues/Life',8,8);span(flash,'CommonValues/GenerationTimeOffset',0,0)
        for axis in 'XYZ':
            for field in ('Location','Velocity','Acceleration'):span(flash,'LocationValues/PVA/'+field+'/'+axis,0,0)
            span(flash,'ScalingValues/PVA/Scale/'+axis,1.4,1.4)
            span(flash,'ScalingValues/PVA/Velocity/'+axis,.09,.09)
            span(flash,'ScalingValues/PVA/Acceleration/'+axis,0,0)
        put(flash,'RendererCommonValues/ColorTexture','Texture/SilkFlash.png')
        put(flash,'RendererCommonValues/FadeOut/Frame',7)
    put(tree.getroot(),'EndFrame',45)
    E.indent(tree);tree.write(out/(name+'.efkproj'),encoding='utf-8',xml_declaration=True)
print('Authored SilkTravel and SilkRupture')
