# Releasing Gimbot

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
   secret `MINISIGN_SECRET_KEY`, and verifies the signature against **both**
   public keys embedded in `install.sh` (either may match); if signing says
   "Error while loading the secret key file", the secret's contents are
   wrong: paste the key file into it again;
3. creates a **draft** release with those files and the version's notes from
   `CHANGELOG.md`, adds a build provenance attestation (public repositories only), checks every file is
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

## Before you upload

1. Update the version in `CMakeLists.txt`, the top of `CHANGELOG.md`, the
   metainfo `<releases>` and the beta PKGBUILD (see below).
2. Run `bash scripts/check.sh`. It must end with "All checks passed".
3. Upload. StowLock runs the same checks before it pushes.

## Changelog style

A version heading, a one-line summary, then bullets that start with a bold
lead and say why it changed. Plain language: what users will notice.

## Version numbers

In `CMakeLists.txt`, `project(gimbot VERSION 0.1.1 …)` takes numbers only and
`set(GIMBOT_VERSION "0.1.1")` is the full version. A beta of the *next*
version is `0.1.2-beta.1` (a beta sorts before the release it leads to, so
`0.1.1-beta.1` would be older than `0.1.1`). Add each version to
`CHANGELOG.md` (top entry), `<releases>` in
`data/io.github.Matt_B_007.Gimbot.metainfo.xml` and the beta PKGBUILD;
`scripts/check.sh` fails if they disagree.

The normal update channel ignores betas; the beta channel takes both.

## AUR

`packaging/aur/` holds PKGBUILDs for `gimbot` and `gimbot-beta`, for
publishing to the AUR. They need the SDK zip placed next to the PKGBUILD.
Update `pkgver` (or `_tag` and `pkgver` for the beta) with each version.

## If something goes wrong

- **Publish failed:** nothing was published. The job deletes its own draft;
  if a draft for that version is still under Releases, delete it, fix the
  problem and upload again.
- **"MINISIGN_SECRET_KEY secret is missing":** add it in Settings › Secrets
  and variables › Actions, then re-run the job.
- **"Error while loading the secret key file":** the secret's contents are
  wrong (usually a bad paste). Paste the key file into the secret again.
- **The primary key is lost or leaked:** put the backup secret key (kept
  offline) into `MINISIGN_SECRET_KEY`; installed copies of Gimbot already
  accept it. Then make a new key pair to be the next backup, and replace the
  old primary's public key with it in `install.sh` and the Publish job.
