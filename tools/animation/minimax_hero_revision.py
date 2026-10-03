"""Resume specific art revisions; credentials and signed URLs stay out of records."""
import argparse, base64, hashlib, json, shutil, time, urllib.request
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--key-file', type=Path, required=True)
p.add_argument('folders', nargs='+', type=Path)
args = p.parse_args()
token = args.key_file.read_text().strip()

def save(path, value):
    temp = path.with_suffix(path.suffix + '.tmp')
    temp.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    temp.replace(path)

def api(route, payload=None):
    request = urllib.request.Request('https://api.minimax.io' + route,
        data=json.dumps(payload).encode() if payload is not None else None,
        headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'})
    with urllib.request.urlopen(request, timeout=90) as response:
        return json.load(response)

active = []
for folder in args.folders:
    record = folder / 'task.json'
    if (folder / 'video.mp4').exists():
        continue
    if record.exists():
        task = json.loads(record.read_text())
        if not task.get('task_id'):
            raise SystemExit('Unresolved prior POST; do not submit again: ' + str(folder))
    else:
        metadata = json.loads((folder / 'request.json').read_text())
        payload = {k: metadata[k] for k in ['model', 'duration', 'resolution', 'prompt_optimizer', 'prompt']}
        payload['first_frame_image'] = 'data:image/png;base64,' + base64.b64encode((folder / 'input.png').read_bytes()).decode()
        save(record, {'unknownOutcome': True})
        task = api('/v1/video_generation', payload)
        save(record, task)
        if not task.get('task_id'):
            raise SystemExit('Submission rejected: ' + str(task.get('base_resp')))
        print('ACCEPTED', folder.name, task['task_id'], flush=True)
        time.sleep(4)
    active.append((folder, task['task_id']))

deadline = time.monotonic() + 1800
while active and time.monotonic() < deadline:
    for folder, task_id in active[:]:
        status = api('/v1/query/video_generation?task_id=' + str(task_id))
        save(folder / 'status.json', status)
        if status.get('status') == 'Fail':
            print('FAILED', folder.name, flush=True)
            active.remove((folder, task_id))
        elif status.get('status') == 'Success':
            result = api('/v1/files/retrieve?file_id=' + str(status['file_id']))
            url = result['file']['download_url']
            if not url.startswith('https://'):
                raise ValueError('Expected HTTPS download')
            video = folder / 'video.mp4'
            with urllib.request.urlopen(url, timeout=120) as response, (folder / 'video.part').open('wb') as stream:
                shutil.copyfileobj(response, stream)
            (folder / 'video.part').replace(video)
            save(folder / 'result.json', {'task_id': task_id, 'file_id': status['file_id'],
                'sha256': hashlib.sha256(video.read_bytes()).hexdigest(), 'bytes': video.stat().st_size,
                'width': status['video_width'], 'height': status['video_height'], 'notInApp': True})
            active.remove((folder, task_id))
            print('DOWNLOADED', folder.name, flush=True)
    if active:
        time.sleep(30)
if active:
    raise SystemExit('Bounded wait ended; task records retained for resume.')
