function eth_rx_pipeline(msg, meta, varargin)
%ETH_RX_PIPELINE save/log/plot 결합 콜백 래퍼.

p = inputParser;
p.addParameter('Save', true, @(x)islogical(x)||isnumeric(x));
p.addParameter('Log', true, @(x)islogical(x)||isnumeric(x));
p.addParameter('Plot', false, @(x)islogical(x)||isnumeric(x));
p.addParameter('Key', '', @(x)ischar(x)||isstring(x));
p.parse(varargin{:});
opt = p.Results;

if logical(opt.Save)
    eth_rx_save(msg, meta, 'Key', opt.Key);
end
if logical(opt.Log)
    eth_rx_log(msg, meta, 'Key', opt.Key);
end
if logical(opt.Plot)
    eth_rx_plot(msg, meta, 'Key', opt.Key);
end
end
