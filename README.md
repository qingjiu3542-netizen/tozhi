# NotifyIcon

**Rootless Theos source prototype** for briefly showing the sender app's icon in the SpringBoard status-bar area when a notification arrives.

> **Compatibility warning:** This is experimental source, not a tested installable tweak. It hooks private SpringBoard/BulletinBoard APIs and draws an overlay on a private status-bar window. Apple does not provide stable public APIs for either task. The hook signature, app-icon lookup, overlay position, and package compatibility can vary by iOS version and jailbreak. It has not been built or tested on an iPhone. Do not install until built for, and tested on, your exact iOS/jailbreak combination. The overlay may overlap system indicators.

## Target and settings

- Theos rootless package for arm64/arm64e; injects only into SpringBoard.
- A PreferenceLoader entry registers the settings bundle in Settings on jailbreaks that provide a compatible PreferenceLoader.
- The panel provides a master enable switch, an all-apps switch, a searchable installed-app list with app icons and per-app switches, and an icon-display duration slider (2–30 seconds).
- The settings domain is `com.minis.notifyicon`. The build includes PreferenceLoader as a package dependency; if your bootstrap does not supply a compatible package, the panel may not appear.

This is experimental source, not a tested installable tweak. It hooks private SpringBoard/BulletinBoard APIs and draws an overlay on a private status-bar window. API signatures and layout vary by iOS version and jailbreak, and the overlay may overlap system indicators. It has not been built or tested on an iPhone. Do not install until built for and tested on your exact iOS/jailbreak combination.

## Build

### GitHub Actions / cloud Mac build

`.github/workflows/build.yml` uses GitHub-hosted macOS and Theos to build a rootless `.deb`. Run `Build rootless package` manually from the repository's Actions page. A successful build does not mean the private hook has been verified on-device.

Local Mac build:

```sh
make package
```

This is for conventional rootless jailbreaks. roothide uses a randomized jailbreak root and may need a roothide-compatible packaging workflow; do not install this artifact on roothide unless your bootstrap documentation confirms compatibility.

## License

MIT; see `LICENSE`.
