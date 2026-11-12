# Nikkita Shell

A complete Hyprland desktop for Arch Linux, kept in one repository: panels, app search,
notifications, lock screen and a Settings window, all drawn by [Quickshell](https://quickshell.org).

## Requirements

A fresh Arch Linux from `archinstall` with:

- profile **Minimal** (no desktop: this repo is the desktop);
- **PipeWire** audio and **NetworkManager**;
- your user in the `wheel` group (sudo);
- `git`.

## Install

Clone the repo **to this exact path** (the configs refer to it) and run the installer as your
user, not as root:

```bash
git clone https://github.com/jzuletadev/nikkita-shell.git ~/nikkita-shell
cd ~/nikkita-shell
./install.sh
```

It lists what it will install and the GPUs it found, then asks before starting. It asks for your
sudo password when it needs it. When it ends, reboot and log in.

### Options

`./install.sh` alone installs the desktop. Add any of these, in any combination:

| Option | Adds |
|--------|------|
| `--apps` | The apps in `packages/apps.txt` (Docker, Node, Steam…), and enables `[multilib]` for Steam. |
| `--aur` | The apps in `packages/aur.txt` (Brave, VS Code…), building `paru` first if it is missing. |
| `--gpu-drivers` | The driver for an NVIDIA GPU, chosen by model, plus the setup for laptops with two GPUs. Intel and AMD need nothing. |
| `--all` | `--apps`, `--aur` and `--gpu-drivers`. |
| `--link` | Links the configs to the repo instead of copying them, so edits apply live. Use it for development. |
| `--dry-run` | Prints every step and changes nothing. |
| `-y` | Doesn't ask before starting. |

```bash
./install.sh --all --dry-run    # see what a full install would do
./install.sh --all              # the desktop and every extra
```

### Update, or add a part later

Running the installer again is safe: it adds what is missing, and offers (default: no) to
remove what earlier versions installed and this one replaced (`packages/removed.txt`).

```bash
cd ~/nikkita-shell && git pull
./install.sh            # with the same options as the first time
./install.sh --aur      # adds one part to an installed desktop
```

## First steps

| Keys | Opens |
|------|-------|
| `SUPER` (tap) | App search |
| `SUPER + /` | Settings: Wi-Fi, Bluetooth, sound, theme, wallpaper, every keyboard shortcut… |
| `ALT + TAB` | Switch windows: the workspace rail grows to list them, the most recent first (hold ALT, TAB for the next) |
| `SUPER + S` | Screenshot of the monitor; `+ SHIFT` a region, `+ CTRL` the window, `+ ALT` to annotate |
| `SUPER + R` | Record the monitor; `+ SHIFT` a region, `+ ALT` with its sound. Again to stop |
| `SUPER + N` | Do not disturb on/off (notifications wait in the top-right corner) |
| `SUPER + SHIFT + C` | Pick a color from the screen (copied) |

The panels open when the pointer touches a screen edge or corner.

In app search, a sum shows its result (`2*(3+4)^2`, Enter copies it) and `:` searches emoji (`:smile`).
Settings → Display has night light, the monitor layout (drag them, then apply) and the main display: SUPER + 1
is on it and the session starts there, the others get workspaces 2, 3…. An amber mark at the
bottom shows while an app uses your microphone, camera or screen; the tray says which. The Power corner
counts package updates and opens a terminal to install them. The battery warns at 20 % and 5 %.

Settings → Keyboard, Shortcuts and Mouse & touchpad change layouts, key repeat, every shortcut (click it, press
the new keys) and your own (a command for a key), pointer speed, scrolling, tapping and each touchpad gesture.
A ↶ beside a setting puts its default back. On laptops whose battery or keyboard has them, Settings also offers a
charge limit (Power) and the keyboard light (Keyboard).

Touchpad gestures, by default (Settings → Mouse & touchpad changes any of them):

| Fingers | Left / right | Up | Down | Pinch out (apart) / in (together) |
|---------|--------------|----|------|-----------------------------------|
| 3 | Previous / next workspace | Bring the hidden windows back | Hide every window, on every monitor | Float the window / tile it |
| 4 | Focus the window on the left / right | Volume, following your fingers (up louder, down quieter) | ← | Show all panels / lock the screen |

Safety: a firewall lets nothing in except what you allow (Settings → Network; SSH stays allowed if sshd runs),
and on a btrfs root a snapshot is kept before and after every update (Settings → About). If the panels ever
crash, systemd brings them back.

## If something goes wrong

- **The panels are gone.** `qs log` shows why. Start them again with
  `systemctl --user restart nikkita-shell` (or, on an install from before the service, `qs kill; hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`).
- **The login screen doesn't show up.** Press `Ctrl+Alt+F2`, log in and run
  `uwsm start hyprland.desktop`: your desktop starts there. Then
  `sudo ~/nikkita-shell/scripts/install-greeter.sh` installs the login screen again.
- **Stuck on the lock screen.** Press `Ctrl+Alt+F3` and log in. Run
  `pkill -x qs; hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'`, go back with
  `Ctrl+Alt+F1` and unlock in hyprlock.
- **NVIDIA:** which driver you get, laptops with two GPUs, and games are covered in
  [`system/nvidia/README.md`](system/nvidia/README.md).
