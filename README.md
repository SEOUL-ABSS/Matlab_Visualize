# Matlab_Visualize

Modular MATLAB project for signal-processing debugging and monitoring workflows.

## Project structure

- `src/app/` app-shell state and workflow orchestration.
- `src/pipeline/` processing pipeline execution and validation.
- `src/processing/` signal-processing algorithms and spatial placeholders.
- `src/visualization/` rendering functions (plot1d + dashboard shell).
- `src/io/` logging and persistence helpers.
- `tests/` MATLAB `matlab.unittest` test suites.
- `scripts/` developer scripts.
- `data/output/` generated logs and exports.

## First app-shell step

- Shared app/session state via `create_app_state`.
- Main view selector via `select_main_view`.
- Dashboard shell with:
  - one main view
  - summary card
  - frame quality card
  - event/status strip
- Frame selection/stepping and synchronized summaries.
- Cached rendering paths to avoid recomputation in plotting functions.

## Current main views

- Spectrum
- Waterfall
- Peak Trend
- Compare
- Frame Quality
- Bearing Map (placeholder)

## Getting started (MATLAB)

```matlab
addpath(genpath('src'))
run_smoke
addpath('scripts')
run_all_tests
```

## License

Apache 2.0 (see `LICENSE`).
