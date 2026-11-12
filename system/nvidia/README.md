# NVIDIA (desktop PCs and hybrid laptops)

`./install.sh --gpu-drivers` picks the driver by the card's generation
(`./scripts/gpu-drivers.sh detect` shows what it found):

| GPU | Driver |
|-----|--------|
| Turing or newer: GTX 16, RTX 20/30/40/50 | `nvidia-open-dkms` |
| Maxwell, Pascal, Volta: GTX 900/10 | `nvidia-580xx-dkms` (AUR, the legacy branch) |
| Kepler or older | none: the installer only points to the Arch wiki |

Intel and AMD GPUs run on Mesa: the desktop install already adds their Vulkan and video decoding.

On a **hybrid laptop** (integrated AMD/Intel + NVIDIA) the desktop draws on the integrated GPU, and
NVIDIA runs what you start with `prime-run`. For games, set Steam's launch options to
`prime-run %command%`. Never add global NVIDIA variables (`GBM_BACKEND`,
`__GLX_VENDOR_LIBRARY_NAME`…): they move every app to the NVIDIA GPU.

After rebooting, `nvidia-smi` should list the GPU; on a hybrid laptop,
`printenv AQ_DRM_DEVICES` should start with the integrated one.

## What gets installed

After picking the driver, `--gpu-drivers` (or `scripts/gpu-drivers.sh setup` alone) puts these in
place. `nvidia.conf` goes on every machine with an NVIDIA GPU; the other two only on a hybrid
laptop:

| file | destination | what for |
|---|---|---|
| `nvidia.conf` | `/etc/modprobe.d/` | module options |
| `99-gpu-symlinks.rules` | `/etc/udev/rules.d/` | stable names (`/dev/dri/amd-igpu`, `intel-igpu`, `nvidia-dgpu`) for `DRI_PRIME` and for launching something on a given GPU |
| `env-hyprland` | `~/.config/uwsm/env-hyprland` | which cards the compositor uses, and in what order |

It also sets `MODULES=([<igpu>] nvidia nvidia_modeset nvidia_uvm nvidia_drm …)` in
`/etc/mkinitcpio.conf` (backed up first, other modules kept) and rebuilds the initramfs.

uwsm's file is **sourced** by `prepare-env.sh` before Hyprland starts, so it is real
shell, not a list of `KEY=value` lines.

## The failure not to repeat

For a while both pieces identified the cards by their **PCI address**
(`KERNELS=="0000:06:00.0"` for the AMD one). That address **changes between boots**.

One day the integrated GPU showed up at `05:00.0`. The rule stopped matching, the
`/dev/dri/amd-igpu` link wasn't created, and `AQ_DRM_DEVICES` was left pointing at a file
that didn't exist. Hyprland opened **only** the NVIDIA card and, since the laptop panel
hangs off the AMD one, that screen **vanished from the desktop**: it stayed frozen on the
last SDDM frame (the "verifying" one) while the session started on the external monitor.

The symptom is misleading: it looks like the login hung, but what happens is that
nobody is drawing on that output. A `hyprctl monitors` that lists only one screen, with
`/sys/class/drm/cardN-eDP-1/status` saying `connected`, is exactly this.

Now `env-hyprland` resolves the cards by their **DRIVER** when the session starts
(`amdgpu`/`i915`/`xe` versus `nvidia`), which is stable, and the udev rule matches by
**vendor** (`0x1002`, `0x10de`) instead of by address. The integrated GPU goes first
because it drives the panel.

## Quick diagnosis

```bash
hyprctl monitors | grep ^Monitor          # are all the screens there?
for c in /sys/class/drm/card*-*/; do echo "$(basename $c) $(cat $c/status)"; done
tr '\0' '\n' < /proc/$(pgrep -x Hyprland)/environ | grep AQ_DRM_DEVICES
ls -l /dev/dri/                            # do the links it points to exist?
```

If `AQ_DRM_DEVICES` names a path that isn't in `/dev/dri/`, that card (and all of its
screens) doesn't exist for the compositor.
