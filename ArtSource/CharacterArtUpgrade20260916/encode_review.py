from pathlib import Path
import subprocess,concurrent.futures
root=Path(__file__).resolve().parents[2];out=root/'output/character-art-upgrade-20260916';videos=out/'videos';videos.mkdir(exist_ok=True)
ffmpeg=root/'ArtSource/TranscriptionScribe20260916/video-env/lib/python3.9/site-packages/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1'
def encode(p):
 if (videos/(p.name+'.mp4')).exists():return
 subprocess.run([str(ffmpeg),'-y','-v','error','-framerate','12','-i',str(p/'frame-%03d.png'),'-c:v','libx264','-threads','2','-preset','fast','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(videos/(p.name+'.mp4'))],check=True)
 print(p.name,flush=True)
paths=[p for p in (out/'final').iterdir() if p.is_dir() and (p/'frame-239.png').exists()]
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:list(pool.map(encode,paths))
