function state = step_frame(state, stepDelta)
%STEP_FRAME Move selected frame backward/forward for replay.
%   stepDelta < 0 : backward
%   stepDelta > 0 : forward

if nargin < 2 || isempty(stepDelta)
    stepDelta = 1;
end
validateattributes(stepDelta, {'numeric'}, {'scalar', 'integer'}, mfilename, 'stepDelta', 2);

if state.current_frame_idx == 0
    state.selected_frame_idx = 0;
    return;
end

if state.selected_frame_idx == 0
    baseIdx = state.current_frame_idx;
else
    baseIdx = state.selected_frame_idx;
end

newIdx = baseIdx + stepDelta;
newIdx = max(1, min(state.current_frame_idx, newIdx));

state = select_frame_idx(state, newIdx);
end
