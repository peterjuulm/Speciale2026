run_build() {
    mkdir -p /tmp/reprotest.X/build-experiment-1-aux && \
    SETARCH_ARCH=$(for a in $(setarch --list); do setarch $a true && echo $a || true; done) && \
    DROP_ARCH="-v -e ^$(uname -m)\$" && \
    WORDSIZE=64 && \
    if [ $WORDSIZE -eq 64 ]; then     for _ARCH_TO_DROP in armh armv7b armv7l         armv8b armv8l arm athlon i386 i486         i586 i686 linux32 mips32 mips parisc32         parisc ppc32le ppc32 ppcle ppc s390         sparc32bash sparc32 sparc;     do         DROP_ARCH="$DROP_ARCH -e ^$_ARCH_TO_DROP\$";     done; fi && \
    SETARCH_ARCH=$(echo "$SETARCH_ARCH" | grep $DROP_ARCH | shuf -n1) && \
    KERNEL_VERSION=$(uname -r) && \
    if [ ${KERNEL_VERSION#2.6} = $KERNEL_VERSION ]; then SETARCH_OPTS=--uname-2.6; fi && \
    echo "INFO:reprotest.build:KERNEL variation: SETARCH_ARCH = '$SETARCH_ARCH' SETARCH_OPTS = '$SETARCH_OPTS'" >&2 && \
    CPU_MAX=$(nproc) && \
    CPU_MIN=$({ echo $CPU_MAX; echo 2; } | sort -n | head -n1) && \
    CPU_NUM=$(if [ $CPU_MIN = $CPU_MAX ];             then echo $CPU_MIN; echo >&2 "only 1 CPU is available; num_cpus is ineffective";             else shuf -i$((CPU_MIN + 1))-$CPU_MAX -n1; fi) && \
    export CPU_LIST="$(echo $(shuf -i0-$((CPU_MAX - 1)) -n$CPU_NUM) | tr ' ' ,)" && \
    echo "INFO:reprotest.build:NUM_CPUS variation: cpu_list = $CPU_LIST" >&2 && \
    umask 0002 && \
    export REPROTEST_BUILD_PATH=/tmp/reprotest.X/build-experiment-1/ && \
    export REPROTEST_UMASK=$(umask) && \
    faketime +398days+19hours+39minutes \
    taskset -a -c $CPU_LIST \
    setarch $SETARCH_ARCH $SETARCH_OPTS \
    sh -ec 'cd "$REPROTEST_BUILD_PATH"; unset REPROTEST_BUILD_PATH; umask "$REPROTEST_UMASK"; unset REPROTEST_UMASK; sh probe.sh'
}

cleanup() {
    __c=0; \
    rm -rf /tmp/reprotest.X/build-experiment-1-aux || __c=$?; \
    exit $__c
}

trap '( cleanup )' HUP INT QUIT ABRT TERM PIPE # FIXME doesn't quite work reliably yet

if ( run_build ); then ( cleanup ); else
    __x=$?; # save the exit code of run_build
    if ( ! false ); then
        if ( cleanup ); then :; else echo >&2 "cleanup failed with exit code $?"; fi;
    fi
    exit $__x
fi
