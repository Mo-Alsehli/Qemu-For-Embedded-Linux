# 🧩 1️⃣ Understand QEMU in Yocto

Yocto can generate images for **virtual machines (QEMU targets)** just as it does for real boards.
QEMU targets are “machines” defined in layers such as `meta-poky` or `meta-yocto-bsp`:

| Architecture   | Machine name    | QEMU binary used      |
| -------------- | --------------- | --------------------- |
| 32-bit ARM     | `qemuarm`       | `qemu-system-arm`     |
| 64-bit ARM     | `qemuarm64`     | `qemu-system-aarch64` |
| x86            | `qemux86`       | `qemu-system-i386`    |
| x86-64         | `qemux86-64`    | `qemu-system-x86_64`  |
| PowerPC / MIPS | similar entries |                       |

Each has its own kernel config, DTB, and rootfs tuning.

---

# 🧱 2️⃣ Prepare a clean QEMU build directory

It’s best practice to keep your hardware builds separate from your emulation builds.

```bash
cd ~/yocto
source poky/oe-init-build-env build-qemu
```

Now edit the configuration files under `build-qemu/conf`.

---

# ⚙️ 3️⃣ Configure for QEMU in `local.conf`

### Minimal setup

```conf
MACHINE ?= "qemuarm64"

DISTRO_FEATURES:append = " wayland pam"
VIRTUAL-RUNTIME_init_manager = "systemd"

# Add GUI and input support
IMAGE_INSTALL:append = " weston weston-init seatd weston-examples \
                         mesa mesa-driver-virtio"

# Produce .wic images for full-disk emulation
IMAGE_FSTYPES += "wic"

# Optional QoL
EXTRA_IMAGE_FEATURES ?= "debug-tweaks ssh-server-dropbear"
```

You can also test a headless image (CLI only) by omitting Weston.

---

# 🧩 4️⃣ Build an image

```bash
bitbake core-image-sato          # GUI demo
# or your custom image:
bitbake core-image-supra
```

Results go under:

```
build-qemu/tmp/deploy/images/qemuarm64/
```

Files you’ll see:

```
core-image-supra-qemuarm64.wic
core-image-supra-qemuarm64.ext4
bzImage
Image
```

---

# 🧠 5️⃣ Run with `runqemu` (recommended)

Yocto ships `runqemu`, which automatically chooses:

* the right `qemu-system-*` binary,
* kernel + DTB + rootfs,
* CPU count, memory, network, display.

## Basic text-only boot

```bash
runqemu nographic
```

## Graphical Weston (Wayland) GUI

```bash
runqemu qemuarm64 wic sdl
```

or GTK:

```bash
runqemu qemuarm64 wic gtk
```

## Add networking and serial

```bash
runqemu qemuarm64 slirp serial
```

**Tip:** `slirp` gives user-mode NAT networking (no root privileges needed).

---

# 🖥️ 6️⃣ GUI / Weston verification

After boot, you should see Weston start automatically (if your image includes `weston-init` service).
If not, log in and run:

```bash
systemctl start weston@root
# or manually:
weston-launch --backend=drm-backend.so
```

Check logs:

```bash
journalctl -u weston@root -b
cat /var/log/weston.log
```

If you see `/dev/dri/card0` and `virtio-gpu` — you have hardware acceleration inside QEMU ✅

---

# 🧩 7️⃣ Command-line alternatives to `runqemu`

You can launch manually, e.g.:

```bash
qemu-system-aarch64 \
  -machine virt \
  -cpu cortex-a57 \
  -m 1024 \
  -kernel Image \
  -append "console=ttyAMA0 root=/dev/vda rw rootwait" \
  -drive file=core-image-supra-qemuarm64.wic,if=virtio,format=raw \
  -device virtio-gpu-pci \
  -device virtio-keyboard-pci \
  -device virtio-mouse-pci \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  -display sdl -serial mon:stdio
```

### Notes

* `virtio-gpu-pci` → enables DRM/KMS for Weston.
* `virtio-keyboard-pci` and `virtio-mouse-pci` → GUI input devices.
* `-netdev user,hostfwd=tcp::2222-:22` → allows `ssh localhost -p2222`.
* `-display sdl` (or `gtk`) → graphical window.

---

# 🧩 8️⃣ Networking inside QEMU

* **Default:** `slirp` (user networking, NAT)

  * Works out of the box.
  * SSH accessible via host port forward (see above).
* **Advanced:** `tap` or `bridge`

  * For DHCP or real LAN access.
  * Requires root privileges and host configuration.

Check connectivity inside guest:

```bash
ip addr
ping 8.8.8.8
```

---

# 🧩 9️⃣ Persistent disk and mounting on host

Each `.wic` is a full disk image.
Mount it on host:

```bash
sudo losetup --show --partscan -f core-image-supra-qemuarm64.wic
# Example output: /dev/loop7
sudo mount /dev/loop7p2 /mnt
```

When done:

```bash
sudo umount /mnt
sudo losetup -d /dev/loop7
```

You can inspect or modify rootfs before booting again.

---

# 🧩 🔟 Debugging Tips

| Problem                         | Diagnostic                                             | Fix                                                     |                                       |
| ------------------------------- | ------------------------------------------------------ | ------------------------------------------------------- | ------------------------------------- |
| Boots to `#` prompt, no GUI     | `systemctl status weston@root`                         | ensure `seatd`, `mesa-driver-virtio`, and `drm` backend |                                       |
| No `/dev/dri/card0`             | `ls /dev/dri`                                          | add `virtio-gpu-pci`                                    |                                       |
| Weston logs `permission denied` | check `ls -l /dev/dri`; ensure `root` or `video` group |                                                         |                                       |
| No network                      | `ip link`, `dmesg                                      | grep eth`                                               | verify `-netdev` and `virtio-net-pci` |
| Console frozen                  | add `console=ttyAMA0,115200` to bootargs               |                                                         |                                       |

---

# 🧩 11️⃣ Integrate with your custom image (core-image-supra)

Your existing image (for Raspberry Pi) can often run in QEMU if you rebuild it for `MACHINE = "qemuarm64"`.
Keep same recipes, layers, and features — only the **machine** changes.

That lets you test:

* `systemd` services,
* Wi-Fi scripts (with virtual NICs),
* Weston apps (with virtio-gpu),
* psplash,
* users/login scripts.

---

# 🧠 12️⃣ Advanced: emulate hardware-like features

| Feature      | QEMU flag                                   | Note                       |
| ------------ | ------------------------------------------- | -------------------------- |
| Serial debug | `-serial mon:stdio`                         | Show boot logs in terminal |
| GPIO test    | `-device gpio-pci` (x86)                    | limited on ARM             |
| Sound        | `-device intel-hda -device hda-duplex`      | works on virt machines     |
| USB devices  | `-device usb-mouse -device usb-kbd`         | for Weston                 |
| Extra disk   | `-drive file=data.img,if=virtio,format=raw` | test mount points          |

---

# 🧩 13️⃣ Exiting and cleaning up

Inside QEMU:

```bash
poweroff
```

or from host (if stuck):

```bash
Ctrl-A X        # (for nographic session)
```

---

# ✅ 14️⃣ Summary Table

| Task                      | Best Practice                                |
| ------------------------- | -------------------------------------------- |
| Quick GUI boot            | `runqemu qemuarm64 wic sdl`                  |
| Text-only debug           | `runqemu nographic`                          |
| Manual control            | Use `qemu-system-*` directly                 |
| Networking                | `-netdev user,id=net0,hostfwd=tcp::2222-:22` |
| Modify image              | Mount `.wic` via `losetup`                   |
| Real hardware mimic (RPi) | Text-only, no GUI                            |
| Automated tests           | `runqemu` + `expect` scripts                 |

---

# 🧠 15️⃣ Practical Development Flow

1. **Build once for hardware** (e.g. `MACHINE=raspberrypi3`).
2. **Build once for emulation** (`MACHINE=qemuarm64`).
3. Test all systemd services, user scripts, and GUI inside QEMU quickly.
4. Flash the real RPi image only when logic works.

That’s the standard industry workflow:

> *QEMU for integration testing → hardware for validation.*
