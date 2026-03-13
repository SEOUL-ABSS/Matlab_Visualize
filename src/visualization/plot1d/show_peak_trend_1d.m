function show_peak_trend_1d(peakTrend, selectedFrameIdx, ax)
%SHOW_PEAK_TREND_1D Plot strongest peak frequency/magnitude trends by frame.

if nargin < 3 || isempty(ax)
    figure('Name', 'Peak Trend', 'Color', 'w');
    ax = gca;
end

if isempty(peakTrend)
    axis(ax, 'off');
    text(ax, 0.02, 0.5, 'No peak history available', 'FontSize', 10);
    title(ax, 'Peak Trend');
    return;
end

frameIdx = [peakTrend.frameIdx];
peakHz = [peakTrend.strongestPeakFrequencyHz];
peakMag = [peakTrend.strongestPeakMagnitude];

yyaxis(ax, 'left');
plot(ax, frameIdx, peakHz, '-o', 'LineWidth', 1.1, 'DisplayName', 'Peak Frequency (Hz)');
ylabel(ax, 'Peak Frequency (Hz)');

yyaxis(ax, 'right');
plot(ax, frameIdx, peakMag, '-s', 'LineWidth', 1.1, 'DisplayName', 'Peak Magnitude');
ylabel(ax, 'Peak Magnitude');

if nargin >= 2 && ~isempty(selectedFrameIdx) && any(frameIdx == selectedFrameIdx)
    idx = find(frameIdx == selectedFrameIdx, 1, 'last');
    yyaxis(ax, 'left');
    hold(ax, 'on');
    plot(ax, frameIdx(idx), peakHz(idx), 'pr', 'MarkerSize', 10, 'MarkerFaceColor', 'r', ...
        'DisplayName', 'Selected Frame');
    xline(ax, selectedFrameIdx, '--r', sprintf('Frame %d', selectedFrameIdx), 'LabelVerticalAlignment', 'middle');
    hold(ax, 'off');

    yyaxis(ax, 'right');
    hold(ax, 'on');
    plot(ax, frameIdx(idx), peakMag(idx), 'dr', 'MarkerSize', 8, 'MarkerFaceColor', 'r', ...
        'HandleVisibility', 'off');
    hold(ax, 'off');
end

xlabel(ax, 'Frame');
title(ax, 'Peak Trend');
grid(ax, 'on');
legend(ax, 'show', 'Location', 'best');
end
