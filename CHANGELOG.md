# Changelog

What changed in each version of Gimbot. The newest is at the top; the app
shows a version's notes in its update window.

## 0.1.0-beta.17 (2026-11-28)
Fixes for the 30 problems found by going through every screen of beta.16.
- **Up-and-down drags work again.** The page's scrolling was taking them
  over, so the aim pad, drag-to-steer on the picture and the tracking area's
  corners only moved sideways.
- **Arrow keys keep working** after you click a button in the cards.
- **The buttons on "Preview is off" and "Another app is using the picture"
  work.** The picture's click area was lying on top of them.
- **The picture stays put** while you scroll the cards: in a wide window the
  picture's side and the cards' side now scroll separately.
- **Tracking area:** the four corners are always on the picture. A corner
  whose edge is outside the picture waits at the picture's edge, so any edge
  can be pulled into view. Dragging a corner changes only its own two edges;
  the others stay exactly as they were. Esc leaves drawing, and it ends by
  itself if the camera sleeps or is unplugged. Corners and the bar's ends can
  be reached with Tab and moved a degree at a time with the arrow keys.
- **Reset area** in the drawing panel now does the same as in Settings: the
  camera's whole range.
- **"Camera starts at"** no longer shows "Straight ahead" at startup when
  nothing was chosen.
- **Menus are as wide as their longest line,** so nothing is cut off (preset
  options, Profiles, quality, sleep timer).
- **Asleep screen:** the sleep picture buttons no longer turn white under the
  pointer in the light theme, they are hidden when the camera isn't set to
  show a picture, and Mirror shows what the camera reports.
- **Arrow keys are the same everywhere,** with the aim pad focused or not.
  Settings no longer says Movement smoothness applies to the aim pad; the pad
  follows your hand directly.
- **Settings:** a Tracking card holds "Zoom in automatically while tracking"
  and "Resume tracking by itself"; Profiles sits above App, not below
  Uninstall.
- **Presets:** the camera holds three, and the app now says so when they are
  full. Shortcuts are listed as Ctrl 1-3. On small cards the name is no
  longer cut short by the shortcut label.
- Smaller things: the tour points to Help's new place and starts on the
  right screen; the Connect screen lost its old second logo and gear; About
  credits Space Grotesk; switched-off buttons and sliders look switched off;
  Resume is off while the camera sleeps; the Status light card's dot is lit
  only while the camera's light is; the picture's hint no longer covers the
  top bar; "Preview is off" no longer claims the camera is tracking you;
  "Draw the tracking area" is only offered when there is a picture to draw
  on; the area box follows the video when it isn't 16:9; the zoom label and
  aiming use the camera's real top zoom; the simulated camera stops at 120
  degrees like the real one.

## 0.1.0-beta.16 (2026-11-27)
A new look for the whole app, built from the mockup. This release changes
the inside of the code and what you see at the same time, which usually
goes in two releases; it's one on purpose, because the new screens were
written for the new code.
- **A new side rail** for Studio and Settings, with Help (tour, shortcuts,
  commands, direction check, what's new, report a problem, about) at the
  bottom. The top bar has the camera, profiles, search, Sleep, and an
  **Update ready** button when there's an update.
- **Double-click the picture to aim** the camera there. A single click no
  longer moves it, so you can click into the picture without it turning.
- **Aim with a circle:** drag the dot. A little is slow, to the edge is fast,
  and it springs back and stops when you let go. Arrow keys and Home still
  work.
- **Tracking shows in blue,** the same blue as the camera's light: a dot in
  the picture's label and corner brackets around the picture. The label
  also shows the field of view and zoom.
- **Draw the tracking area on the picture:** drag its corners, or the ends of
  the bar under it for an area wider than the picture. Open it from the
  status bar, the Tracking card or the commands (Ctrl K).
- **Status light card:** shows the camera light's level (Off, 1, 2 or 3). The
  camera reports it but the SDK can't change it, so the card only shows it.
- **Sleep picture:** choose which of the camera's three saved pictures it
  shows while asleep, and mirror it, from the Asleep screen or from
  Settings › Startup and sleep.
- **Clearer camera states:** no camera, another app using the video, asleep,
  and preview off each get their own screen with the next step.
- **Settings in seven groups:** Camera, Tracking, Image, Microphone and
  voice, Gestures, Startup and sleep, App and updates. Every setting is
  still there. "Keep the microphone on while asleep" moved to Microphone
  and voice.
- **Narrow windows** show the Tracking, Aim and Image cards as tabs.
- **Tray menu reordered:** Tracking, Camera asleep, presets, Start with my
  computer, then Open Gimbot, Settings and Quit. It's the desktop's own
  menu, so it keeps your desktop's style.
- **Title font:** the Studio title uses Space Grotesk (SIL Open Font
  License), bundled with the app.
- Fixed: a rare crash when the window got narrow while the status bar or
  the tracking area panel was updating. Lists that changed on every camera
  update now keep their items and update them in place.
- For developers: `cam`, `platform` and `updater` are now QML singletons
  (`Cam`, `Platform`, `Updater`) instead of context properties, and qmllint's
  unqualified-access and context-property checks are on again with no
  warnings.

## 0.1.0-beta.15 (2026-11-27)
Beta.14 again, with its new check fixed. Nothing for you to notice.
- **The check for Qt Quick's lint rules gave a false alarm** on GitHub, so
  beta.14 was never published. It asked qmllint for a list of its plugins,
  which didn't work as expected; it now plants a small layout mistake and
  checks that qmllint reports it, which is a sure test.
- Beta.13 and beta.14 were never signed, so your Gimbot skips them.

## 0.1.0-beta.14 (2026-11-27)
Beta.13 again, with the last QML lint warnings fixed so it passes GitHub's
checks and arrives as a signed update. Nothing for you to notice.
- **Seven status dots, dividers and the dialog icon** now give their size as
  a size hint (`implicitWidth`/`implicitHeight`) instead of setting `width`
  and `height` inside a layout, which Qt calls undefined behaviour. They
  look exactly the same.
- **The checks can't miss this again:** some copies of qmllint come without
  Qt Quick's own rules, and then those rules silently don't run. `check.sh`
  now says when that's the case (and fails in CI), and checks the layout
  rule itself as well (`tests/check_qml_layouts.py`), so it runs everywhere.
- Beta.13 failed those checks, so it was never signed; your Gimbot skips it.

## 0.1.0-beta.13 (2026-11-27)
A tidy-up of the code with nothing for you to notice, plus a fix that lets
updates arrive again.
- **Updates work again:** beta.10, 11 and 12 were published without their
  signature files, so Gimbot (rightly) wouldn't install them. The release
  was being created when the files were uploaded, and the publishing job
  took "a release exists" to mean "already done". It now checks for the
  signature, and adds the checked, signed files to a release that doesn't
  have them yet, the signature last. If adding them fails, the files already
  added are taken off again. This version is the first to arrive that way.
- **Code tidy-up, no changes in behaviour:** all C++ is formatted with
  clang-format (style in `.clang-format`), and the QML passes qmllint with no
  warnings (settings in `.qmllint.ini`). A few objects were renamed so they
  no longer hide Qt's own properties of the same name (the command palette,
  the toast list, the status strip's message and the preview), and a few
  bindings name the object they mean instead of reaching it through
  `parent`. The screenshots before and after are identical.
- **Two new checks:** `scripts/check.sh` (and so CI and StowLock) now checks
  the C++ formatting with clang-format 23.1.5 (the version Arch ships, and
  pinned in CI) and runs qmllint, where any warning fails. If clang-format
  is missing, it says to install `clang`.
- **One qmllint rule is off on purpose:** the app hands `cam`, `platform`
  and `updater` to QML from C++ as context properties, which qmllint can't
  see. Turning them into QML singletons would change how the app starts,
  so that's left for a release of its own.

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
