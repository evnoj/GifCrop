<p align="center"><img src="Support/AppIcon.png" width="128" alt="GifCrop icon"></p>

# GifCrop

A minimal macOS app for cropping animated GIFs, modeled on Preview's selection tool. Cropping is done by a bundled copy of [gifsicle](https://github.com/kohler/gifsicle).

![GifCrop with a selection drawn over an animated GIF](docs/demo.webp)

## Installation

Requires macOS 12 or later. The app is universal, so the same download runs on Apple silicon and Intel Macs.

1. Download `GifCrop.zip` from the [latest release](https://github.com/evnoj/GifCrop/releases/latest)
2. Unzip it and move `GifCrop.app` to `/Applications`
3. Open it. GifCrop isn't signed with an Apple Developer ID, so macOS will refuse to open it the first time. Allow it in one of two ways:
   - Open System Settings → Privacy & Security, scroll down to the message about GifCrop, click "Open Anyway", and confirm
   - Or run `xattr -dr com.apple.quarantine /Applications/GifCrop.app` in Terminal

   Either way you only need to do this once.

To use GifCrop from the terminal, choose GifCrop → Install Command Line Tool…, which links `/usr/local/bin/gifcrop` to the tool inside the app.

## Usage

- Drag to select an area (the GIF keeps playing); drag inside the selection to move it, or drag a handle to resize it
- ⌘K crops, ⌘Z undoes
- ⌘S saves in place, ⇧⌘S saves to a new file
- ⌘A selects all, ⇧⌘A or Esc deselects, Shift-drag draws a square
- The Aspect Ratio menu locks the selection to a preset, the current selection's ratio, or your own custom presets

## Building

Requires Xcode (or the Command Line Tools with a macOS SDK) and an internet connection the first time, to download the gifsicle source.

```sh
./scripts/build-app.sh
```

This builds a universal (Apple silicon + Intel) gifsicle from source into `build/gifsicle`, builds the Swift package, and assembles an ad-hoc signed `build/GifCrop.app` with gifsicle and the icon inside it.

To install:

```sh
cp -R build/GifCrop.app /Applications/
```

To package a release, zip the app with `ditto` (it preserves the code signature and bundle metadata, which Finder's Compress and plain `zip` can break) and attach `build/GifCrop.zip` to a GitHub release:

```sh
ditto -c -k --keepParent build/GifCrop.app build/GifCrop.zip
```

## Layout

- `Sources/GifCrop/` — the app (AppKit, `NSDocument`-based)
- `Support/Info.plist` — app bundle metadata, registers GIF as an openable type
- `Support/AppIcon.png` — 1024px icon, converted to `.icns` during the build
- `scripts/build-gifsicle.sh` — downloads and builds gifsicle
- `scripts/build-app.sh` — builds `build/GifCrop.app`
