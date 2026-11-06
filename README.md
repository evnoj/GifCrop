# GifCrop

A minimal macOS app for cropping animated GIFs, modeled on Preview's selection tool. Cropping is done by a bundled copy of [gifsicle](https://github.com/kohler/gifsicle).

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

## Layout

- `Sources/GifCrop/` — the app (AppKit, `NSDocument`-based)
- `Support/Info.plist` — app bundle metadata, registers GIF as an openable type
- `Support/AppIcon.png` — 1024px icon, converted to `.icns` during the build
- `scripts/build-gifsicle.sh` — downloads and builds gifsicle
- `scripts/build-app.sh` — builds `build/GifCrop.app`
