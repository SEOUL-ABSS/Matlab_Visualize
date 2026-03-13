function vis = show_spectrum_1d(fftResult, ax)
%SHOW_SPECTRUM_1D Plot one-sided FFT magnitude with peak annotations.
%   vis = SHOW_SPECTRUM_1D(fftResult)
%   vis = SHOW_SPECTRUM_1D(fftResult, ax)
%
% fftResult is expected to be the struct returned by compute_fft.

if nargin < 2 || isempty(ax)
    figure('Name', 'Spectrum 1D');
    ax = axes();
end

if ~isstruct(fftResult) || ~isfield(fftResult, 'spectrum') || ~isfield(fftResult.spectrum, 'frequencyHz') || ~isfield(fftResult.spectrum, 'magnitude')
    error('show_spectrum_1d:InvalidInput', 'fftResult must contain spectrum.frequencyHz and spectrum.magnitude.');
end

f = fftResult.spectrum.frequencyHz(:);
m = fftResult.spectrum.magnitude(:);

validateattributes(f, {'numeric'}, {'real', 'finite', 'vector', 'nonempty'}, mfilename, 'fftResult.spectrum.frequencyHz');
validateattributes(m, {'numeric'}, {'real', 'finite', 'vector', 'nonempty'}, mfilename, 'fftResult.spectrum.magnitude');
if numel(f) ~= numel(m)
    error('show_spectrum_1d:LengthMismatch', 'frequencyHz and magnitude must have same length.');
end

plot(ax, f, m, 'LineWidth', 1.2);
grid(ax, 'on');
xlabel(ax, 'Frequency (Hz)');
ylabel(ax, 'Magnitude');
title(ax, 'FFT Magnitude (One-Sided)');
hold(ax, 'on');

peakPoints = [];
if isfield(fftResult, 'peaks') && isfield(fftResult.peaks, 'items') && ~isempty(fftResult.peaks.items)
    items = fftResult.peaks.items;
    px = arrayfun(@(p) p.x, items);
    py = arrayfun(@(p) p.y, items);

    plot(ax, px, py, 'rv', 'MarkerFaceColor', 'r', 'DisplayName', 'Peaks');

    for i = 1:numel(px)
        text(ax, px(i), py(i), sprintf('  %.2f Hz', px(i)), ...
            'Color', [0.7 0 0], 'FontSize', 8, 'VerticalAlignment', 'bottom');
    end
    peakPoints = [px(:), py(:)];
end
hold(ax, 'off');

vis = struct();
vis.axis = struct(...
    'xName', 'frequency', 'xUnit', 'Hz', ...
    'yName', 'magnitude', 'yUnit', 'a.u.');
vis.series = struct(...
    'x', f, ...
    'y', m, ...
    'label', 'fftMagnitude');
vis.peaks = peakPoints;
end
