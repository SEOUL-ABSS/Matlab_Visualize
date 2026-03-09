function logger = create_logger(logDir, sessionName)
%CREATE_LOGGER Create a simple file-backed logger.
%   logger = CREATE_LOGGER()
%   logger = CREATE_LOGGER(logDir, sessionName)

if nargin < 1 || isempty(logDir)
    logDir = fullfile('data', 'output', 'logs');
end
if nargin < 2 || isempty(sessionName)
    sessionName = 'session';
end

validateattributes(logDir, {'char', 'string'}, {'nonempty'}, mfilename, 'logDir', 1);
validateattributes(sessionName, {'char', 'string'}, {'nonempty'}, mfilename, 'sessionName', 2);

logDir = char(logDir);
sessionName = char(sessionName);
if ~exist(logDir, 'dir')
    mkdir(logDir);
end

ts = datestr(now, 'yyyymmdd_HHMMSS');
filePath = fullfile(logDir, sprintf('%s_%s.log', sessionName, ts));

fid = fopen(filePath, 'a');
if fid < 0
    error('create_logger:OpenFailed', 'Failed to create log file: %s', filePath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '[%s] [INFO] Logger initialized (%s)\n', datestr(now, 31), sessionName);

logger = struct(...
    'filePath', filePath, ...
    'sessionName', sessionName, ...
    'createdAt', datetime('now'));
end
