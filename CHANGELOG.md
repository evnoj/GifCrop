# Changelog

## [1.0.1] - 2026-11-15

### Fixed

- Choosing a file in the Open panel shown at launch quit GifCrop instead of opening the file
- Reactivating GifCrop (e.g. clicking its Dock icon) while the launch Open panel was showing stacked a second panel on top of it, which was left behind after opening a file
- Removed stray debug output written to stderr

## [1.0] - 2026-11-15

First release.

### Added

- Crop animated GIFs with a Preview-style selection: drag to select while the GIF keeps playing, move the selection or resize it from its handles, Shift-drag for a square
- Crop (⌘K) with undo (⌘Z), save in place (⌘S) or to a new file (⇧⌘S)
- Select all (⌘A) and deselect (⇧⌘A or Esc)
- Aspect Ratio menu: lock the selection to a preset, the current selection's ratio, or your own custom presets
- `gifcrop` command-line tool, installed from GifCrop → Install Command Line Tool…; it opens a GIF in GifCrop and waits until the window is closed, so it works as an editor command in scripts
- Universal build for Apple silicon and Intel Macs, with gifsicle 1.98 bundled

[1.0.1]: https://github.com/evnoj/GifCrop/releases/tag/v1.0.1
[1.0]: https://github.com/evnoj/GifCrop/releases/tag/v1.0
