<p align="center"><img src="data/icons/gimbot.svg" width="96" alt=""></p>

# Gimbot

An unofficial Linux control app for OBSBOT Tiny 2 cameras, built with C++20 and
Qt 6 for KDE Plasma (it runs on any desktop). **Not affiliated with OBSBOT or
Remo Tech.**

- **Live preview**: click anywhere to point the camera there, scroll to zoom, with a framing grid
- **AI tracking**: person (full body, upper body, close-up), group, hand, desk and whiteboard, plus tracking style
- **Aim dial**: shows where the camera points, live; click or drag to aim. Arrow keys move, Home recenters
- **Presets** with thumbnails, Ctrl+1–3, rename/update/delete
- **Every Tiny 2 setting in the SDK**: tracking area, startup position and mode, sleep timer, microphone during sleep, automatic mic volume, voice commands and language, field of view, exposure/shutter, focus, white balance presets and temperature, brightness/contrast/saturation/sharpness/hue, anti-flicker, HDR, mirror, zoom speed, gestures, reverse pan, guide light, factory reset
- **Profiles**: save whole setups ("Meetings", "Streaming"), switch in one click, import/export
- **Automatic camera detection**: plug in and it connects; unplug and it waits
- **Ctrl+K command search**, light/dark theme, optional Plasma accent color
- **Tray icon** and **system-wide shortcuts** (KDE), start at login, stays out of the way
- **Report a problem**: gathers versions and a log for a pre-filled GitHub issue; nothing is sent automatically
- **Update notices** for normal or beta releases (the package manager does the updating)
- **`gimbotctl`** for scripts and keyboard shortcuts, routed through the running app over D-Bus

Camera firmware updates aren't possible from Linux: OBSBOT's SDK doesn't expose
them. Use OBSBOT Center on Windows or macOS for those.

## The OBSBOT SDK

Gimbot is built on OBSBOT's SDK (`libdev`), which OBSBOT emails to you when you
apply at <https://obsbot.com/sdk>. The SDK is **not included** in this
repository: its zip carries no license terms, so check with OBSBOT before
redistributing it. Gimbot installs `libdev.so` privately under
`/usr/lib/gimbot/`.

## Install on CachyOS / Arch

Two AUR packages, one per update channel:

| Package       | Gets                                    |
|---------------|-----------------------------------------|
| `gimbot`      | normal releases                         |
| `gimbot-beta` | test releases, to try new things early  |

Put `libdev_v2.1.0_8.zip` next to the PKGBUILD (from `packaging/aur/`), then:

```sh
makepkg -si
```

Once they're published to the AUR, `paru -S gimbot` works the same way, with the
SDK zip placed in paru's build folder when it asks.

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
| `GIMBOT_REPO`     | (empty) | `owner/repo` on GitHub, for update checks and bug reports. Empty turns both off |
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
gdbus call --session --dest io.github.gimbot.Gimbot --object-path /Gimbot \
    --method io.github.gimbot.Gimbot1.Run "['zoom', '40']"
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

1. Bump `project(gimbot VERSION …)` in `CMakeLists.txt` and the `<releases>` list in `data/io.github.gimbot.Gimbot.metainfo.xml`.
2. Tag and publish a GitHub release: `v1.2.0` for normal, `v1.3.0-beta.1` (marked *pre-release*) for beta.
3. Update `pkgver` in `packaging/aur/gimbot/PKGBUILD` or `_tag`/`pkgver` in `gimbot-beta`, then push to the AUR.

The app's update check reads the GitHub releases list: the normal channel
ignores pre-releases, and the beta channel includes them.

## Status

Gimbot hasn't been tested on a real Tiny 2 yet. Things to check first on
hardware:

- **Aim direction**: if clicking the preview turns the camera the wrong way, flip it in **Settings › Movement and zoom** (and please report it).
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
