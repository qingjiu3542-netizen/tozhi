# NotifyIcon

**Experimental Roothide Theos tweak** for briefly showing the sender app's icon in the SpringBoard status-bar area when a notification arrives.

> **Compatibility warning:** This is experimental source, not a tested installable tweak. It hooks private SpringBoard/BulletinBoard APIs and draws an overlay on a private status-bar window. Apple does not provide stable public APIs for either task. The hook signature, app-icon lookup, overlay position, and package compatibility can vary by iOS version and jailbreak. It has not been built or tested on an iPhone. Do not install until built for, and tested on, your exact iOS/jailbreak combination. The overlay may overlap system indicators.

## Target and settings

- Roothide Theos package for arm64e; injects only into SpringBoard.
- A PreferenceLoader entry registers the settings bundle in Settings on jailbreaks that provide a compatible PreferenceLoader.
- The panel provides a master enable switch, an all-apps switch, a searchable installed-app list with app icons and per-app switches, and an icon-display duration slider (2–30 seconds).
- The settings domain is `com.minis.notifyicon`. The build includes PreferenceLoader as a package dependency; if your bootstrap does not supply a compatible package, the panel may not appear.
- This package must be built with `THEOS_PACKAGE_SCHEME=roothide`; do not install the ordinary `/var/jb` rootless artifact on Roothide.

This is experimental source, not a tested installable tweak. It hooks private SpringBoard/BulletinBoard APIs and draws an overlay on a private status-bar window. API signatures and layout vary by iOS version and jailbreak, and the overlay may overlap system indicators. It has not been built or tested on an iPhone. Do not install until built for and tested on your exact iOS/jailbreak combination.

## Build

### GitHub Actions / cloud Mac build

`.github/workflows/build.yml` uses the Roothide-aware Theos Action and builds an arm64e package with `THEOS_PACKAGE_SCHEME=roothide`. Run **Build Roothide package** manually from the repository's Actions page. A successful build does not mean the private hook has been verified on-device.

Local Mac build:

```sh
make clean package THEOS_PACKAGE_SCHEME=roothide
```

Do not install an ordinary rootless `/var/jb` package on Roothide. Install the verified Roothide artifact only.

## License

MIT; see `LICENSE`.
