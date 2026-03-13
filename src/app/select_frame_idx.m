function state = select_frame_idx(state, frameIdx)
%SELECT_FRAME_IDX Select a processed frame index for synchronized inspection.

validateattributes(frameIdx, {'numeric'}, {'scalar', 'integer', 'nonnegative'}, mfilename, 'frameIdx', 2);
if frameIdx == 0
    state.selected_frame_idx = 0;
    return;
end

if frameIdx > state.current_frame_idx
    error('select_frame_idx:OutOfRange', 'frameIdx (%d) exceeds current_frame_idx (%d).', frameIdx, state.current_frame_idx);
end

state.selected_frame_idx = frameIdx;
state = update_event_log(state, 'INFO', sprintf('Selected frame: %d', frameIdx));
end
