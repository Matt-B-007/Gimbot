# Contributing to Gimbot

Thanks for helping. Gimbot is a small project, so a few house rules keep it
easy to look after.

## Reporting a problem

Use **Help (?) › Report a problem** in the app, or run `gimbot --report`.
Either saves a report with your home folder, names, addresses and secrets
hidden. Open an issue with the bug report form and attach the file.

## Making a change

1. Read [BUILDING.md](BUILDING.md) to build it. You don't need a camera:
   `gimbot --fake` simulates one.
2. Keep changes small and on one topic. A pure tidy-up (formatting, moving
   files) goes in its own pull request, never mixed with a behaviour change.
3. Run `bash scripts/check.sh` before you push. It runs exactly what CI runs
   and must end with "All checks passed". If it says tools are missing, it
   prints the `pacman` command to install them.
4. Add a line to the top of `CHANGELOG.md` saying what users will notice.

## Style

- **C++ 17 and Qt 6.** Nothing slow on the interface thread: camera calls
  go through the worker thread, network through Qt's async APIs. Format
  with `clang-format` (the style is in `.clang-format`).
- **QML:** take colors, sizes and fonts from `Theme.qml`. Every text color
  must pass 4.5:1 contrast in both themes (a test checks it). qmllint must
  report nothing; refer to objects by `id` rather than through `parent`.
- **Words in the interface:** plain language, say what to do next, no
  jargon. Buttons say what they do ("Save to file", not "OK").
- **Shell scripts:** bash, clean under shellcheck at every severity. Use
  `if`/`then` rather than `A && B || C`.
- **Every source file** starts with `SPDX-License-Identifier: MIT` in a
  comment.

## Licence

By contributing you agree that your work is released under the MIT licence
in [LICENSE](LICENSE). Don't add code from the OBSBOT SDK or anything whose
licence doesn't allow that.
