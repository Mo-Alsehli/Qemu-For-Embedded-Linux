# 📘 README — QEMU Bridged Networking for OTA & SOME/IP

## 1. Purpose

This document describes how to set up a **Layer-2 bridged network** between:

* **Ubuntu Host (OTA Server)**
* **QEMU Linux (OTA Client / ECU Emulator)**

The setup is designed to fully support:

* ✅ TCP communication
* ✅ UDP multicast
* ✅ SOME/IP Service Discovery
* ✅ Future integration with **QNX VM** and **Raspberry Pi**

This network topology emulates a **real automotive Ethernet segment**.

---

## 2. Target Network Topology

```text
                Linux Bridge (br0)
            192.168.100.0 / 24
        ┌───────────┬────────────┬────────────┐
        │           │            │            │
   Ubuntu Host   QEMU Linux    QNX VM     Raspberry Pi
  192.168.100.1 192.168.100.10  .20           .30
```

* `br0` acts as a **virtual Ethernet switch**
* All nodes are **peers on the same L2 network**
* Multicast traffic stays inside this subnet

---

## 3. Why Bridged Networking (Not User-Mode / NAT)

| Feature                | User-mode (SLIRP) | Bridged (TAP + Bridge) |
| ---------------------- | ----------------- | ---------------------- |
| SSH / FTP              | ✅                 | ✅                      |
| Direct IP reachability | ❌                 | ✅                      |
| UDP multicast          | ❌                 | ✅                      |
| SOME/IP SD             | ❌                 | ✅                      |
| QNX compatibility      | ❌                 | ✅                      |

> **SOME/IP does not work reliably without multicast.**

---

## 4. Host (Ubuntu) Network Setup

### 4.1 Create Linux Bridge

```bash
sudo ip link add br0 type bridge
sudo ip addr add 192.168.100.1/24 dev br0
sudo ip link set br0 up
```

Verify:

```bash
ip addr show br0
```

---

### 4.2 Create TAP Interface for QEMU

```bash
sudo ip tuntap add tap0 mode tap user $USER
sudo ip link set tap0 master br0
sudo ip link set tap0 up
```

Verify:

```bash
bridge link
```

You should see `tap0` attached to `br0`.

---

## 5. QEMU Launch Command (Bridged)

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp 4 \
  -m 4096 \
  -kernel tmp/deploy/images/qemux86-64/bzImage \
  -append "root=/dev/vda2 rw rootwait console=ttyS0,115200 ip=none netconsole=off" \
  -drive file=tmp/deploy/images/qemux86-64/core-image-weston-qemux86-64.wic,format=raw,if=virtio \
  -device virtio-gpu-pci \
  -netdev tap,id=net0,ifname=tap0,script=no,downscript=no \
  -device virtio-net-pci,netdev=net0 \
  -serial mon:stdio
```

### Why `ip=none`?

* Prevents kernel boot from blocking on DHCP
* Network is configured later from userspace

---

## 6. QEMU Guest Network Configuration

Inside the QEMU Linux system:

```bash
ip link set enp0s4 up
ip addr add 192.168.100.10/24 dev enp0s4
ip route add default via 192.168.100.1
```

Verify connectivity:

```bash
ping 192.168.100.1
```

---

## 7. Multicast Configuration (IMPORTANT)

### 7.1 Correct Multicast Routing Rule (Canonical)

Instead of adding a route to a **single multicast IP**, always route the **entire multicast range**:

#### On Ubuntu (Host)

```bash
sudo route add -nv 224.224.224.245 dev br0
```

#### On QEMU (Guest)

```bash 
route add -n 224.224.224.245 dev enp0s4
```

📌 Why this matters:

* SOME/IP SD uses different multicast addresses
* `/4` ensures **all multicast traffic** is routed correctly
* This matches real ECU network behavior

---

### 7.2 Verify Multicast Membership

```bash
ip maddr show br0
ip maddr show enp0s4
```

---

## 8. Firewall & Kernel Settings (Recommended for Development)

### Disable reverse-path filtering:

```bash
sudo sysctl -w net.ipv4.conf.all.rp_filter=0
```

### Enable forwarding (optional, future-proof):

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

### Disable firewall temporarily:

```bash
sudo ufw disable
```

---

## 9. Multicast Verification (Debugging)

On Ubuntu:

```bash
sudo tcpdump -i br0 udp
```

You should see:

* SOME/IP SD packets
* UDP multicast traffic from QEMU

If traffic appears on `wlo1` instead → binding is incorrect.

---

## 10. IP Address Plan (Project Standard)

| Node              | IP               |
| ----------------- | ---------------- |
| Ubuntu OTA Server | `192.168.100.1`  |
| QEMU Linux        | `192.168.100.10` |
| QNX VM            | `192.168.100.20` |
| Raspberry Pi      | `192.168.100.30` |

Netmask:

```text
255.255.255.0
```

---

## 11. Binding Rules for OTA / SOME-IP Applications

* ❌ Do NOT bind to `127.0.0.1`
* ❌ Do NOT bind to Wi-Fi (`192.168.1.x`)
* ✅ Always bind to `192.168.100.x`
* ✅ Explicitly set multicast interface to `br0`

This avoids silent Service Discovery failures.

---

## 12. Ready for Next Stages

With this setup, the system is now ready for:

* ✔ SOME/IP Service Discovery
* ✔ SOME/IP TCP methods
* ✔ UDP events
* ✔ SOME/IP-TP OTA transfer
* ✔ QNX VM integration
* ✔ Raspberry Pi OTA testing

---

## 13. Summary (Key Takeaway)

> **`br0` is your virtual automotive Ethernet cable.**
> Everything OTA- and SOME/IP-related must live on it.

