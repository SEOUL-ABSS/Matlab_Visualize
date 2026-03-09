function state = create_app_state()
%CREATE_APP_STATE Initialize shared app/session state for dashboard workflow.

state = struct();
state.current_view = 'Spectrum';
state.current_preset = 'Quick Check';
state.current_frame_idx = 0;
state.selected_frame_idx = 0;
state.threshold_enabled = false;
state.threshold_value = 0.5;

state.current_input = struct();
state.current_result = struct();

% Cached history for frame-centric inspection views.
state.waterfall = struct(...
    'frequencyHz', [], ...
    'magnitudeMatrix', [], ...
    'hold_enabled', false, ...
    'hold_frame_indices', []);
state.frame_history = {};
state.quality_history = [];
state.peak_trend = [];
state.bearing = build_bearing_maps_placeholder(state);

state.frame_quality_summary = struct(...
    'rms', NaN, ...
    'peakAmplitude', NaN, ...
    'clippingRatio', NaN, ...
    'qualityLabel', 'unknown');

state.event_log = {};
state.last_update_time = NaT;
state.last_issue = struct('level', '', 'message', '');
end
