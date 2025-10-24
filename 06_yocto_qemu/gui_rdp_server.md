# 🖥️ Connect Weston RDP Backend with Remmina (Yocto + QEMU)

This guide explains how to enable **Remote Desktop (RDP)** access for a Yocto image running Weston, and connect to it using **Remmina** on your host.

---

## 🧩 1. What is Weston RDP?

Weston, the reference Wayland compositor, can run using different **backends** (e.g., DRM, Wayland, X11, RDP).
When you use the **RDP backend**, Weston acts as an RDP server — letting you connect remotely using any RDP client such as **Remmina**.

This is extremely useful for QEMU or headless setups where no physical display is available.

---

# 🖥️ Access Yocto Weston GUI via RDP (Remmina)

---

## 1. Enable Weston RDP in Yocto build

Add RDP support before building:

```bash
DISTRO_FEATURES:append = " wayland pam systemd"
IMAGE_INSTALL:append = " weston weston-init seatd weston-examples"
PACKAGECONFIG:append:pn-weston = " rdp"
```

Re-build your image:

```bash
bitbake core-image-weston
```

---

## 2. Run the image with QEMU and forward port 3389

```bash
runqemu qemuarm64 slirp nographic \
  qemuparams="-nic user,model=virtio-net-pci,hostfwd=tcp::3389-:3389"
```

This maps
**Host 127.0.0.1:3389 → Guest 0.0.0.0:3389**
so your host can reach the Weston RDP server inside QEMU.

---

## 3. Start Weston RDP inside the guest (Qemu run)

```bash
mkdir -p /etc/freerdp/keys
openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout /etc/freerdp/keys/server.key \
  -out /etc/freerdp/keys/server.crt -subj "/CN=weston"

systemctl stop weston
weston --backend=rdp-backend.so \
  --rdp-tls-cert=/etc/freerdp/keys/server.crt \
  --rdp-tls-key=/etc/freerdp/keys/server.key \
  --no-clients-resize &
```

Check it’s listening:

```bash
netstat -tln | grep 3389
```

---

## 4. Connect from Remmina (on host)

1. Open **Remmina** → New Connection
2. **Protocol:** RDP
3. **Server:** `127.0.0.1:3389`
4. **Username:** `root`
5. **Password:** (blank if `debug-tweaks`)
6. Click **Connect**

You’ll see the **Weston desktop** streamed over RDP — smooth and responsive.

---

### Quick summary

```bash
# Guest(Qemu) side
systemctl stop weston
weston --backend=rdp-backend.so --rdp-tls-cert=/etc/freerdp/keys/server.crt \
       --rdp-tls-key=/etc/freerdp/keys/server.key &

# Host(Ubuntu) side
runqemu qemuarm64 slirp nographic \
  qemuparams="-nic user,model=virtio-net-pci,hostfwd=tcp::3389-:3389"
# Then connect with Remmina → 127.0.0.1:3389
```