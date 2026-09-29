# GamePorter

GamePorter is a macOS Apple Silicon game launcher and compatibility runtime manager for Windows games.

## Goal

Provide a native-feeling launcher around existing compatibility technologies such as Wine and Apple's game-porting tooling, rather than implementing a Windows emulator from scratch.

## MVP

- Detect Windows `.exe` games
- Manage per-game profiles and prefixes
- Detect installed compatibility runtimes
- Launch games with the selected runtime
- Keep per-game logs
- Provide a foundation for DX11/DX12 translation and performance profiles

## Architecture

Windows game → compatibility runtime → DirectX translation → Metal → Apple GPU

## Status

Early MVP. Compatibility varies by game, dependencies and anti-cheat systems.
