# ASUS Fan Control — Linux driver/installer

Control ASUS laptop fans from user space without granting full root access.
This project provides a single Bash script that **installs** or **removes** a fan‑control helper and sets **safe udev permissions** so your user (via a dedicated group) can write to PWM controls.

- **Script:** `asus-fan-control.sh`
- **Flags:** `--install`/`-i`, `--remove`/`-r`, `--help`/`-h`
- **Requires:** Linux, Bash, `sudo`, `udevadm` (and a machine exposing `hwmon` PWM controls)

> By default the installer can copy **your own fan control script** into place. If you don’t pass one, it installs a tiny
> **fallback helper** that toggles `pwm1_enable` (0↔2) so you can validate permissions end‑to‑end.

---

## Quick start

```bash
# 1) Make executable
chmod +x ./asus-fan-control.sh

# 2) See help
./asus-fan-control.sh -h

# 3) Install
#    Option A: install your own helper (recommended)
sudo ./asus-fan-control.sh -i /path/to/your/asus-fan-control

#    Option B: install the minimal fallback toggle
sudo ./asus-fan-control.sh -i

# 4) Uninstall
sudo ./asus-fan-control.sh -r

#    Uninstall and also remove the group (if empty)
sudo ./asus-fan-control.sh -r --remove-group
```

**Target user detection**: uses `$SUDO_USER`. If it can’t detect your non‑root user (e.g., in CI), set it explicitly:

```bash
INSTALL_USER=<your-user> sudo ./asus-fan-control.sh -i
```

---

## What gets installed

- **Helper binary**: `/usr/local/bin/asus-fan-control` (yours or the fallback)
- **Unix group**: `fan` (configurable) and your user is added to it
- **udev rule**: `/etc/udev/rules.d/99-asus-fan-perms.rules` to grant group‑write on PWM nodes
- **udev reload & trigger** so permissions apply immediately

Typical nodes affected (model‑dependent):

```
/sys/class/hwmon/hwmon*/pwm1_enable
/sys/class/hwmon/hwmon*/pwm1
```

> The fallback helper is **only** a sanity check. For real control, install your own script that sets fan curves safely for your model.

---

## Usage

- `-i, --install [SCRIPT]` — Install/setup. Optionally pass a path to your fan helper which will be copied to the target path.
- `-r, --remove [--remove-group]` — Remove/uninstall. Use `--remove-group` to delete the Unix group as well (must be empty).
- `-h, --help` — Show usage.

Once installed, run your helper directly:

```bash
/usr/local/bin/asus-fan-control  # your script's own flags apply
```

---

## Configuration (env vars)

You can override defaults when calling the installer:

- `BIN_TARGET` — install path for the helper (default: `/usr/local/bin/asus-fan-control`)
- `GROUP_NAME` — Unix group to manage permissions (default: `fan`)
- `UDEV_RULE` — udev rules path (default: `/etc/udev/rules.d/99-asus-fan-perms.rules`)
- `INSTALL_USER` — non‑root user to add to the group (auto‑detected from `$SUDO_USER`)

**Examples**

```bash
# Custom group and binary path
GROUP_NAME=asusfan BIN_TARGET=/opt/asus/asus-fan-control sudo ./asus-fan-control.sh -i /path/to/your/script

# Remove using custom paths and also delete the group
GROUP_NAME=asusfan UDEV_RULE=/etc/udev/rules.d/50-asus.rules sudo ./asus-fan-control.sh -r --remove-group
```

---

## How it works (under the hood)

- The installer sets up a **narrow permission model**: write access only to PWM sysfs nodes via a dedicated group.
- A udev rule assigns **group ownership** and **g+w** to the nodes whenever the hwmon device appears or changes:
  ```udev
  # /etc/udev/rules.d/99-asus-fan-perms.rules
  KERNEL=="hwmon*", SUBSYSTEM=="hwmon", ACTION=="add|change",     RUN+="/bin/sh -c 'chgrp $GROUP /sys/%p/pwm1_enable 2>/dev/null && chmod g+w /sys/%p/pwm1_enable;       if [ -e /sys/%p/pwm1 ]; then chgrp $GROUP /sys/%p/pwm1 && chmod g+w /sys/%p/pwm1; fi'"
  ```
- We avoid function names that collide with `/usr/bin/install` to keep calls like `install -m 0755 …` working as intended.

---

## Verify it’s working

```bash
# After install
udevadm control --reload
udevadm trigger --subsystem-match=hwmon

# Permissions should reflect your group
ls -l /sys/class/hwmon/hwmon*/pwm1_enable
ls -l /sys/class/hwmon/hwmon*/pwm1 2>/dev/null || true

# Apply group membership without logout
newgrp fan
```

If you used the fallback helper, a single run should toggle `pwm1_enable` between 0 and 1.

---

## Troubleshooting

- **“Could not detect your non‑root username”**
  Export `INSTALL_USER=<you>` when running `-i`.

- **Permissions didn’t change**
  `udevadm control --reload && udevadm trigger --subsystem-match=hwmon` and re‑plug/boot if needed.

- **Group changes not applied**
  `newgrp fan` or log out/in.

- **Windows line endings**
  `dos2unix asus-fan-control.sh` if you see odd parsing errors.

---

## Security notes

- Only install and run **trusted** helpers. You are granting group‑level write access to specific sysfs nodes.
- Never disable vendor thermal protections in firmware or the kernel. Your helper should respect safe limits.
- The installer itself runs with `sudo`, but the day‑to‑day helper can run unprivileged (via the group).

---

## Contributing

Issues and PRs are welcome — see **[CONTRIBUTE.md](./CONTRIBUTE.md)**.

---

## License

**GPL‑3.0** — see [LICENSE](./LICENSE).
