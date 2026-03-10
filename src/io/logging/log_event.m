function entry = log_event(logger, level, message, meta)
%LOG_EVENT Append a timestamped event to logger.filePath.
%   entry = LOG_EVENT(logger, level, message)
%   entry = LOG_EVENT(logger, level, message, meta)

if nargin < 4 || isempty(meta)
    meta = struct();
end

if ~isstruct(logger) || ~isfield(logger, 'filePath')
    error('log_event:InvalidLogger', 'logger must be a struct with filePath.');
end
validateattributes(level, {'char', 'string'}, {'nonempty'}, mfilename, 'level', 2);
validateattributes(message, {'char', 'string'}, {'nonempty'}, mfilename, 'message', 3);
if ~isstruct(meta)
    error('log_event:InvalidMeta', 'meta must be a struct.');
end

level = upper(char(level));
message = char(message);
ts = datestr(now, 31);

metaText = '';
metaFields = fieldnames(meta);
if ~isempty(metaFields)
    pairs = cell(1, numel(metaFields));
    for i = 1:numel(metaFields)
        k = metaFields{i};
        v = meta.(k);
        if isnumeric(v) || islogical(v)
            vText = mat2str(v);
        elseif isstring(v) || ischar(v)
            vText = char(v);
        else
            vText = class(v);
        end
        pairs{i} = sprintf('%s=%s', k, vText);
    end
    metaText = [' {' strjoin(pairs, ', ') '}'];
end

fid = fopen(logger.filePath, 'a');
if fid < 0
    error('log_event:OpenFailed', 'Failed to open log file: %s', logger.filePath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
line = sprintf('[%s] [%s] %s%s', ts, level, message, metaText);
fprintf(fid, '%s\n', line);

entry = struct('timestamp', datetime('now'), 'level', level, 'message', message, 'meta', meta, 'line', line);
end
