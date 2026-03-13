function vis = show_signal_1d(signal, fs, ax)
%SHOW_SIGNAL_1D Plot a real-valued 1D signal in time domain.
%   vis = SHOW_SIGNAL_1D(signal)
%   vis = SHOW_SIGNAL_1D(signal, fs)
%   vis = SHOW_SIGNAL_1D(signal, fs, ax)

if nargin < 2 || isempty(fs)
    fs = 1;
end
if nargin < 3 || isempty(ax)
    figure('Name', 'Signal 1D');
    ax = axes();
end

validateattributes(signal, {'numeric'}, {'real', 'finite', 'vector', 'nonempty'}, mfilename, 'signal', 1);
validateattributes(fs, {'numeric'}, {'real', 'finite', 'scalar', 'positive'}, mfilename, 'fs', 2);

x = signal(:);
t = (0:numel(x)-1)' / fs;

plot(ax, t, x, 'LineWidth', 1.2);
grid(ax, 'on');
xlabel(ax, 'Time (s)');
ylabel(ax, 'Amplitude');
title(ax, 'Time-Domain Signal');

vis = struct();
vis.axis = struct(...
    'xName', 'time', 'xUnit', 's', ...
    'yName', 'amplitude', 'yUnit', 'a.u.');
vis.series = struct(...
    'x', t, ...
    'y', x, ...
    'label', 'signal');
end
