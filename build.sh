#!/bin/bash

# optional - deps for Alpine

# apk add build-base linux-headers flex bison bc perl \
#        elfutils-dev openssl-dev ncurses-dev \
#        diffutils findutils coreutils bash

# Kernel
# git clone --depth 1 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
# cd linux && make defconfig && make -j$(nproc) bzImage && cd ..
# -> linux/arch/x86/boot/bzImage

# BusyBox, statically linked
# git clone --depth 1 https://git.busybox.net/busybox
# cd busybox && make defconfig
# sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
# make -j$(nproc) && make install    # -> _install/
# cd ..

# Root filesystem
mkdir -p rootfs && cp -a busybox/_install/* rootfs/
mkdir -p rootfs/proc rootfs/sys rootfs/dev rootfs/etc/init.d

cat > rootfs/etc/init.d/rcS <<'EOF'
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev

hostname foo

echo "Hello from my tiny Linux"

ip link set lo up
ip link set eth0 up
udhcpc -i eth0 -q

# we will not run the shell with PID1 as init, redirect init to busybox instead 
# (e.g. to get controlling terminal and job control in the shell) 
# exec /bin/sh
EOF

chmod +x rootfs/etc/init.d/rcS

# create inittab file
cat > rootfs/etc/inittab <<'EOF'
::sysinit:/etc/init.d/rcS
ttyS0::respawn:/bin/sh
::ctrlaltdel:/sbin/reboot
::shutdown:/bin/umount -a -r
EOF

cd rootfs
ln -sf bin/busybox init
cd ..

# dhpc script - use the one provided by busybox
mkdir -p rootfs/usr/share/udhcpc rootfs/etc
cp busybox/examples/udhcp/simple.script rootfs/usr/share/udhcpc/default.script
chmod +x rootfs/usr/share/udhcpc/default.script

# build ramfs image
(cd rootfs && find . | cpio -o -H newc | gzip) > initramfs.cpio.gz

# Boot it
# qemu-system-x86_64 -kernel linux/arch/x86/boot/bzImage \
#  -initrd initramfs.cpio.gz -append "console=ttyS0" -nographic -nic=user
