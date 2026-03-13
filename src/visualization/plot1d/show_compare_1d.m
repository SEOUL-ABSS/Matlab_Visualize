function show_compare_1d(compareData, selectedFrameIdx, ax)
%SHOW_COMPARE_1D Render comparison overlays for signal/spectrum debug workflows.

if nargin < 3 || isempty(ax)
    figure('Name', 'Compare View', 'Color', 'w');
    ax = gca;
end

if nargin < 2 || isempty(selectedFrameIdx)
    selectedFrameIdx = 0;
end

if ~isstruct(compareData) || ~isfield(compareData, 'signal') || ~isfield(compareData, 'spectrum')
    axis(ax, 'off');
    text(ax, 0.02, 0.5, 'Compare data unavailable', 'FontSize', 10);
    title(ax, 'Compare');
    return;
end

rawSignal = compareData.signal.raw;
processedSignal = compareData.signal.processed;
if isempty(rawSignal) || isempty(processedSignal)
    axis(ax, 'off');
    text(ax, 0.02, 0.5, 'Signal comparison unavailable', 'FontSize', 10);
    title(ax, 'Compare');
    return;
end

rawSignal = rawSignal(:);
processedSignal = processedSignal(:);
n = min(numel(rawSignal), numel(processedSignal));
rawSignal = rawSignal(1:n);
processedSignal = processedSignal(1:n);
sampleIdx = (1:n)';

cla(ax);

% Signal comparison (left axis)
yyaxis(ax, 'left');
plot(ax, sampleIdx, rawSignal, '-', 'Color', [0 0.45 0.74], 'LineWidth', 1.0, 'DisplayName', 'Raw Signal');
hold(ax, 'on');
plot(ax, sampleIdx, processedSignal, '--', 'Color', [0 0.7 0.3], 'LineWidth', 1.0, 'DisplayName', 'Processed Signal');
ylabel(ax, 'Amplitude');

% Spectrum comparison (right axis, normalized for shared axis readability)
yyaxis(ax, 'right');
if isfield(compareData.spectrum, 'raw') && isfield(compareData.spectrum.raw, 'magnitude') && ...
        isfield(compareData.spectrum, 'processed') && isfield(compareData.spectrum.processed, 'magnitude')
    rawMag = compareData.spectrum.raw.magnitude(:);
    procMag = compareData.spectrum.processed.magnitude(:);
    m = min(numel(rawMag), numel(procMag));
    rawMag = rawMag(1:m);
    procMag = procMag(1:m);
    freqNorm = linspace(0, 1, m)';

    plot(ax, freqNorm, rawMag, ':', 'Color', [0.85 0.33 0.1], 'LineWidth', 1.1, ...
        'DisplayName', 'Raw Spectrum');
    plot(ax, freqNorm, procMag, '-.', 'Color', [0.49 0.18 0.56], 'LineWidth', 1.1, ...
        'DisplayName', 'Processed Spectrum');
end
ylabel(ax, 'Spectrum Magnitude');

% Deferred threshold comparison annotation.
if isfield(compareData, 'meta') && isfield(compareData.meta, 'thresholdComparisonAvailable') && ...
        ~compareData.meta.thresholdComparisonAvailable
    text(ax, 0.02, 0.04, 'Threshold pre/post comparison deferred (post-threshold stage not available yet).', ...
        'Units', 'normalized', 'FontAngle', 'italic', 'Color', [0.3 0.3 0.3]);
end

xlabel(ax, 'Signal sample index (left) / normalized frequency bin (right-axis plots)');
title(ax, sprintf('Compare: Raw vs Processed (Frame %d)', selectedFrameIdx));
grid(ax, 'on');
legend(ax, 'show', 'Location', 'best');
hold(ax, 'off');
end
