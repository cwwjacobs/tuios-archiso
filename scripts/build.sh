#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
PROFILE_DIR="${BUILD_DIR}/profile"
WORK_DIR="${BUILD_DIR}/work"
OUT_DIR="${ROOT_DIR}/out"
REPO_DIR="${PROFILE_DIR}/airootfs/opt/tuios/repo"
DATE_TAG="$(date -u +%Y.%m.%d)"
ISO_LABEL="TUIOS_$(date -u +%Y%m%d)"

log() { printf '\n\033[1;35m[TUIOS]\033[0m %s\n' "$*"; }
fail() { printf '\n\033[1;31m[TUIOS:FAIL]\033[0m %s\n' "$*" >&2; exit 1; }

[[ ${EUID} -eq 0 ]] || fail "mkarchiso must run as root"
command -v mkarchiso >/dev/null || fail "archiso is not installed"
command -v repo-add >/dev/null || fail "repo-add is not installed"

rm -rf "${BUILD_DIR}" "${OUT_DIR}"
mkdir -p "${BUILD_DIR}" "${OUT_DIR}"

log "Copying the official Arch baseline profile"
cp -a /usr/share/archiso/configs/baseline "${PROFILE_DIR}"

# Brand the image without forking Arch itself.
sed -i \
  -e 's/^iso_name=.*/iso_name="tuios"/' \
  -e "s/^iso_label=.*/iso_label=\"${ISO_LABEL}\"/" \
  -e "s/^iso_publisher=.*/iso_publisher=\"Gold Trace Dataworks <ultra_operator@proton.me>\"/" \
  -e 's/^iso_application=.*/iso_application="TUIOS offline Arch installer and operator shell"/' \
  -e "s/^iso_version=.*/iso_version=\"${DATE_TAG}\"/" \
  -e 's/^install_dir=.*/install_dir="tuios"/' \
  "${PROFILE_DIR}/profiledef.sh"

log "Adding live-environment packages"
cat >> "${PROFILE_DIR}/packages.x86_64" <<'LIVE_PACKAGES'
arch-install-scripts
base-devel
bash-completion
curl
dialog
dosfstools
e2fsprogs
fd
fzf
git
gptfdisk
jq
less
man-db
nano
networkmanager
nodejs
npm
openssh
parted
python
python-pip
python-pipx
python-rich
python-textual
ripgrep
rsync
sudo
tmux
unzip
vim
wget
which
zip
LIVE_PACKAGES
sort -u -o "${PROFILE_DIR}/packages.x86_64" "${PROFILE_DIR}/packages.x86_64"

log "Embedding the exact Figma Make source as an offline reference"
mkdir -p "${PROFILE_DIR}/airootfs/usr/local/share/tuios/reference"
base64 -d "${ROOT_DIR}/reference/amazingTUI.zip.b64" \
  > "${PROFILE_DIR}/airootfs/usr/local/share/tuios/reference/amazingTUI.zip"

log "Writing the native Textual operator shell"
mkdir -p "${PROFILE_DIR}/airootfs/usr/local/share/tuios"
cat > "${PROFILE_DIR}/airootfs/usr/local/share/tuios/app.py" <<'PY_APP'
from __future__ import annotations

import sys
from dataclasses import dataclass
from datetime import datetime

from rich.text import Text
from textual import on
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical
from textual.widgets import Footer, OptionList, Static
from textual.widgets.option_list import Option


@dataclass(frozen=True)
class Stage:
    label: str
    title: str
    note: str
    action: str


NAV = ["Overview", "Explore", "Mine", "Refine", "Mint", "Hallmark", "Vault", "Inventory", "System", "Viewer"]
STAGES: dict[str, Stage] = {
    "Overview": Stage("PRODUCTION CHAIN", "Trace products, governed end to end", "Explore → Mine → Refine → Mint → Hallmark → Vault", "OPEN PIPELINE"),
    "Explore": Stage("EXPLORATION", "Domain claims and mine plans", "Validate claims; compile only approved Mine packs.", "VALIDATE CLAIM"),
    "Mine": Stage("MINE / EVIDENCE", "Capture immutable execution evidence", "Mine records execution. It does not grade or curate.", "RUN SCENARIO"),
    "Refine": Stage("REFINERY", "Deterministic verification and casting", "Normalize, redact, quarantine, and cast provenance-backed ingots.", "CAST INGOT"),
    "Mint": Stage("MINT / INTELLIGENCE", "Curate products with matching eval packs", "Rubric, dataset, eval pack, and curation ledger.", "CURATE LOT"),
    "Hallmark": Stage("HALLMARK / QA", "Independent product assay", "PASS, FAIL, or HOLD. No silent repair.", "VERIFY LOT"),
    "Vault": Stage("VAULT / ADMISSION", "Append-only inventory admission", "Only complete lots with matching PASS reports are admitted.", "ADMIT LOT"),
    "Inventory": Stage("INVENTORY", "Vault readiness and product lots", "Local sale-eligible inventory; publishing stays manual.", "INSPECT LOT"),
    "System": Stage("SYSTEM", "Runtime and dependency control", "Observe services, storage, contracts, and host state.", "REFRESH HEALTH"),
    "Viewer": Stage("OUTPUT VIEWER", "Inspect reserved output", "Non-mutating JSON, diff, trace, and raw-output views.", "ATTACH PARSER"),
}

RUNS = [
    ("run_8d3e", "tool-misuse/checkout", "llama-8b", "tool trace", 78, "RUNNING"),
    ("run_a170", "policy/refusal-chain", "api-worker", "judge pass", 61, "JUDGING"),
    ("run_1c29", "retrieval/citation", "llama-8b", "receipt seal", 92, "SEALING"),
    ("run_ff81", "agent/unsafe-action", "api-worker", "invariant", 39, "BLOCKED"),
]

EVENTS = [
    ("INFO", "run_8d3e tool response captured"),
    ("WARN", "judge disagreement · 0.41 spread"),
    ("SEAL", "bundle ev_391a committed to evidence store"),
    ("FAIL", "run_ff81 blocked by safety invariant"),
    ("PASS", "candidate row ds_06f2 extracted"),
]


class TuiOS(App[int]):
    TITLE = "TUIOS // GOLD TRACE"
    SUB_TITLE = "native operator shell"

    CSS = """
    Screen { background: #050509; color: #d8d7e4; }
    #topbar { height: 3; background: #09090f; border-bottom: heavy #59506f; padding: 0 1; }
    #brand { width: 1fr; color: #ded6ad; text-style: bold; content-align: left middle; }
    #meta { width: auto; color: #8e8b9c; content-align: right middle; }
    #shell { height: 1fr; }
    #rail { width: 22; min-width: 18; background: #08080d; border-right: heavy #242231; padding: 1 0; }
    #rail > .option-list--option-highlighted { background: #28213a; color: #f4efff; text-style: bold; }
    #workspace { width: 1fr; padding: 1 1 0 1; }
    #hero { height: 6; border: heavy #5c5278; background: #0a0910; padding: 0 1; }
    #metrics { height: 7; margin-top: 1; }
    .metric { width: 1fr; margin-right: 1; border: tall #343044; background: #09090f; padding: 0 1; }
    .metric:last-child { margin-right: 0; }
    #mainrow { height: 1fr; margin-top: 1; }
    #runs { width: 2fr; border: heavy #3f3852; background: #08080d; padding: 0 1; margin-right: 1; }
    #health { width: 1fr; border: heavy #3b4852; background: #08080d; padding: 0 1; }
    #events { height: 8; border: heavy #4b3a51; background: #08080d; padding: 0 1; margin-top: 1; }
    .gold { color: #ded6ad; }
    .cyan { color: #5ee1d8; }
    .purple { color: #a693ea; }
    .pink { color: #ec75d1; }
    .red { color: #ff6b78; }
    .muted { color: #777484; }
    Footer { background: #09090f; color: #a6a2b5; }
    """

    BINDINGS = [
        Binding("1", "module(0)", "Overview", show=False),
        Binding("2", "module(1)", "Explore", show=False),
        Binding("3", "module(2)", "Mine", show=False),
        Binding("4", "module(3)", "Refine", show=False),
        Binding("5", "module(4)", "Mint", show=False),
        Binding("6", "module(5)", "Hallmark", show=False),
        Binding("7", "module(6)", "Vault", show=False),
        Binding("8", "module(7)", "Inventory", show=False),
        Binding("9", "module(8)", "System", show=False),
        Binding("0", "module(9)", "Viewer", show=False),
        Binding("i", "install", "Install"),
        Binding("s", "shell", "Shell"),
        Binding("r", "refresh", "Refresh"),
        Binding("q", "quit", "Quit"),
    ]

    active_module = "Overview"

    def compose(self) -> ComposeResult:
        with Horizontal(id="topbar"):
            yield Static("✦  TUIOS // GOLD TRACE", id="brand")
            yield Static(id="meta")
        with Horizontal(id="shell"):
            yield OptionList(*(Option(f"{i if i < 10 else 0}  {name}", id=name) for i, name in enumerate(NAV, 1)), id="rail")
            with Vertical(id="workspace"):
                yield Static(id="hero")
                with Horizontal(id="metrics"):
                    yield Static(id="m1", classes="metric")
                    yield Static(id="m2", classes="metric")
                    yield Static(id="m3", classes="metric")
                    yield Static(id="m4", classes="metric")
                with Horizontal(id="mainrow"):
                    yield Static(id="runs")
                    yield Static(id="health")
                yield Static(id="events")
        yield Footer()

    def on_mount(self) -> None:
        self.query_one("#rail", OptionList).highlighted = 0
        self._render()
        self.set_interval(1.0, self._tick)

    def _tick(self) -> None:
        self.query_one("#meta", Static).update(
            Text.from_markup(
                f"[dim]env:[/] [bold cyan]LIVE ISO[/]   [dim]runtime:[/] [bold green]CONNECTED[/]   {datetime.now().strftime('%H:%M:%S')}"
            )
        )

    @on(OptionList.OptionSelected, "#rail")
    def option_selected(self, event: OptionList.OptionSelected) -> None:
        if event.option_id:
            self.active_module = str(event.option_id)
            self._render()

    def action_module(self, index: int) -> None:
        index = max(0, min(index, len(NAV) - 1))
        self.active_module = NAV[index]
        self.query_one("#rail", OptionList).highlighted = index
        self._render()

    def action_install(self) -> None:
        self.exit(42)

    def action_shell(self) -> None:
        self.exit(43)

    def action_refresh(self) -> None:
        self.notify("Operator surface refreshed", title="TUIOS")
        self._render()

    def _render(self) -> None:
        stage = STAGES[self.active_module]
        self.query_one("#hero", Static).update(
            Text.from_markup(
                f"[bold purple]{stage.label}[/]\n[bold white]{stage.title}[/]\n[dim]{stage.note}[/]   [bold gold]‹ {stage.action} ›[/]"
            )
        )
        metrics = [
            ("SEALED RUNS", "184", "+12", "cyan"),
            ("CAST INGOTS", "76", "+8", "purple"),
            ("HALLMARK PASS", "61", "98.4%", "gold"),
            ("PUBLISH", "MANUAL", "locked", "pink"),
        ]
        for widget_id, (label, value, delta, color) in zip(("#m1", "#m2", "#m3", "#m4"), metrics, strict=True):
            self.query_one(widget_id, Static).update(Text.from_markup(f"[dim]{label}[/]\n[bold {color}]{value}[/]\n[dim]↗ {delta}[/]"))

        run_lines = ["[bold]┌─ ACTIVE RUNS ─────────────────────────────────────────────────────[/]"]
        for run_id, scenario, model, phase, progress, state in RUNS:
            bar = "█" * (progress // 10) + "░" * (10 - progress // 10)
            state_color = "red" if state == "BLOCKED" else "cyan" if state == "RUNNING" else "purple"
            run_lines.append(
                f"[bold]{run_id}[/]  {scenario:<28} [dim]{model:<12}[/] {phase:<12} [{state_color}]{bar} {progress:>3}%  {state}[/]"
            )
        run_lines.append("\n[dim]Prototype data only. API and Mine adapters are deliberately disconnected.[/]")
        self.query_one("#runs", Static).update(Text.from_markup("\n".join(run_lines)))

        health = [
            "[bold]┌─ RUNTIME HEALTH ─────────────[/]",
            "scheduler        [green]NOMINAL[/]   7ms",
            "model runtime    [green]NOMINAL[/]  42ms",
            "sandbox          [green]NOMINAL[/]  13ms",
            "judge service    [gold]DEGRADED[/] 186ms",
            "evidence store   [green]SEALED[/]   21ms",
            "dataset extract  [purple]IDLE[/]      0ms",
            "\n[dim]The shell displays state; engines remain separate.[/]",
        ]
        self.query_one("#health", Static).update(Text.from_markup("\n".join(health)))

        event_lines = ["[bold]┌─ EVENT STREAM ───────────────────────────────────────────────────[/]"]
        palette = {"INFO": "cyan", "WARN": "gold", "SEAL": "pink", "FAIL": "red", "PASS": "purple"}
        now = datetime.now().strftime("%H:%M")
        for level, message in EVENTS:
            event_lines.append(f"[dim]{now}[/] [{palette[level]}][{level:<4}][/] {message}")
        self.query_one("#events", Static).update(Text.from_markup("\n".join(event_lines)))


def main() -> int:
    result = TuiOS().run()
    return int(result or 0)


if __name__ == "__main__":
    sys.exit(main())
PY_APP

cat > "${PROFILE_DIR}/airootfs/usr/local/bin/tuios" <<'TUIOS_LAUNCHER'
#!/usr/bin/env bash
set -u
python /usr/local/share/tuios/app.py
status=$?
case "$status" in
  42) exec /usr/local/bin/tuios-install ;;
  43) export TUIOS_SKIP=1; exec bash -l ;;
  *) exit "$status" ;;
esac
TUIOS_LAUNCHER

log "Writing the destructive, whole-disk offline installer"
cat > "${PROFILE_DIR}/airootfs/usr/local/bin/tuios-install" <<'INSTALLER'
#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID} -eq 0 ]] || { echo "Run as root." >&2; exit 1; }
[[ -d /run/archiso ]] || { echo "This installer only runs from the TUIOS live ISO." >&2; exit 1; }

clear
cat <<'BANNER'
╔══════════════════════════════════════════════════════════════════════╗
║                    TUIOS // OFFLINE INSTALLER                       ║
║               VANILLA ARCH BASE · TEXTUAL OPERATOR                 ║
╚══════════════════════════════════════════════════════════════════════╝

This installer erases one entire disk. It does not support dual boot,
manual partition preservation, BIOS/MBR installation, or encrypted root.
BANNER

lsblk -dpno NAME,SIZE,MODEL,TYPE | awk '$NF == "disk" {print}'
echo
read -r -p "Target disk (example /dev/nvme0n1): " DISK
[[ -b "$DISK" ]] || { echo "Not a block device: $DISK" >&2; exit 1; }

if [[ "$DISK" =~ (nvme|mmcblk) ]]; then
  ESP="${DISK}p1"
  ROOT_PART="${DISK}p2"
else
  ESP="${DISK}1"
  ROOT_PART="${DISK}2"
fi

read -r -p "Hostname [tuios]: " HOSTNAME
HOSTNAME=${HOSTNAME:-tuios}
read -r -p "Username [corey]: " USERNAME
USERNAME=${USERNAME:-corey}
read -r -p "Timezone [America/Chicago]: " TIMEZONE
TIMEZONE=${TIMEZONE:-America/Chicago}

echo
printf 'You selected: %s\n' "$DISK"
printf 'Everything on that disk will be destroyed. Type ERASE-%s: ' "$(basename "$DISK")"
read -r CONFIRM
[[ "$CONFIRM" == "ERASE-$(basename "$DISK")" ]] || { echo "Cancelled."; exit 1; }

read -r -s -p "Password for ${USERNAME}: " USER_PASSWORD
echo
read -r -s -p "Repeat password: " USER_PASSWORD_2
echo
[[ -n "$USER_PASSWORD" && "$USER_PASSWORD" == "$USER_PASSWORD_2" ]] || { echo "Passwords did not match." >&2; exit 1; }

cleanup() {
  umount -R /mnt 2>/dev/null || true
}
trap cleanup EXIT

printf '\n[1/8] Partitioning %s\n' "$DISK"
swapoff -a 2>/dev/null || true
umount -R /mnt 2>/dev/null || true
wipefs -af "$DISK"
sgdisk --zap-all "$DISK"
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart ESP fat32 1MiB 1025MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart ROOT ext4 1025MiB 100%
partprobe "$DISK"
udevadm settle

printf '[2/8] Formatting filesystems\n'
mkfs.fat -F 32 -n TUIOS_EFI "$ESP"
mkfs.ext4 -F -L TUIOS_ROOT "$ROOT_PART"
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot /mnt/repo
mount "$ESP" /mnt/boot
mount --bind /opt/tuios/repo /mnt/repo

printf '[3/8] Installing the complete offline package set\n'
mapfile -t PACKAGES < <(grep -Ev '^\s*(#|$)' /opt/tuios/install-packages.x86_64)
pacman-key --init
pacman-key --populate archlinux
pacstrap -K -C /opt/tuios/offline-pacman.conf /mnt "${PACKAGES[@]}"
umount /mnt/repo
rmdir /mnt/repo

printf '[4/8] Installing TUIOS source and shell\n'
install -Dm755 /usr/local/bin/tuios /mnt/usr/local/bin/tuios
install -Dm755 /usr/local/bin/tuios-install /mnt/usr/local/bin/tuios-install
install -Dm644 /usr/local/share/tuios/app.py /mnt/usr/local/share/tuios/app.py
install -Dm644 /usr/local/share/tuios/reference/amazingTUI.zip /mnt/usr/local/share/tuios/reference/amazingTUI.zip
install -Dm644 /opt/tuios/install-packages.x86_64 /mnt/usr/local/share/tuios/install-packages.x86_64

printf '[5/8] Writing base system configuration\n'
genfstab -U /mnt > /mnt/etc/fstab
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /mnt/etc/localtime
arch-chroot /mnt hwclock --systohc
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
printf 'LANG=en_US.UTF-8\n' > /mnt/etc/locale.conf
printf '%s\n' "$HOSTNAME" > /mnt/etc/hostname
cat > /mnt/etc/hosts <<HOSTS
127.0.0.1 localhost
::1       localhost
127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}
HOSTS

printf '[6/8] Creating operator account\n'
arch-chroot /mnt useradd -m -G wheel,audio,video,storage -s /bin/bash "$USERNAME"
printf '%s:%s\n' "$USERNAME" "$USER_PASSWORD" | arch-chroot /mnt chpasswd
unset USER_PASSWORD USER_PASSWORD_2
printf '%%wheel ALL=(ALL:ALL) ALL\n' > /mnt/etc/sudoers.d/10-wheel
chmod 0440 /mnt/etc/sudoers.d/10-wheel
cat > "/mnt/home/${USERNAME}/.bash_profile" <<'PROFILE'
if [[ -z ${TUIOS_SKIP:-} && $(tty 2>/dev/null) == /dev/tty1 ]]; then
  tuios
fi
PROFILE
chown "1000:1000" "/mnt/home/${USERNAME}/.bash_profile"

printf '[7/8] Installing systemd-boot with normal and safe-video entries\n'
arch-chroot /mnt bootctl install
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
CPU_VENDOR=$(awk -F: '/vendor_id/ {gsub(/ /, "", $2); print $2; exit}' /proc/cpuinfo)
MICROCODE=""
if [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then MICROCODE='initrd /amd-ucode.img'; fi
if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then MICROCODE='initrd /intel-ucode.img'; fi
cat > /mnt/boot/loader/loader.conf <<'LOADER'
default tuios.conf
timeout 4
console-mode max
editor no
LOADER
cat > /mnt/boot/loader/entries/tuios.conf <<ENTRY
title   TUIOS / Arch Linux
linux   /vmlinuz-linux-lts
${MICROCODE}
initrd  /initramfs-linux-lts.img
options root=UUID=${ROOT_UUID} rw quiet
ENTRY
cat > /mnt/boot/loader/entries/tuios-safe.conf <<ENTRY
title   TUIOS / Safe video
linux   /vmlinuz-linux-lts
${MICROCODE}
initrd  /initramfs-linux-lts.img
options root=UUID=${ROOT_UUID} rw nomodeset systemd.unit=multi-user.target
ENTRY

printf '[8/8] Enabling required services\n'
arch-chroot /mnt systemctl enable NetworkManager.service
arch-chroot /mnt systemctl enable sshd.service

sync
cleanup
trap - EXIT
cat <<'DONE'

Installation complete.

Remove the USB and reboot:
  reboot

Normal boot opens TUIOS on tty1. Press S inside TUIOS for a normal shell.
The original Figma Make source is preserved at:
  /usr/local/share/tuios/reference/amazingTUI.zip
DONE
INSTALLER

mkdir -p "${PROFILE_DIR}/airootfs/root"
cat > "${PROFILE_DIR}/airootfs/root/.bash_profile" <<'LIVE_PROFILE'
if [[ $(tty 2>/dev/null) == /dev/tty1 ]]; then
  tuios
fi
LIVE_PROFILE

cat > "${PROFILE_DIR}/airootfs/etc/motd" <<'MOTD'
TUIOS // GOLD TRACE
Native Textual operator shell over a vanilla Arch live environment.
[i] offline installer   [s] shell   [q] quit
MOTD

log "Preparing the complete offline package repository"
mkdir -p "${REPO_DIR}" "${PROFILE_DIR}/airootfs/opt/tuios"
install -Dm644 "${ROOT_DIR}/config/install-packages.x86_64" \
  "${PROFILE_DIR}/airootfs/opt/tuios/install-packages.x86_64"
mapfile -t INSTALL_PACKAGES < <(grep -Ev '^\s*(#|$)' "${ROOT_DIR}/config/install-packages.x86_64")

# pacman -Sw resolves and downloads the explicit packages plus dependencies.
pacman -Sy --noconfirm
pacman -Sw --noconfirm --cachedir "${REPO_DIR}" "${INSTALL_PACKAGES[@]}"
shopt -s nullglob
PKG_FILES=("${REPO_DIR}"/*.pkg.tar.zst)
(( ${#PKG_FILES[@]} > 0 )) || fail "No offline packages were downloaded"
repo-add "${REPO_DIR}/tuios.db.tar.zst" "${PKG_FILES[@]}"

cat > "${PROFILE_DIR}/airootfs/opt/tuios/offline-pacman.conf" <<'PACMAN_CONF'
[options]
Architecture = auto
CheckSpace
ParallelDownloads = 5
SigLevel = Required DatabaseOptional
LocalFileSigLevel = Optional

[tuios]
Server = file:///repo
PACMAN_CONF

chmod 0755 \
  "${PROFILE_DIR}/airootfs/usr/local/bin/tuios" \
  "${PROFILE_DIR}/airootfs/usr/local/bin/tuios-install"
chmod 0644 \
  "${PROFILE_DIR}/airootfs/usr/local/share/tuios/app.py" \
  "${PROFILE_DIR}/airootfs/root/.bash_profile"

# baseline's profile permissions need explicit executable modes for overlay scripts.
cat >> "${PROFILE_DIR}/profiledef.sh" <<'PROFILE_PERMS'

file_permissions+=(
  ["/usr/local/bin/tuios"]="0:0:0755"
  ["/usr/local/bin/tuios-install"]="0:0:0755"
  ["/root/.bash_profile"]="0:0:0644"
)
PROFILE_PERMS

log "Validating generated sources"
python -m py_compile "${PROFILE_DIR}/airootfs/usr/local/share/tuios/app.py"
bash -n "${PROFILE_DIR}/airootfs/usr/local/bin/tuios"
bash -n "${PROFILE_DIR}/airootfs/usr/local/bin/tuios-install"

log "Building ISO"
mkarchiso -v -r -w "${WORK_DIR}" -o "${OUT_DIR}" "${PROFILE_DIR}"

cd "${OUT_DIR}"
sha256sum ./*.iso > SHA256SUMS
ls -lh ./*.iso SHA256SUMS
log "Build complete"
