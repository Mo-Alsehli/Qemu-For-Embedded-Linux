# Running Weston GUI on qemux86-64 (Yocto + QEMU)

This document describes how to reliably run **Weston (Wayland compositor)** on **qemux86-64** using **QEMU**, covering **two supported configurations**:

* **Case A** – Standard Yocto image (no custom partitioning)
* **Case B** – Custom OTA-oriented image (A/B rootfs + data partition)

The two cases share the **same QEMU runtime command**, but differ in **Yocto configuration and system assumptions**.

---

# Case A — qemux86-64 **Without Custom Partitioning**

## A.1 When to Use This Case

Use this setup when:

* You only want Weston GUI on QEMU
* You are **not testing OTA**
* You use the **default Yocto disk layout**
* You want the **simplest possible configuration**

This is ideal for:

* GUI bring-up
* Qt/Wayland testing
* Application UI development

---

## A.2 Yocto Configuration (Minimal)

### MACHINE

```conf
MACHINE = "qemux86-64"
```

### Image

Typical images:

* `core-image-weston`
* `core-image-sato`

No `.wks` file is required.

---

## A.3 `/etc/fstab` (No Changes Required)

For this case:

* **Do not modify fstab**
* The stock `base-files` fstab is sufficient
* Yocto auto-mounts root filesystem correctly

⚠️ Do **not** add:

* `/boot`
* `/data`
* `mmcblk` entries

---

## A.4 Kernel Location (Important)

For qemux86-64:

* Kernel is installed in the **root filesystem**
* Path:

  ```
  tmp/deploy/images/qemux86-64/bzImage
  ```

The FAT `/boot` partition (if present) is **not used** for kernel loading.

---

## A.5 QEMU Command (Case A)

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp 4 \
  -m 4096 \
  -kernel tmp/deploy/images/qemux86-64/bzImage \
  -append "root=/dev/vda2 rw rootwait console=ttyS0,115200" \
  -drive file=tmp/deploy/images/qemux86-64/core-image-weston-qemux86-64.wic,format=raw,if=virtio \
  -device virtio-gpu-pci \
  -display gtk,gl=on \
  -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::2121-:21 \
  -device virtio-net-pci,netdev=net0 \
  -serial mon:stdio
```
**NOTE**: you can access it locally the qemu system using `ssh root@localhost -p 2222`.

### Notes

* `root=/dev/vda` works because there is only **one root filesystem**
* No partition awareness is required

---

## A.6 Weston Startup

Weston usually starts automatically.

Manual start (if needed):

```sh
weston --backend=drm-backend.so
```

Fallback:

```sh
weston --backend=fbdev-backend.so
```

---

## A.7 Common Issues (Case A)

| Issue        | Cause           | Fix                        |
| ------------ | --------------- | -------------------------- |
| Slow GUI     | No KVM / no GL  | Use `-enable-kvm`, `gl=on` |
| No Weston    | Package missing | Add `weston` to image      |
| Black screen | GPU mismatch    | Ensure `virtio-gpu-pci`    |

---

# Case B — qemux86-64 **With Custom Partitioning (OTA / A/B)**

## B.1 When to Use This Case

Use this setup when:

* You implement **OTA updates**
* You need **A/B rootfs switching**
* You have a **data partition**
* You want behavior close to real embedded devices

This matches:

* Automotive OTA flows
* Robust update systems
* Your Linux–QNX–Raspberry Pi project

---

## B.2 Custom Partition Layout (`.wks`)

Example OTA-oriented layout:

```wks
part /boot --source bootimg-partition --fstype=vfat --label boot --active --size 256
part /     --source rootfs           --fstype=ext4 --label rootfsA --size 4096
part /     --fstype=ext4             --label rootfsB --size 6144
part /data --fstype=ext4             --label data --size 512
```

---

## B.3 Critical Requirement: Custom `/etc/fstab`

### Why This Is Mandatory

QEMU exposes disks as:

```
/dev/vda*
```

Raspberry Pi uses:

```
/dev/mmcblk*
```

Hardcoding either **will break the other**.

### Correct Solution

* Override `fstab` **via `base-files.bbappend`**
* Use **LABEL-based mounts only**

---

## B.4 `base-files.bbappend` (QEMU Only)

```
meta-yourlayer/
└── recipes-core/
    └── base-files/
        ├── base-files_%.bbappend
        └── files/
            └── fstab-qemu
```

### `base-files_%.bbappend`

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append:qemux86-64 = " file://fstab-qemu"

do_install:append:qemux86-64() {
    install -m 0644 ${WORKDIR}/fstab-qemu ${D}${sysconfdir}/fstab
}
```

---

## B.5 QEMU-Specific fstab (OTA Safe)

```fstab
LABEL=rootfsA   /              ext4   defaults              1  1
LABEL=boot      /boot          vfat   defaults              0  2
LABEL=data      /data          ext4   defaults              0  2

proc            /proc          proc   defaults              0  0
devpts          /dev/pts       devpts mode=0620,ptmxmode=0666,gid=5  0  0
tmpfs           /run           tmpfs  mode=0755,nodev,nosuid,strictatime 0  0
tmpfs           /var/volatile  tmpfs  defaults              0  0
```

⚠️ Never mount `rootfsB` at boot.

---

## B.6 QEMU Command (Case B)

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp 4 \
  -m 4096 \
  -kernel tmp/deploy/images/qemux86-64/bzImage \
  -append "root=/dev/vda2 rw rootwait console=ttyS0,115200" \
  -drive file=tmp/deploy/images/qemux86-64/core-image-weston-qemux86-64.wic,format=raw,if=virtio \
  -device virtio-gpu-pci \
  -display gtk,gl=on \
  -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::2121-:21 \
  -device virtio-net-pci,netdev=net0 \
  -serial mon:stdio
```
**NOTE**: you can access the qemu system using `ssh root@localhost -p 2222`.

### Partition Mapping

| Partition | Device      |
| --------- | ----------- |
| rootfsA   | `/dev/vda2` |
| rootfsB   | `/dev/vda3` |
| data      | `/dev/vda4` |

---

## B.7 Simulating OTA Switch (QEMU)

To simulate booting into the updated system:

```text
root=/dev/vda2  →  root=/dev/vda3
```

No other changes are required.

---

## B.8 Common Issues (Case B)

| Issue                 | Cause                       | Fix                       |
| --------------------- | --------------------------- | ------------------------- |
| Emergency mode        | mmcblk in fstab             | Use LABELs                |
| Boot hangs            | Wrong root                  | Use `/dev/vda2`           |
| `/boot` empty         | Expected                    | Kernel is in rootfs       |
| systemd mount timeout | fstab owned by wrong recipe | Use `base-files.bbappend` |

---

# Final Notes

* **Case A** is best for fast GUI work
* **Case B** is mandatory for OTA systems
* Both use the **same QEMU runtime**
* Differences are entirely in **Yocto configuration**
