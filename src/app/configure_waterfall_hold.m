function state = configure_waterfall_hold(state, holdEnabled, holdFrameIndices)
%CONFIGURE_WATERFALL_HOLD Configure optional hold overlays for waterfall view.

if nargin < 2 || isempty(holdEnabled)
    holdEnabled = false;
end
if nargin < 3 || isempty(holdFrameIndices)
    holdFrameIndices = [];
end

validateattributes(holdEnabled, {'logical', 'numeric'}, {'scalar'}, mfilename, 'holdEnabled', 2);
validateattributes(holdFrameIndices, {'numeric'}, {'vector', 'integer', 'positive'}, mfilename, 'holdFrameIndices', 3);

maxFrame = state.current_frame_idx;
holdFrameIndices = holdFrameIndices(holdFrameIndices <= maxFrame);

state.waterfall.hold_enabled = logical(holdEnabled);
state.waterfall.hold_frame_indices = holdFrameIndices(:)';

entry = struct('time', datetime('now'), 'level', 'INFO', ...
    'message', sprintf('Waterfall hold updated: enabled=%d, count=%d', state.waterfall.hold_enabled, numel(holdFrameIndices)));
state.event_log{end+1} = entry;
state.last_update_time = entry.time;
end
