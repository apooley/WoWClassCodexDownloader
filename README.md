# WoW ClassCodex Addon Downloader

This repository provides a downloader for the ClassCodex Addon for World of Warcraft.

# ClassCodex Downloader

A downloader for the [ClassCodex](https://addons.wago.io/addons/classcodex) Addon for World of Warcraft. (https://www.icy-veins.com/download)

It downloads the latest production build of ClassCodex, verifies the downloaded files using SHA-256 checksums, and installs or updates the addon in your WoW `AddOns` folder.

Use either the **macOS app** or the **Python script**. Both talk to the same CDN and apply the same integrity checks.

## Features

* Downloads the latest ClassCodex production build
* Verifies the manifest using SHA-256
* Verifies every downloaded file using SHA-256
* Skips files that are already up to date
* Prevents unsafe manifest paths
* Uses temporary files during downloads to avoid incomplete files
* Supports a dry-run mode

## macOS app

Requires macOS 13 or later and Xcode.

1. Open `ClassCodexDownloader/ClassCodexDownloader.xcodeproj` in Xcode and press Run.
2. The app locates World of Warcraft (retail) via Launch Services and mounted `Applications` folders, then targets `_retail_/Interface/AddOns`. If that install is missing, choose the folder yourself.
3. Click **Update**. Enable **Dry run** first if you want to see what would change without writing files.

The last folder you pick is remembered for the next launch.

To build from the command line:

```bash
xcodebuild -scheme ClassCodexDownloader -configuration Release -project ClassCodexDownloader/ClassCodexDownloader.xcodeproj
```

The `.app` is written under Xcode’s DerivedData build products. Tests:

```bash
xcodebuild test -scheme ClassCodexDownloader -destination 'platform=macOS' -project ClassCodexDownloader/ClassCodexDownloader.xcodeproj
```

## Python script

Requires Python 3.9 or newer. The script uses only the standard library.

### Configuration

Open `download_classcodex.py` and set `ADDONS_PATH` to your World of Warcraft `AddOns` folder.

### Usage

```bash
python download_classcodex.py
```

### Dry run

If you want to see which files would be downloaded without modifying anything, set:

```python
DRY_RUN = True
```

The downloader will:
1. Download the current ClassCodex channel configuration.
2. Download and verify the manifest.
3. Verify that the manifest belongs to ClassCodex Retail.
4. Compare local files with the expected SHA-256 hashes.
5. Download missing or outdated files.
6. Verify every downloaded file.
7. Report the installed build and download results.

## Security
The downloader performs integrity checks before installing files.
The channel configuration provides the expected SHA-256 hash of the manifest. The manifest then provides the expected SHA-256 hash and file size for each addon file.
Downloaded files are verified before they are considered successfully installed.
Unsafe manifest paths (path traversal, missing `ClassCodex/` prefix) are rejected.

## Disclaimer
This is an independent downloader for the ClassCodex Addon.
World of Warcraft and related trademarks are property of their respective owners. This project is not affiliated with or endorsed by Blizzard Entertainment unless explicitly stated otherwise.
The ClassCodex addon, its data, and its distribution infrastructure may be subject to their own licenses and terms. This repository's license applies only to the code contained in this repository.
