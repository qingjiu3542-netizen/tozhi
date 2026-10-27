# NotifyIcon

**Rootless Theos source prototype** for briefly showing the sender app's icon in the SpringBoard status-bar area when a notification arrives.

> **Compatibility warning:** This is experimental source, not a tested installable tweak. It hooks private SpringBoard/BulletinBoard APIs and draws an overlay on a private status-bar window. Apple does not provide stable public APIs for either task. The hook signature, app-icon lookup, overlay position, and package compatibility can vary by iOS version and jailbreak. It has not been built or tested on an iPhone. Do not install until built for, and tested on, your exact iOS/jailbreak combination. The overlay may overlap system indicators.

## Target and settings

- Theos rootless package scheme; intended as a starting point for arm64/arm64e.
- Injects only into SpringBoard.
- If `EnabledBundleIDs` is absent, all apps are enabled. To allow only selected apps, write an array of bundle IDs to `com.minis.notifyicon.plist`, for example:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>EnabledBundleIDs</key>
  <array>
    <string>com.apple.MobileSMS</string>
    <string>com.example.chatapp</string>
  </array>
</dict></plist>
```

Place it at `/var/mobile/Library/Preferences/com.minis.notifyicon.plist` using a plist editor (replace sample IDs with real app bundle IDs), then respring. There is no in-app app-picker UI in this prototype.

## Build

## GitHub Actions / 云端 Mac 构建

`.github/workflows/build.yml` 使用 `macos-latest` 和 Theos Action，在 GitHub 云端 Mac 上生成 rootless `.deb`。推送任意 `v*` 标签时，构建产物还会自动附加到 GitHub Release；也可以在仓库 Actions 页面手动运行 `Build rootless package`。

本地 Mac 构建命令：

```sh
make package
```

云端构建成功仍不代表私有 Hook 已在你的设备上验证。安装前必须针对 roothide、iOS 版本和具体设备测试。

### roothide note

This Makefile creates a conventional Theos rootless package. roothide installations use a randomized jailbreak root and may require conversion/patching with a roothide-compatible packaging workflow. Do not install this artifact directly on roothide unless your bootstrap's documentation confirms the package format is supported. The bundle ID and Debian metadata are ordinary source metadata, not a compatibility guarantee.

## License

MIT; see `LICENSE`.
