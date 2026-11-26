# Changelog

What changed in each version of Gimbot. The newest is at the top; the app
shows a version's notes in its update window.

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
