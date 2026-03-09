function state = apply_preset(state, presetName)
%APPLY_PRESET Apply app preset to shared state.

validateattributes(presetName, {'char', 'string'}, {'nonempty'}, mfilename, 'presetName', 2);
presetName = char(presetName);

switch presetName
    case 'Quick Check'
        state.current_view = 'Spectrum';
        state.threshold_enabled = false;
        state.threshold_value = 0.5;
    case 'Detection'
        state.current_view = 'Spectrum';
        state.threshold_enabled = true;
        state.threshold_value = 0.2;
    case 'History'
        state.current_view = 'Waterfall';
        state.threshold_enabled = false;
        state.threshold_value = 0.5;
    case 'Debug'
        state.current_view = 'Frame Quality';
        state.threshold_enabled = true;
        state.threshold_value = 0.1;
    otherwise
        error('apply_preset:UnknownPreset', 'Unknown preset: %s', presetName);
end

state.current_preset = presetName;
state = append_event(state, 'INFO', sprintf('Preset applied: %s', presetName));
end

function state = append_event(state, level, message)
entry = struct('time', datetime('now'), 'level', level, 'message', message);
state.event_log{end+1} = entry;
state.last_update_time = entry.time;
end
