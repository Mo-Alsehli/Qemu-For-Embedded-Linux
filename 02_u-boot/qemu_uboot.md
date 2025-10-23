# Running U-Boot on QEMU

---

## **Overview**

This guide explains how to run **U-Boot** under **QEMU**, both using a **generic virtual board** and an **emulated Raspberry Pi 3B** setup. It walks through the installation, configuration, and execution steps, clarifying when each approach should be used and why.

---

## **1. Install QEMU System**

To simulate a full ARM platform with U-Boot, install the QEMU system package.

```bash
sudo apt install qemu-system-arm
```

---

## **2. Clone and Configure U-Boot**

### **Step 1 — Get the Source**

```bash
git clone https://source.denx.de/u-boot/u-boot.git
cd u-boot
```

### **Step 2 — Set Cross-Compilation and Architecture**

```bash
export ARCH=arm64
export CROSS_COMPILE=/path/to/aarch64-linux-gnu-
```

### **Step 3 — Load Raspberry Pi 3 Default Config**

```bash
make rpi_3_defconfig
```

### **Step 4 — Optimize for QEMU**

Open the configuration menu:

```bash
make menuconfig
```

Then adjust the following:

| Feature                          | Action           | Purpose                                       |
| -------------------------------- | ---------------- | --------------------------------------------- |
| `CONFIG_ENV_IS_IN_FLASH`         | **Unset**        | Avoid flash-specific behavior under emulation |
| `CONFIG_ENV_IS_IN_FAT`           | **Set**          | Store environment on FAT partition            |
| `CONFIG_ENV_FAT_INTERFACE`       | **Set to `mmc`** | Define interface type                         |
| `CONFIG_ENV_FAT_DEVICE_AND_PART` | **Set to `0:1`** | Target device:partition                       |
| `CONFIG_CMD_EDITENV`             | **Enable**       | Allow `editenv` command                       |
| `CONFIG_CMD_BOOTD`               | **Enable**       | Allow `bootd` command                         |

These adjustments make U-Boot environment handling QEMU-friendly.

---

## **3. Attempting to Run Raspberry Pi 3B U-Boot**

A naive attempt would be:

```bash
qemu-system-aarch64 -M raspi3b -m 1G -nographic -kernel u-boot.bin
```

However, this **usually fails** because:

* Raspberry Pi hardware relies on its **GPU firmware** (`bootcode.bin`, `start.elf`) to initialize memory.
* QEMU does **not** emulate the Pi’s GPU boot sequence.

Hence, the board never reaches U-Boot unless those files are included on a simulated SD card.

---

## **4. Option 1 — Run Generic ARM U-Boot on QEMU (Recommended for Testing)**

This approach skips Raspberry Pi-specific firmware and uses a **generic “virt” machine** that works directly in QEMU.

```bash
make CROSS_COMPILE=aarch64-linux-gnu- qemu_arm64_defconfig
make CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)

qemu-system-aarch64 \
  -M virt \
  -cpu cortex-a53 \
  -m 1G \
  -nographic \
  -bios u-boot.bin
```

✅ **Result:**
Boots immediately into the U-Boot shell (no GPU or SD card needed).
Ideal for debugging, command testing, and initial environment exploration.

---

## **5. Option 2 — Emulate the Real Raspberry Pi 3 Boot Chain**

If your goal is to **fully reproduce the RPi boot sequence**, you must include firmware files and an SD card image.

### **Step 1 — Gather Required Files**

```
bootcode.bin
start.elf
fixup.dat
config.txt
u-boot.bin
```

### **Step 2 — Create a FAT32 SD Image**

```bash
mkdir boot && cp *.bin *.dat *.elf config.txt boot/
dd if=/dev/zero of=sd.img bs=1M count=64
mkfs.vfat sd.img
mcopy -i sd.img -s boot/* ::
```

### **Step 3 — Configure Boot Parameters**

`config.txt`

```
enable_uart=1
kernel=u-boot.bin
```

### **Step 4 — Run with Raspberry Pi 3B Machine**

```bash
qemu-system-aarch64 \
  -M raspi3b \
  -m 1G \
  -serial null -serial mon:stdio \
  -drive file=sd.img,if=sd,format=raw
```

✅ **Result:**
QEMU loads `bootcode.bin`, executes the GPU firmware chain, and eventually transfers control to `u-boot.bin`.
This is the **only reliable method** to test the actual `rpi_3_defconfig` boot flow.

---

## **Summary**

| Mode                    | Machine   | Firmware Needed                                          | Use Case                      |
| ----------------------- | --------- | -------------------------------------------------------- | ----------------------------- |
| **Generic Virt Board**  | `virt`    | ❌ None                                                   | Fast, flexible U-Boot testing |
| **Real Pi 3 Emulation** | `raspi3b` | ✅ `bootcode.bin`, `start.elf`, `fixup.dat`, `config.txt` | Full boot chain simulation    |

---

## **References**

* [KernelConfig.io — Linux Configurations](https://www.kernelconfig.io)
* [U-Boot Official Repository](https://source.denx.de/u-boot/u-boot)
* [QEMU System Emulation Documentation](https://www.qemu.org/docs/master/system/)
