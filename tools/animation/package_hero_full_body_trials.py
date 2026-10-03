"""Decode and inspect full-body candidates before selecting them into the library."""
import hashlib, json, subprocess
from pathlib import Path
import imageio_ffmpeg

root = Path(__file__).resolve().parents[2]
out = root / 'docs/development/hero-ai-animation-20261002/motion-library/full-body'
spec = json.loads((out / 'actions.json').read_text())
ff = imageio_ffmpeg.get_ffmpeg_exe()
records = []

def run(arguments):
    return subprocess.run([ff, '-hide_banner', '-y', '-loglevel', 'error'] + arguments,
        check=True, capture_output=True, text=True)

for action in spec['actions']:
    complete = True
    for outfit in spec['outfits']:
        folder = out / (action['id'] + '-' + outfit)
        video = folder / 'video.mp4'
        if not video.exists():
            complete = False
            continue
        proof = json.loads((folder / 'result.json').read_text())
        assert hashlib.sha256(video.read_bytes()).hexdigest() == proof['sha256']
        reader = imageio_ffmpeg.read_frames(str(video))
        metadata = next(reader)
        reader.close()
        decoded = run(['-i', str(video), '-progress', 'pipe:1', '-nostats', '-f', 'null', '-'])
        frames = [int(line.split('=')[1]) for line in decoded.stdout.splitlines() if line.startswith('frame=')][-1]
        records.append({'action': action['id'], 'outfit': outfit, 'sourceSHA256': proof['sha256'],
            'size': metadata['size'], 'fps': metadata['fps'], 'seconds': metadata['duration'],
            'decodedFrames': frames, 'fullDecodePassed': True})
        run(['-i', str(video), '-vf', 'fps=2,scale=300:420:force_original_aspect_ratio=decrease,pad=300:420:(ow-iw)/2:(oh-ih)/2:color=0xdad8d3,tile=6x2',
            '-frames:v', '1', str(folder / 'frames.jpg')])
        run(['-i', str(video), '-vf', 'setpts=PTS/3,fps=24', '-an', '-c:v', 'libx264',
            '-crf', '19', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(folder / 'video-3x.mp4')])
        print('CHECKED', folder.name, flush=True)
    if complete:
        inputs = []
        filters = []
        for i, outfit in enumerate(spec['outfits']):
            inputs += ['-i', str(out / (action['id'] + '-' + outfit) / 'video.mp4')]
            filters.append(f'[{i}:v]setpts=PTS/3,scale=420:600:force_original_aspect_ratio=decrease,pad=420:600:(ow-iw)/2:(oh-ih)/2:color=0xdad8d3,fps=24[v{i}]')
        filters.append('[v0][v1][v2]hstack=inputs=3[v]')
        run(inputs + ['-filter_complex', ';'.join(filters), '-map', '[v]', '-an', '-c:v', 'libx264',
            '-crf', '19', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(out / (action['id'] + '-comparison-3x.mp4'))])
(out / 'media-check.json').write_text(json.dumps({'clips': records, 'count': len(records),
    'complete': len(records) == 6, 'notInApp': True}, indent=2) + '\n')
