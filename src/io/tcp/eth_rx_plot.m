function eth_rx_plot(msg, meta, varargin)
%ETH_RX_PLOT 수신 콜백 플롯 래퍼.
%   DetViz 클래스가 있으면 연동하고, 없으면 경량 기본 플롯을 사용.

persistent plotMap
if isempty(plotMap)
    plotMap = containers.Map('KeyType','char','ValueType','any');
end

if nargin >= 1 && (ischar(msg) || isstring(msg))
    cmd = lower(char(msg));
    switch cmd
        case 'close'
            keys = plotMap.keys;
            for i = 1:numel(keys)
                h = plotMap(keys{i});
                if ishghandle(h)
                    close(h);
                end
            end
            plotMap = containers.Map('KeyType','char','ValueType','any');
            return;
        case 'reset'
            keys = plotMap.keys;
            for i = 1:numel(keys)
                h = plotMap(keys{i});
                if ishghandle(h)
                    close(h);
                end
            end
            plotMap = containers.Map('KeyType','char','ValueType','any');
            return;
    end
end

p = inputParser;
p.addParameter('Key', '', @(x)ischar(x)||isstring(x));
p.addParameter('YField', 'a', @(x)ischar(x)||isstring(x));
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

try
    if exist('DetViz', 'class') == 8
        if ~isKey(plotMap, key) || ~isvalid(plotMap(key))
            plotMap(key) = DetViz();
        end
        viz = plotMap(key);
        if ismethod(viz, 'update')
            viz.update(msg, meta);
        end
        return;
    end

    if ~isKey(plotMap, key) || ~ishghandle(plotMap(key))
        fig = figure('Name', ['eth_rx_plot:' key], 'Color', 'w');
        plotMap(key) = fig;
    else
        fig = plotMap(key);
    end

    if ~isstruct(msg) || ~isfield(msg, char(opt.YField))
        return;
    end
    y = msg.(char(opt.YField));
    if ~isnumeric(y)
        return;
    end

    figure(fig);
    plot(y(:), 'LineWidth', 1.0);
    grid on;
    xlabel('Index');
    ylabel(char(opt.YField));
    title(sprintf('RX Plot - %s', key));
    drawnow limitrate;
catch err
    warning('eth_rx_plot:PlotFailed', 'Plot callback failed: %s', err.message);
    % 실패 시에도 다음 콜백이 동작하도록 persistent 상태는 유지
end
end
