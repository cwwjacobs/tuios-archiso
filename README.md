# TUIOS Arch ISO

TUIOS is a **vanilla Arch Linux offline installer plus a native Textual operator shell** for Gold Trace Dataworks.

It does not fork Arch, replace the kernel, or place intelligence inside the operating system. Arch remains the deterministic base. TUIOS is the operator surface layered above it.

## Current build

The ISO contains:

- a native Python/Textual shell using the visual grammar of `amazingTUI.zip`;
- an exact offline copy of the original Figma Make React/Vite source;
- a complete local Arch package repository for installation without internet;
- `linux-lts`, firmware for the GTX 1070 generation, NetworkManager, SSH, Git, Python, Node/npm, build tools, tmux, Neovim, and common CLI utilities;
- normal and `nomodeset` safe-video boot entries.

The native shell preserves the important design language from the Figma prototype: near-black surfaces, layered terminal panels, gold identity, cyan live state, violet/pink Gold Trace distinction, dense run tables, runtime health, event streams, and keyboard-first navigation. The Figma app itself is a web prototype; the installed shell is a real terminal application rather than a browser pretending to be one. The original Figma source is preserved at `/usr/local/share/tuios/reference/amazingTUI.zip`.

## Build with GitHub Actions

Open **Actions → Build TUIOS ISO → Run workflow**.

The workflow builds inside a privileged Arch container using the official `archiso` tooling, then uploads:

```text
tuios-archiso/
├── tuios-*.iso
└── SHA256SUMS
```

Archiso is the official Arch tool for custom live and installer images; profiles select packages through `packages.x86_64`, add files through `airootfs`, and build through `mkarchiso`.

## Phone download and verification

After the workflow succeeds, download the `tuios-archiso` artifact from GitHub Actions, extract it in Termux, and verify:

```bash
cd ~/storage/downloads/tuios-archiso
sha256sum -c SHA256SUMS
```

Only flash the ISO with EtchDroid after the checksum reports `OK`.

## Live controls

```text
1–9,0   switch module
I       start offline installer
S       leave TUIOS for a normal shell
R       refresh surface
Q       quit
```

## Installer boundary

The v0 installer is intentionally narrow:

- **UEFI/GPT only**;
- **one whole target disk is erased**;
- no dual boot;
- no preserved partitions;
- no encrypted root yet;
- ext4 root and systemd-boot;
- offline packages come only from the repository embedded in the ISO.

`pacstrap` supports an alternate pacman configuration with `-C`, and Arch documents local repositories as the correct offline installation shape.

## Source layout

```text
.github/workflows/build-iso.yml   GitHub Actions ISO builder
scripts/build.sh                  profile generation, offline repo, ISO build
config/install-packages.x86_64    packages installed onto the target system
reference/amazingTUI.zip.b64      exact original Figma Make source archive
```

## Current validation

The workflow performs:

- Bash syntax validation;
- base64 decode and ZIP integrity validation for the Figma source;
- Python bytecode compilation for the generated Textual app;
- full `mkarchiso` build;
- SHA-256 checksum generation.

A successful ISO build is not yet proof that the installer boots correctly on the ASUS PRIME B550M/GTX 1070 machine. The first hardware boot remains the acceptance test.
