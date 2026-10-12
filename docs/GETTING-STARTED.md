# Getting started on macOS

The [README quick start](../README.md#quick-start) installs pinned local tools,
stages Freedoom and starts the browser playground. Use macOS arm64 with Git,
Python 3.10+, Node **24.11.0** and Chrome. The browser needs IndexedDB and Web
Locks. macOS is the documented platform; other platforms have not been release
tested. Native oracle reproduction additionally pins Apple Clang/target details
in [TOOLCHAIN.md](../TOOLCHAIN.md).

Use `git submodule update --init --recursive` if the checkout was not recursive.
`source scripts/env.sh` selects project-local binaries and the shared execution
budget. Players use committed contract artifacts; compilation and npm installs
are unnecessary for the browser launcher.

For deployment flags, installation recovery and controls, use
[Browser deployment](browser-deployment/README.md).

## Commercial IWADs on macOS

Freedoom works without a commercial game. To use Ultimate DOOM or DOOM II, obtain
the classic IWAD from your own licensed copy. Keep it outside Git, such as in
`~/Downloads/`; the browser authenticates exact bytes before installation.

### Install SteamCMD

With [Homebrew](https://brew.sh/) installed:

```sh
brew install --cask steamcmd
```

This is the command in the [official Homebrew SteamCMD cask](https://formulae.brew.sh/cask/steamcmd).
If macOS requests Rosetta on Apple Silicon, follow its prompt. SteamCMD may
prompt for a password and Steam Guard approval/code. Enter credentials only at
its interactive prompts; never put a password in a command, script or repository.

### Ultimate DOOM — tested procedure

The following procedure was tested on macOS for Steam app **2280**. Replace only
`YOUR_STEAM_USERNAME` with your Steam account name:

```sh
mkdir -p ~/Downloads/doom-steam

steamcmd \
  +@sSteamCmdForcePlatformType windows \
  +force_install_dir "$HOME/Downloads/doom-steam" \
  +login YOUR_STEAM_USERNAME \
  +app_update 2280 validate \
  +quit
```

Keep the `windows` override: it selects the distribution containing the classic
IWAD while SteamCMD runs on macOS. It is not an instruction to run the game on
Windows. This procedure establishes the Ultimate DOOM download; DOOM II is
documented separately below.

The verified classic file is `~/Downloads/doom-steam/base/DOOM.WAD`.
Check it with macOS `md5`:

```sh
md5 -q "$HOME/Downloads/doom-steam/base/DOOM.WAD"
# expected: c4fe9fd920207691a9f493668e0a2083
```

### DOOM II — separate app and installation

The classic DOOM II Steam app ID is **2300**, independently confirmed by
[Steam's DOOM II product page](https://store.steampowered.com/app/2300/).
That legacy app is no longer sold individually; your account must have access
to it. Use the same macOS download method with its own app ID and destination:

```sh
mkdir -p ~/Downloads/doom2-steam

steamcmd \
  +@sSteamCmdForcePlatformType windows \
  +force_install_dir "$HOME/Downloads/doom2-steam" \
  +login YOUR_STEAM_USERNAME \
  +app_update 2300 validate \
  +quit
```

Look for the classic `base/DOOM2.WAD` under that installation directory. If Steam
supplies a different layout, locate `DOOM2.WAD` there and check the file itself:

```sh
md5 -q "$HOME/Downloads/doom2-steam/base/DOOM2.WAD"
# expected: 25e1459ca71d321525f84628f45ca8cd
```

The app ID is source-verified; this release-preparation run did not log into Steam
or repeat that authenticated download. The locally available DOOM II IWAD and
browser profile have separate project verification. A “no subscription” error
requires an entitled account; a newer/different IWAD checksum is not accepted.
Do not substitute a renamed rerelease file or assume app 2280 installs both games.

### Import into the playground

1. Start the local site and Anvil using the [quick start](../README.md#quick-start).
2. Open `http://127.0.0.1:18992`, enter `http://127.0.0.1:18991`, and **Connect**.
3. Select **Ultimate DOOM** or **DOOM II**. Use **Local IWAD** to choose the file
   above. In the macOS file picker, **⌘⇧G** opens a folder-path entry.
4. Wait for authentication, then **Install / resume** and **Play**.

The IWAD is read and packed in the browser; resource transactions go to the
selected localhost Anvil. No commercial IWAD is uploaded to a website server
or added to the repository. Pending transaction calldata may remain in local
IndexedDB for recovery. After a completed installation is verified, reconnecting
to the same chain can play without reselecting the WAD. An interrupted upload
may require selecting it again.

The accepted profiles are Ultimate Episode One and DOOM II's bounded coverage
in the [compatibility matrix](COMPATIBILITY.md). Installation does not confer
full-game acceptance.
