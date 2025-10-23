# 🧩 Comprehensive Guide: Running Linux on QEMU VExpress-A9

---

## 1️⃣ Install prerequisites on host

```bash
sudo apt update
sudo apt install -y build-essential git qemu-system-arm gcc-arm-linux-gnueabi \
                    libncurses-dev bison flex libssl-dev bc u-boot-tools cpio
```

---

## 2️⃣ Get and build the kernel

```bash
git clone https://github.com/torvalds/linux.git
cd linux
# Choose a stable version (example: v6.6)
git checkout v6.6
```

### Configure for Versatile Express A9

```bash
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- vexpress_defconfig
```

### Optional tweaks

Run `make menuconfig` to:

* Enable `CONFIG_DEVTMPFS` and `CONFIG_DEVTMPFS_MOUNT`
* Disable unneeded GPU or sound drivers (for faster boot)

### Build

```bash
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- -j$(nproc) zImage dtbs modules
```

The resulting files:

```
arch/arm/boot/zImage
arch/arm/boot/dts/vexpress-v2p-ca9.dtb
```

---

## 3️⃣ Build a minimal BusyBox root filesystem

```bash
wget https://busybox.net/downloads/busybox-1.36.1.tar.bz2
tar -xf busybox-1.36.1.tar.bz2
cd busybox-1.36.1
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- defconfig
make menuconfig
```

Enable:

```
[*] Build static binary (no shared libs)
```

Then build and install:

```bash
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- -j$(nproc)
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- install
```

---

## 4️⃣ Populate root filesystem tree

```bash
cd _install
mkdir -p dev proc sys tmp etc
```

### Create essential device nodes

```bash
sudo mknod dev/console c 5 1
sudo mknod dev/null c 1 3
sudo mknod dev/tty1 c 4 1
sudo mknod dev/tty2 c 4 2
sudo mknod dev/tty3 c 4 3
sudo mknod dev/tty4 c 4 4
```

### Add init script

`init` at root of filesystem:

```bash
cat > init <<"EOF"
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev || echo "devtmpfs mount failed"
echo "Welcome to BusyBox rootfs on VExpress-A9"
exec /bin/sh
EOF
chmod +x init
```

---

## 5️⃣ Create rootfs image (CPIO or EXT4)

### Option A: CPIO initrd (simplest)

```bash
find . | cpio -H newc -o | gzip > ../rootfs.cpio.gz
```

### Option B: EXT4 root partition

Create a 1 GB SD-card image:

```bash
cd ..
dd if=/dev/zero of=file.img bs=1M count=1024
cfdisk file.img      # create p1(FAT 100M boot) + p2(EXT4 rest)
sudo losetup -f --show --partscan file.img
sudo mkfs.vfat /dev/loopXp1
sudo mkfs.ext4 /dev/loopXp2
sudo mount /dev/loopXp2 /mnt
sudo cp -a _install/* /mnt/
sudo umount /mnt
sudo losetup -d /dev/loopX
```

---

## 6️⃣ Boot with QEMU

### A. Using initrd (CPIO)

```bash
qemu-system-arm \
  -M vexpress-a9 \
  -m 512M \
  -kernel arch/arm/boot/zImage \
  -dtb arch/arm/boot/dts/vexpress-v2p-ca9.dtb \
  -initrd rootfs.cpio.gz \
  -append "console=ttyAMA0 rdinit=/init" \
  -nographic
```

### B. Using SD-card image (EXT4)

```bash
qemu-system-arm \
  -M vexpress-a9 \
  -m 512M \
  -kernel vexpress_tools/zImage \
  -dtb vexpress_tools/vexpress-v2p-ca9.dtb \
  -append "console=ttyAMA0 root=/dev/mmcblk0p2 rw rootwait init=/init" \
  -sd sdcard/file.img \
  -nographic
```

---

## 7️⃣ Interact with system

You should see:

```
Starting kernel ...
Welcome to BusyBox rootfs on VExpress-A9
/ #
```

Common BusyBox commands:

```bash
mount
cat /proc/cpuinfo
ls /dev
```

---

## 8️⃣ Optional : enable login prompt (getty)

Edit `/etc/inittab`:

```bash
::sysinit:/etc/init.d/rcS
::respawn:-/bin/sh
ttyAMA0::respawn:/sbin/getty -L ttyAMA0 115200 vt100
```

And create `/etc/init.d/rcS`:

```bash
#!/bin/sh
mount -a
/bin/hostname QEMU-VEXPRESS
```

(make executable)

---

## 9️⃣ Optional : network

Add to QEMU:

```bash
-net nic -net user,hostfwd=tcp::2222-:22
```

Then inside BusyBox:

```bash
ifconfig eth0 up
udhcpc eth0
```

You can then `ssh` from host:

```bash
ssh -p 2222 root@localhost
```

---

## 🔧 Common troubleshooting

| Symptom                            | Fix                                                       |
| ---------------------------------- | --------------------------------------------------------- |
| `No working init found`            | Missing `/init` or `/dev/console`; rebuild BusyBox static |
| `VFS: Unable to mount rootfs`      | Wrong root partition (`p1` vs `p2`)                       |
| `devtmpfs: error mounting -2`      | Add `/dev` + `mknod console/null`                         |
| `Kernel panic` after BusyBox build | Use static binary (`menuconfig → Build static binary`)    |

---

## ✅ Summary workflow

```bash
# 1. Build kernel
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- vexpress_defconfig && make zImage dtbs -j$(nproc)

# 2. Build static busybox
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- defconfig
make menuconfig (enable static)
make install

# 3. Create init + dev nodes
# 4. Pack rootfs (cpio or sdcard)
# 5. Boot with QEMU
qemu-system-arm -M vexpress-a9 -m 512M -kernel zImage -dtb vexpress-v2p-ca9.dtb \
  -append "console=ttyAMA0 rdinit=/init" -initrd rootfs.cpio.gz -nographic
```
