function [state, artifacts] = export_session_artifacts(state, fig, outputRoot, baseName)
%EXPORT_SESSION_ARTIFACTS Export figure, current result, snapshot and summary.

if nargin < 2
    fig = [];
end
if nargin < 3 || isempty(outputRoot)
    outputRoot = fullfile('data', 'output');
end
if nargin < 4 || isempty(baseName)
    baseName = 'session';
end

validateattributes(outputRoot, {'char', 'string'}, {'nonempty'}, mfilename, 'outputRoot', 3);
validateattributes(baseName, {'char', 'string'}, {'nonempty'}, mfilename, 'baseName', 4);

outputRoot = char(outputRoot);
baseName = char(baseName);

artifacts = struct(...
    'figurePng', '', ...
    'resultMat', '', ...
    'snapshotMat', '', ...
    'summaryCsv', '');

% Current main-view figure export (if applicable).
if ~isempty(fig) && ishandle(fig)
    artifacts.figurePng = export_dashboard_figure(fig, fullfile(outputRoot, 'figures'), [baseName '_view']);
    state = update_event_log(state, 'INFO', 'Dashboard figure exported', struct('file', artifacts.figurePng));
else
    state = update_event_log(state, 'INFO', 'Dashboard figure export skipped (no valid figure)', struct());
end

% Current structured result export.
artifacts.resultMat = save_result_mat(state.current_result, fullfile(outputRoot, 'results'), [baseName '_result']);
state = update_event_log(state, 'INFO', 'Current result exported', struct('file', artifacts.resultMat));

% Full session snapshot export.
artifacts.snapshotMat = export_state_snapshot(state, fullfile(outputRoot, 'snapshots'), [baseName '_snapshot']);
state = update_event_log(state, 'INFO', 'Session snapshot exported', struct('file', artifacts.snapshotMat));

% Compact summary export.
artifacts.summaryCsv = export_result_summary(state, fullfile(outputRoot, 'summaries'), [baseName '_summary']);
state = update_event_log(state, 'INFO', 'Session summary exported', struct('file', artifacts.summaryCsv));

state.last_exports = artifacts;
if ~isfield(state.current_result, 'log') || ~isstruct(state.current_result.log)
    state.current_result.log = struct();
end
state.current_result.log.io = artifacts;
end
