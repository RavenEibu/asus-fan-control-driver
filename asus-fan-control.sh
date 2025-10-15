#!/usr/bin/env bash
# asus-fan-control unified installer/uninstaller
# Flags:
#   --install | -i   Install/setup
#   --remove  | -r   Remove/uninstall
#   --help    | -h   Help

set -Eeuo pipefail

usage() {
cat <<'USAGE'
asus-fan-control — installer/uninstaller

Options:
  -i, --install      Run installation/setup
  -r, --remove       Run removal/uninstall
  -h, --help         Show this help
USAGE
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "This action requires root. Re-running with sudo..."
    exec sudo --preserve-env=PATH "$0" "$@"
  fi
}

# === Original installer logic ===
do_install() {
# ---- begin original install script ----
# Installs your ASUS fan toggle script and sets safe write access via udev.
# Usage: sudo ./install-asus-fan-control.sh /path/to/asus-fan-control.sh
# If you omit the path, we’ll install a minimal 0<->2 toggle as a default.


BIN_TARGET="${BIN_TARGET:-/usr/local/bin/asus-fan-control}"
GROUP_NAME="${GROUP_NAME:-fan}"
UDEV_RULE="${UDEV_RULE:-/etc/udev/rules.d/99-asus-fan-perms.rules}"

# Become root if needed
if [[ $EUID -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"
fi

# Determine the non-root user to add to the group
INSTALL_USER="${INSTALL_USER:-${SUDO_USER:-}}"
if [[ -z "${INSTALL_USER}" || "${INSTALL_USER}" == "root" ]]; then
  echo "Could not detect your non-root username. Run with: INSTALL_USER=<you> sudo ./install-asus-fan-control.sh ..." >&2
  exit 1
fi

# 1) Create group and add user
if ! getent group "${GROUP_NAME}" >/dev/null; then
  groupadd -r "${GROUP_NAME}"
fi
usermod -aG "${GROUP_NAME}" "${INSTALL_USER}"

# 2) Install the toggle script
SRC="${1:-}"
if [[ -n "${SRC}" ]]; then
  if [[ ! -r "${SRC}" ]]; then
    echo "Source script not found or unreadable: ${SRC}" >&2
    exit 1
  fi
  install -m 0755 -o root -g root "${SRC}" "${BIN_TARGET}"
else
  # Fallback: tiny 0<->2 toggle (uses the ASUS nb-wmi hwmon path)
  cat >"${BIN_TARGET}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
PWM_MODE_FILE="$(ls /sys/devices/platform/asus-nb-wmi/hwmon/hwmon*/pwm1_enable 2>/dev/null | head -n1 || true)"
if [[ -z "${PWM_MODE_FILE:-}" || ! -e "${PWM_MODE_FILE}" ]]; then
  echo "Error: pwm1_enable not found under /sys/devices/platform/asus-nb-wmi/hwmon/." >&2
  exit 1
fi
cur="$(cat "${PWM_MODE_FILE}")"
case "${cur}" in
  0) new=2 ;;
  2) new=0 ;;
  *) echo "Unsupported value in pwm1_enable: ${cur}" >&2; exit 2 ;;
esac
printf '%s\n' "${new}" > "${PWM_MODE_FILE}"
echo "pwm1_enable: ${cur} -> ${new}"
EOF
  chmod 0755 "${BIN_TARGET}"
fi

# 3) Create udev rule for runtime permissions (survives changing hwmonN)
#    - Makes pwm1_enable and pwm1 group-writable by "${GROUP_NAME}"
install -d -m 0755 /etc/udev/rules.d
cat >"${UDEV_RULE}" <<EOF
# Writable ASUS hwmon fan knobs for group "${GROUP_NAME}"
SUBSYSTEM=="hwmon", KERNEL=="hwmon*", KERNELS=="asus-nb-wmi", ACTION=="add|change", \
  RUN+="/bin/sh -c 'chgrp ${GROUP_NAME} /sys/%p/pwm1_enable 2>/dev/null && chmod g+w /sys/%p/pwm1_enable; \
                    if [ -e /sys/%p/pwm1 ]; then chgrp ${GROUP_NAME} /sys/%p/pwm1 && chmod g+w /sys/%p/pwm1; fi'"
EOF

# 4) Reload + reapply rules now
udevadm control --reload
udevadm trigger --subsystem-match=hwmon || true

echo
echo "✔ Installed: ${BIN_TARGET}"
echo "✔ udev rule: ${UDEV_RULE}"
echo "✔ Group     : ${GROUP_NAME} (added ${INSTALL_USER})"
echo
echo "Tip: to apply group membership immediately in this shell:  newgrp ${GROUP_NAME}"
echo "Otherwise log out/in. Then run:  ${BIN_TARGET}"

# ---- end original install script ----
}

# === Original uninstaller logic ===
do_remove() {
# ---- begin original uninstall script ----
# Removes the ASUS fan toggle install (binary + udev rule) and reverts perms.
# Usage: sudo ./uninstall-asus-fan-toggle.sh [--remove-group]


BIN_TARGET="${BIN_TARGET:-/usr/local/bin/asus-fan-control}"
GROUP_NAME="${GROUP_NAME:-fan}"
UDEV_RULE="${UDEV_RULE:-/etc/udev/rules.d/99-asus-fan-perms.rules}"

REMOVE_GROUP=0
[[ "${1:-}" == "--remove-group" ]] && REMOVE_GROUP=1

# Become root if needed
if [[ $EUID -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"
fi

# 1) Remove binary
if [[ -e "${BIN_TARGET}" ]]; then
  rm -f "${BIN_TARGET}"
  echo "Removed ${BIN_TARGET}"
fi

# 2) Remove udev rule
if [[ -e "${UDEV_RULE}" ]]; then
  rm -f "${UDEV_RULE}"
  echo "Removed ${UDEV_RULE}"
fi

# 3) Reload udev and revert current sysfs file perms (best-effort)
udevadm control --reload
udevadm trigger --subsystem-match=hwmon || true

for f in /sys/devices/platform/asus-nb-wmi/hwmon/hwmon*/pwm1_enable /sys/devices/platform/asus-nb-wmi/hwmon/hwmon*/pwm1; do
  [[ -e "$f" ]] || continue
  chgrp root "$f" 2>/dev/null || true
  chmod g-w "$f" 2>/dev/null || true
done
echo "Reverted runtime sysfs perms (best effort). Defaults will also apply after reboot."

# 4) Optionally remove the group
if [[ ${REMOVE_GROUP} -eq 1 ]]; then
  if getent group "${GROUP_NAME}" >/dev/null; then
    # Will fail if the group still has members
    if groupdel "${GROUP_NAME}"; then
      echo "Removed group ${GROUP_NAME}"
    else
      echo "Could not remove group ${GROUP_NAME} (it may still have members)."
      echo "Remove members first, then run again."
    fi
  fi
fi

echo "✔ Uninstall complete."

# ---- end original uninstall script ----
}

main() {
  local arg="${1:-}"
  case "$arg" in
    -i|--install)
      shift || true
      require_root "$arg" "$@"
      do_install "$@"
      ;;
    -r|--remove|--uninstall)
      shift || true
      require_root "$arg" "$@"
      do_remove "$@"
      ;;
    -h|--help|"")
      usage ;;
    *)
      echo "Unknown option: $arg" >&2
      echo
      usage
      exit 2 ;;
  esac
}

main "$@"
