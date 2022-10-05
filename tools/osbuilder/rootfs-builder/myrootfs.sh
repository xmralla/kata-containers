#!/bin/bash
. mylib.sh
export EXTRA_PKGS="htop pciutils kmod g++-11 gcc-11 make iproute2 net-tools coreutils less"

script -fec 'sudo -E GOPATH=$GOPATH AGENT_INIT=no USE_DOCKER=true SECCOMP=no LIBC=gnu EXTRA_PKGS="${EXTRA_PKGS}"  ./rootfs.sh ubuntu'
