function state = run_smoke()
%RUN_SMOKE Run deterministic app-shell smoke flow.

logger = create_logger(fullfile('data', 'output', 'logs'), 'run_smoke');
log_event(logger, 'INFO', 'Smoke app-shell run started');

cfg = get_default_config();
state = create_app_state();
state = apply_preset(state, 'Quick Check');
state = select_main_view(state, 'Peak Trend');

nFrames = 3;
for k = 1:nFrames
    inputData = struct();
    x = (0:255)';
    inputData.data = sin(2*pi*x/64 + 0.2*k) + 0.4*sin(2*pi*x/16);
    inputData.fs = 1024;
    inputData.timestamp = datetime(2024, 1, 1, 0, 0, k, 'TimeZone', 'UTC');
    inputData.type = 'timeseries';
    inputData.meta = struct('source', 'run_smoke', 'frameId', k);

    log_event(logger, 'INFO', 'Frame update started', struct('frameIdx', k, 'samples', numel(inputData.data)));
    state = update_app_state(state, inputData, cfg);
    log_event(logger, 'INFO', 'Frame update completed', struct('frameIdx', state.current_frame_idx));
end

state = step_frame(state, -1);
state = configure_waterfall_hold(state, true, [1 state.selected_frame_idx]);
state = select_main_view(state, 'Waterfall');
render_dashboard(state);

outputMat = save_result_mat(state.current_result, fullfile('data', 'output'), 'smoke_result');
snapshotFile = export_state_snapshot(state, fullfile('data', 'output', 'snapshots'), 'smoke_snapshot');
summaryFile = export_result_summary(state, fullfile('data', 'output', 'summaries'), 'smoke_summary');

log_event(logger, 'INFO', 'Result exported', struct('matFile', outputMat));
log_event(logger, 'INFO', 'Snapshot exported', struct('snapshotFile', snapshotFile));
log_event(logger, 'INFO', 'Summary exported', struct('summaryFile', summaryFile));

state.current_result.log.io = struct(...
    'logFile', logger.filePath, ...
    'matFile', outputMat, ...
    'snapshotFile', snapshotFile, ...
    'summaryFile', summaryFile);

fprintf('run_smoke completed. Current=%d, Selected=%d, View=%s, Preset=%s\n', ...
    state.current_frame_idx, state.selected_frame_idx, state.current_view, state.current_preset);
end
