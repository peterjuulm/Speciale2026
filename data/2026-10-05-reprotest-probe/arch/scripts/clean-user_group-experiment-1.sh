run_build() {
    mkdir -p /tmp/reprotest.X/build-experiment-1-aux && \
    mv /tmp/reprotest.X/build-experiment-1/ /tmp/reprotest.X/const_build_path && \
    SETARCH_OPTS="$SETARCH_OPTS -R" && \
    CPU_MAX=$(nproc) && \
    CPU_MIN=$({ echo $CPU_MAX; echo 2; } | sort -n | head -n1) && \
    CPU_NUM=$CPU_MIN && \
    export CPU_LIST="$(echo $(shuf -i0-$((CPU_MAX - 1)) -n$CPU_NUM) | tr ' ' ,)" && \
    sh -ec '
        mkdir -p "/tmp/reprotest.X/bin"
        printf '"'"'#!/bin/sh\nsudo -E -u rb1b -g rb1b env -u SUDO_COMMAND -u SUDO_GID -u SUDO_UID -u SUDO_USER /usr/bin/disorderfs "$@"\n'"'"' > "/tmp/reprotest.X/bin"/disorderfs
        chmod +x "/tmp/reprotest.X/bin"/disorderfs
        printf '"'"'#!/bin/sh\nsudo -E -u rb1b -g rb1b env -u SUDO_COMMAND -u SUDO_GID -u SUDO_UID -u SUDO_USER /bin/mkdir "$@"\n'"'"' > "/tmp/reprotest.X/bin"/mkdir
        chmod +x "/tmp/reprotest.X/bin"/mkdir
        printf '"'"'#!/bin/sh\nsudo -E -u rb1b -g rb1b env -u SUDO_COMMAND -u SUDO_GID -u SUDO_UID -u SUDO_USER /bin/fusermount "$@"\n'"'"' > "/tmp/reprotest.X/bin"/fusermount
        chmod +x "/tmp/reprotest.X/bin"/fusermount
    ' && \
    export PATH="/tmp/reprotest.X/bin:$PATH" && \
    sudo chown -h -R --from=leos rb1b /tmp/reprotest.X/const_build_path/ && \
    umask 0022 && \
    export REPROTEST_BUILD_PATH=/tmp/reprotest.X/const_build_path/ && \
    export REPROTEST_UMASK=$(umask) && \
    sudo -E -u rb1b -g rb1b env -u SUDO_COMMAND -u SUDO_GID -u SUDO_UID -u SUDO_USER \
    taskset -a -c $CPU_LIST \
    sh -ec 'cd "$REPROTEST_BUILD_PATH"; unset REPROTEST_BUILD_PATH; umask "$REPROTEST_UMASK"; unset REPROTEST_UMASK; sh probe.sh'
}

cleanup() {
    __c=0; \
    sudo chown -h -R --from=rb1b leos /tmp/reprotest.X/const_build_path/ || __c=$?; \
    sh -ec 'cd "/tmp/reprotest.X/bin" && rm -f disorderfs mkdir fusermount' || __c=$?; \
    mv /tmp/reprotest.X/const_build_path /tmp/reprotest.X/build-experiment-1/ || __c=$?; \
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
