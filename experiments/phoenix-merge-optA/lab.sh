#!/bin/bash
#
# lab.sh STEP SCRIPT-FILE
#
# Runs SCRIPT-FILE (a bash script on the Mac) on Arch, visibly, in the tmux
# session `lab` that Leo watches: the script is copied to
# /private/tmp/rb1-lab/scripts/STEP.sh, shown with cat, run with its output
# to ~/lab-logs/STEP.log, and its exit code to ~/lab-logs/STEP.rc. This
# script then waits for tmux's signal STEP and prints the exit code and the
# last lines of the log. WAIT=0 sends it and returns at once. TARGET is the
# tmux target (default lab, the session's current pane); lab:probe is a
# second window for short read-only checks while a long job runs in lab.
#
# Written 23 November 2026, at Leo's request to watch the Arch runs.

set -euo pipefail
step=$1 file=$2
arch=leos@192.168.9.124
case "$step" in *[!A-Za-z0-9._-]*) echo "lab.sh: bad step name" >&2; exit 2;; esac
target=${TARGET:-lab}
ssh -o BatchMode=yes "$arch" 'mkdir -p /private/tmp/rb1-lab/scripts ~/lab-logs'
[ "$target" = lab ] || ssh -o BatchMode=yes "$arch" "tmux list-windows -t lab -F '#W' | grep -qx '${target#lab:}' || tmux new-window -d -t lab -n '${target#lab:}' bash"
scp -q "$file" "$arch:/private/tmp/rb1-lab/scripts/$step.sh"
ssh -o BatchMode=yes "$arch" "rm -f ~/lab-logs/$step.rc; tmux send-keys -t $target 'clear; echo \"== $step  \$(date +%H:%M:%S)\"; cat /private/tmp/rb1-lab/scripts/$step.sh; echo ----; bash /private/tmp/rb1-lab/scripts/$step.sh 2>&1 | tee ~/lab-logs/$step.log; echo \${PIPESTATUS[0]} > ~/lab-logs/$step.rc; echo \"== $step done, exit \$(cat ~/lab-logs/$step.rc)  \$(date +%H:%M:%S)\"; tmux wait-for -S $step' Enter"
[ "${WAIT:-1}" = 0 ] && exit 0
ssh -o BatchMode=yes "$arch" "tmux wait-for $step"
rc=$(ssh -o BatchMode=yes "$arch" "cat ~/lab-logs/$step.rc")
echo "== $step exit $rc"
ssh -o BatchMode=yes "$arch" "tail -n ${TAIL:-25} ~/lab-logs/$step.log"
exit "$rc"
