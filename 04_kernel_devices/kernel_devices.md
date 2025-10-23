# 🧠 Running Linux Kernel on QEMU (Raspberry Pi 3B)

This guide explains how to emulate the **Raspberry Pi 3B** board using **QEMU**, load the kernel, and understand why it may fail due to missing system components — and how switching to **vexpress** provides a working setup.

---

## 🧩 1. QEMU Command to Run the Kernel

```bash
qemu-system-aarch64 -M raspi3b -m 1G \
      -kernel tempStorage/boot/u-boot.bin \
      -dtb tempStorage/boot/bcm2710-rpi-3-b.dtb \
      -drive file=file.img,if=sd,format=raw \
      -nographic
```

### Explanation of Each Parameter

| Option                                      | Description                                             |
| ------------------------------------------- | ------------------------------------------------------- |
| `-M raspi3b`                                | Selects the Raspberry Pi 3B machine model.              |
| `-m 1G`                                     | Allocates 1 GB of RAM for the emulated system.          |
| `-kernel tempStorage/boot/u-boot.bin`       | Specifies the kernel (in this case, U-Boot) to boot.    |
| `-dtb tempStorage/boot/bcm2710-rpi-3-b.dtb` | Loads the device tree binary matching the board.        |
| `-drive file=file.img,if=sd,format=raw`     | Mounts the virtual SD card image as a raw block device. |
| `-nographic`                                | Runs QEMU entirely in the terminal (no GUI output).     |

> 🗂️ **Note:**
> The `tempStorage` folder is an external directory containing the `u-boot.bin` and `dtb` files — it is **not** the root filesystem or SD card image itself.

---

## ⚙️ 2. Boot Arguments Configuration

Inside the U-Boot environment, set the boot arguments to define the console and root filesystem:

```bash
setenv bootargs 'console=ttyAMA0,115200 earlycon=pl011,0x3f201000 root=/dev/mmcblk0p2 rootwait rw'
```

### Explanation

| Parameter                   | Purpose                                                            |
| --------------------------- | ------------------------------------------------------------------ |
| `console=ttyAMA0,115200`    | Directs kernel messages to the primary serial console (UART0).     |
| `earlycon=pl011,0x3f201000` | Enables early console debugging before full driver initialization. |
| `root=/dev/mmcblk0p2`       | Mounts the second SD card partition as the root filesystem.        |
| `rootwait`                  | Waits for the root device to become available before mounting.     |
| `rw`                        | Mounts the root filesystem as read-write.                          |

---

## ⚠️ 3. Why the Kernel Panics

Although the kernel starts correctly, it soon triggers a **kernel panic** due to missing critical user-space components:

1. **No `/sbin/init` process**
   The kernel cannot find an initialization process to start the system.

2. **Empty `/dev` directory**
   Without device nodes like `/dev/ttyAMA0` or `/dev/mmcblk0p*`, user space cannot interact with hardware.

3. **No proper root filesystem**
   If `file.img` is not properly partitioned or lacks a rootfs (e.g., BusyBox or Debian), the boot fails after kernel initialization.

This results in an error like:

```
Kernel panic - not syncing: No init found. Try passing init= option to kernel.
```

---

## 🔄 4. Switching to VExpress Platform

Since QEMU support for **Raspberry Pi** boards is incomplete (especially with storage and interrupt mapping), a more stable alternative is to emulate the **Versatile Express** platform:

```bash
qemu-system-arm -M vexpress-a9 -m 512M \
      -kernel vexpress_tools/u-boot \
      -dtb vexpress_tools/vexpress-v2p-ca9.dtb \
      -sd sdcard/file.img \
      -nographic
```

### Why VExpress Works Better

* **Fully supported by QEMU** — no missing peripherals or broken SD interfaces.
* **Easier debugging** — standard UART, NIC, and block device emulation.
* **Compatible with generic ARM kernels** built using `ARCH=arm` and `CROSS_COMPILE=arm-linux-gnueabihf-`.

> ✅ With `vexpress-a9`, you can boot U-Boot → Linux kernel → BusyBox rootfs seamlessly.

---

## 🧾 Summary

| Step | Action                                | Purpose                                   |
| ---- | ------------------------------------- | ----------------------------------------- |
| 1️⃣  | Prepare kernel (`u-boot.bin`) and DTB | Bootloader and hardware description       |
| 2️⃣  | Create virtual SD card image          | Holds partitions and rootfs               |
| 3️⃣  | Run QEMU with `-M raspi3b`            | Attempt Raspberry Pi emulation            |
| 4️⃣  | Observe kernel panic                  | Caused by missing init/rootfs             |
| 5️⃣  | Switch to `vexpress-a9`               | Stable and fully supported emulation path |

---

By transitioning to **VExpress**, you gain a functional and reproducible ARM environment where U-Boot, kernel, and rootfs integration can be tested reliably — an essential foundation before deploying to actual Raspberry Pi hardware.
