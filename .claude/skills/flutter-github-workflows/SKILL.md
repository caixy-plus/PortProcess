---
name: flutter-github-workflows
description: Flutter 跨平台应用 GitHub Actions CI/CD 打包与发布方案。覆盖 Android APK（签名）、macOS DMG、Windows MSI（WiX v3）、Web 的完整工作流配置与坑点清单。
user-invocable: true
---

# Flutter 跨平台 GitHub Actions 打包与发布 Skill

## 适用场景

- Flutter 项目需要同时构建 Android / macOS / Windows / Web
- 通过 GitHub Actions 自动打包并发布 GitHub Release
- 需要避免各平台已知的 CI 坑点

## 前置检查

1. `pubspec.yaml` 中 `name` 字段决定 Windows 构建产物 exe 名称
2. `windows/CMakeLists.txt` 中的 `BINARY_NAME` 必须与 `pubspec.yaml` 的 `name` 一致
3. `windows/runner/Runner.rc` 中的 `OriginalFilename` 也需同步
4. GitHub Actions 触发条件：`push tags: 'v*'`

## 完整工作流结构

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

env:
  FLUTTER_VERSION: '3.x.x'

jobs:
  build-android:
  build-macos:
  build-windows:
  build-web:
  publish-release:
```

---

## Android APK 打包（签名版）

### 前置 Secrets

在仓库 Settings > Secrets and variables > Actions 中配置：

| Secret | 说明 |
|---|---|
| `KEYSTORE_PASSWORD` | keystore 密码 |
| `KEY_PASSWORD` | key 密码 |
| `KEY_ALIAS` | key alias |
| `KEYSTORE_FILE` | keystore 文件 base64 编码 |

### GitHub Actions Android Job

```yaml
  build-android:
    name: Build Android APK
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: 'gradle'

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: 'stable'
          cache: true

      - run: flutter pub get

      - name: Create key.properties
        run: |
          echo "storePassword=${{ secrets.KEYSTORE_PASSWORD }}" > android/key.properties
          echo "keyPassword=${{ secrets.KEY_PASSWORD }}" >> android/key.properties
          echo "keyAlias=${{ secrets.KEY_ALIAS }}" >> android/key.properties
          echo "${{ secrets.KEYSTORE_FILE }}" | base64 -d > android/app/release.jks

      - run: flutter build apk --release

      - uses: actions/upload-artifact@v4
        with:
          name: android-apk
          path: build/app/outputs/flutter-apk/app-release.apk
          retention-days: 7
```

---

## macOS DMG 打包

```yaml
  build-macos:
    name: Build macOS
    runs-on: macos-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: 'stable'
          cache: true

      - run: flutter pub get
      - run: cd macos && pod install && cd ..
      - run: flutter build macos --release

      - name: Install create-dmg
        run: |
          if ! command -v create-dmg &> /dev/null; then
            brew install create-dmg
          fi

      - name: Prepare and Create DMG
        run: |
          APP_PATH="build/macos/Build/Products/Release/<AppName>.app"
          DMG_PATH="<AppName>-macos.dmg"

          xattr -cr "$APP_PATH"
          chmod +x "$APP_PATH/Contents/MacOS/<AppName>"

          create-dmg \
            --volname "<AppName>" \
            --window-pos 200 200 \
            --window-size 600 400 \
            --icon-size 80 \
            --icon "<AppName>.app" 150 200 \
            --app-drop-link 450 200 \
            --hide-extension "<AppName>.app" \
            --format UDZO \
            "$DMG_PATH" \
            "$APP_PATH"

      - uses: actions/upload-artifact@v4
        with:
          name: macos-dmg
          path: <AppName>-macos.dmg
          retention-days: 7
```

---

## Windows MSI 打包（WiX Toolset v3）

### WiX 文件目录

```
wix/
└── <AppName>.wxs
```

### WiX 模板（必含桌面快捷方式）

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
  <Product Id="*"
           Name="<AppName>"
           Language="1033"
           Version="$(var.Version)"
           Manufacturer="<Manufacturer>"
           UpgradeCode="<固定GUID>">

    <Package InstallerVersion="200"
             Compressed="yes"
             InstallScope="perMachine"
             Platform="x64" />

    <MajorUpgrade DowngradeErrorMessage="A newer version of <AppName> is already installed." />
    <MediaTemplate EmbedCab="yes" />

    <Directory Id="TARGETDIR" Name="SourceDir">
      <Directory Id="ProgramFiles64Folder">
        <Directory Id="INSTALLFOLDER" Name="<AppName>" />
      </Directory>
      <Directory Id="ProgramMenuFolder">
        <Directory Id="ApplicationProgramsFolder" Name="<AppName>" />
      </Directory>
      <!-- 必须显式声明 DesktopFolder -->
      <Directory Id="DesktopFolder" />
    </Directory>

    <!-- 开始菜单快捷方式 -->
    <DirectoryRef Id="ApplicationProgramsFolder">
      <Component Id="ApplicationShortcut" Guid="*">
        <Shortcut Id="ApplicationStartMenuShortcut"
                  Name="<AppName>"
                  Description="..."
                  Target="[INSTALLFOLDER]<exe_name>.exe"
                  WorkingDirectory="INSTALLFOLDER" />
        <RemoveFolder Id="CleanUpShortCut" Directory="ApplicationProgramsFolder" On="uninstall" />
        <RegistryValue Root="HKCU" Key="Software\<Manufacturer>\<AppName>" Name="installed" Type="integer" Value="1" KeyPath="yes" />
      </Component>
    </DirectoryRef>

    <!-- 桌面快捷方式（不要遗漏） -->
    <DirectoryRef Id="DesktopFolder">
      <Component Id="DesktopShortcut" Guid="*">
        <Shortcut Id="DesktopShortcut"
                  Name="<AppName>"
                  Description="..."
                  Target="[INSTALLFOLDER]<exe_name>.exe"
                  WorkingDirectory="INSTALLFOLDER" />
        <RegistryValue Root="HKCU" Key="Software\<Manufacturer>\<AppName>" Name="desktop" Type="integer" Value="1" KeyPath="yes" />
      </Component>
    </DirectoryRef>

    <Feature Id="MainApplication" Title="<AppName>" Level="1">
      <ComponentGroupRef Id="ProductComponents" />
      <ComponentRef Id="ApplicationShortcut" />
      <ComponentRef Id="DesktopShortcut" />
    </Feature>

    <UIRef Id="WixUI_InstallDir" />
    <Property Id="WIXUI_INSTALLDIR" Value="INSTALLFOLDER" />
  </Product>
</Wix>
```

### GitHub Actions Windows Job

```yaml
  build-windows:
    name: Build Windows
    runs-on: windows-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: 'stable'
          cache: true

      - run: flutter pub get
      - run: flutter config --enable-windows-desktop
      - run: flutter build windows --release

      # GitHub Actions windows-latest runner 已预装 WiX v3.14，不要 choco install
      - name: Verify WiX Toolset
        shell: pwsh
        run: Get-Command heat, candle, light

      - name: Generate WiX components
        shell: pwsh
        run: |
          $buildDir = "build\windows\x64\runner\Release"
          if (!(Test-Path $buildDir)) { $buildDir = "build\windows\runner\Release" }

          heat dir "$buildDir" `
            -cg ProductComponents -gg -scom -sreg -sfrag -srd -dr INSTALLFOLDER `
            -out "wix\components.wxs"

      - name: Build MSI
        shell: pwsh
        run: |
          $version = "${{ github.ref_name }}".TrimStart('v')
          $buildDir = "build\windows\x64\runner\Release"
          if (!(Test-Path $buildDir)) { $buildDir = "build\windows\runner\Release" }

          candle -arch x64 -dVersion="$version" `
            "wix\<AppName>.wxs" "wix\components.wxs" `
            -out "wix\obj\"

          # -b 参数必须指定，否则 light 找不到 SourceDir 下的文件
          light -ext WixUIExtension `
            -cultures:en-us `
            -b "$buildDir" `
            "wix\obj\<AppName>.wixobj" "wix\obj\components.wixobj" `
            -out "<AppName>-windows.msi"

      - uses: actions/upload-artifact@v4
        with:
          name: windows-msi
          path: <AppName>-windows.msi
          retention-days: 7
```

---

## Web 打包

```yaml
  build-web:
    name: Build Web
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: 'stable'
          cache: true

      - run: flutter pub get
      - run: flutter build web --release --no-web-resources-cdn

      - uses: actions/upload-artifact@v4
        with:
          name: web-build
          path: build/web
          retention-days: 7
```

---

## 发布 Job（统一发布所有平台）

```yaml
  publish-release:
    name: Publish Release
    runs-on: ubuntu-latest
    needs: [build-android, build-macos, build-windows, build-web]
    if: always() && needs.build-android.result == 'success' && needs.build-macos.result == 'success' && needs.build-windows.result == 'success' && needs.build-web.result == 'success'
    permissions:
      contents: write
    steps:
      - uses: actions/download-artifact@v4
        with:
          path: artifacts

      - name: Prepare release files
        run: |
          mkdir -p release_dist

          # Android
          find artifacts -name "app-release.apk" -exec cp {} release_dist/<AppName>-android.apk \;

          # macOS
          find artifacts -name "<AppName>-macos.dmg" -exec cp {} release_dist/ \;

          # Windows
          find artifacts -name "<AppName>-windows.msi" -exec cp {} release_dist/ \;

          # Web - 打包为 zip
          if [ -d "artifacts/web-build" ]; then
            cd artifacts/web-build && zip -r ../../release_dist/<AppName>-web.zip . && cd ../..
          fi

          ls -la release_dist/

      - uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ github.ref_name }}
          name: <AppName> ${{ github.ref_name }}
          draft: false
          prerelease: false
          generate_release_notes: true
          files: release_dist/*
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## 完整坑点清单

| 坑点 | 现象 | 解决方案 |
|---|---|---|
| WiX 路径硬编码 | `heat.exe` 找不到 | runner 已预装 WiX v3，使用 `Get-Command` 验证，不要硬编码 `C:\Program Files (x86)\...` |
| `heat --help` 失败 | Install WiX 步骤报错退出 | `heat` 不支持 `--help`，改用 `Get-Command heat` 验证存在性 |
| WiX v5 `wix build` 与 v3 混用 | 语法不兼容 | 统一使用 WiX v3 (`heat` + `candle` + `light`) |
| `light` 找不到源文件 | `error LGHT0103: cannot find file 'SourceDir\...'` | `light` 必须加 `-b "$buildDir"` 绑定路径 |
| exe 名称不一致 | MSI 中 Target 指向错误文件名 | 同步 `pubspec.yaml` name、`windows/CMakeLists.txt` BINARY_NAME、`windows/runner/Runner.rc` OriginalFilename |
| 缺少桌面快捷方式 | 安装后只有开始菜单快捷方式 | `.wxs` 中必须显式声明 `<Directory Id="DesktopFolder" />` 并添加 `DirectoryRef` + `Component` + `Feature` 引用 |
| `wix/` 目录未提交 | CI 找不到 `.wxs` 文件 | 确保 `wix/` 目录已 `git add` 并提交到仓库 |
| Android 签名失败 | `key.properties` 不存在 | 在 CI 中动态创建 `android/key.properties` 和 `release.jks` |
| macOS pod install 失败 | 缺少 CocoaPods 依赖 | 在 `flutter build macos` 之前运行 `cd macos && pod install` |

---

## 快速检查清单

创建或修改打包方案时，逐项确认：

- [ ] Android `key.properties` 和 `release.jks` 通过 Secrets 注入
- [ ] macOS `pod install` 在 build 之前执行
- [ ] `wix/<AppName>.wxs` 包含 `DesktopFolder` 和 `DesktopShortcut`
- [ ] `wix/<AppName>.wxs` 的 `Target` 指向正确的 exe 文件名
- [ ] `windows/CMakeLists.txt` `BINARY_NAME` 与 pubspec name 一致
- [ ] GitHub Actions 使用 `Get-Command` 验证 WiX 而非硬编码路径
- [ ] `light` 命令包含 `-b "$buildDir"`
- [ ] `publish-release` 的 `needs` 包含所有 build job
- [ ] tag 格式为 `v*` 以触发 Release workflow
