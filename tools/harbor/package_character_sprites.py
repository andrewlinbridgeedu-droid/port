"""Package Blender-rendered GLTF frames into Xcode image assets."""

import json
import shutil
from pathlib import Path
from PIL import Image


root = Path(__file__).resolve().parents[2]
renders = root / "output/harbor-npc-route-20260925/render"
new_renders = root / "output/harbor-map-daynight-20260925/render"
resident_walk_renders = root / "output/harbor-user-roads-20260925/render"
assets = root / "mistport-ios/Mistport/Assets.xcassets"

animated = {
    "HarborPostmanWalkAtlas": "postman-user-walking",
    "HarborCourierWalkAtlas": "courier-walking",
}
new_animated = {
    "HarborLamplighterWalkAtlas": "harbor_lamplighter",
    "HarborFlowerSellerWalkAtlas": "harbor_flower_seller",
    "HarborSailorWalkAtlas": "harbor_sailor",
    "HarborArchiveApprenticeWalkAtlas": "harbor_archive_apprentice",
}
standing = {
    "HarborNPCCafeKeeper": "cafe_keeper-idle",
    "HarborNPCStreetWarden": "street_warden-idle",
    "HarborNPCFlorist": "florist-idle",
    "HarborNPCMusician": "musician-idle",
    "HarborNPCBaker": "baker-idle",
    "HarborNPCScholar": "scholar-idle",
    "HarborNPCDockworker": "dockworker-idle",
    "HarborNPCMerchant": "merchant-idle",
    "HarborNPCClockmaker": "clockmaker-idle",
    "HarborNPCVisitor": "visitor-idle",
}
resident_animated = {
    "HarborResidentCafeKeeperWalkAtlas": "cafe_keeper",
    "HarborResidentStreetWardenWalkAtlas": "street_warden",
    "HarborResidentFloristWalkAtlas": "florist",
    "HarborResidentMusicianWalkAtlas": "musician",
    "HarborResidentBakerWalkAtlas": "baker",
    "HarborResidentScholarWalkAtlas": "scholar",
    "HarborResidentDockworkerWalkAtlas": "dockworker",
    "HarborResidentMerchantWalkAtlas": "merchant",
    "HarborResidentClockmakerWalkAtlas": "clockmaker",
    "HarborResidentVisitorWalkAtlas": "visitor",
}


def catalog(asset_name: str, file_name: str) -> Path:
    directory = assets / f"{asset_name}.imageset"
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "Contents.json").write_text(json.dumps({
        "images": [{"filename": file_name, "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }, indent=2) + "\n")
    return directory / file_name


for asset_name, stem in {**animated, **new_animated, **resident_animated}.items():
    source = (resident_walk_renders if asset_name in resident_animated else
              new_renders if asset_name in new_animated else renders)
    frames = [Image.open(source / f"{stem}-{index:02d}.png").convert("RGBA")
              for index in range(8)]
    if any(frame.size != (256, 256) for frame in frames):
        raise ValueError(f"Unexpected frame size: {stem}")
    atlas = Image.new("RGBA", (2048, 256), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        atlas.paste(frame, (index * 256, 0))
    atlas.save(catalog(asset_name, "art.png"), optimize=True)

for asset_name, stem in standing.items():
    source = renders / f"{stem}-00.png"
    with Image.open(source) as image:
        if image.mode != "RGBA" or image.size != (256, 256):
            raise ValueError(f"Unexpected resident sprite: {stem}")
    shutil.copy2(source, catalog(asset_name, "art.png"))

print(f"Packaged {len(animated) + len(new_animated) + len(resident_animated)} animated and {len(standing)} resident GLTF characters")
