FROM scratch
ARG lnx_ver=5.15.26-nvidia-gpu
ARG drv_ver=510.85.02
ARG distro=ubuntu
ARG drv_name=NVIDIA-Linux-x86_64-${drv_ver}-no-compat32
COPY rootfs-${distro} /

RUN for f in `grep ExecStart.*agetty /usr/lib/systemd/system/*service -l`; do \
        sed -i -E 's/agetty *-o .*--/agetty -a root --/' $f; \
    done
WORKDIR /boot
COPY linux*.deb ./

ADD https://download.nvidia.com/XFree86/Linux-x86_64/${drv_ver}/${drv_name}.run ${drv_name}.run

ENV IGNORE_CC_MISMATCH=1
RUN mkdir -p /var/log && dpkg -i linux*deb
RUN ls -la . && dpkg -l
RUN cp /boot/System.map-${lnx_ver} /usr/src/linux-headers-${lnx_ver}/System.map
RUN ls -la /usr/src/linux-headers-${lnx_ver}/
RUN bash ${drv_name}.run -a -q \
    --skip-module-unload \
    --skip-depmod --no-x-check \
    --no-kernel-module \
    --no-install-libglvnd \
    --no-libglx-indirect \
    --no-opengl-files \
    --no-systemd \
    --no-check-for-alternate-installs \
    --ui=none 
RUN bash ${drv_name}.run -x
WORKDIR /boot/${drv_name}/kernel
RUN CC=gcc-11 make KERNEL_UNAME=$lnx_ver modules
RUN CC=gcc-11 make KERNEL_UNAME=$lnx_ver modules_install
RUN depmod -F /boot/System.map-${lnx_ver} -a "${lnx_ver}"

