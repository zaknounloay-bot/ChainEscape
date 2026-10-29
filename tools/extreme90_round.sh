#!/bin/bash
# tools/extreme90_round.sh <data dir> <seed> [godot]: every core of <dir>/protocol.json once with this
# RNG seed (ta90_search.gd --ops=v20, 12 min, batch 40, beam 5, patience 8), 4 at a time, families interleaved
cd "$(dirname "$0")/.."
D=$1
SD=$2
G=${3:-godot}
run(){ timeout 1000 $G --headless --path . --script res://tools/ta90_search.gd -- --file=$D/seed_$1.json --minutes=12 --batch=40 --beam=5 --patience=8 --seed=$SD --ops=v20 --out=$D/run_$1_s$SD.json > $D/run_$1_s$SD.log 2>&1; }
order=$(python3 -c "
import json
f=json.load(open('$D/protocol.json'))['families']
fams=list(f.values()); out=[]
for i in range(4):
    for fam in fams: out.append(fam[i])
print(' '.join(out))")
set -- $order
w=0
while [ $# -gt 0 ]; do
  w=$((w+1))
  for i in 1 2 3 4; do [ $# -gt 0 ] && { run $1 & shift; }; done
  wait
  echo "WAVE $w DONE seed $SD" >> $D/rounds.done
done
echo "ROUND DONE seed $SD" >> $D/rounds.done
