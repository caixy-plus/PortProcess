---
name: flutter-github-workflows
description: Flutter 桌面应用跨平台打包与 GitHub Actions 发布方案。覆盖 Windows MSI（WiX v3）、macOS DMG、Android APK 的 CI/CD 完整配置，包含所有已知坑点与修复方案。
user-invocable: true
---

# Flutter 桌面应用跨平台打包与发布 Skill

## 适用场景

- Flutter 桌面应用（Windows + macOS）需要打包成可安装格式
- 需要通过 GitHub Actions 自动构建并发布 Release
- 需要避免已知的 WiX / GitHub Actions 平台坑点

## 前置检查

1. `pubspec.yaml` 中 `name` 字段决定 Windows 构建产物 exe 名称
2. `windows/CMakeLists.txt` 中的 `BINARY_NAME` 必须与 `pubspec.yaml` 的 `name` 一致
3. `windows/runner/Runner.rc` 中的 `OriginalFilename` 也需同步
4. GitHub Actions 触发条件：`push tags: 'v*'`

## Windows MSI 打包（WiX Toolset v3）

### 目录结构

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

### GitHub Actions Windows Job 模板

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

## macOS DMG 打包

```yaml
  build-macos:
    name: Build macOS
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: 'stable'
          cache: true

      - run: flutter pub get
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

## 发布 Job 模板

```yaml
  publish-release:
    name: Publish Release
    runs-on: ubuntu-latest
    needs: [build-macos, build-windows]
    if: always() && needs.build-macos.result == 'success' && needs.build-windows.result == 'success'
    steps:
      - uses: actions/download-artifact@v4
        with:
          path: artifacts

      - name: Prepare release files
        run: |
          mkdir -p release_dist
          find artifacts -name "<AppName>-macos.dmg" -exec cp {} release_dist/ \;
          find artifacts -name "<AppName>-windows.msi" -exec cp {} release_dist/ \;
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

## 快速检查清单

创建或修改打包方案时，逐项确认：

- [ ] `wix/<AppName>.wxs` 包含 `DesktopFolder` 和 `DesktopShortcut`
- [ ] `wix/<AppName>.wxs` 的 `Target` 指向正确的 exe 文件名
- [ ] `windows/CMakeLists.txt` `BINARY_NAME` 与 pubspec name 一致
- [ ] GitHub Actions 使用 `Get-Command` 验证 WiX 而非硬编码路径
- [ ] `light` 命令包含 `-b "$buildDir"`
- [ ] tag 格式为 `v*` 以触发 Release workflow
