# Architecture

GamePorter is an orchestration layer, not a Windows implementation from scratch.

Windows game
→ compatibility runtime (Wine/GPTK)
→ DirectX translation/runtime components
→ Metal
→ Apple GPU

The launcher owns game profiles, prefixes, runtime selection, logs and future performance profiles.
