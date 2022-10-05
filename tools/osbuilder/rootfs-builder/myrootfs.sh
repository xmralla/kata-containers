#!/bin/bash
. mylib.sh
script -fec 'sudo -E GOPATH=$GOPATH AGENT_INIT=${AGENT_INIT:-no} USE_DOCKER=true SECCOMP=no LIBC=gnu EXTRA_PKGS="${EXTRA_PKGS}"  ./rootfs.sh ${distro:-ubuntu} '
