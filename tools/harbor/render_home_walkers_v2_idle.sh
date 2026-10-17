#!/bin/zsh
# Standing frames for task NPCs who wait for the player (rows 4 toward and 3 toward-right; the
# app mirrors 3 for toward-left), from each look's idle model with the same recolour.
#   zsh tools/harbor/render_home_walkers_v2_idle.sh OUTPUT_DIR [SIZE]
set -u
root="${0:A:h:h:h}"
out="$1"; size="${2:-512}"
blender=/Applications/Blender.app/Contents/MacOS/Blender
mkdir -p "$out"
jobs_file="$out/idle-jobs.txt"
python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); [print(k, d["idleModels"][v["model"]], v.get("hue","-")) for k,v in d["looks"].items()]' \
  "$root/tools/harbor/home_walkers_v2.json" > "$jobs_file"
running=0
while read -r name model hue; do
  (
    extra=(); [[ "$hue" != "-" ]] && extra=(--hue "$hue")
    if "$blender" --background --factory-startup --python "$root/tools/harbor/render_home_walkers_v2.py" -- \
        "$root/$model" "$out/$name-idle" --size "$size" --rows 3,4 --arms 0 --swing 1 $extra > "$out/$name-idle.log" 2>&1; then
      echo "RENDERED $name idle"
    else
      echo "FAILED $name idle"
    fi
  ) &
  running=$((running + 1))
  if (( running >= 3 )); then wait; running=0; fi
done < "$jobs_file"
wait
echo "ALL DONE"
