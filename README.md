# GamePorter

GamePorter is a macOS Apple Silicon launcher and compatibility-runtime manager for Windows games.

It does **not** try to implement Windows from scratch. It orchestrates existing compatibility technology such as Wine and Apple's Game Porting Toolkit, with per-game prefixes, graphics configuration, runtime detection, preflight checks and logs.

## Architecture

Windows game (.exe)  
→ GamePorter  
→ Wine / Game Porting Toolkit  
→ DXVK or D3DMetal  
→ Metal  
→ Apple GPU

## Current MVP

- Game registry stored under `~/Library/Application Support/GamePorter`
- Per-game Wine prefixes
- Per-game logs
- Automatic runtime selection
- GPTK and Wine detection
- D3DMetal detection with `GAMEPORTER_D3DMETAL` override
- Runtime architecture detection
- Windows PE architecture detection (x86 / x86_64 / ARM64)
- Compatibility preflight before launch
- DXVK / D3DMetal graphics profiles
- Esync / Fsync / optional DXVK HUD environment setup
- GitHub Actions build + test on macOS

## CLI

Build:

```bash
swift build
```

Detect runtimes:

```swift
.build/debug/gameporter list-runtimes
```

Register a game:

```bash
.build/debug/gameporter add "My Game" "/path/to/Game.exe"
```

Check compatibility without launching:

```bash
.build/debug/gameporter check "My Game"
```

Launch:

```bash
.build/debug/gameporter run "My Game"
```

Other commands:

```text
list-games
info <name>
help
```

## Environment overrides

`GAMEPORTER_GPTK` can point to a GPTK installation root.

`GAMEPORTER_WINE` can point directly to a Wine executable.

`GAMEPORTER_D3DMETAL` can point directly to `D3DMetal.framework` or another D3DMetal installation path.

## Important compatibility limits

GamePorter is a launcher/runtime layer, not a guarantee that every Windows game will run on macOS.

Games can still fail because of anti-cheat, launchers, DRM, missing Windows components, unsupported DirectX features, 32-bit dependencies, networking requirements, or runtime-specific bugs.

Fortnite in particular should be treated as a compatibility investigation rather than a promised supported title.

## Status

MVP implementation is in place. The next layer is game-specific compatibility profiles, installer/import flows, automatic dependency setup, performance profiles and a native SwiftUI frontend.
