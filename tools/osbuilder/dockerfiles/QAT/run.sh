#!/bin/bash
#
# Copyright (c) 2021 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0

set -e
set -u

# NOTE: Some env variables are set in the Dockerfile - those that are
# intended to be over-rideable.
export QAT_SRC=~/src/QAT
export ROOTFS_DIR=~/src/rootfs
export GOPATH=~/src/go
export PATH=${PATH}:/usr/local/go/bin:${GOPATH}/bin

katarepo=github.com/kata-containers/kata-containers
katarepopath=${GOPATH}/src/${katarepo}

testsrepo=github.com/kata-containers/tests
testsrepopath=${GOPATH}/src/${testsrepo}

grab_kata_repos()
{
    # Check out all the repos we will use now, so we can try and ensure they use the specified branch
    # Only check out the branch needed, and make it shallow and thus space/bandwidth efficient
    # Use a green prompt with white text for easy viewing
    bin/echo -e "\n\e[1;42mClone and checkout Kata repos\e[0m" 
    git clone --single-branch --branch $KATA_REPO_VERSION --depth=1 https://${katarepo} ${katarepopath}
    git clone --single-branch --branch $KATA_REPO_VERSION --depth=1 https://${testsrepo} ${testsrepopath}
}

configure_kernel()
{
    cp /input/qat.conf ${katarepopath}/tools/packaging/kernel/configs/fragments/common/qat.conf
    # We need yq and go to grab kernel versions etc.
    ${testsrepopath}/.ci/install_yq.sh
    ${testsrepopath}/.ci/install_go.sh -p
    cd ${katarepopath}
    /bin/echo -e "\n\e[1;42mDownload and configure Kata kernel with CRYPTO support\e[0m"
    ./tools/packaging/kernel/build-kernel.sh setup
}

build_kernel()
{
    cd ${katarepopath}
    LINUX_VER=$(ls -d kata-linux-*)
    sed -i 's/EXTRAVERSION =/EXTRAVERSION = .qat.container/' $LINUX_VER/Makefile
    /bin/echo -e "\n\e[1;42mBuild Kata kernel with CRYPTO support\e[0m" 
    ./tools/packaging/kernel/build-kernel.sh build
}

build_rootfs()
{
    # Due to an issue with debootstrap unmounting /proc when running in a
    # --privileged container, change into /proc to keep it from being umounted. 
    # This should only be done for Ubuntu and Debian based OS's. Other OS 
    # distributions had issues if building the rootfs from /proc

    if [ "${ROOTFS_OS}" == "debian" ] || [ "${ROOTFS_OS}" == "ubuntu" ]; then 
        cd /proc
    fi
    /bin/echo -e "\n\e[1;42mDownload ${ROOTFS_OS} based rootfs\e[0m"
    SECCOMP=no EXTRA_PKGS='kmod' ${katarepopath}/tools/osbuilder/rootfs-builder/rootfs.sh $ROOTFS_OS 
}

grab_qat_drivers()
{
    /bin/echo -e "\n\e[1;42mDownload and extract the drivers\e[0m" 
    mkdir -p $QAT_SRC
    cd $QAT_SRC
    curl -L $QAT_DRIVER_URL | tar zx
}

build_qat_drivers()
{
    /bin/echo -e "\n\e[1;42mCompile driver modules\e[0m"
    cd ${katarepopath}
    linux_kernel_path=${katarepopath}/${LINUX_VER}
    KERNEL_MAJOR_VERSION=$(awk '/^VERSION =/{print $NF}' ${linux_kernel_path}/Makefile)
    KERNEL_PATHLEVEL=$(awk '/^PATCHLEVEL =/{print $NF}' ${linux_kernel_path}/Makefile)
    KERNEL_SUBLEVEL=$(awk '/^SUBLEVEL =/{print $NF}' ${linux_kernel_path}/Makefile)
    KERNEL_EXTRAVERSION=$(awk '/^EXTRAVERSION =/{print $NF}' ${linux_kernel_path}/Makefile)
    KERNEL_ROOTFS_DIR=${KERNEL_MAJOR_VERSION}.${KERNEL_PATHLEVEL}.${KERNEL_SUBLEVEL}${KERNEL_EXTRAVERSION}
    cd $QAT_SRC
    KERNEL_SOURCE_ROOT=${linux_kernel_path} ./configure ${QAT_CONFIGURE_OPTIONS}
    make all -j$(nproc) 
}

add_qat_to_rootfs()
{
    /bin/echo -e "\n\e[1;42mCopy driver modules to rootfs\e[0m"
    cd $QAT_SRC
    make INSTALL_MOD_PATH=${ROOTFS_DIR} qat-driver-install -j$(nproc)
    cp $QAT_SRC/build/usdm_drv.ko ${ROOTFS_DIR}/lib/modules/${KERNEL_ROOTFS_DIR}/updates/drivers
    depmod -a -b ${ROOTFS_DIR} ${KERNEL_ROOTFS_DIR}
    cd ${katarepopath}/tools/osbuilder/image-builder
    /bin/echo -e "\n\e[1;42mBuild rootfs image\e[0m"
    ./image_builder.sh ${ROOTFS_DIR}
}

copy_outputs()
{
    /bin/echo -e "\n\e[1;42mCopy kernel and rootfs to the output directory and provide sample configuration files\e[0m"
    mkdir -p ${OUTPUT_DIR} || true
    cp ${linux_kernel_path}/arch/x86/boot/bzImage $OUTPUT_DIR/vmlinuz-${LINUX_VER}_qat
    cp ${linux_kernel_path}/vmlinux $OUTPUT_DIR/vmlinux-${LINUX_VER}_qat
    cp  ${katarepopath}/tools/osbuilder/image-builder/kata-containers.img $OUTPUT_DIR
    mkdir -p ${OUTPUT_DIR}/configs || true
    # Change extension from .conf.vm to just .conf and change the SSL section to 
    # SHIM so it works with Kata containers 
    for f in $QAT_SRC/quickassist/utilities/adf_ctl/conf_files/*.conf.vm; do
        output_conf_file=$(basename -- "$f" .conf.vm).conf
        cp -- "$f" "${OUTPUT_DIR}/configs/${output_conf_file}"
        sed -i 's/\[SSL\]/\[SHIM\]/g' ${OUTPUT_DIR}/configs/${output_conf_file}
    done
}

help() {
cat << EOF
Usage: $0 [-h] [options]
   Description:
        This script builds kernel and rootfs artifacts for Kata Containers,
        configured and built to support QAT hardware.
   Options:
        -d,         Enable debug mode
        -h,         Show this help
EOF
}

main()
{
    local check_in_container=${OUTPUT_DIR:-}
	if [ -z "${check_in_container}" ]; then
		echo "Error: 'OUTPUT_DIR' not set" >&2
		echo "$0 should be run using the Dockerfile supplied." >&2
		exit -1
	fi

	local OPTIND
	while getopts "dh" opt;do
		case ${opt} in
		d)
		    set -x
		    ;;
		h)
		    help
		    exit 0;
		    ;;
		?)
		    # parse failure
		    help
		    echo "ERROR: Failed to parse arguments"
		    exit -1
		    ;;
		esac
	done
	shift $((OPTIND-1))

	grab_kata_repos
	configure_kernel
	build_kernel
	build_rootfs
	grab_qat_drivers
	build_qat_drivers
	add_qat_to_rootfs
	copy_outputs
}

main "$@"
