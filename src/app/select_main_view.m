function state = select_main_view(state, viewName)
%SELECT_MAIN_VIEW Select the active dashboard main view.

validateattributes(viewName, {'char', 'string'}, {'nonempty'}, mfilename, 'viewName', 2);
viewName = char(viewName);

allowedViews = {'Spectrum', 'Waterfall', 'Peak Trend', 'Compare', 'Frame Quality', 'Bearing Map', 'Bearing Frequency', 'Bearing Time'};
allowedViews = {'Spectrum', 'Waterfall', 'Peak Trend', 'Compare', 'Frame Quality', 'Bearing Map'};
if ~ismember(viewName, allowedViews)
    error('select_main_view:UnknownView', 'Unknown main view: %s', viewName);
end

state.current_view = viewName;

% Keep view switching lightweight: only UI emphasis changes, no recomputation.
state.panel_emphasis.mainView = true;
if strcmp(viewName, 'Frame Quality')
    state.panel_emphasis.qualityCard = true;
end
if strcmp(viewName, 'Spectrum') || strcmp(viewName, 'Peak Trend')
    state.panel_emphasis.summaryCard = true;
end

state = update_event_log(state, 'INFO', sprintf('View selected: %s', viewName));
entry = struct('time', datetime('now'), 'level', 'INFO', 'message', sprintf('View selected: %s', viewName));
state.event_log{end+1} = entry;
state.last_update_time = entry.time;
end
