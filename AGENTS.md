# AGENTS.md

## Project intent
This repository is evolving into a MATLAB signal-processing visualization and debugging application.
Treat it as a reusable internal tool, not a one-off demo.

## Core rules
- Preserve existing verified FFT, peak detection, and waterfall logic whenever possible.
- Separate processing from rendering.
- Do not recompute FFT or heavy features inside plotting functions.
- Prefer small, incremental diffs over broad rewrites.
- Prefer shared app/session state over scattered visualization state.

## UI direction
The application should evolve toward:
- one main view
- summary card
- frame quality card
- event log / status strip
- preset-based interaction

## Required presets
- Quick Check
- Detection
- History
- Debug

## Preferred views
- Spectrum
- Waterfall
- Peak Trend
- Compare
- Frame Quality
- Bearing Map (future-ready placeholder is acceptable)

## Implementation priorities
1. app/session state
2. app shell / dashboard
3. summary + quality + event visibility
4. frame synchronization across views
5. snapshot/export
6. TCP and bearing-oriented extensions later

## MATLAB validation policy
- If runnable MATLAB support is available in this environment, use it for validation.
- If runnable MATLAB support is not available, perform static consistency checks and clearly state validation limits.
- Do not claim runtime verification unless it was actually executed.

## Editing policy
- Keep function/file naming consistent.
- Minimize regressions in existing calculation paths.
- Update docs when architecture changes materially.

## Review guidelines
- Flag regressions in verified calculation paths as high priority.
- Treat broken state synchronization across views as important.
- Prefer maintainability and usability over adding extra standalone plots.
