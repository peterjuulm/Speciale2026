# Leo's choice (23 Nov, ~16:20): stop the Claude and Codex processes on Arch
# that are two or more days old. SIGTERM only; their transcripts stay and
# they can be resumed. Nothing else is touched.
grep MemAvailable /proc/meminfo
old=$(ps -eo pid=,etimes=,comm= | awk '($3=="claude" || $3=="codex") && $2 >= 172800 {print $1}')
echo "-- to stop ($(echo $old | wc -w)):"
for p in $old; do printf "%8s %s %s  %s\n" "$p" "$(ps -o etime= -p $p | tr -d ' ')" "$(ps -o comm= -p $p)" "$(readlink /proc/$p/cwd)"; done
[ -n "$old" ] && kill -TERM $old
sleep 30
echo "-- still running after 30 s:"
for p in $old; do kill -0 "$p" 2>/dev/null && echo "  $p"; done
echo "(none listed = all stopped)"
sleep 15
grep MemAvailable /proc/meminfo
ps -eo rss=,comm= | awk '{m[$2]+=$1; n[$2]++} END {for (c in m) printf "%6.1f GB %4d %s\n", m[c]/1048576, n[c], c}' | sort -rn | head -6
