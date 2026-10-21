"""Hero back-view motion takes with Veo 3.1 Fast on Vertex AI (2026-10-21: the eight 雾港夜行 takes).

Runs in Cloud Shell of project movie-511703 (account linrenandrew@gmail.com; its free-trial credit had
CA$20.72 left on 10-21 and the account is upgraded, so spend past the credit is charged: keep CAP_USD).
Put ref.jpg (the outfit's gray reference, ArtSource/HeroBackViews4K20261002/gray/, 1080x1920) and
shots.json ([{id, prompt}], prompts from HERO_MOTION_PROMPTS_20261018.md) in /tmp/hero; home is full.
Veo Fast allows about two requests at once per base model: more get 429 (not billed, but booked here).
Ten takes cost about US$9.6 at the list price of $0.12/s (1080p, 8 s).
"""
import concurrent.futures as cf, json, os, sys, threading, time
from google import genai
from google.genai import types
PROJECT, LOCATION = "movie-511703", "us-central1"
MODEL = os.environ.get("MODEL", "veo-3.1-fast-generate-001")
PRICE_PER_SECOND = 0.12          # USD, Veo 3.1 Fast 1080p list price (video with audio; video only is not dearer)
SECONDS = 8
CAP_USD = float(os.environ.get("CAP_USD", "11"))
NEG = ("black background, gradient background, dark background, face, turning around, facing the camera, profile, "
       "sword, weapon, mask, card, props, glow, particles, light beams, walking, stepping, shuffling, camera movement, zoom, "
       "text, subtitles, watermark, logo")
lock = threading.Lock()
def book():
    with lock:
        s = json.load(open("spent.json")) if os.path.exists("spent.json") else {"usd": 0.0, "requests": 0}
        cost = PRICE_PER_SECOND * SECONDS
        if s["usd"] + cost > CAP_USD + 1e-9:
            return None
        s["usd"] = round(s["usd"] + cost, 2); s["requests"] += 1
        json.dump(s, open("spent.json", "w"))
        return s["usd"]
client = genai.Client(vertexai=True, project=PROJECT, location=LOCATION)
shots = json.load(open("shots.json"))
only = set(sys.argv[1:])
os.makedirs("out", exist_ok=True)
image = types.Image(image_bytes=open("ref.jpg", "rb").read(), mime_type="image/jpeg")
def run(shot):
    path = f"out/{shot['id']}.mp4"
    if os.path.exists(path): return shot["id"], "exists"
    total = book()
    if total is None: return shot["id"], f"SKIPPED: budget cap {CAP_USD} USD reached"
    cfg = types.GenerateVideosConfig(aspect_ratio="9:16", resolution="1080p", duration_seconds=SECONDS, number_of_videos=1,
                                     generate_audio=False, negative_prompt=NEG)
    try:
        op = client.models.generate_videos(model=MODEL, prompt=shot["prompt"], image=image, config=cfg)
    except Exception as e:
        return shot["id"], f"request failed (booked {total}): {e}"
    while not op.done:
        time.sleep(15); op = client.operations.get(op)
    if op.error: return shot["id"], f"error: {op.error}"
    vids = op.response.generated_videos if op.response else None
    if not vids: return shot["id"], f"no video (filtered?): {getattr(op.response, 'rai_media_filtered_reasons', None)}"
    v = vids[0].video
    if v and v.video_bytes:
        open(path, "wb").write(v.video_bytes); return shot["id"], f"ok booked total {total} USD"
    return shot["id"], f"no bytes: {v.uri if v else None}"
todo = [s for s in shots if not only or s["id"] in only]
with cf.ThreadPoolExecutor(3) as pool:
    for r in pool.map(run, todo): print("VEO", *r, flush=True)
print("VEO done", json.load(open("spent.json")) if os.path.exists("spent.json") else {}, flush=True)
