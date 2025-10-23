# Creating a Virtual SD Card for QEMU

---

## **Overview**

To emulate Raspberry Pi or other ARM boards in QEMU, you need a **virtual SD card** image.
This SD card acts as persistent storage and can contain the boot partition (FAT) and a root filesystem (Linux).

The following steps explain how to create, partition, format, and mount this virtual SD card properly.

---

## **1. Allocate Space for the Virtual SD Card**

```bash
sudo dd if=/dev/zero of=file.img count=1024 bs=1M status=progress
```

### **Explanation**

| Option            | Meaning                                                 |
| ----------------- | ------------------------------------------------------- |
| `if=/dev/zero`    | Input file filled with zeros (used to initialize space) |
| `of=file.img`     | Output image file representing your virtual SD card     |
| `bs=1M`           | Block size (1 MB per block)                             |
| `count=1024`      | Number of blocks (creates 1 GB total)                   |
| `status=progress` | Shows real-time progress during creation                |

✅ **Result:**
Creates a 1 GB empty image file (`file.img`) that will serve as your virtual SD card.

---

## **2. Partition the Image Using `cfdisk`**

```bash
sudo cfdisk file.img
```

When prompted:

1. Choose **DOS** partition table type.
2. Create **two partitions**:

   * **Partition 1 (boot):**

     * Size: `100 MB`
     * Type: `FAT32`
     * Mark it as **bootable**
   * **Partition 2 (rootfs):**

     * Size: remaining space
     * Type: `Linux`

Write the changes and quit `cfdisk`.

✅ **Result:**
The image now contains a valid partition table with two partitions inside.

---

## **3. Create Loop Devices for the Partitions**

```bash
sudo losetup -f --show --partscan file.img
```

* This command automatically maps the image to a loop device (for example `/dev/loop0`).
* Because of `--partscan`, the partitions will appear as:

  ```
  /dev/loop0p1  → boot
  /dev/loop0p2  → rootfs
  ```

✅ **Result:**
Each partition in the image is now accessible like a real block device.

---

## **4. Format the Partitions**

If this is the first time using the image, format them:

```bash
sudo mkfs.vfat /dev/loop0p1    # Boot partition (FAT32)
sudo mkfs.ext4 /dev/loop0p2    # Root filesystem (EXT4)
```

✅ **Result:**
Partitions are ready to store files.

---

## **5. Mount the Partitions**

Create mount directories and mount them:

```bash
mkdir -p ~/mnt/boot ~/mnt/rootfs

sudo mount /dev/loop0p1 ~/mnt/boot
sudo mount /dev/loop0p2 ~/mnt/rootfs
```

Now:

* `~/mnt/boot` → corresponds to the Pi boot partition (contains firmware and U-Boot)
* `~/mnt/rootfs` → corresponds to the main Linux root filesystem

✅ **Result:**
You can copy or edit files directly in the mounted directories (e.g., add `bootcode.bin`, `start.elf`, `u-boot.bin`, etc.).

---

## **6. Unmount and Detach the Loop Device**

When finished, always clean up:

```bash
sudo umount ~/mnt/boot
sudo umount ~/mnt/rootfs
sudo losetup -d /dev/loop0
```

✅ **Result:**
Releases the image safely from the system, preventing data corruption or device leaks.

---

## **Summary**

| Step | Command                        | Description                              |
| ---- | ------------------------------ | ---------------------------------------- |
| 1    | `dd if=/dev/zero ...`          | Create blank SD card image               |
| 2    | `cfdisk file.img`              | Partition into boot (FAT) + root (Linux) |
| 3    | `losetup -f --show --partscan` | Map image to loop devices                |
| 4    | `mkfs.vfat` / `mkfs.ext4`      | Format partitions                        |
| 5    | `mount`                        | Access partitions as normal directories  |
| 6    | `umount` + `losetup -d`        | Safely release resources                 |

---

### **Next Step**

Once created, you can use this image in QEMU as a virtual SD card:

```bash
qemu-system-aarch64 -M raspi3b -m 1G \
-kernel mmcStorage/boot/u-boot.bin \
-dtb mmcStorage/boot/bcm2710-rpi-3-b.dtb \
-drive file=file.img,if=sd,format=raw \
-nographic
```

- `file.img` is the virtual sdcard with boot and rootfs partitions.
- `mmcStorage/boot` is the mount point for vitual sdcard partition p1.
- `mmcStorage/rootfs` is the mount point for virtual sdcard partition p2.

This will let QEMU boot from the SD card exactly like a real Raspberry Pi.
