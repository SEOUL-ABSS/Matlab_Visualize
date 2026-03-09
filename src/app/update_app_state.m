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

% Update waterfall cache from FFT spectrum.
if isfield(result, 'features') && isfield(result.features, 'spectrum')
    spectrum = result.features.spectrum;
    if isempty(state.waterfall.frequencyHz)
        state.waterfall.frequencyHz = spectrum.frequencyHz;
        state.waterfall.magnitudeMatrix = spectrum.magnitude(:)';
    else
        state.waterfall.magnitudeMatrix(end+1, :) = spectrum.magnitude(:)'; %#ok<AGROW>
    end
end

x = result.raw.data(:);
peakAmp = max(abs(x));
rmsValue = sqrt(mean(x.^2));
clippingRatio = mean(abs(x) >= 0.98 * max(peakAmp, eps));
if clippingRatio > 0.10
    qualityLabel = 'poor';
elseif clippingRatio > 0.02
    qualityLabel = 'fair';
else
    qualityLabel = 'good';
end

quality = struct(...
    'rms', rmsValue, ...
    'peakAmplitude', peakAmp, ...
    'clippingRatio', clippingRatio, ...
    'qualityLabel', qualityLabel);
state.frame_quality_summary = quality;
state.quality_history = [state.quality_history; quality]; %#ok<AGROW>

if isfield(result, 'peaks') && isfield(result.peaks, 'count') && result.peaks.count > 0
    state.peak_trend(end+1, 1) = result.peaks.items(1).y; %#ok<AGROW>
else
    state.peak_trend(end+1, 1) = NaN; %#ok<AGROW>
end

% Keep bearing map placeholder contract synchronized with cached history.
state.bearing = build_bearing_maps_placeholder(state);

% Cache per-frame payload for inspection views without recomputation.
snapshot = struct(...
    'frameIdx', state.current_frame_idx, ...
    'input', inputData, ...
    'result', result, ...
    'quality', quality, ...
    'timestamp', datetime('now'));
state.frame_history{end+1} = snapshot;

entry = struct('time', datetime('now'), 'level', 'INFO', ...
    'message', sprintf('Frame %d processed', state.current_frame_idx));
state.event_log{end+1} = entry;
state.last_update_time = entry.time;
state.last_issue = struct('level', '', 'message', '');
end
