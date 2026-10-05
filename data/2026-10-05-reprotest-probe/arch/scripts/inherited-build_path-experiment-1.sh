run_build() {
    mkdir -p /tmp/reprotest.X/build-experiment-1-aux && \
    SETARCH_OPTS="$SETARCH_OPTS -R" && \
    CPU_MAX=$(nproc) && \
    CPU_MIN=$({ echo $CPU_MAX; echo 2; } | sort -n | head -n1) && \
    CPU_NUM=$CPU_MIN && \
    export CPU_LIST="$(echo $(shuf -i0-$((CPU_MAX - 1)) -n$CPU_NUM) | tr ' ' ,)" && \
    umask 0022 && \
    export REPROTEST_BUILD_PATH=/tmp/reprotest.X/build-experiment-1/ && \
    export REPROTEST_UMASK=$(umask) && \
    taskset -a -c $CPU_LIST \
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
