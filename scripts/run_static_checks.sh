#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Basic repository consistency checks for environments without MATLAB.
rg "function\s+run_smoke_validation" scripts/run_smoke_validation.m >/dev/null
rg "run_local_validation" scripts/run_local_validation.m >/dev/null
rg "setup_project_paths" scripts/setup_project_paths.m README.md scripts/run_smoke_validation.m >/dev/null
rg "example_function_groups_usage" scripts/example_function_groups_usage.m README.md >/dev/null
rg "example_underwater_exhibition_scenario" scripts/example_underwater_exhibition_scenario.m README.md >/dev/null
rg "export_session_artifacts" src/app/run_smoke.m tests/test_pipeline_smoke.m README.md docs/ARCHITECTURE.md >/dev/null
rg "last_exports" src/app/create_app_state.m src/app/export_session_artifacts.m tests/test_pipeline_smoke.m >/dev/null
rg "update_tcp_packet_context" src/app/update_app_state.m tests/test_pipeline_smoke.m docs/ARCHITECTURE.md README.md >/dev/null

# TCP extension core files
rg "classdef\s+EthTcpServer" src/io/tcp/EthTcpServer.m >/dev/null
rg "classdef\s+EthTcpStructRecorder" src/io/tcp/EthTcpStructRecorder.m >/dev/null
rg "classdef\s+EthTcpSimpleLogger" src/io/tcp/EthTcpSimpleLogger.m >/dev/null
rg "function\s+eth_rx_pipeline" src/io/tcp/eth_rx_pipeline.m >/dev/null
rg "function\s+selftest_strip_preprocessor_and_schema" tests/selftest_strip_preprocessor_and_schema.m >/dev/null

# Ensure no whitespace/errors in diff-able text files if invoked in CI/pre-commit context.
git diff --check >/dev/null

echo "Static checks passed."
