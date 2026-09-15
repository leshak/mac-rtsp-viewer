[Read this README in Russian](https://github.com/leshak/mac-rtsp-viewer/blob/master/README_RU.md)

# RTSP Viewer

A native RTSP camera viewer for macOS. The app lives in the menu bar, stays out
of the Dock, and opens the video stream in a separate window.

## Features

- video camera icon in the menu bar;
- show or hide the viewer with one click;
- `rtsp://` and `rtsps://` playback through VLCKit;
- RTSP over TCP with a small network buffer for local cameras;
- manual URL entry, `⌘V`, and a dedicated Paste button;
- saved RTSP URL and language preference between launches;
- automatic Russian interface for a Russian macOS locale and English for all
  other locales;
- System, Russian, and English language options in Settings;
- reconnect without restarting the app;
- a clear error message when the camera is unavailable.

The app does not include a preset camera address. Open Settings on the first
launch and enter your own RTSP URL.

## Requirements

- macOS 15 or later;
- Xcode 26 or later;
- an internet connection for the first build so Swift Package Manager can
  download VLCKit/libVLC.

## Quick Start

Build the app:

```shell
make app
```

Open the resulting bundle:

```shell
open "build/RTSP Viewer.app"
```

After launch:

1. Click the video camera icon on the right side of the menu bar.
2. Open Settings with the gear button.
3. Enter or paste an RTSP URL.
4. Choose an interface language if you do not want to follow the macOS locale.
5. Click Save to start the stream immediately.

A left click on the menu bar icon shows or hides the window. A right click
opens the Quit menu.

## Development in Xcode

1. Open [Package.swift](Package.swift) in Xcode.
2. Select the `RTSPViewer` scheme and the `My Mac` destination.
3. Click Run.

Available commands:

| Command | Purpose |
| --- | --- |
| `make build` | Build a debug executable with Swift Package Manager |
| `make run` | Build and run from Terminal |
| `make app` | Create a release `RTSP Viewer.app` bundle |
| `make clean` | Remove build output |

The finished app is created at `build/RTSP Viewer.app`. The packaging script
embeds `VLCKit.framework` and applies a local ad-hoc signature.

## Settings Storage

The RTSP URL and language preference are stored in the app's `UserDefaults`
under the `streamURL` and `appLanguage` keys. Clear removes the saved camera
address. Credentials included directly in a URL are stored with that address.

The System language option checks the preferred macOS locale at app launch. A
Russian locale selects Russian; every other locale selects English.

## Project Structure

| Path | Contents |
| --- | --- |
| `Sources/RTSPViewer` | AppKit and SwiftUI application code |
| `Support` | App metadata and localized permission descriptions |
| `Scripts/build-app.sh` | `.app` packaging script |
| `Package.swift` | Swift Package Manager configuration and dependencies |

## Video Engine and License

The project uses [VLCKit](https://github.com/videolan/vlckit) and libVLC.
VLCKit/libVLC are distributed under LGPL 2.1. This project's source code is
available under the [MIT License](LICENSE).
