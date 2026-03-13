function state = update_event_log(state, level, message, details)
%UPDATE_EVENT_LOG Append an event entry to shared app-state event log.

if nargin < 4 || isempty(details)
    details = struct();
end

entry = struct(...
    'time', datetime('now'), ...
    'level', upper(char(level)), ...
    'message', char(message), ...
    'details', details);

state.event_log{end+1} = entry;
state.last_update_time = entry.time;
end
