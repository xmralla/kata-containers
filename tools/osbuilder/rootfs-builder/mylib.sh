#!/bin/bash
rp=`realpath $0`
dn=`dirname ${rp}`

export ROOTFS_DIR=$dn/rootfs-ubuntu
export GOPATH=${HOME}/go/
export LIBC=gnu
