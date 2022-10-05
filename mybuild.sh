#!/bin/bash

lnx_ver=5.15.26
build_kernel="no"
build_rootfs="no"
build_image="yes"
distro="ubuntu"
AGENT_INIT="no"
EXTRA_PKGS="htop pciutils kmod g++-11 gcc-11 make iproute2 net-tools coreutils less curl gnupg"

if [ "$build_kernel" = "yes" ]; then
    pushd tools/packaging/kernel
    
    rm -rf kata-linux-$lnx_ver-* linux-upstream_$lnx_ver* linux-*.deb

    ./build-kernel.sh -v $lnx_ver -g nvidia -f setup
    ./build-kernel.sh -v $lnx_ver -g nvidia -f build
    ./build-kernel.sh -v $lnx_ver -g nvidia -f install

    n=`grep processor /proc/cpuinfo| wc -l`
    
    pushd kata-linux-$lnx_ver-*
    make deb-pkg -j $n
    popd
    
    popd
fi

img=ubuntu2204-gpu

if [ "$build_rootfs" = "yes" ]; then
    pushd tools/osbuilder/rootfs-builder
    
    ./myrootfs.sh
    mv ../../packaging/kernel/linux-*.deb .

    sudo docker build -t localhost:32000/$img --build-arg lnx_ver="${lnx_ver}-nvidia-gpu" .
    docker run localhost:32000/$img bash

    c=`docker container ls -a |grep $img |head -1 |awk '{print $1;}'`

    docker export $c -o $img.tar
    docker container rm $c

    rm -rf $img
    mkdir $img
    pushd $img
    tar xf ../$img.tar
    popd
    
    popd
fi

if [ "$build_image" = "yes" ]; then
    pushd tools/osbuilder/image-builder
    echo "Building image for $img"
    sudo ./image_builder.sh ../rootfs-builder/$img

    name=""
    if [ "$AGENT_INIT" = "no" ]; then
        name="-systemd"
    fi
    img="kata-containers-nvidia-gpu${name}.img"
    sudo install -o root -g root -m 0640 -D kata-containers.img "/usr/share/kata-containers/${img}"
    popd
fi