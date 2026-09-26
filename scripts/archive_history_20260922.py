"""Archive selected historical directories, with byte verification before relocation.

The explicit plan is reviewable in output/storage-archive-20260922/plan.json.
Unarchived siblings are linked into the external mirror to preserve relative paths.
"""
from pathlib import Path
from datetime import datetime
import hashlib
import json
import os
import shutil
import stat
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
VOLUME = Path("/Volumes/andrew's SSD")
DEST = VOLUME / "Mistport-archives/20260922/mindstone-game"
RECEIPTS = ROOT / "output/storage-archive-20260922"


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + '.writing')
    temp.write_text(json.dumps(data, ensure_ascii=False, indent=2))
    temp.replace(path)


def inventory(path, hashes=False):
    result = []
    for folder, dirs, files in os.walk(path, followlinks=False):
        for name in sorted(dirs + files):
            p = Path(folder) / name
            s = p.lstat()
            item = dict(path=str(p.relative_to(path)), mode=stat.S_IMODE(s.st_mode))
            if p.is_symlink():
                item.update(kind='link', target=os.readlink(p))
            elif p.is_dir():
                item.update(kind='directory')
            elif p.is_file():
                item.update(kind='file', size=s.st_size, mtime_ns=s.st_mtime_ns)
                if hashes:
                    h = hashlib.sha256()
                    with p.open('rb') as f:
                        for block in iter(lambda: f.read(8 * 1024 * 1024), b''):
                            h.update(block)
                    after = p.stat()
                    if (s.st_size, s.st_mtime_ns, s.st_ctime_ns) != (after.st_size, after.st_mtime_ns, after.st_ctime_ns):
                        raise RuntimeError(f'File changed while hashing: {p}')
                    item['sha256'] = h.hexdigest()
            else:
                raise RuntimeError(f'Unsupported file type: {p}')
            result.append(item)
    return sorted(result, key=lambda x: x['path'])


def comparable(items):
    return [{k: v for k, v in item.items() if k != 'mtime_ns'} for item in items]


def plan():
    items = []
    for parent, cutoff, minimum in [('ArtSource', '2026-09-19', 50_000_000), ('output', '2026-09-22', 10_000_000)]:
        limit = datetime.fromisoformat(cutoff).timestamp()
        for p in sorted((ROOT / parent).iterdir()):
            if p.is_symlink() or not p.is_dir():
                continue
            inv = inventory(p)
            files = [x for x in inv if x['kind'] == 'file']
            size = sum(x['size'] for x in files)
            if size < minimum or any(x['mtime_ns'] / 1e9 >= limit for x in files):
                continue
            items.append(dict(path=str(p.relative_to(ROOT)), bytes=size, files=len(files), source_inventory=inv))
    result = dict(root=str(ROOT), destination=str(DEST), created=datetime.now().isoformat(), items=items,
                  bytes=sum(x['bytes'] for x in items), directories=len(items))
    save(RECEIPTS / 'plan.json', result)
    print(json.dumps({k: v for k, v in result.items() if k != 'items'}), flush=True)


def mirror_links():
    for parent in [Path('.'), Path('ArtSource'), Path('output')]:
        target_parent = DEST / parent
        target_parent.mkdir(parents=True, exist_ok=True)
        for p in (ROOT / parent).iterdir():
            if parent == Path('.') and p.name in ['ArtSource', 'output']:
                continue
            target = target_parent / p.name
            if not os.path.lexists(target):
                target.symlink_to(p, target_is_directory=p.is_dir())


def apply():
    if not os.path.ismount(VOLUME):
        raise RuntimeError('External volume is not mounted')
    data = json.loads((RECEIPTS / 'plan.json').read_text())
    if shutil.disk_usage(VOLUME).free < data['bytes'] + 5_000_000_000:
        raise RuntimeError('Insufficient external free space')
    done = []
    DEST.mkdir(parents=True, exist_ok=True)
    for i, item in enumerate(data['items']):
        src = ROOT / item['path']
        dst = DEST / item['path']
        if src.is_symlink() and src.resolve() == dst:
            raise RuntimeError(f'Already archived; inspect receipts before resuming: {src}')
        if inventory(src) != item['source_inventory']:
            raise RuntimeError(f'Source changed since plan; left untouched: {src}')
        if os.path.lexists(dst):
            raise RuntimeError(f'Destination already exists: {dst}')
        print(f'[{i+1}/{len(data["items"])}] Copy and verify {item["path"]} ({item["bytes"]/1e9:.2f} GB)', flush=True)
        dst.parent.mkdir(parents=True, exist_ok=True)
        partial = dst.with_name(dst.name + '.copying')
        if os.path.lexists(partial):
            raise RuntimeError(f'Partial copy already exists: {partial}')
        subprocess.run(['/usr/bin/ditto', '--rsrc', '--extattr', '--acl', str(src), str(partial)], check=True)
        before = inventory(src, hashes=True)
        copied = inventory(partial, hashes=True)
        if comparable(before) != comparable(copied):
            raise RuntimeError(f'Copy mismatch; original retained: {src}')
        if inventory(src) != item['source_inventory']:
            raise RuntimeError(f'Source changed during copying; original retained: {src}')
        manifest = dict(source=str(src), destination=str(dst), bytes=item['bytes'], files=item['files'], entries=before)
        name = item['path'].replace('/', '--') + '.json'
        save(RECEIPTS / 'manifests' / name, manifest)
        save(DEST.parent / 'manifests' / name, manifest)
        partial.rename(dst)
        hold = src.with_name('.' + src.name + '.archive-verified-20260922')
        if os.path.lexists(hold):
            raise RuntimeError(f'Local hold already exists: {hold}')
        src.rename(hold)
        try:
            if inventory(hold) != item['source_inventory']:
                raise RuntimeError(f'Source changed before switch: {src}')
            src.symlink_to(dst, target_is_directory=True)
        except Exception:
            hold.rename(src)
            raise
        # Only this verified, explicitly selected duplicate is removed locally.
        shutil.rmtree(hold)
        done.append(dict(path=item['path'], bytes=item['bytes'], files=item['files'], manifest=name))
        save(RECEIPTS / 'completed.json', done)
        print(f'  Archived and original path linked; total {sum(x["bytes"] for x in done)/1e9:.2f} GB', flush=True)
    mirror_links()
    result = dict(completed=datetime.now().isoformat(), directories=len(done), files=sum(x['files'] for x in done),
                  bytes=sum(x['bytes'] for x in done), destination=str(DEST), links_verified=all((ROOT/x['path']).resolve()==DEST/x['path'] for x in done))
    save(RECEIPTS / 'result.json', result)
    save(DEST.parent / 'result.json', result)
    print(json.dumps(result), flush=True)


if __name__ == '__main__':
    if sys.argv[1:] == ['--plan']:
        plan()
    elif sys.argv[1:] == ['--apply']:
        apply()
    else:
        raise SystemExit('Use --plan, inspect the plan, then --apply.')
