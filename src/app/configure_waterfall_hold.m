function state = configure_waterfall_hold(state, holdEnabled, holdFrameIndices, overlayOpts)
%CONFIGURE_WATERFALL_HOLD Configure optional hold overlays for waterfall view.

if nargin < 2 || isempty(holdEnabled)
    holdEnabled = false;
end
if nargin < 3 || isempty(holdFrameIndices)
    holdFrameIndices = [];
end
if nargin < 4 || isempty(overlayOpts)
    overlayOpts = struct();
end

validateattributes(holdEnabled, {'logical', 'numeric'}, {'scalar'}, mfilename, 'holdEnabled', 2);
validateattributes(holdFrameIndices, {'numeric'}, {'vector', 'integer', 'positive'}, mfilename, 'holdFrameIndices', 3);
validateattributes(overlayOpts, {'struct'}, {'scalar'}, mfilename, 'overlayOpts', 4);

maxFrame = state.current_frame_idx;
holdFrameIndices = holdFrameIndices(holdFrameIndices <= maxFrame);

state.waterfall.hold_enabled = logical(holdEnabled);
state.waterfall.hold_frame_indices = holdFrameIndices(:)';

if ~isfield(state.waterfall, 'overlay') || ~isstruct(state.waterfall.overlay)
    state.waterfall.overlay = struct('showCurrentMarker', true, 'showMaxHold', false, 'showMeanHold', false);
end
if isfield(overlayOpts, 'showCurrentMarker')
    state.waterfall.overlay.showCurrentMarker = logical(overlayOpts.showCurrentMarker);
end
if isfield(overlayOpts, 'showMaxHold')
    state.waterfall.overlay.showMaxHold = logical(overlayOpts.showMaxHold);
end
if isfield(overlayOpts, 'showMeanHold')
    state.waterfall.overlay.showMeanHold = logical(overlayOpts.showMeanHold);
end

state = update_event_log(state, 'INFO', ...
    sprintf('Waterfall hold updated: enabled=%d, count=%d', state.waterfall.hold_enabled, numel(holdFrameIndices)));
end
