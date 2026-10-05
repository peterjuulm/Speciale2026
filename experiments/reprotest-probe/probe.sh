#!/bin/sh
# The "build" for reprotest-probe: writes down what a build under reprotest
# sees, one file per property in probe/. No compiler, no network.
#
# Written 5 October 2026.
set -u
mkdir -p probe
env | LC_ALL=C sort > probe/env.txt
umask > probe/umask.txt
: > probe/newfile && stat -c '%a' probe/newfile > probe/mode.txt && rm probe/newfile
{ nproc; grep '^Cpus_allowed_list' /proc/self/status; } > probe/cpus.txt
date -u +%Y-%m-%d > probe/date.txt
date +%z > probe/tz.txt
uname -srm > probe/uname.txt
cat /proc/self/personality > probe/personality.txt
# With ASLR off, the main stack always ends at the top of the address space.
awk '/\[stack\]/ { split($1, a, "-"); print (a[2] == "7ffffffff000") ? "aslr off" : "aslr on" }' /proc/self/maps > probe/aslr.txt
{ id -u; id -un; id -g; id -gn; } > probe/id.txt
pwd > probe/pwd.txt
{ uname -n; cat /proc/sys/kernel/domainname; } > probe/host.txt
locale > probe/locale.txt 2>&1
# ICU's default locale and time zone: what .NET reads on Linux.
icuinfo 2> /dev/null | sed -n 's/ *<param name="\(locale.default\|tz.default\)">\([^<]*\)<.*/\1=\2/p' > probe/icu.txt
grep -c libfaketime /proc/self/maps > probe/faketime.txt || true
