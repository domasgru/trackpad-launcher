# Trackpad Launcher

A macOS app that brings apps to the front with trackpad gestures: rest your thumb in a corner of the trackpad and tap
with one to five fingers to open the app you picked for that tap. With the thumb down, sliding two fingers sideways
switches between recent apps, and up or down between the front app's windows; tapping the thumb under two resting
fingers swaps the two most recent apps. It runs in the background with no menu bar icon: open the app to see its
settings.

Needs macOS 26 or later.

## Install

1. Download `TrackpadLauncher.dmg` from the [latest release](https://github.com/domasgru/trackpad-launcher/releases/latest).
2. Open it and drag Trackpad Launcher to Applications.
3. Open Trackpad Launcher from Applications and allow Accessibility when asked.

Updates come on their own at login, with nothing to press and nothing shown, when the copy can write to its own bundle. Otherwise the settings window shows an update card with *Update now*.

## Commands

Run `make` to list them. Each one calls a script in `Scripts/`. `Scripts/build-sparkle.sh` rebuilds the vendored Sparkle in `LauncherKit/Vendor/Sparkle` from its pinned source; it is not part of the normal build.

| Command | What it does |
|---|---|
| `make test` | Runs every test. |
| `make run` | Builds the development app and opens it, replacing a development copy that is already running. |
| `make project` | Regenerates `TrackpadLauncher.xcodeproj` from `project.yml` (it is not committed). |
| `make release-patch` | Releases a fix: 1.2.3 → 1.2.4. |
| `make release-minor` | Releases new features: 1.2.3 → 1.3.0. |
| `make release-major` | Releases big changes: 1.2.3 → 2.0.0. |
| `make release` | Releases the version already set in `Config/Version.xcconfig`: the first release, or a retry after a failed publish. |

A development build (`make run`, or Xcode) never checks for updates and never shows the move to Applications dialog.
Debug builds also open the launch animation tuner. A Debug build runs as `com.domasgru.TrackpadLauncherApp.debug`: System Settings lists it as a second *Trackpad Launcher* under Privacy & Security, and it keeps its own settings, apart from the installed release's.

## Releasing

A release is a GitHub release with the disk image and the update archive, and an item in `appcast.xml`. It is built, signed with the Developer ID,
notarised and published from this Mac, by one command.

### One-time setup

- Xcode, and xcodegen: `brew install xcodegen`.
- The *Developer ID Application* certificate in the login keychain: `security find-identity -v -p codesigning` lists it.
- Notarisation credentials, stored once under the profile name `trackpad-launcher`, with an app-specific password from
  [account.apple.com](https://account.apple.com) → Sign-In and Security → App-Specific Passwords:
  ```
  xcrun notarytool store-credentials trackpad-launcher --apple-id <apple-id-email> --team-id CQK27876UL
  ```
- GitHub CLI logged in: `gh auth login`.

### Each release

From an up-to-date `main` with nothing uncommitted, run `make release-patch` (or `-minor`, `-major`). It:

1. checks the certificate, the notarisation credentials, the GitHub login, and that `main` is clean and equal to
   GitHub's;
2. runs every test;
3. raises the version and the build number in `Config/Version.xcconfig`, in a local commit;
4. builds the app, has Apple notarise it and the disk image, and checks the signatures as Gatekeeper will;
5. pushes the version commit and publishes the release;
6. adds an item for the release to `appcast.xml`, the update list, and pushes it.

If anything fails before step 5, the version commit is undone, so the same command tries the same version again. If
the push in step 6 fails, the release is already published: `Scripts/release.sh --feed-only <version>` finishes it. The
first time, macOS asks to let Terminal control Finder: allow it, it lays out the disk image's window.

Releases are immutable once published: a broken one is fixed by releasing a higher version.

The update key signs every update. Its private half lives in the login keychain, and it cannot rotate: every installed
copy trusts only that key. Back it up with `generate_keys -x <file>` (in `LauncherKit/Vendor/Sparkle/bin`), and keep the file out of the repository.

After each release, update a copy of the previous version by hand: open its settings window and press *Update now*,
and once restart the Mac with it installed. Check that the new version runs, its gestures work, and its settings and
permissions are unchanged. Do it right after publishing: installed copies take the release at their next login, and a
release whose updater is broken cannot be replaced by an update.

### How users get it

A copy signed with the Developer ID that lies in /Applications makes an update check at each login start, if it can
write to its own bundle. Finding a newer version, it downloads and installs it straight away (a login update) and
restarts silently; gestures may stop for up to 10 seconds. At any other time nothing updates by itself: opening the
settings window makes one check, and a newer version shows the update card at the top of the window. *Update now*
reads the update list once more, downloads and installs the version, asking an administrator's name and password
when the account cannot write to /Applications, and the new version opens with its settings window. Drafts and
pre-releases never appear, because only the release command writes the list. A copy from before automatic updates
still offers a release on its old card, through the GitHub release, the next time its settings window opens.

## Docs

- `docs/product-overview.md`: what the product does and its rules (privacy, performance).
- `docs/domain-model.md`: the glossary.
- `docs/architecture.md`: how it is built.
- `docs/performance.md`: how resource use is measured.
