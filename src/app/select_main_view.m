function state = select_main_view(state, viewName)
%SELECT_MAIN_VIEW Select the active dashboard main view.

validateattributes(viewName, {'char', 'string'}, {'nonempty'}, mfilename, 'viewName', 2);
viewName = char(viewName);

allowedViews = {'Spectrum', 'Waterfall', 'Peak Trend', 'Compare', 'Frame Quality', 'Bearing Map'};
if ~ismember(viewName, allowedViews)
    error('select_main_view:UnknownView', 'Unknown main view: %s', viewName);
end

state.current_view = viewName;
entry = struct('time', datetime('now'), 'level', 'INFO', 'message', sprintf('View selected: %s', viewName));
state.event_log{end+1} = entry;
state.last_update_time = entry.time;
end
