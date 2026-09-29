"""Overlay the proposed map on an untouched CityHubView device snapshot.

Usage: python3 .../overlay_device.py screenshot.png [output.jpg]
Requires the snapshot's adjacent .png.json geometry sidecar. Coordinates are
converted from painting-height units to window pixels, including camera offset.
The output is a proposal annotation, not an implemented UI or visual acceptance.
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

source = Path(sys.argv[1])
destination = Path(sys.argv[2]) if len(sys.argv) > 2 else source.with_suffix('.proposal.jpg')
geometry = json.loads(Path(str(source) + '.json').read_text())
layout = json.loads((Path(__file__).parent / 'home-map-layout.json').read_text())
image = Image.open(source).convert('RGB')
draw = ImageDraw.Draw(image)
font = ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc', 24)
scale = geometry['screenScale']
origin_x = geometry['windowWidth'] / 2 - geometry['panoramaWidth'] / 2 + geometry['offset'] + geometry['paintingMinX']


def point(value):
    return ((origin_x + value[0] * geometry['paintingHeight']) * scale,
            (geometry['paintingMinY'] + value[1] * geometry['paintingHeight']) * scale)


def label(value, text, color):
    x, y = point(value)
    if not 0 <= x <= image.width or not 0 <= y <= image.height:
        return
    draw.ellipse((x - 7, y - 7, x + 7, y + 7), fill=color)
    box = draw.textbbox((x + 10, y), text, font=font)
    draw.rectangle(box, fill=(20, 20, 25))
    draw.text((x + 10, y), text, fill=color, font=font)


for street in layout['streets']:
    draw.line([point(p) for p in street['points']], fill='white', width=4)
for hold in layout['holdSpots']:
    label(hold['at'], hold['id'], '#ffd65a')
for building in layout['buildings']:
    label(building['at'], building['name'], '#80caff')
for person in layout['namedPosts'] + layout['alwaysInteractive']:
    label(person['post'], person['who'], '#d5a1ff')
draw.rectangle((0, image.height - 55, image.width, image.height), fill=(18, 21, 28))
draw.text((12, image.height - 45), '真机截图叠加坐标提案：未实装、未经用户认可', font=font, fill='white')
image.save(destination, quality=88)
print(destination)
