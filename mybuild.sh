#!/bin/bash

lnx_ver=5.15.26
build_kernel="no"
build_rootfs="yes"
build_image="yes"

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

if [ "$build_rootfs" = "yes" ]; then
    pushd tools/osbuilder/rootfs-builder
    ./myrootfs.sh

    mv ../../packaging/kernel/linux-*.deb .

    img=ubuntu2204-gpu

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
    sudo ./image_builder.sh ../rootfs-builder/$img
    popd
fi