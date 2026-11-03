#!/bin/bash
G=/tmp/claude-0/-home-user-ChainEscape/7e9f2bd8-6e70-52bd-944d-4d9f0e72484e/scratchpad/godot/godot; D=/tmp/claude-0/-home-user-ChainEscape/7e9f2bd8-6e70-52bd-944d-4d9f0e72484e/scratchpad/p33/rtime
for i in 1 2 3; do for T in CUR BASE; do
  while [ $(cut -d. -f1 /proc/loadavg) -ge 1 ] || awk '{exit !($1>=0.5)}' /proc/loadavg; do sleep 20; done
  L=$(cut -d' ' -f1 /proc/loadavg)
  if [ $T = CUR ]; then P=/home/user/ChainEscape; else P=/tmp/claude-0/-home-user-ChainEscape/7e9f2bd8-6e70-52bd-944d-4d9f0e72484e/scratchpad/p33/wt32; fi
  timeout 600 $G --headless --path $P res://tools/RTimeCheck.tscn > $D/${T}_$i.log 2>&1; c=$?
  echo "$T run $i load_before $L exit=$c :: $(grep -E 'RTIME CHECK|FAIL' $D/${T}_$i.log | tr '\n' ' ')" >> $D/summary.txt
done; done
echo RTIME_DONE >> $D/summary.txt
