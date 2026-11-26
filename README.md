# Drop-off

A temporary macOS shelf for files, images, and links you want to drag between apps.

## Install

[Download from GitHub Releases](https://github.com/vojtasbrandejs/Drop-off-mac/releases/latest). The installer requires macOS 14.5 or later and Apple Command Line Tools with Swift 6 or newer.

```sh
curl -fL -o install.sh https://github.com/vojtasbrandejs/Drop-off-mac/releases/download/v1.1.2/install.sh && bash install.sh
```

The installer builds the app on your Mac for Apple silicon and Intel, then opens it. Run it again to update.

## Use

Shake the pointer while dragging a file to open a shelf, or choose **New Shelf** from the menu bar. Drop items onto it, then drag them into the destination app.

## Build from source

```sh
DROPOFF_PACKAGE_DISTRIBUTION=0 ./scripts/build-app.sh
./scripts/run-tests.sh
```

[Privacy](PRIVACY.md) · [Security](SECURITY.md) · [MIT License](LICENSE)
