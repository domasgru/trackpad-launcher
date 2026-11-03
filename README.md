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

Updates come to the app itself: when a newer version is out, the settings window shows *App version X is available*
with *Update now*.

## Commands

Run `make` to list them. Each one calls a script in `Scripts/`.

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

A release is a GitHub release with the disk image and the update archive. It is built, signed with the Developer ID,
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
5. pushes the version commit and publishes the release.

If anything fails before step 5, the version commit is undone, so the same command tries the same version again. The
first time, macOS asks to let Terminal control Finder: allow it, it lays out the disk image's window.

Releases are immutable once published: a broken one is fixed by releasing a higher version.

### How users get it

Every installed copy checks for a newer release each time its settings window opens, never in the background, and
offers it on a card with *Update now*. Drafts and pre-releases are never offered.

## Docs

- `docs/product-overview.md`: what the product does and its rules (privacy, performance).
- `docs/domain-model.md`: the glossary.
- `docs/architecture.md`: how it is built.
- `docs/performance.md`: how resource use is measured.
