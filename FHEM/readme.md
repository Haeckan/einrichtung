Ja 👍
Ich habe die README jetzt **GitHub-typisch formatiert** (saubere Überschriften, konsistente Codeblöcke, klare Struktur, gut renderbar auf GitHub).

👉 **Direkt als `README.md` für ein GitHub-Repo nutzbar**

---

````md
# FHEM + CUL in an Unprivileged LXC (Proxmox VE 9.1)

This guide explains how to pass through a USB CUL (868/433 MHz) **reliably and reboot-safe**
to a **FHEM installation running inside an unprivileged LXC container** on **Proxmox VE 9.1**.

The setup is fully **cgroup v2 compatible** and avoids privileged containers.

---

## ✨ Features

- ✅ Unprivileged LXC (recommended)
- ✅ Reboot- and reconnect-safe
- ✅ Stable device path (`/dev/cul`)
- ✅ No dependency on `ttyACM0` / `ttyUSB0`
- ✅ Fully compatible with FHEM (CUL / CUL868 / CUL433)

---

## 📋 Requirements

- Proxmox VE **≥ 9.1**
- Unprivileged LXC container
- FHEM installed inside the container
- USB CUL (Atmel LUFA / CDC ACM)
- Root access on the Proxmox host

---

## 🔍 1. Identify the USB CUL (Host)

```bash
lsusb
````

Example output:

```
ID 03eb:204b Atmel Corp. LUFA USB to Serial Adapter Project
```

Check the serial device:

```bash
ls -l /dev/ttyACM*
```

---

## 🧷 2. Create a Persistent udev Rule (Host)

Purpose:

* Stable device name (`/dev/cul`)
* Proper permissions for unprivileged containers

### Create the rule

```bash
nano /etc/udev/rules.d/99-cul.rules
```

```ini
SUBSYSTEM=="tty", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="204b", MODE="0666", SYMLINK+="cul"
```

Reload udev:

```bash
udevadm control --reload
udevadm trigger
```

Verify:

```bash
ls -l /dev/cul
```

Expected:

```
/dev/cul -> ttyACM0
```

---

## 📦 3. Configure the LXC Container

Stop the container:

```bash
pct stop <CTID>
```

Edit the container config:

```
/etc/pve/lxc/<CTID>.conf
```

### cgroup v2 device permissions

```ini
# USB raw devices
lxc.cgroup2.devices.allow: c 189:* rwm

# USB CDC ACM (ttyACM / CUL)
lxc.cgroup2.devices.allow: c 166:* rwm
```

### Bind-mount the device

```ini
lxc.mount.entry: /dev/cul dev/cul none bind,optional,create=file
```

---

## ▶️ 4. Start and Verify

```bash
pct start <CTID>
pct enter <CTID>
```

Inside the container:

```bash
ls -l /dev/cul
```

Expected:

```
crw-rw-rw- 1 root root 166,0 /dev/cul
```

---

## 🏠 5. Configure FHEM

In FHEM:

```text
define CUL CUL /dev/cul@38400 1234
```

Test:

```text
get CUL version
```

---

## ⚠️ Troubleshooting

| Issue                       | Cause                             |
| --------------------------- | --------------------------------- |
| `/dev/cul` missing          | udev rule not loaded              |
| Permission denied           | `MODE="0666"` missing             |
| Device changes after reboot | No symlink used                   |
| CUL not responding          | Wrong baud rate (must be `38400`) |

---

## 🛠 Best Practices

* Always use `/dev/cul` instead of `ttyACM0`
* Disable USB power saving on the host
* Avoid passive USB hubs
* Prefer unprivileged containers for security

---

## ✅ Result

* ✔ Stable USB passthrough
* ✔ Reliable FHEM operation
* ✔ Secure and maintainable Proxmox setup

---

## 📄 License

This documentation is provided as-is and may be freely used and adapted.

```

---

Wenn du willst, kann ich dir noch:
- 🏷️ ein **Repository-Description + Topics**
- 📂 eine sinnvolle **Repo-Struktur**
- 🧪 ein **Test-/Debug-Kapitel**
- 🔁 einen **Reconnect-Watchdog für FHEM**

für GitHub vorbereiten.
```
