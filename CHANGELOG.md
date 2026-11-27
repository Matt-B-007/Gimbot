# Changelog

What changed in each version of Gimbot. The newest is at the top; the app
shows a version's notes in its update window.

## 0.1.0-beta.12 (2026-11-27)
Gimbot's new colors, shared with the other apps in the family, plus terminal
commands and the project files that make it easier to help.
- **Purple, on navy:** the accent changes from indigo to purple, and the
  backgrounds take the navy "hull" every app in the family now shares, in
  both themes. Success, warning and error colors match the family too. If
  you use your KDE accent color, that still wins.
- **Small family details:** cards have a faint accent edge; the Tracking card
  shows corner brackets while tracking is on (and any card does while it has
  keyboard focus); only the main button on a screen glows; a faint dot
  pattern sits behind the preview when there's no picture. **Settings ›
  App › Plain background** turns the pattern off, and so does turning
  animations off in System Settings.
- **New icon and tray colors:** the launcher icon is a navy square with a
  purple symbol, and the tray icon lights up purple while tracking.
- **Easy to read:** every text color passes the family's contrast rules on
  every surface (a test checks all of them, in both themes).
- **Terminal commands:** `gimbot --report` saves a problem report,
  `--update`, `--rollback` and `--uninstall` run the installer (or show the
  AUR command), and they work over SSH too. The installer adds `--beta` and
  `--no-launch`; `--selftest` is now `--self-test` (the old name still works).
- **Reports say how Gimbot was installed** and which update channel you're
  on, so problems are quicker to sort out.
- **Project files:** screenshots and a Privacy section in the README, plus
  CONTRIBUTING, SUPPORT, SECURITY and RELEASING guides, a bug report form,
  a pull request checklist, and a licence line at the top of every file.
- **Fixed a rare crash** when many icons changed color at once (for example
  switching between light and dark): icons are now redrawn fresh when they
  come into view instead of switching their drawing layer off and on, which
  could crash Qt's shape drawing.
- **Stricter checks:** compiler warnings now fail the build, a Release build
  runs its own self-test, and GitHub's actions are on their current versions.

## 0.1.0-beta.11 (2026-11-27)
The family look, clearer reports, and a stricter release check. This is the
first update your installed Gimbot checks before installing.
- **Tray icon shows what's going on:** plain when the camera is idle, lit in
  the accent while tracking, a red badge when it's asleep or tracking is
  paused, an amber dot when an update is ready, a red dot after a camera
  error, and grey with no camera. Hover for the reason.
- **Reports:** Save to file, Copy report and Open log folder are the main
  buttons. Open on GitHub now warns that the issue is public, puts only your
  summary and the first lines of the details in it, and saves the full report
  for you to attach.
- **More private reports:** IP and MAC addresses, tokens and passwords are
  hidden too (shown as `<ip>`, `<mac>`, `<secret>`), as well as your home
  folder, user name and computer name (`<host>`). Version numbers stay.
- **After an update** Gimbot says so once, with What's new and the tour.
- **Easier to read:** faint text, and success and warning colors in the light
  theme, are darker so all text passes 4.5:1 contrast; a test checks every
  color in both themes.
- **Releases:** the signature is checked against both public keys before
  anything is published, and `scripts/check.sh` lists any missing tools with
  the `pacman` command to install them (exit code 3).

## 0.1.0-beta.10 (2026-11-26)
Safer updates and better crash reports. This is the first signed release.
- **Updates are verified.** Each release carries SHA256SUMS and a minisign
  signature; the installer and Update now refuse a download unless both
  check out, so a damaged or changed download can't be installed.
- **Signed releases only.** Updates come from published releases with a
  signature. `--from-source` still builds the latest uploaded files, clearly
  marked as not verified.
- **Self-test.** `gimbot --self-test` (and `--quick`) checks the app works;
  each new build runs the quick one before it replaces the installed one.
- **Go back.** The previous version is kept, so Settings › Updates or
  `gimbot-update --rollback` can reinstall it if an update misbehaves.
- **Crash details.** If Gimbot crashes, the next start says so and the bug
  report includes a short trace (the last 10 are kept).
- **Settings are versioned and backed up** every 15 minutes at most (5 kept),
  so future changes can migrate them safely.
- **Logs moved** to `~/.local/state/gimbot` (3 files of 1 MB at most).
- **AUR installs** show the `paru` command instead of updating themselves.
- **Installer** works with `| sh`, and explains why it needs your password.
- **The tour** starts by itself only on new installs.

## 0.1.0-beta.9 (2026-11-26)
- The preview quality menu lists every resolution and frame rate the camera
  really offers (for example 1080p · 60 fps, 1080p · 30 fps, 4K · 30 fps),
  plus Auto. Combinations the camera can't do never appear, and the preview
  bar shows which one is in use. 30 fps can look brighter in a dim room.

## 0.1.0-beta.8 (2026-11-25)
- One line installs Gimbot straight from the uploaded files, with no release
  needed. If the OBSBOT SDK isn't in Downloads, the installer explains where to
  get it and waits.
- The update check also looks at the uploaded files, so a new version is
  offered even before a release is made. Release notes come from this file.
- New versions are published automatically: upload the files, or just the
  zip, and GitHub creates the release.
- Shorter README; building and releasing moved to BUILDING.md.

## 0.1.0-beta.7 (2026-11-25)
- Fixed: every GitHub address pointed to a lookalike domain that doesn't
  exist, so update checks, the one-line install and downloads all failed.
- A check that every web address in the code is one Gimbot expects.

## 0.1.0-beta.6 (2026-11-25)
- Fixed the drag-to-steer guide line and the "Could not register app ID"
  warning.
- Preview: Auto stays at 1080p (smoother 60 fps), and resizing the window no
  longer restarts the video.
- Try again waits 30 seconds after a failed check and no longer stretches
  the automatic retries; the log records why the backup lookup failed.
- Main screen: anti-flicker, hue, a sleep timer next to Sleep, zoom buttons,
  a "Camera starts at" choice, drag-to-reorder presets, Ctrl+1–9, and a
  keyboard shortcuts page (press ?).

## 0.1.0-beta.5 (2026-11-24)
- Update checks and the installer work around broken DNS, explain problems
  in plain words, and stop repeating.
- Screen-reader names for every control.
- Bug reports say why KDE integration is on or off.

## 0.1.0-beta.4 (2026-11-24)
- New main screen: tracking switch, field of view, white balance, focus,
  exposure, quick toggles, profile switcher, preview quality bar, status line.
- Smooth movement (Fast, Normal, Smooth, Cinematic), smooth presets, eased
  arrow keys and drag-to-steer.
- Up is up and right is right everywhere, with a direction check.
- Tracking pauses clearly after a manual move, with Resume.
- Sharpest preview format chosen automatically.
- First-run tour, hover hints, Undo, plain-language errors.
- Uninstall, SDK folder handling, and a fix for crashes on quit.
