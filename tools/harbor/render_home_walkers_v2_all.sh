#!/bin/zsh
# Renders every look in tools/harbor/home_walkers_v2.json (rows 0-4; the app mirrors 5-7),
# three Blender processes at a time. Re-running skips frames already on disk.
#   zsh tools/harbor/render_home_walkers_v2_all.sh OUTPUT_DIR [SIZE]
set -u
root="${0:A:h:h:h}"
out="$1"; size="${2:-512}"
blender=/Applications/Blender.app/Contents/MacOS/Blender
mkdir -p "$out"
jobs_file="$out/jobs.txt"
python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); [print(k, d["models"][v["model"]], v.get("hue","-")) for k,v in d["looks"].items()]' \
  "$root/tools/harbor/home_walkers_v2.json" > "$jobs_file"
running=0
while read -r name model hue; do
  (
    extra=(); [[ "$hue" != "-" ]] && extra=(--hue "$hue")
    if "$blender" --background --factory-startup --python "$root/tools/harbor/render_home_walkers_v2.py" -- \
        "$root/$model" "$out/$name" --size "$size" --rows 0,1,2,3,4 $extra > "$out/$name.log" 2>&1; then
      echo "RENDERED $name"
    else
      echo "FAILED $name"
    fi
  ) &
  running=$((running + 1))
  if (( running >= 3 )); then wait; running=0; fi
done < "$jobs_file"
wait
echo "ALL DONE"
