from PIL import Image
import sys

src, dst = sys.argv[1:]
im = Image.open(src).convert('RGBA')
px = im.load()
for y in range(im.height):
    for x in range(im.width):
        r, g, b, _ = px[x, y]
        green = g - max(r, b)
        # Keep soft edges while removing the saturated key color.
        alpha = max(0, min(255, int(255 - green * 2.25)))
        if g > 150 and g > r * 1.18 and g > b * 1.18:
            alpha = min(alpha, max(0, int((max(r, b) - 35) * 3.2)))
        if alpha == 0:
            px[x, y] = (0, 0, 0, 0)
        else:
            # Despill green on semi-transparent cloth and hair edges.
            spill = min(g, int((r + b) * 0.5 + 18))
            px[x, y] = (r, spill, b, alpha)
im.save(dst)
