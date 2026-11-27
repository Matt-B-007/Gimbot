# Building Gimbot

For people working on Gimbot. To just install it, see the [README](README.md).
To publish a version, see [RELEASING.md](RELEASING.md); to help out, see
[CONTRIBUTING.md](CONTRIBUTING.md).

## Checks

```sh
bash scripts/check.sh
```

runs exactly what CI runs, in the same order: shell scripts (`bash -n` +
shellcheck at every severity), workflow files (actionlint), web addresses,
version numbers agreeing, a licence header in every source file, the build
with warnings as errors, unit, controller and UI tests, `gimbot --self-test`,
a Release build and its self-test, the installer's self-test, and loading
every screen.
The tests include theme contrast (every text color 4.5:1 in both themes),
tray icon states and report redaction. Run it before every zip; StowLock runs
it before pushing.

It first checks for every tool it needs and, if any are missing, lists them
with the `sudo pacman -S --needed …` command and exits with code **3**
without checking anything. A failed check exits with **1**, a pass with
**0**. Colors appear only in a terminal, and never when `NO_COLOR` is set.

CI pins shellcheck 0.11.0 and actionlint 1.7.12
(`pip install shellcheck-py==0.11.0.1 actionlint-py==1.7.12.25`). Other
versions on your PC only print a note.

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
does the same from the app. Logs live in `~/.local/state/gimbot/`.

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
scripts/      check.sh: every check, the same locally and in CI
tests/        unit, controller and UI tests (no camera needed), web address check
.github/      checks on every push, publishing releases, issue and PR templates
```
