# WoW ClassCodex Addon Downloader

A downloader for the [ClassCodex](https://addons.wago.io/addons/classcodex) addon for World of Warcraft ([Icy Veins download](https://www.icy-veins.com/download)).

It fetches the latest production build of ClassCodex, verifies the manifest and every file with SHA-256, and installs or updates the addon in your retail WoW `AddOns` folder.

Use either the **macOS app** or the **Python script**. Both talk to the same CDN and apply the same integrity checks.

## Credits

This project is a fork of [gable44/WoWClassCodexDownloader](https://github.com/gable44/WoWClassCodexDownloader).

**[gable44](https://github.com/gable44)** designed and published the original downloader: the CDN/channel flow, SHA-256 verification model, safe path handling, and the Python client that this repository still ships. That work is the foundation everything else builds on.

This fork adds a native macOS SwiftUI app that can locate a retail World of Warcraft install and install ClassCodex into `_retail_/Interface/AddOns`.

## Features

* Downloads the latest ClassCodex production build
* Verifies the manifest using SHA-256
* Verifies every downloaded file using SHA-256
* Skips files that are already up to date
* Rejects unsafe manifest paths (traversal, missing `ClassCodex/` prefix)
* Writes through temporary files so incomplete downloads are not left in place
* Supports a dry-run mode
* **macOS app:** finds retail WoW via Launch Services and mounted `Applications` folders, then resolves to `_retail_/Interface/AddOns` (including when you pick the WoW install folder itself)

## macOS app

Requires macOS 13 or later.

### Run from Xcode

1. Open `ClassCodexDownloader/ClassCodexDownloader.xcodeproj` in Xcode and press Run.
2. The app looks for World of Warcraft (retail) and targets `_retail_/Interface/AddOns`. If nothing is found, use **Choose Folder…** and select either the WoW install folder or `Interface/AddOns` directly.
3. Click **Update**. Enable **Dry run** first if you want to see what would change without writing files.

The resolved AddOns path is remembered for the next launch.

### Build and package

Release build:

```bash
xcodebuild -scheme ClassCodexDownloader -configuration Release \
  -project ClassCodexDownloader/ClassCodexDownloader.xcodeproj
```

The `.app` is written under Xcode’s DerivedData build products. Packaged builds (Developer ID signed) can be placed under `dist/` (gitignored).

Tests:

```bash
xcodebuild test -scheme ClassCodexDownloader -destination 'platform=macOS' \
  -project ClassCodexDownloader/ClassCodexDownloader.xcodeproj
```

## Python script

Requires Python 3.9 or newer. The script uses only the standard library and is the original client from [gable44](https://github.com/gable44).

### Configuration

Open `download_classcodex.py` and set `ADDONS_PATH` to your World of Warcraft retail `AddOns` folder, for example:

```text
…/World of Warcraft/_retail_/Interface/AddOns
```

### Usage

```bash
python download_classcodex.py
```

### Dry run

Set the following in the script to preview downloads without writing files:

```python
DRY_RUN = True
```

### What it does

1. Download the current ClassCodex channel configuration.
2. Download and verify the manifest.
3. Verify that the manifest belongs to ClassCodex Retail.
4. Compare local files with the expected SHA-256 hashes.
5. Download missing or outdated files.
6. Verify every downloaded file.
7. Report the installed build and download results.

## Security

The downloader performs integrity checks before installing files.

The channel configuration provides the expected SHA-256 hash of the manifest. The manifest then provides the expected SHA-256 hash and file size for each addon file. Downloaded files are verified before they are considered successfully installed. Unsafe manifest paths are rejected.

## License

This repository is released under [CC0 1.0 Universal](LICENSE) (same as the upstream project).

## Disclaimer

This is an independent downloader for the ClassCodex addon. World of Warcraft and related trademarks are property of their respective owners. This project is not affiliated with or endorsed by Blizzard Entertainment unless explicitly stated otherwise.

The ClassCodex addon, its data, and its distribution infrastructure may be subject to their own licenses and terms. This repository’s license applies only to the code contained in this repository.
