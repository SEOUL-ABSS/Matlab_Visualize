function show_waterfall_1d(waterfallData, selectedFrameIdx, ax)
%SHOW_WATERFALL_1D Render cached waterfall matrix with frame-aware overlays.

if nargin < 3 || isempty(ax)
    figure('Name', 'Waterfall', 'Color', 'w');
    ax = gca;
end
if nargin < 2 || isempty(selectedFrameIdx)
    selectedFrameIdx = 0;
end

if ~isstruct(waterfallData) || ~isfield(waterfallData, 'magnitudeMatrix') || isempty(waterfallData.magnitudeMatrix)
    axis(ax, 'off');
    text(ax, 0.02, 0.5, 'Waterfall cache is empty', 'FontSize', 10);
    title(ax, 'Waterfall');
    return;
end

mag = waterfallData.magnitudeMatrix;
[nFrames, nBins] = size(mag);

if isfield(waterfallData, 'frame_indices') && numel(waterfallData.frame_indices) == nFrames
    frameIdx = waterfallData.frame_indices(:);
else
    frameIdx = (1:nFrames)';
end

imagesc(ax, 1:nBins, frameIdx, mag);
set(ax, 'YDir', 'normal');
colormap(ax, 'turbo');
cb = colorbar(ax);
cb.Label.String = 'Magnitude';

xlabel(ax, 'Frequency Bin');
ylabel(ax, 'Frame Index');
grid(ax, 'on');

if ~isfield(waterfallData, 'overlay') || ~isstruct(waterfallData.overlay)
    waterfallData.overlay = struct('showCurrentMarker', true, 'showMaxHold', false, 'showMeanHold', false);
end

hold(ax, 'on');
xLimits = [1 nBins];

if waterfallData.overlay.showCurrentMarker && selectedFrameIdx > 0
    if selectedFrameIdx >= min(frameIdx) && selectedFrameIdx <= max(frameIdx)
        plot(ax, xLimits, [selectedFrameIdx selectedFrameIdx], '--w', 'LineWidth', 1.6, 'DisplayName', 'Selected Frame');
    end
end

if isfield(waterfallData, 'hold_enabled') && waterfallData.hold_enabled && ...
        isfield(waterfallData, 'hold_frame_indices') && ~isempty(waterfallData.hold_frame_indices)
    holdIdx = waterfallData.hold_frame_indices(:);
    holdIdx = holdIdx(holdIdx >= min(frameIdx) & holdIdx <= max(frameIdx));
    for h = 1:numel(holdIdx)
        plot(ax, xLimits, [holdIdx(h) holdIdx(h)], ':y', 'LineWidth', 1.1, 'HandleVisibility', 'off');
    end
end

if waterfallData.overlay.showMaxHold
    maxHold = max(mag, [], 1);
    [~, maxBin] = max(maxHold);
    plot(ax, [maxBin maxBin], [min(frameIdx) max(frameIdx)], '-', ...
        'Color', [1 0.6 0.1], 'LineWidth', 1.5, 'DisplayName', 'Max-Hold Bin');
end

if waterfallData.overlay.showMeanHold
    meanHold = mean(mag, 1);
    [~, meanBin] = max(meanHold);
    plot(ax, [meanBin meanBin], [min(frameIdx) max(frameIdx)], '-', ...
        'Color', [0.7 1 1], 'LineWidth', 1.2, 'DisplayName', 'Mean-Hold Bin');
end

hold(ax, 'off');

historyMode = 'full';
if isfield(waterfallData, 'max_history_frames') && isfinite(waterfallData.max_history_frames)
    historyMode = sprintf('rolling(%d)', waterfallData.max_history_frames);
end

title(ax, sprintf('Waterfall | Frames %d-%d | Rows=%d | History=%s', ...
    min(frameIdx), max(frameIdx), nFrames, historyMode));

if waterfallData.overlay.showCurrentMarker || waterfallData.overlay.showMaxHold || waterfallData.overlay.showMeanHold
    legend(ax, 'show', 'Location', 'northoutside', 'Orientation', 'horizontal');
end
end
