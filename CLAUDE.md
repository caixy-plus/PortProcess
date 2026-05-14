# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PortProcess is a Flutter desktop application for managing local network ports. It lists processes with bound ports and allows killing them. Supports macOS and Windows (Linux support was removed from releases).

## Common Commands

```bash
# Run the app
flutter run

# Build for desktop platforms
flutter build macos
flutter build windows

# Lint
flutter analyze

# Run tests
flutter test
flutter test test/widget_test.dart
```

## Architecture

### Data Flow

The app follows a simple service-oriented pattern:

- **`ProcessService`** (`lib/services/process_service.dart`) — A singleton that shells out to platform-specific CLI commands to fetch listening processes and kill them. This is the core of the app; all platform abstraction lives here.
- **`ProcessInfo`** (`lib/models/process_info.dart`) — A mutable data class. Note that `name` is **not** `final` because Windows fetches process names in a second pass via `tasklist` after parsing `netstat` output.
- **`HomeScreen`** (`lib/screens/home_screen.dart`) — The only screen. It manages the custom title bar (via `window_manager` with `TitleBarStyle.hidden`), auto-refreshes the process list every 5 seconds, and handles search debouncing.

### Platform Commands

| Platform | List Ports | Kill Process |
|----------|-----------|--------------|
| macOS    | `lsof -iTCP -sTCP:LISTEN -P -n` | `kill -9` |
| Linux    | `ss -tlnp` (fallback: `netstat -tlnp`) | `kill -9` |
| Windows  | `netstat -ano` + `tasklist` | `taskkill /F /PID` |

### Custom Title Bar

The app uses a fully custom title bar because `TitleBarStyle.hidden` is set in `main.dart`. Window controls (minimize, maximize/restore, close) are rendered in Flutter via `_WindowControlButton`. The title bar supports drag-to-move (`windowManager.startDragging()`) and double-click to maximize/restore.

## Known Quirks

- **`test/widget_test.dart` is stale.** It references `MyApp`, which was renamed to `PortProcessApp`. There are no meaningful tests yet.
- **Process name is nullable and mutable.** Not all platforms return process names in the initial listing; Windows resolves them asynchronously via `tasklist`.
- **`window_manager` lifecycle:** `HomeScreen` implements `WindowListener` to track maximize/restore state for updating the title bar button icons.

## Release Process

Releases are built via GitHub Actions (`.github/workflows/release.yml`) and triggered by pushing a version tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The workflow builds a macOS `.dmg` and a Windows `.zip`, then publishes a GitHub Release with both artifacts. Flutter version is pinned to `3.27.0` in the workflow.
