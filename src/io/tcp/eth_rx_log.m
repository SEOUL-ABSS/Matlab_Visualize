function eth_rx_log(msg, meta, varargin)
%ETH_RX_LOG 수신 콜백 로그 래퍼.
%   eth_rx_log(msg, meta, 'Key','topic_10', 'LogFile','data/output/logs/topic10.log')
%   eth_rx_log('close')
%   eth_rx_log('reset')

persistent loggerMap
if isempty(loggerMap)
    loggerMap = containers.Map('KeyType','char','ValueType','any');
end

if nargin >= 1 && (ischar(msg) || isstring(msg))
    cmd = lower(char(msg));
    switch cmd
        case 'close'
            keys = loggerMap.keys;
            for i = 1:numel(keys)
                l = loggerMap(keys{i});
                if isa(l, 'EthTcpSimpleLogger')
                    l.close();
                end
            end
            return;
        case 'reset'
            keys = loggerMap.keys;
            for i = 1:numel(keys)
                l = loggerMap(keys{i});
                if isa(l, 'EthTcpSimpleLogger')
                    l.close();
                end
            end
            loggerMap = containers.Map('KeyType','char','ValueType','any');
            return;
    end
end

p = inputParser;
p.addParameter('Key', '', @(x)ischar(x)||isstring(x));
p.addParameter('LogFile', '', @(x)ischar(x)||isstring(x));
p.parse(varargin{:});
opt = p.Results;

if isempty(opt.Key)
    if isstruct(meta) && isfield(meta, 'topicId')
        key = sprintf('topic_%d', double(meta.topicId));
    else
        key = 'default';
    end
else
    key = char(opt.Key);
end

if isempty(opt.LogFile)
    logFile = fullfile('data', 'output', 'logs', ['rx_' key '.log']);
else
    logFile = char(opt.LogFile);
end

if ~isKey(loggerMap, key)
    loggerMap(key) = EthTcpSimpleLogger(logFile, 'EnableConsole', true, 'ConsoleEvery', 1, 'FlushEvery', 1);
end
l = loggerMap(key);
l.log(msg, meta);
end
