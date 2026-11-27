# Security

## Reporting a vulnerability

Please **don't** open a public issue. Use GitHub's private reporting:
**Security › Report a vulnerability** on this repository. Include what you
found, how to reproduce it and which version you used (`gimbot --version`).

You'll get an answer when the maintainer has seen it, usually within a week.
Fixes ship as a new release; the changelog credits you if you'd like.

## Supported versions

Only the newest release (normal or beta) gets fixes. Update with **Update
now** in the app or `gimbot --update`.

## How releases are protected

- Releases are built by GitHub Actions from the repository, never uploaded by
  hand, with a build provenance attestation.
- Each release has `SHA256SUMS` signed with minisign. The installer and the
  app refuse an update unless the checksum **and** the signature (from the
  primary or the offline backup key, both embedded in `install.sh`) are
  valid.
- `--from-source` installs are the one exception: they're labelled as not
  verified.

## What Gimbot can reach

Gimbot talks to the camera over USB (and the OBSBOT SDK looks for cameras on
the local network), to GitHub to check for updates, and to public DNS
(1.1.1.1 and 8.8.8.8) only when your system's DNS can't find GitHub. It asks
for your password only to install or remove its system package.
