"""Author three finite, asymmetric crystal fracture lobes in the editable Effekseer project."""
from pathlib import Path
import copy
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[2]
source = root / 'backups/d02-editor-polish-20260920/SaltmawEffekseer/CrystalImpact.efkproj'
target = root / 'UnityBattleSource/Assets/Resources/ChurchSpellArt/SaltmawEffekseer/CrystalImpact.efkproj'
tree = ET.parse(source)
children = tree.find('./Root/Children')
template = copy.deepcopy(children[0])
children.clear()

def value(parent, path, number):
    for segment in path.split('/'):
        found = parent.find(segment)
        parent = found if found is not None else ET.SubElement(parent, segment)
    parent.text = str(number)

for index, (vx, vy, vz) in enumerate([(-.18, .12, .045), (.135, .07, -.07), (.015, -.13, .11)]):
    node = copy.deepcopy(template)
    value(node, 'Name', f'Crystal fracture lobe {index + 1}')
    value(node, 'CommonValues/MaxGeneration/Value', 3)
    for bound, life in [('Center', 18), ('Min', 15), ('Max', 22)]:
        value(node, f'CommonValues/Life/{bound}', life)
    for bound in ['Center', 'Min', 'Max']:
        value(node, f'CommonValues/GenerationTime/{bound}', .8)
    for axis, speed in zip('XYZ', (vx, vy, vz)):
        for bound, n in [('Center', speed), ('Min', speed-.025), ('Max', speed+.025)]:
            value(node, f'LocationValues/PVA/Velocity/{axis}/{bound}', n)
    for axis, scale, speed in [('X', 1.15, .065), ('Y', 1.75, .09), ('Z', 1, .035)]:
        for bound in ['Center', 'Min', 'Max']:
            value(node, f'ScalingValues/PVA/Scale/{axis}/{bound}', scale)
            value(node, f'ScalingValues/PVA/Velocity/{axis}/{bound}', speed)
    value(node, 'RotationValues/PVA/Rotation/Z/Min', -70 + index*47)
    value(node, 'RotationValues/PVA/Rotation/Z/Max', -38 + index*47)
    value(node, 'RendererCommonValues/FadeOut/Frame', 10)
    children.append(node)
ET.indent(tree)
tree.write(target, encoding='utf-8', xml_declaration=True)
print('Authored 3 lobes × 3 shards; original 22-particle source preserved.')
