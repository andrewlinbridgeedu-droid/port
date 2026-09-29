"""Prepare numeric R/G lamp scheduling data, without repainting the light art."""
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
CENTERS = [(79, 70), (122, 117), (189, 163), (288, 212), (409, 273)]
ON = [.04, .09, .14, .20, .26]
OFF = [.93, .89, .95, .91, .97]


def main():
    glow = Image.open(HERE / 'assets/CommissionBoulevardLights.png').convert('RGBA')
    assert glow.size == (512, 512)
    alpha = glow.getchannel('A').load()
    order = Image.new('RGB', glow.size)
    pixels = order.load()
    for y in range(512):
        for x in range(512):
            if alpha[x, y]:
                index = min(range(5), key=lambda k: (x - CENTERS[k][0]) ** 2 + (y - CENTERS[k][1]) ** 2)
                pixels[x, y] = (round(255 * (1 - ON[index])), round(255 * OFF[index]), 0)
    order.save(HERE / 'assets/CommissionBoulevardLightOrder.png')


if __name__ == '__main__':
    main()
