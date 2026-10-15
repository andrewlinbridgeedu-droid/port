"""Cut the user's counter portraits painted on black with a warm rim glow into the transparent
cutouts the counter scenes use (HomeSceneArtwork composites them over the room, 2026-10-15,
the bicycle order's 赫伯特 / 黛娜 / 乔里 / 米拉). The background is the near-black region joined
to the border; the rim glow round the figure is taken off by shrinking the figure a few pixels
past it, then the edge is softened by one pixel. Writes <Asset>.imageset/art.png and the crop
bounds into WisteriaMap/home-counter-portrait-metrics.json.

usage: <python with numpy, scipy, PIL> matte_counter_portraits.py <src> <AssetName> [<src> <AssetName> ...]
"""
import json, sys
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

root = Path(__file__).resolve().parents[2]
assets = root/'mistport-ios/Mistport/Assets.xcassets'
metrics_path = root/'mistport-ios/Mistport/WisteriaMap/home-counter-portrait-metrics.json'
W, H = 1024, 1536

def cut(src):
    im = Image.open(src).convert('RGB')
    s = min(W / im.width, H / im.height)
    im = im.resize((round(im.width * s), round(im.height * s)), Image.Resampling.LANCZOS)
    canvas = Image.new('RGB', (W, H)); canvas.paste(im, ((W - im.width) // 2, H - im.height))
    a = np.asarray(canvas).astype(np.float32)
    v = a.max(axis=2)
    # The painted black is 0-3; dark trousers go down to 3-8 in their creases, so the background
    # is grown only through solid black (eroded, so a crease cannot carry it into the cloth),
    # then widened back to the black and the dark fringe round the figure.
    black = v <= 6
    core = ndi.binary_erosion(black, iterations=3, border_value=1)
    seeds = np.zeros_like(core); seeds[0] = core[0]; seeds[:, 0] = core[:, 0]; seeds[:, -1] = core[:, -1]
    background = ndi.binary_propagation(seeds, mask=core)
    # Then through the dark fringe round the figure (up to 24 px from the solid black): it stops
    # at the bright orange rim line, which the erosion below takes off.
    near = ndi.distance_transform_edt(~background) <= 24
    background = ndi.binary_propagation(background, mask=background | ((v < 60) & near))
    # A wider glow (乔里's shoulder): smooth, untextured warm light still joined to the black.
    lum = a.mean(axis=2)
    texture = np.sqrt(np.maximum(ndi.uniform_filter(lum * lum, 5) - ndi.uniform_filter(lum, 5) ** 2, 0))
    near = ndi.distance_transform_edt(~background) <= 22
    background = ndi.binary_propagation(background, mask=background | ((texture < 3.2) & (v < 150) & near))
    figure = ~background
    labels, n = ndi.label(figure)
    sizes = np.bincount(labels.ravel()); sizes[0] = 0
    figure = np.isin(labels, np.where(sizes > 2000)[0])
    figure = ndi.binary_fill_holes(figure)
    # The rim glow: a warm band a few pixels wide outside the painted edge.
    figure = ndi.binary_erosion(figure, iterations=6)
    alpha = ndi.gaussian_filter(figure.astype(np.float32), .9)
    alpha[ndi.binary_erosion(figure, iterations=2)] = 1
    rgba = np.dstack([a, alpha * 255]).astype(np.uint8)
    return Image.fromarray(rgba, 'RGBA')

def main(pairs):
    metrics = json.loads(metrics_path.read_text())
    for src, name in pairs:
        out = cut(src)
        folder = assets/f'{name}.imageset'; folder.mkdir(exist_ok=True)
        out.save(folder/'art.png', optimize=True)
        (folder/'Contents.json').write_text(json.dumps({'images': [{'filename': 'art.png', 'idiom': 'universal'}],
                                                         'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
        x0, y0, x1, y1 = out.getchannel('A').point(lambda p: 255 if p > 8 else 0).getbbox()
        metrics[name] = {'bounds': [x0, y0, x1 - x0, y1 - y0]}
        print(name, out.size, 'bounds', metrics[name]['bounds'])
    metrics_path.write_text(json.dumps(metrics, indent=2, ensure_ascii=False) + '\n')

if __name__ == '__main__':
    args = sys.argv[1:]
    main(list(zip(args[0::2], args[1::2])))
