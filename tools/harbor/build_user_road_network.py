"""Trace the player's painted harbor streets into the game's route network.

The thick red strokes in user-road-markup.png are the route authority.  The
thin red lines in that screenshot are the rejected old graph and are removed
by opening the color mask before tracing.  Outputs are deterministic so route
changes can be reviewed as data and as an overlaid image.
"""

from __future__ import annotations

import hashlib
import heapq
import json
import math
import random
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "ArtSource/HarborCityRoutes20260925"
MAP = ROOT / "mistport-ios/Mistport/WisteriaMap"
PREVIEW = ROOT / "output/harbor-user-roads-20260925"
PREVIEW.mkdir(parents=True, exist_ok=True)

# Calibrated against 22 matching yellow nodes in the supplied screenshot and
# the 2048 × 1143 panorama.  Maximum registration residual: 0.54 pixel.
SCALE_X, OFFSET_X = 0.808428793597736, 42.56114997086499
SCALE_Y, OFFSET_Y = 0.8092009185128531, -59.15900116778501
# The second annotated screenshot is a browser-scaled view of the first
# corrected overlay.  Register the same 2048 × 1143 panorama by minimizing
# the RGB difference at 10,000 distributed landmarks (mean clipped error 4.92).
BLUE_SCALE_X, BLUE_OFFSET_X = 1.0899, 31.0
BLUE_SCALE_Y, BLUE_OFFSET_Y = 1.0900333333, -49.9166667


def neighbors_in(mask: set[tuple[int, int]], p: tuple[int, int]):
    y, x = p
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1),
                   (1, 1), (1, -1), (-1, 1), (-1, -1)):
        q = (y + dy, x + dx)
        if q not in mask:
            continue
        # A diagonal next to an orthogonal pixel is an alias of that same
        # turn, not a new crossing or a shortcut across a nearby street.
        if dx and dy and ((y + dy, x) in mask or (y, x + dx) in mask):
            continue
        yield q


def binary_open(mask: np.ndarray, passes: int = 2) -> np.ndarray:
    def morph(values: np.ndarray, want_all: bool) -> np.ndarray:
        padded = np.pad(values, 1)
        result = np.ones_like(values) if want_all else np.zeros_like(values)
        for dy in range(3):
            for dx in range(3):
                neighbor = padded[dy:dy + values.shape[0], dx:dx + values.shape[1]]
                if want_all:
                    result &= neighbor
                else:
                    result |= neighbor
        return result

    for _ in range(passes):
        mask = morph(mask, True)
    for _ in range(passes):
        mask = morph(mask, False)
    return mask


def skeletonize(mask: np.ndarray) -> np.ndarray:
    for _ in range(80):
        before = int(mask.sum())
        for phase in (0, 1):
            padded = np.pad(mask, 1)
            h, w = mask.shape
            p = [padded[0:h, 1:w + 1], padded[0:h, 2:w + 2],
                 padded[1:h + 1, 2:w + 2], padded[2:h + 2, 2:w + 2],
                 padded[2:h + 2, 1:w + 1], padded[2:h + 2, 0:w],
                 padded[1:h + 1, 0:w], padded[0:h, 0:w]]
            count = sum(v.astype(np.uint8) for v in p)
            loop = p + [p[0]]
            changes = sum((~loop[i] & loop[i + 1]).astype(np.uint8)
                          for i in range(8))
            if phase == 0:
                remove = (mask & (count >= 2) & (count <= 6) &
                          (changes == 1) & ~(p[0] & p[2] & p[4]) &
                          ~(p[2] & p[4] & p[6]))
            else:
                remove = (mask & (count >= 2) & (count <= 6) &
                          (changes == 1) & ~(p[0] & p[2] & p[6]) &
                          ~(p[0] & p[4] & p[6]))
            mask[remove] = False
        if int(mask.sum()) == before:
            break
    return mask


def main_component(pixels: set[tuple[int, int]]) -> set[tuple[int, int]]:
    components = []
    remaining = pixels.copy()
    while remaining:
        start = remaining.pop()
        found = {start}
        queue = [start]
        while queue:
            for p in neighbors_in(pixels, queue.pop()):
                if p in remaining:
                    remaining.remove(p)
                    found.add(p)
                    queue.append(p)
        components.append(found)
    return max(components, key=len)


def image_point(pixel: tuple[int, int]) -> list[int]:
    y, x = pixel
    return [round(max(0, min(2048, (x - OFFSET_X) / SCALE_X))),
            round(max(0, min(1143, (y - OFFSET_Y) / SCALE_Y)))]


def simplify(points: list[tuple[int, int]], tolerance: float = 2.1):
    if len(points) <= 2:
        return points
    ay, ax = points[0]
    by, bx = points[-1]
    length = (bx - ax) ** 2 + (by - ay) ** 2
    farthest, index = -1.0, 0
    for i, (y, x) in enumerate(points[1:-1], 1):
        fraction = max(0, min(1, ((x - ax) * (bx - ax) +
                                  (y - ay) * (by - ay)) / length)) if length else 0
        distance = math.hypot(x - (ax + fraction * (bx - ax)),
                              y - (ay + fraction * (by - ay)))
        if distance > farthest:
            farthest, index = distance, i
    if farthest <= tolerance:
        return [points[0], points[-1]]
    return simplify(points[:index + 1], tolerance)[:-1] + simplify(points[index:], tolerance)


def trace_network() -> tuple[list[list[int]], list[list[int]], set[tuple[int, int]]]:
    pixels = np.asarray(Image.open(SOURCE / "user-road-markup.png").convert("RGB"))
    r, g, b = [pixels[:, :, i].astype(np.int16) for i in range(3)]
    # Opening excludes the 1–2 px lines in the rejected diagnostic graph.
    mask = binary_open((r > 170) & (r - g > 65) &
                       (r - b > 70) & (g < 160))
    image = Image.fromarray((mask * 255).astype("uint8"))
    brush = ImageDraw.Draw(image)
    # Separate hand strokes stop a few pixels short at these two paved
    # junctions; join only these surveyed endpoints.
    brush.line([(1191, 289), (1202, 289)], fill=255, width=7)
    brush.line([(1283, 424), (1291, 424)], fill=255, width=7)
    mask = skeletonize(np.asarray(image).copy() > 0)
    path_pixels = main_component(set(zip(*np.where(mask))))

    def trim_leaf(screen_start: tuple[int, int], stop=None):
        nonlocal path_pixels
        start = min(path_pixels, key=lambda p: (p[1] - screen_start[0]) ** 2 +
                    (p[0] - screen_start[1]) ** 2)
        assert sum(1 for _ in neighbors_in(path_pixels, start)) == 1
        preceding = None
        current = start
        to_remove = []
        while True:
            choices = [p for p in neighbors_in(path_pixels, current)
                       if p != preceding]
            if stop and current[1] <= stop[0] and current[0] >= stop[1]:
                break
            if len(choices) != 1:
                break
            to_remove.append(current)
            preceding, current = current, choices[0]
        path_pixels.difference_update(to_remove)

    # The painter's broad strokes specify topology, but these three sketch
    # tails land on blue roofs.  Keep the paved branches and trim only those
    # roof portions; the low west promenade remains connected.
    trim_leaf((553, 380))
    trim_leaf((288, 506))
    trim_leaf((144, 473), stop=(35, 625))
    degree = {p: sum(1 for _ in neighbors_in(path_pixels, p)) for p in path_pixels}
    terminals = {p for p, count in degree.items() if count != 2}
    assert len(path_pixels) > 3800 and len(terminals) < 30, (len(path_pixels), len(terminals))

    visited_edges: set[frozenset[tuple[int, int]]] = set()
    chains: list[list[tuple[int, int]]] = []
    for start in sorted(terminals):
        for adjacent in neighbors_in(path_pixels, start):
            edge = frozenset((start, adjacent))
            if edge in visited_edges:
                continue
            visited_edges.add(edge)
            chain = [start, adjacent]
            prior, current = start, adjacent
            while current not in terminals:
                choices = [p for p in neighbors_in(path_pixels, current) if p != prior]
                assert len(choices) == 1, (current, choices)
                following = choices[0]
                visited_edges.add(frozenset((current, following)))
                chain.append(following)
                prior, current = current, following
            if len(chain) > 2 or chain[0] != chain[-1]:
                chains.append(simplify(chain))

    node_index: dict[tuple[int, int], int] = {}
    nodes: list[list[int]] = []
    edges: list[list[int]] = []
    for chain in chains:
        last = None
        for point in chain:
            if point not in node_index:
                node_index[point] = len(nodes)
                nodes.append(image_point(point))
            index = node_index[point]
            if last is not None and index != last:
                edges.append([last, index])
            last = index
    # The painted east-west stroke disappears *behind* the clock tower here.
    # Without a foreground geometry layer a walker is rendered on the tower
    # wall.  Use the player's lower circular pavement instead for walking.
    # Both sides remain connected by that circular route.
    edges = [edge for edge in edges if not (
        1180 <= (nodes[edge[0]][0] + nodes[edge[1]][0]) / 2 <= 1420 and
        715 <= (nodes[edge[0]][1] + nodes[edge[1]][1]) / 2 <= 755)]
    used = {index for edge in edges for index in edge}
    remap = {old: new for new, old in enumerate(sorted(used))}
    nodes = [nodes[old] for old in sorted(used)]
    edges = [[remap[a], remap[b]] for a, b in edges]
    assert len(nodes) < 550 and len(edges) < 600, (len(nodes), len(edges))
    return nodes, edges, path_pixels


def add_blue_alleys(nodes: list[list[int]], edges: list[list[int]]):
    """Follow all three blue brush strokes, including the very narrow lane.

    They join the red pavement at only the two ends the player marked.  The
    short gaps between pen strokes are joined locally, never by a shortest
    straight line through a house or canal.
    """
    screenshot = np.asarray(Image.open(SOURCE / "user-blue-alley-markup.png")
                            .convert("RGB"))
    blue = ((screenshot[:, :, 0] == 16) &
            (screenshot[:, :, 1] == 174) &
            (screenshot[:, :, 2] == 255))
    bounds = [(72, 404, 721, 597), (458, 558, 1051, 713),
              (100, 616, 667, 897)]
    branches: list[list[int]] = []
    for x1, y1, x2, y2 in bounds:
        margin = 3
        crop = blue[y1-margin:y2+margin+1, x1-margin:x2+margin+1].copy()
        skeleton = skeletonize(crop)
        stroke = main_component(set(zip(*np.where(skeleton))))
        endpoints = sorted((p for p in stroke if sum(
            1 for _ in neighbors_in(stroke, p)) == 1), key=lambda p: p[1])
        assert len(endpoints) == 2, (bounds, endpoints)
        chain = [endpoints[0]]
        prior = None
        while chain[-1] != endpoints[1]:
            following = [p for p in neighbors_in(stroke, chain[-1]) if p != prior]
            assert len(following) == 1, (bounds, chain[-1], following)
            prior = chain[-1]
            chain.append(following[0])
        if len(branches) == 1:
            # Preserve the closest *painted* point at the hidden meeting of
            # the upper and middle alleys.  Free simplification would replace
            # it with a chord that cuts the adjacent narrow roof gap.
            upper_end = nodes[branches[0][-1]]
            anchor = min(range(len(chain)), key=lambda index: math.dist(
                ((chain[index][1] + x1 - margin - BLUE_OFFSET_X) / BLUE_SCALE_X,
                 (chain[index][0] + y1 - margin - BLUE_OFFSET_Y) / BLUE_SCALE_Y),
                upper_end))
            simplified = (simplify(chain[:anchor + 1], tolerance=2.1)[:-1] +
                          simplify(chain[anchor:], tolerance=2.1))
        else:
            simplified = simplify(chain, tolerance=2.1)
        screen_points = [(p[0] + y1 - margin, p[1] + x1 - margin)
                         for p in simplified]
        indices = []
        for screen_y, screen_x in screen_points:
            coordinate = [round((screen_x - BLUE_OFFSET_X) / BLUE_SCALE_X),
                          round((screen_y - BLUE_OFFSET_Y) / BLUE_SCALE_Y)]
            if indices and nodes[indices[-1]] == coordinate:
                continue
            indices.append(len(nodes))
            nodes.append(coordinate)
            if len(indices) > 1:
                edges.append([indices[-2], indices[-1]])
        branches.append(indices)

    def join(a: int, b: int, limit: float):
        distance = math.dist(nodes[a], nodes[b])
        assert distance <= limit, (nodes[a], nodes[b], distance)
        edges.append([a, b])

    upper, middle, lower = branches
    original_count = len(nodes) - sum(map(len, branches))
    def closest(source: int, candidates: list[int]):
        return min(candidates, key=lambda i: math.dist(nodes[source], nodes[i]))

    # Brush lifts at these four visible alley junctions.  Connections are
    # 10–29 panorama pixels, on the same narrow lane, never across a block.
    join(upper[0], lower[0], 30)
    join(upper[-1], closest(upper[-1], middle), 30)
    join(middle[0], closest(middle[0], lower), 35)
    join(middle[-1], closest(middle[-1], list(range(original_count))), 25)
    join(lower[-1], closest(lower[-1], list(range(original_count))), 15)
    return branches


def shortest_route(nodes: list[list[int]], adjacency, first: int, last: int):
    if first == last:
        return [first]
    heap = [(0.0, first)]
    cost = {first: 0.0}
    prior = {}
    while heap:
        distance, current = heapq.heappop(heap)
        if current == last:
            result = [current]
            while result[-1] != first:
                result.append(prior[result[-1]])
            return result[::-1]
        if distance > cost[current]:
            continue
        for next_node in adjacency[current]:
            weight = math.dist(nodes[current], nodes[next_node])
            alternative = distance + weight
            if alternative < cost.get(next_node, float("inf")):
                cost[next_node] = alternative
                prior[next_node] = current
                heapq.heappush(heap, (alternative, next_node))
    raise AssertionError(f"Road graph disconnected: {first} → {last}")


def nearest(nodes: list[list[int]], screen: tuple[int, int]):
    x = (screen[0] - OFFSET_X) / SCALE_X
    y = (screen[1] - OFFSET_Y) / SCALE_Y
    index = min(range(len(nodes)), key=lambda i: math.dist(nodes[i], (x, y)))
    assert math.dist(nodes[index], (x, y)) < 180, (screen, nodes[index])
    return index


def build_catalog(nodes: list[list[int]], edges: list[list[int]]):
    adjacency = [set() for _ in nodes]
    for a, b in edges:
        adjacency[a].add(b)
        adjacency[b].add(a)
    # Every place is a point on the user's painted road, across three broad
    # city regions.  All citizens can choose all three regions over a circuit.
    districts = {
        "旧街": [(50, 650), (170, 830), (390, 720), (470, 645)],
        "钟楼": [(790, 515), (910, 585), (1050, 745), (1200, 550)],
        "东岸": [(1190, 290), (1260, 230), (1320, 425), (1410, 760)],
    }
    hubs = {name: [nearest(nodes, spot) for spot in points]
            for name, points in districts.items()}
    source = json.loads((SOURCE / "citizen-roster-source.json").read_text())
    jobs = {
        "west-lane": "旧街门牌登记员", "cafe-lane": "咖啡馆跑堂",
        "market-lane": "花摊帮工", "clock-square": "钟楼广场水手",
        "east-houses": "东岸提灯人", "upper-road": "上坡守灯人",
        "south-quay": "港务抄账员", "cathedral-road": "教会跑腿",
        "flower-seller-walk": "流动花贩", "sailor-walk": "离港水手",
    }
    resident_atlases = {
        "cafe_keeper": "HarborResidentCafeKeeperWalkAtlas",
        "street_warden": "HarborResidentStreetWardenWalkAtlas",
        "florist": "HarborResidentFloristWalkAtlas",
        "musician": "HarborResidentMusicianWalkAtlas",
        "baker": "HarborResidentBakerWalkAtlas",
        "scholar": "HarborResidentScholarWalkAtlas",
        "dockworker": "HarborResidentDockworkerWalkAtlas",
        "merchant": "HarborResidentMerchantWalkAtlas",
        "clockmaker": "HarborResidentClockmakerWalkAtlas",
        "visitor": "HarborResidentVisitorWalkAtlas",
    }
    people = []
    for previous in source["walkers"] + source["residents"]:
        identifier = previous["id"]
        if "route" in previous:
            old = previous["route"][0]
            atlas = previous["atlasName"]
        else:
            old = previous["point"]
            atlas = resident_atlases[identifier]
        old_screen = (old[0] * SCALE_X + OFFSET_X,
                      old[1] * SCALE_Y + OFFSET_Y)
        if identifier == "east-houses":
            # The old isolated 60-pixel walk at x=1935 was outside the
            # player-painted connected street network.  Start at its east
            # residential branch so this watchman can cross the city.
            old_screen = (1400, 760)
        origin = nearest(nodes, old_screen)
        record = {
            "id": identifier,
            "name": jobs.get(identifier, previous["name"]),
            "atlasName": atlas,
            "dialogue": previous.get("dialogue", "今天的港城很热闹。"),
            "pixelsPerSecond": (18.5 if identifier == "postman" else
                                17.3 if identifier == "courier" else
                                13.8 + (hashlib.sha256(identifier.encode()).digest()[0] % 5)),
            "frameDuration": previous.get("frameDuration", 0.17),
            "phase": 0.02 + (hashlib.sha256((identifier + "-phase").encode()).digest()[0] / 255) * 0.95,
            "routes": [],
        }
        for variant in range(3):
            seed = int.from_bytes(hashlib.sha256(f"{identifier}:{variant}:20260925".encode()).digest()[:8], "big")
            rng = random.Random(seed)
            district_order = list(districts)
            rng.shuffle(district_order)
            destinations = [rng.choice(hubs[region]) for region in district_order]
            destinations += [rng.choice(hubs[rng.choice(list(districts))])
                             for _ in range(2)]
            destinations.append(origin)
            route = [origin]
            for target in destinations:
                leg = shortest_route(nodes, adjacency, route[-1], target)
                route.extend(leg[1:])
            points = [nodes[index] for index in route]
            points = [point for i, point in enumerate(points)
                      if i == 0 or point != points[i - 1]]
            assert math.dist(points[0], points[-1]) < 0.01
            record["routes"].append(points)
        people.append(record)
    catalog = {"referenceWidth": 2048, "referenceHeight": 1143,
               "citizens": people, "districtHubs":
               {name: [nodes[i] for i in indices] for name, indices in hubs.items()}}
    (MAP / "harbor-pedestrians.json").write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")
    return catalog


def preview(nodes, edges, blue_branches):
    image = Image.open(ROOT / "mistport-ios/Mistport/Assets.xcassets/BountyCityPanorama.imageset/city.png")
    image = image.resize((2048, 1143), Image.Resampling.LANCZOS).convert("RGBA")
    overlay = Image.new("RGBA", image.size)
    pen = ImageDraw.Draw(overlay)
    first_blue = blue_branches[0][0]
    for a, b in edges:
        color = ((16, 174, 255, 236) if max(a, b) >= first_blue
                 else (220, 35, 45, 220))
        pen.line((*nodes[a], *nodes[b]), fill=color, width=4)
    for x, y in nodes:
        pen.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(255, 247, 140, 255))
    # The watercolor panorama draws some narrow alleys *behind* house
    # silhouettes.  Keep those edges in the movement graph but do not paint
    # them on top of the foreground roofs in the player-facing review.
    layer = np.asarray(overlay).copy()
    for left, top, right, bottom in ((495, 468, 640, 555),
                                      (390, 555, 715, 710),
                                      (290, 690, 435, 785)):
        layer[top:bottom + 1, left:right + 1, 3] = 0
    overlay = Image.fromarray(layer)
    Image.alpha_composite(image, overlay).convert("RGB").save(PREVIEW / "corrected-road-network.png")


def main():
    nodes, edges, path_pixels = trace_network()
    blue_branches = add_blue_alleys(nodes, edges)
    # Preserve the old 3D preview's home and tour references.  The panorama
    # route IDs are regenerated, so IDs in its NPC metadata must be remapped
    # rather than accidentally pointing at unrelated new streets.
    navigation = json.loads((SOURCE / "navigation-source.json").read_text())
    old_nodes = navigation["nodes"]
    old_home = old_nodes[navigation["spawn"]]
    old_tour = old_nodes[8]
    home_index = min(range(len(nodes)), key=lambda i: math.dist(nodes[i], old_home))
    ordered = [home_index] + [i for i in range(len(nodes)) if i != home_index]
    remap = {old: new for new, old in enumerate(ordered)}
    nodes = [nodes[i] for i in ordered]
    edges = [[remap[a], remap[b]] for a, b in edges]
    blue_branches = [[remap[i] for i in branch] for branch in blue_branches]
    navigation["spawn"] = 0
    navigation["tourNode"] = min(range(len(nodes)), key=lambda i: math.dist(nodes[i], old_tour))
    for npc in navigation["npcs"]:
        previous_position = npc.get("position") or old_nodes[npc["node"]]
        npc["node"] = min(range(len(nodes)), key=lambda i: math.dist(
            nodes[i], previous_position))
    navigation["nodes"] = nodes
    navigation["edges"] = edges
    navigation["source"] = [
        "ArtSource/HarborCityRoutes20260925/user-road-markup.png",
        "ArtSource/HarborCityRoutes20260925/user-blue-alley-markup.png",
    ]
    (MAP / "navigation.json").write_text(json.dumps(navigation, ensure_ascii=False, indent=2) + "\n")
    catalog = build_catalog(nodes, edges)
    preview(nodes, edges, blue_branches)
    print(f"{len(path_pixels)} red road pixels + {len(blue_branches)} blue alley strokes "
          f"→ {len(nodes)} nodes, {len(edges)} edges; "
          f"{len(catalog['citizens'])} citizens × 3 seeded citywide itineraries")


if __name__ == "__main__":
    main()
