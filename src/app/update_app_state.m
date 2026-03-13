function state = update_app_state(state, inputData, cfg)
%UPDATE_APP_STATE Process one frame and update shared app state.

if nargin < 3 || isempty(cfg)
    cfg = get_default_config();
end

result = execute_pipeline(inputData, cfg);

state.current_frame_idx = state.current_frame_idx + 1;
state.selected_frame_idx = state.current_frame_idx;
state.current_input = inputData;
state.current_result = result;


% Update optional TCP metadata context when packet-like metadata is provided.
if isfield(inputData, 'meta') && isstruct(inputData.meta) && isfield(inputData.meta, 'packet')
    state = update_tcp_packet_context(state, inputData.meta.packet);
end

% Update waterfall cache from FFT spectrum.
if isfield(result, 'features') && isfield(result.features, 'spectrum')
    spectrum = result.features.spectrum;
    if isempty(state.waterfall.frequencyHz)
        state.waterfall.frequencyHz = spectrum.frequencyHz;
        state.waterfall.magnitudeMatrix = spectrum.magnitude(:)';
        state.waterfall.frame_indices = state.current_frame_idx;
    else
        state.waterfall.magnitudeMatrix(end+1, :) = spectrum.magnitude(:)'; %#ok<AGROW>
        state.waterfall.frame_indices(end+1) = state.current_frame_idx; %#ok<AGROW>
    end

    if isfield(state.waterfall, 'max_history_frames') && isfinite(state.waterfall.max_history_frames)
        maxRows = max(1, floor(state.waterfall.max_history_frames));
        rowCount = size(state.waterfall.magnitudeMatrix, 1);
        if rowCount > maxRows
            keepStart = rowCount - maxRows + 1;
            state.waterfall.magnitudeMatrix = state.waterfall.magnitudeMatrix(keepStart:end, :);
            state.waterfall.frame_indices = state.waterfall.frame_indices(keepStart:end);
        end
    end
end

quality = compute_frame_quality(inputData, result);
state.frame_quality_summary = quality;
state.quality_history = [state.quality_history; quality]; %#ok<AGROW>

detection = build_detection_summary(result, state.threshold_enabled, state.threshold_value);
state.detection_summary = detection;
state.detection_history{end+1} = detection;

trendEntry = struct(...
    'frameIdx', state.current_frame_idx, ...
    'strongestPeakFrequencyHz', detection.strongestPeakFrequencyHz, ...
    'strongestPeakMagnitude', detection.strongestPeakMagnitude);
state.peak_trend(end+1) = trendEntry; %#ok<AGROW>

% Keep bearing map placeholder contract synchronized with cached history.
state.bearing = build_bearing_maps_placeholder(state);

% Cache per-frame payload for inspection views without recomputation.
snapshot = struct(...
    'frameIdx', state.current_frame_idx, ...
    'input', inputData, ...
    'result', result, ...
    'quality', quality, ...
    'detection', detection, ...
    'timestamp', datetime('now'));
state.frame_history{end+1} = snapshot;

state = update_event_log(state, 'INFO', ...
    sprintf('Frame %d processed', state.current_frame_idx), ...
    struct('quality', quality.qualityLabel, 'peakHz', detection.strongestPeakFrequencyHz));

state.last_issue = struct('level', '', 'message', '');
state.last_error_or_warning = struct('level', '', 'message', '');
end
