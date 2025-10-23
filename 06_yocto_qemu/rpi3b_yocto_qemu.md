# How to Emulate a Yocto-Generated Image on QEMU

This guide explains, in **solid, step-by-step form**, how to emulate a Yocto-generated `.wic` image using **QEMU** — particularly for Raspberry Pi targets such as the **raspi3b** machine. It also explains how to prepare and attach a **virtual SD card**.

---

## 🧩 1. Prepare the Yocto Image

Yocto generates `.wic` or `.rootfs.wic` images that contain both **boot** and **root** partitions.
We’ll first make the image accessible on the host system so we can extract the kernel and DTB files.

### Create a Loop Device for the Image

```bash
sudo losetup --show --partscan -f core-image-custom.wic
```

* `--partscan`: automatically creates partition mappings like `/dev/loop0p1`, `/dev/loop0p2`.
* `--show`: prints the loop device name, e.g., `/dev/loop0`.

### Mount the Partitions

```bash
sudo mkdir -p yocto_mount/boot yocto_mount/rootfs
sudo mount /dev/loopXp1 yocto_mount/boot
sudo mount /dev/loopXp2 yocto_mount/rootfs
```

Replace `loopX` with the loop number returned by `losetup`.

This allows you to access:

* **Boot files** → kernel, DTB, overlays.
* **Root filesystem** → libraries, binaries, init scripts, etc.

---

## 🧬 2. Extract Required Files

From the mounted image, copy these to your working directory:

* **Device Tree Blob (DTB)** → describes the hardware layout.
* **Kernel Image** → the bootable kernel used by QEMU.

Example:

```bash
cp yocto_mount/boot/bcm2710-rpi-3-b.dtb .
cp yocto_mount/boot/kernel8.img .
```

---

## 🚀 3. Run QEMU

Execute the QEMU system emulator with the extracted files:

```bash
sudo qemu-system-aarch64 \
    -M raspi3b \
    -cpu cortex-a7 \
    -m 1G \
    -smp 4 \
    -dtb ./yocto_mount/boot/bcm2710-rpi-3-b.dtb \
    -kernel ./yocto_mount/boot/kernel8.img \
    -drive file=core-image-custom.wic,format=raw,if=sd \
    -append "console=ttyAMA0,115200 root=/dev/mmcblk0p2 rootwait rw" \
    -nographic
```

### Explanation:

* `-M raspi3b` → emulates a Raspberry Pi 3B machine.
* `-cpu cortex-a7` → defines the CPU model used.
* `-drive file=core-image-custom.wic,format=raw,if=sd` → attaches the `.wic` as an SD card.
* `-append` → passes boot arguments to the kernel:

  * `console=ttyAMA0,115200` → use serial console for output.
  * `root=/dev/mmcblk0p2` → tells the kernel where the root filesystem is located.
  * `rootwait rw` → wait for the device and mount it read-write.
* `-nographic` → disables graphical display and shows output in the terminal.

---

## ⚠️ 4. Handling Image Size Errors

If QEMU fails with a **“SD size not a power of 2”** error, it means your `.wic` image size isn’t aligned to 2ⁿ (128M, 256M, 512M, etc.).

You can resize it safely using:

```bash
qemu-img resize core-image-custom.wic 512M
```

Pick the next power-of-two size greater than your current image size.
⚠️ **Caution:** resizing is generally for QEMU testing only.
If you plan to flash the image to hardware later, keep the original size intact.

---

## 💾 5. Creating a Virtual SD Card Manually

If you want to boot your own rootfs manually or copy custom files, you can create a **virtual SD card** instead of using `.wic` directly.

### Create an Empty SD Image

```bash
qemu-img create sdcard.img 1G
```

### Partition the SD Card

Run a partitioning tool such as:

```bash
sudo cfdisk sdcard.img
```

* Choose the `dos` label.
* Create:

  * `boot` partition → ~100MB, set bootable, FAT32 type.
  * `rootfs` partition → remaining space, Linux type.

### Map the SD Image to Loop Devices

```bash
sudo losetup -f --show --partscan sdcard.img
```

This creates `/dev/loopXp1` and `/dev/loopXp2`.

### Format Partitions

```bash
sudo mkfs.fat /dev/loopXp1
sudo mkfs.ext4 /dev/loopXp2
```

### Mount and Populate

```bash
sudo mkdir -p sd_mount/boot sd_mount/rootfs
sudo mount /dev/loopXp1 sd_mount/boot
sudo mount /dev/loopXp2 sd_mount/rootfs
```

Now you can copy files:

```bash
sudo cp -r yocto_mount/boot/* sd_mount/boot/
sudo cp -r yocto_mount/rootfs/* sd_mount/rootfs/
```

Finally, unmount everything:

```bash
sudo umount sd_mount/boot sd_mount/rootfs
sudo losetup -D
```

---

## 🧠 6. Run QEMU with the Virtual SD Card

```bash
sudo qemu-system-aarch64 \
    -M raspi3b \
    -cpu cortex-a7 \
    -m 1G \
    -smp 4 \
    -dtb ./sd_mount/boot/bcm2710-rpi-3-b.dtb \
    -kernel ./sd_mount/boot/kernel8.img \
    -drive file=sdcard.img,format=raw,if=sd \
    -append "console=ttyAMA0,115200 root=/dev/mmcblk0p2 rootwait rw" \
    -nographic
```

---

## ✅ Final Notes

* Always ensure the kernel and DTB **match the Yocto build** used for the `.wic` image.
* You can use `qemu-system-arm` for 32-bit images or `qemu-system-aarch64` for 64-bit ones.
* For debugging boot issues, add `-serial mon:stdio` or use `-d guest_errors`.
* If the console freezes, verify that `/etc/inittab` and `/dev/ttyAMA0` are properly configured in the rootfs.
