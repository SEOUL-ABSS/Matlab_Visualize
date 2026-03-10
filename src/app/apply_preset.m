function state = apply_preset(state, presetName)
%APPLY_PRESET Apply app preset to shared state.

validateattributes(presetName, {'char', 'string'}, {'nonempty'}, mfilename, 'presetName', 2);
preset = get_preset_definition(presetName);

state.current_preset = preset.name;
state.current_view = preset.defaultMainView;
state.threshold_enabled = preset.thresholdEnabled;
state.threshold_value = preset.thresholdValue;
state.panel_emphasis = preset.emphasis;

state = update_event_log(state, 'INFO', sprintf('Preset applied: %s', preset.name), ...
    struct('defaultView', preset.defaultMainView, 'thresholdEnabled', preset.thresholdEnabled));
end
