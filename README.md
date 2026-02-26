<p align="center">
  <img src="assets/icon.png" width="128" alt="EyeBreak icon">
</p>

# EyeBreak

A macOS menu bar app that reminds you to look away from the screen every 20 minutes, following the [20-20-20 rule](https://www.healthline.com/health/eye-health/20-20-20-rule). Smart enough to wait when you're in a meeting.

## Install

Download the latest DMG from [Releases](https://github.com/lowercaseclub/eyebreak/releases), open it, and drag EyeBreak to Applications.

> [!WARNING]
> **macOS will block EyeBreak on first launch** because the app is not notarized. To open it:
> 1. Open EyeBreak — macOS will show a blocked message
> 2. Go to **System Settings → Privacy & Security**
> 3. Scroll down and click **Open Anyway** next to the EyeBreak message
>
> You only need to do this once. Alternatively, run `xattr -cr /Applications/EyeBreak.app` in Terminal before opening.

The app runs in the menu bar — no Dock icon. Look for the 👁 icon.

## How it works

Every **20 minutes**, EyeBreak shows a full-screen overlay telling you to look **6 metres away** for **20 seconds**. That's it.

### Meeting detection

If your mic or camera is active (Zoom, Meet, FaceTime, etc.), EyeBreak **defers the break** and tries again 20 minutes later. After 6 consecutive deferrals (~2 hours), it forces a break regardless.

### Snoozing

You can snooze a break up to **3 times** (1 minute each). After that, the snooze button disappears and you have to take the break. Press **Esc** to snooze.

### Menu bar

| Item | Shortcut | Description |
|---|---|---|
| Status | — | Shows countdown to next break |
| Take Break Now | `B` | Trigger a break immediately |
| Pause 1 Hour / Resume | `P` | Pause all breaks for an hour |
| Launch at Login | — | Toggle auto-start via macOS login items |
| Check for Updates... | — | Check for new versions (via Sparkle) |
| Quit | `Q` | Quit the app |

## Build from source

Requires macOS 13+ and Xcode command line tools.

```sh
./build.sh
open build/EyeBreak.app
```

This compiles the Swift source, downloads [Sparkle 2](https://sparkle-project.org) on first run, embeds it in the app bundle, and creates `build/EyeBreak.dmg`.

### Run tests

```sh
brew install bats-core  # if you don't have it
bats tests/build.bats
```

### Legacy cleanup

If you previously ran EyeBreak via launchd scripts:

```sh
./build.sh --cleanup
```

## Release a new version

```sh
./release.sh 1.2
```

This will:
1. Update the version in `build.sh`
2. Build the app and DMG
3. Sign the DMG with your Sparkle EdDSA key
4. Update `docs/appcast.xml` with the new release entry
5. Commit, tag `v1.2`, and push
6. Create a GitHub Release with the DMG attached

### First-time setup

Generate a Sparkle signing keypair (stored in your macOS Keychain):

```sh
deps/Sparkle/bin/generate_keys
```

Paste the public key into the `SUPublicEDKey` field in `build.sh`. This only needs to be done once.

## How updates work

EyeBreak checks for updates automatically on launch using Sparkle. The update feed (`appcast.xml`) is hosted via GitHub Pages at:

```
https://lowercaseclub.github.io/eyebreak/appcast.xml
```

When a new version is available, Sparkle shows an update dialog. Users click Update, and Sparkle handles the download, verification, and replacement automatically.

## License

[MIT](LICENSE)
