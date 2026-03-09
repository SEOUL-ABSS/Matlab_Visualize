function filePath = export_state_snapshot(state, outputDir, baseName)
%EXPORT_STATE_SNAPSHOT Save full app state snapshot to MAT file.

if nargin < 2 || isempty(outputDir)
    outputDir = fullfile('data', 'output', 'snapshots');
end
if nargin < 3 || isempty(baseName)
    baseName = 'state_snapshot';
end

if ~isstruct(state)
    error('export_state_snapshot:InvalidState', 'state must be a struct.');
end

validateattributes(outputDir, {'char', 'string'}, {'nonempty'}, mfilename, 'outputDir', 2);
validateattributes(baseName, {'char', 'string'}, {'nonempty'}, mfilename, 'baseName', 3);

outputDir = char(outputDir);
baseName = char(baseName);
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

ts = datestr(now, 'yyyymmdd_HHMMSS');
filePath = fullfile(outputDir, sprintf('%s_%s.mat', baseName, ts));
snapshot = state; %#ok<NASGU>
save(filePath, 'snapshot');
end
