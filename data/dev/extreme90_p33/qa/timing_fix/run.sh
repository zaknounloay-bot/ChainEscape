cd /home/user/ChainEscape
echo "Corrected web_timing_test, serial, alternating; started $(date -u +%T)" > /tmp/claude-0/-home-user-ChainEscape/7e9f2bd8-6e70-52bd-944d-4d9f0e72484e/scratchpad/p33/timingfix/summary.txt
for i in 1 2 3; do for arm in P33 P32; do
 if [ $arm = P33 ]; then P=/tmp/claude-0/-home-user-ChainEscape/7e9f2bd8-6e70-52bd-944d-4d9f0e72484e/scratchpad/player33; W=/tmp/claude-0/-home-user-ChainEscape/7e9f2bd8-6e70-52bd-944d-4d9f0e72484e/scratchpad/web33; else P=/tmp/claude-0/-home-user-ChainEscape/7e9f2bd8-6e70-52bd-944d-4d9f0e72484e/scratchpad/player32; W=/tmp/claude-0/-home-user-ChainEscape/7e9f2bd8-6e70-52bd-944d-4d9f0e72484e/scratchpad/web32; fi
 node tools/web_timing_test.mjs $P $W > /tmp/claude-0/-home-user-ChainEscape/7e9f2bd8-6e70-52bd-944d-4d9f0e72484e/scratchpad/p33/timingfix/${arm}_$i.log 2>&1; rc=$?
 echo "$arm run $i exit=$rc :: $(tail -1 /tmp/claude-0/-home-user-ChainEscape/7e9f2bd8-6e70-52bd-944d-4d9f0e72484e/scratchpad/p33/timingfix/${arm}_$i.log) :: $(grep -o 'A: active time.*' /tmp/claude-0/-home-user-ChainEscape/7e9f2bd8-6e70-52bd-944d-4d9f0e72484e/scratchpad/p33/timingfix/${arm}_$i.log | cut -c1-200) :: $(grep -o '^[A-Z]* A: negative.*' /tmp/claude-0/-home-user-ChainEscape/7e9f2bd8-6e70-52bd-944d-4d9f0e72484e/scratchpad/p33/timingfix/${arm}_$i.log)" >> /tmp/claude-0/-home-user-ChainEscape/7e9f2bd8-6e70-52bd-944d-4d9f0e72484e/scratchpad/p33/timingfix/summary.txt
done; done
echo "DONE $(date -u +%T)" >> /tmp/claude-0/-home-user-ChainEscape/7e9f2bd8-6e70-52bd-944d-4d9f0e72484e/scratchpad/p33/timingfix/summary.txt
