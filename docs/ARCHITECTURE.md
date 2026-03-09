# Architecture

This repository is evolving toward a reusable signal-processing visualization/debugging application.

## Layers

- `src/app`: app shell state, presets, frame selection/stepping, and frame update workflow.
- `src/pipeline`: input validation and core processing orchestration.
- `src/io`: logging and persistence.
- `src/processing`: deterministic FFT/feature logic and spatial map placeholders.
- `src/visualization`: rendering only (no FFT computation in plotting functions).
- `src/config`: configuration providers only.
- `src/utils`: shared helper utilities.

## First app-shell step (implemented)

- shared app/session state
- main view selector
- summary card
- frame quality card
- event/status strip

## Shared state contract (app shell)

`state` fields:
- `current_view`
- `current_preset`
- `current_frame_idx`
- `selected_frame_idx`
- `threshold_enabled`
- `threshold_value`
- `current_input`
- `current_result`
- `waterfall`
  - `frequencyHz`
  - `magnitudeMatrix`
  - `hold_enabled`
  - `hold_frame_indices`
- `frame_history`
- `quality_history`
- `peak_trend`
- `bearing` (placeholder contract)
- `frame_quality_summary`
- `event_log`
- `last_update_time`
- `last_issue`

## Dashboard main views

- Spectrum
- Waterfall (selected marker + optional hold overlays)
- Peak Trend
- Compare
- Frame Quality
- Bearing Map (placeholder)

## Intentional deferments

- TCP socket runtime + buffering implementation
- packet metadata dashboard views
- full bearing processing algorithms
- advanced interaction controls and multi-window tooling
- persistent multi-session/project management
