# Running Qt (Wayland) Application on QEMU x86 (Yocto / Weston)

## 1. Overview

This document describes a **known-working setup** to run a **Qt Wayland GUI application** on a **qemux86 Yocto image** using **Weston**.

The configuration is intended for:

* GUI validation
* SOME/IP / CommonAPI integration testing
* OTA client UI testing

---

## 2. QEMU Command (Working Configuration)

Use the following command to start QEMU:

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp 4 \
  -m 4096 \
  -kernel tmp/deploy/images/qemux86-64/bzImage \
  -append "root=/dev/vda2 rw rootwait console=ttyS0,115200 ip=none netconsole=off" \
  -drive file=tmp/deploy/images/qemux86-64/core-image-weston-qemux86-64.wic,format=raw,if=virtio \
  -device virtio-vga-gl \
  -display sdl,gl=on \
  -device qemu-xhci,id=xhci \
  -device usb-tablet,bus=xhci.0 \
  -netdev tap,id=net0,ifname=tap0,script=no,downscript=no \
  -device virtio-net-pci,netdev=net0 \
  -serial mon:stdio
```

### Notes

* `virtio-vga-gl` + `SDL` gives acceptable GUI performance.
* `usb-tablet` is required for correct mouse behavior.
* Avoid moving the QEMU window between monitors (can break absolute pointer mapping).

---

## 3. Network & Environment Setup Script (Guest)

Create a script (for example `env.sh`) inside the QEMU guest:

```sh
#!/bin/sh

# Network configuration
ip link set enp0s4 up
ip addr add 192.168.100.10/24 dev enp0s4
ip route add default via 192.168.100.1

# Multicast (for SOME/IP)
route add -n 224.224.224.245 dev enp0s4

# Qt / Wayland configuration
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export QT_WAYLAND_SHELL_INTEGRATION=wl-shell

# IMPORTANT: force Qt Quick software rendering
export QT_QUICK_BACKEND=software
export LIBGL_ALWAYS_SOFTWARE=1

# Wayland runtime
export XDG_RUNTIME_DIR=/run/user/1000

# Auto-detect Wayland display
if [ -e "$XDG_RUNTIME_DIR/wayland-1" ]; then
    export WAYLAND_DISPLAY=wayland-1
else
    export WAYLAND_DISPLAY=wayland-0
fi

# Middleware configuration
export COMMONAPI_CONFIG=commonapi.ini
export VSOMEIP_CONFIGURATION=vsomeip.json
```

Make it executable:

```bash
chmod +x env.sh
```

Run it **before launching the Qt application**:

```bash
. ./env.sh
```

---

## 4. Important Note About `QT_QUICK_BACKEND=software`

If the Qt application is started **before** `QT_QUICK_BACKEND=software` is set, Qt may:

* Select a different rendering path
* Lead to instability or Wayland protocol errors

### Recommendation

Always ensure:

```bash
echo $QT_QUICK_BACKEND
```

returns:

```text
software
```

**before** starting the Qt application.

If needed, explicitly re-export it in the same shell just before running the app:

```bash
export QT_QUICK_BACKEND=software
./your_qt_app
```

This is expected behavior in QEMU and does **not** indicate a build problem.

---

## 5. Mouse Behavior Note

* Mouse issues can occur if the QEMU window is moved between monitors.
* Keep the QEMU window fixed on a single screen for correct input mapping.
* `usb-tablet` already provides absolute positioning; no further input tuning is required.

---

## 6. Summary (Known-Good State)

✔ QEMU x86 with KVM
✔ Weston (Wayland)
✔ Qt Quick (software backend)
✔ Stable GUI rendering
✔ Correct mouse behavior
✔ SOME/IP / CommonAPI ready

This setup is suitable for **GUI-based validation in QEMU**.
Final performance and behavior should always be validated on **real hardware** (e.g. Raspberry Pi).