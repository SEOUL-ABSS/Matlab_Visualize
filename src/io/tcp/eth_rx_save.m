function eth_rx_save(msg, meta, varargin)
%ETH_RX_SAVE 수신 콜백 저장 래퍼.
%   eth_rx_save(msg, meta, 'Key','topic_10', 'MatFile','data/output/rx/topic10.mat')
%   eth_rx_save('close')
%   eth_rx_save('reset')

persistent recorderMap
if isempty(recorderMap)
    recorderMap = containers.Map('KeyType','char','ValueType','any');
end

if nargin >= 1 && (ischar(msg) || isstring(msg))
    cmd = lower(char(msg));
    switch cmd
        case 'close'
            keys = recorderMap.keys;
            for i = 1:numel(keys)
                r = recorderMap(keys{i});
                if isa(r, 'EthTcpStructRecorder')
                    r.close();
                end
            end
            return;
        case 'reset'
            keys = recorderMap.keys;
            for i = 1:numel(keys)
                r = recorderMap(keys{i});
                if isa(r, 'EthTcpStructRecorder')
                    r.close();
                end
            end
            recorderMap = containers.Map('KeyType','char','ValueType','any');
            return;
    end
end

p = inputParser;
p.addParameter('Key', '', @(x)ischar(x)||isstring(x));
p.addParameter('MatFile', '', @(x)ischar(x)||isstring(x));
p.addParameter('RawMode', 'frame', @(x)ischar(x)||isstring(x));
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

if isempty(opt.MatFile)
    matFile = fullfile('data', 'output', 'rx', [key '.mat']);
else
    matFile = char(opt.MatFile);
end

if ~isKey(recorderMap, key)
    recorderMap(key) = EthTcpStructRecorder(matFile, 'RawMode', char(opt.RawMode), 'EnableBin', true);
end
r = recorderMap(key);
r.append(msg, meta);
end
