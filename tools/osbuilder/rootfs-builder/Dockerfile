FROM scratch
ARG lnx_ver=5.15.26-nvidia-gpu

COPY rootfs-ubuntu /

RUN for f in `grep ExecStart.*agetty /usr/lib/systemd/system/*service -l`; do \
        sed -i -E 's/agetty *-o .*--/agetty -a root --/' $f; \
    done

COPY linux*.deb                 /boot/
COPY /NVIDIA-Linux-x86_64-*.run /boot/

RUN cd /boot && mkdir -p /var/log && dpkg -i linux*deb
RUN ls -la /boot && dpkg -l
RUN cd /boot && bash NVIDIA-Linux-x86_64-*.run -a -q \
    --skip-module-unload \
    --skip-depmod --no-x-check \
    --no-kernel-module \
    --no-install-libglvnd \
    --no-libglx-indirect \
    --no-opengl-files \
    --no-systemd \
    --no-check-for-alternate-installs \
    --ui=none 
RUN cd /boot && bash NVIDIA-Linux-x86_64-*.run -x
RUN rm /boot/NVIDIA-Linux-x86_64-*.run
RUN cd /boot && cd NVIDIA-Linux-x86_64-* && cd kernel && CC=gcc-11 make KERNEL_UNAME=$lnx_ver modules
RUN cd /boot && cd NVIDIA-Linux-x86_64-* && cd kernel && CC=gcc-11 make KERNEL_UNAME=$lnx_ver modules_install
RUN depmod -a "${lnx_ver}"

