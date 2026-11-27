# Building and releasing Gimbot

For people working on Gimbot. To just install it, see the [README](README.md).

## Publishing a new version

Each version arrives as one zip (`Gimbot-<version>-source.zip`). Either:

- **Upload the files:** unzip it and upload the contents of the `Gimbot`
  folder to the repository (with StowLock or the GitHub website), or
- **Upload the zip itself** to the top of the repository. GitHub unpacks it,
  puts the files in place and deletes the zip.

The **Publish** job (`.github/workflows/publish.yml`) then, for the version in
`CMakeLists.txt` if it has no release yet:

1. runs every check (`scripts/check.sh`);
2. makes `Gimbot-<version>-source.tar.gz` (and a `.zip`), `SHA256SUMS`, and
   `SHA256SUMS.minisig` signed with the **primary** key from the repository
   secret `MINISIGN_SECRET_KEY`, and verifies them;
3. creates a **draft** release with those files and the version's notes from
   `CHANGELOG.md`, adds a build provenance attestation, checks every file is
   attached, then publishes it (a pre-release if the version is a beta).

If anything fails, nothing is published, and a draft left behind is deleted
(the job's log says so). The job refuses to run without the signing secret.

The installer and Update now only accept a release whose `SHA256SUMS` carries
a valid signature from the primary or the **backup** key (both public keys are
in `install.sh`) and whose source matches its checksum. The backup secret key
is kept offline and only used if the primary is lost or leaked.

GitHub doesn't let tools change files in `.github/workflows` without extra
permission. If an upload of that folder is refused, add or update those files
once through the GitHub website.

## Checks

```sh
bash scripts/check.sh
```

runs exactly what CI runs, in the same order: shell scripts (`bash -n` +
shellcheck at every severity), workflow files (actionlint), web addresses,
version numbers agreeing, the build, unit and controller tests,
`gimbot --self-test`, the installer's self-test, and loading every screen.
Run it before every zip. CI pins shellcheck 0.11.0 and actionlint 1.7.12
(`pip install shellcheck-py==0.11.0.1 actionlint-py==1.7.12.25`).

### Version numbers

In `CMakeLists.txt`, `project(gimbot VERSION 0.1.1 …)` takes numbers only and
`set(GIMBOT_VERSION "0.1.1")` is the full version. A beta of the *next*
version is `0.1.2-beta.1` (a beta sorts before the release it leads to, so
`0.1.1-beta.1` would be older than `0.1.1`). Add each version to
`CHANGELOG.md` (top entry), `<releases>` in
`data/io.github.Matt_B_007.Gimbot.metainfo.xml` and the beta PKGBUILD;
`scripts/check.sh` fails if they disagree.

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
