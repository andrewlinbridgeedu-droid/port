"""One 200 x 200 cm texture atlas per outfit (2048 px, ~10 px/cm). Each garment
part is unwrapped in real centimetres into its own region, so embroidery can be
drawn at true size. The lining atlas shares the same layout."""

SIZE_CM = 200.0
PX = 2048

REGIONS = {  # x0, y0, width, height (cm), origin bottom-left
    'tail': (2.0, 2.0, 58.0, 100.0),
    'side': (62.0, 2.0, 38.0, 74.0),
    'torso': (102.0, 2.0, 96.0, 70.0),
    'sleeve': (102.0, 74.0, 48.0, 66.0),
    'cuff': (152.0, 74.0, 46.0, 18.0),
    'collar': (152.0, 94.0, 46.0, 12.0),
    'facing': (2.0, 104.0, 18.0, 94.0),
    'cape': (22.0, 104.0, 78.0, 44.0),
}


def uv(region, u_cm, v_cm):
    x0, y0, w, h = REGIONS[region]
    return ((x0 + u_cm) / SIZE_CM, (y0 + v_cm) / SIZE_CM)


def to_canvas(region, u_cm, v_cm):
    x0, y0, w, h = REGIONS[region]
    return (x0 + u_cm, y0 + v_cm)
