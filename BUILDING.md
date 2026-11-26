# Building and releasing Gimbot

For people working on Gimbot. To just install it, see the [README](README.md).

## Publishing a new version

Each version arrives as one zip (`Gimbot-<version>-source.zip`). Either:

- **Upload the files:** unzip it and upload the contents of the `Gimbot`
  folder to the repository (with StowLock or the GitHub website), or
- **Upload the zip itself** to the top of the repository. GitHub unpacks it,
  puts the files in place and deletes the zip.

Then the **Publish** job (`.github/workflows/publish.yml`) creates the GitHub
release for the version in `CMakeLists.txt` (a pre-release if it's a beta),
with that version's notes from `CHANGELOG.md`. You don't need to make the
release by hand, and nothing else is needed for people to get it: the
installer and the app's update check also look at the uploaded files, so
even without a release the new version is offered.

GitHub doesn't let tools change files in `.github/workflows` without extra
permission. If an upload of that folder is refused, add or update those files
once through the GitHub website.

### Version numbers

In `CMakeLists.txt`, `project(gimbot VERSION 0.1.1 …)` takes numbers only and
`set(GIMBOT_VERSION "0.1.1")` is the full version. A beta of the *next*
version is `0.1.2-beta.1` (a beta sorts before the release it leads to, so
`0.1.1-beta.1` would be older than `0.1.1`). Add each version to
`CHANGELOG.md` and to `<releases>` in
`data/io.github.Matt_B_007.Gimbot.metainfo.xml`.

The normal update channel ignores betas; the beta channel takes both.

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

## Tests

```sh
ctest --test-dir build --output-on-failure
bash install.sh --selftest
```

They need no camera and include a check that every web address in the source
is one Gimbot expects (`tests/check_urls.sh`).

### AUR

`packaging/aur/` holds PKGBUILDs for `gimbot` and `gimbot-beta`, for
publishing to the AUR. They need the SDK zip placed next to the PKGBUILD.
Update `pkgver` (or `_tag` and `pkgver` for the beta) with each version.

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
tests/        unit tests (no camera needed) and the web address check
.github/      build and test on every push; publish releases
```
