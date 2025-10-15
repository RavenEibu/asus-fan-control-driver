# Contributing to ASUS Fan Control

Thanks for helping improve the ASUS Fan Control installer. The goals are **simplicity**, **safety**, and **predictability** across distros.

## Ground rules

- Stick to **POSIX/Bash**. Avoid new dependencies (beyond `systemd`/`udev` tools already available on most systems).
- Keep permissions **narrow**: only the required `hwmon` PWM nodes should become group‑writable.
- Clear errors and precondition checks (`set -euo pipefail`, trap cleanup). Document user‑visible changes in **README.md**.
- Do not remove safeguards around group creation, udev reload/trigger, or username detection.

## How to contribute

1. **Open an issue** describing the bug/feature with steps, logs, and your hardware model.
2. **Fork** and create a branch:
   ```bash
   git checkout -b feat/short-topic   # or fix/short-topic, docs/short-topic
   ```
3. **Make focused changes** (avoid mixing refactors with features).
4. **Run quick checks** (below) and update docs as needed.
5. **Open a PR** with a clear description: what/why, testing notes, and caveats.

## Quick checks (manual test plan)

> Use real hardware that exposes PWM controls (usually `/sys/class/hwmon/hwmon*/pwm1[_enable]`).

```bash
# 0) Lint (optional)
shellcheck asus-fan-control.sh || true
```

```bash
# 1) Fresh install
sudo ./asus-fan-control.sh --remove || true
sudo ./asus-fan-control.sh --install /path/to/your/helper || sudo ./asus-fan-control.sh --install
```

```bash
# 2) Validate permissions & group
ls -l /sys/class/hwmon/hwmon*/pwm1_enable
ls -l /sys/class/hwmon/hwmon*/pwm1 2>/dev/null || true
id -nG "$SUDO_USER"
```

```bash
# 3) Functional check (fallback helper toggles pwm1_enable)
/usr/local/bin/asus-fan-control
```

```bash
# 4) Removal
sudo ./asus-fan-control.sh --remove
```

## Shell style

- Header:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  IFS=$'\n\t'
  ```
- Prefer functions, `readonly` constants, and `trap` for cleanup.
- Use `printf` (not plain `echo`) for reliable output.
- Avoid parsing `ls`; inspect files directly.
- Log helpers:
  ```bash
  info(){ printf '[INFO] %s\n' "$*"; }
  warn(){ printf '[WARN] %s\n' "$*" >&2; }
  die(){  printf '[ERR ] %s\n' "$*" >&2; exit 1; }
  ```

## PR checklist

- [ ] Install → verify → remove works on a clean host.
- [ ] No privilege escalation beyond PWM nodes and group ownership.
- [ ] README updated for any behavior or flag changes.
- [ ] Logs are concise and actionable.
- [ ] No collisions with `/usr/bin/install` or other core utilities.

## Ideas / good first issues

- Auto‑detect PWM node names more robustly (with explicit opt‑out).
- `--pwm N` flag for selecting a different PWM channel.
- Safer defaults for varying ASUS models (detect and warn instead of assuming).

## License

By contributing, you agree your changes are licensed under **GPL‑3.0** to match the repository’s license.
