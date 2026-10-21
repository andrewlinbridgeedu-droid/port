"""Hero back-view motion takes with Veo on Vertex AI, run in Cloud Shell (10-21: the second round, both
other outfits, veo-3.1-generate-001, two versions per prompt). See veo_hero_takes.py for the first round.

shots.json: [{id, ref, prompt}]; refs beside it. Every request is booked in spent.json at list price
(SAMPLES x SECONDS x PRICE) before it is sent; nothing is sent past CAP_USD. A 429 is not billed: its
booking is returned and the request retried after a minute.

Prompts: docs/development/hero-ai-animation-20261002/integration/veo-shots-20261021b.json. Review the
downloads with veo_review_sheets.py; the list price used for the cap is the one with audio ($0.40/s), video
only bills about half.
"""
import concurrent.futures as cf, json, os, sys, threading, time
from google import genai
from google.genai import types
PROJECT = os.environ["PROJECT"]; LOCATION = "us-central1"
MODEL = os.environ.get("MODEL", "veo-3.1-generate-001")
PRICE = float(os.environ.get("PRICE", "0.40")); SECONDS = 8
SAMPLES = int(os.environ.get("SAMPLES", "2")); CAP = float(os.environ.get("CAP_USD", "250"))
NEG = ("black background, gradient background, dark background, face, turning around, facing the camera, profile view, "
       "sword, blade, weapon, mask, card, props, glow, sparkle, particles, light beams, smoke, steam, mist, vapor, "
       "walking, stepping, shuffling, camera movement, zoom, text, subtitles, watermark, logo")
lock = threading.Lock()
def book(delta):
    with lock:
        s = json.load(open("spent.json")) if os.path.exists("spent.json") else {"usd": 0.0, "requests": 0}
        if delta > 0 and s["usd"] + delta > CAP + 1e-9: return None
        s["usd"] = round(s["usd"] + delta, 2); s["requests"] += 1 if delta > 0 else -1
        json.dump(s, open("spent.json", "w")); return s["usd"]
client = genai.Client(vertexai=True, project=PROJECT, location=LOCATION)
shots = json.load(open("shots.json")); only = set(sys.argv[1:])
os.makedirs("out", exist_ok=True)
def run(shot):
    sid = shot["id"]
    if os.path.exists(f"out/{sid}_1.mp4"): return sid, "exists"
    image = types.Image(image_bytes=open(shot["ref"], "rb").read(), mime_type="image/jpeg")
    cost = PRICE * SECONDS * SAMPLES
    for attempt in range(6):
        total = book(cost)
        if total is None: return sid, f"SKIPPED: cap {CAP} reached"
        cfg = types.GenerateVideosConfig(aspect_ratio="9:16", resolution="1080p", duration_seconds=SECONDS,
                                         number_of_videos=SAMPLES, generate_audio=False, negative_prompt=NEG)
        try:
            op = client.models.generate_videos(model=MODEL, prompt=shot["prompt"], image=image, config=cfg)
        except Exception as e:
            book(-cost)
            if "429" in str(e) or "RESOURCE_EXHAUSTED" in str(e): time.sleep(60); continue
            return sid, f"request failed: {str(e)[:300]}"
        while not op.done:
            time.sleep(15); op = client.operations.get(op)
        if op.error: return sid, f"error (booked): {op.error}"
        vids = op.response.generated_videos if op.response else None
        if not vids: return sid, f"no video (booked): {getattr(op.response, 'rai_media_filtered_reasons', None)}"
        n = 0
        for v in vids:
            if v.video and v.video.video_bytes:
                n += 1; open(f"out/{sid}_{n}.mp4", "wb").write(v.video.video_bytes)
        return sid, f"ok x{n}, booked total {total} USD"
    return sid, "gave up after repeated 429"
todo = [s for s in shots if not only or s["id"] in only]
with cf.ThreadPoolExecutor(int(os.environ.get("PAR", "2"))) as pool:
    for r in pool.map(run, todo): print("VEO", *r, flush=True)
print("VEO done", json.load(open("spent.json")) if os.path.exists("spent.json") else {}, flush=True)
