function uiState = render_dashboard(state, fig)
%RENDER_DASHBOARD Render app shell with first-class summary/quality/event UI.
%RENDER_DASHBOARD Render app shell: main view + summary + quality + event strip.

if nargin < 2 || isempty(fig)
    fig = figure('Name', 'Signal Debug Dashboard', 'Color', 'w');
end

clf(fig);
tl = tiledlayout(fig, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

selected = get_selected_snapshot(state);

axMain = nexttile(tl, [2 1]);
render_main_view(axMain, state, selected);

axSummary = nexttile(tl);
render_summary_card(axSummary, state, selected);

axQuality = nexttile(tl);
render_quality_card(axQuality, selected);

axEvent = nexttile(tl, [1 2]);
render_event_strip(axEvent, state, selected);
render_event_strip(axEvent, state);

uiState = struct('figure', fig, 'layout', tl, 'selectedFrameIdx', selected.frameIdx);
end

function snapshot = get_selected_snapshot(state)
if state.selected_frame_idx >= 1 && state.selected_frame_idx <= numel(state.frame_history)
    snapshot = state.frame_history{state.selected_frame_idx};
elseif ~isempty(state.frame_history)
    snapshot = state.frame_history{end};
else
    snapshot = struct('frameIdx', 0, 'input', struct(), 'result', struct(), ...
        'quality', state.frame_quality_summary, 'detection', state.detection_summary, 'timestamp', NaT);
end

if ~isfield(snapshot, 'quality')
    snapshot.quality = state.frame_quality_summary;
end
if ~isfield(snapshot, 'detection')
    snapshot.detection = state.detection_summary;
end
snapshot.panelEmphasisQuality = isfield(state, 'panel_emphasis') && isfield(state.panel_emphasis, 'qualityCard') && state.panel_emphasis.qualityCard;
        'quality', state.frame_quality_summary, 'timestamp', NaT);
end
end

function render_main_view(ax, state, selected)
viewName = state.current_view;
if selected.frameIdx == 0 || isempty(fieldnames(selected.result))
    axis(ax, 'off');
    text(ax, 0.02, 0.5, 'No data processed yet', 'FontSize', 11);
    title(ax, sprintf('Main View: %s', viewName));
    return;
end

switch viewName
    case 'Spectrum'
        if isfield(selected.result, 'features') && isfield(selected.result.features, 'spectrum') && ...
                isfield(selected.result, 'peaks')
            fftResult = struct('spectrum', selected.result.features.spectrum, 'peaks', selected.result.peaks);
            show_spectrum_1d(fftResult, ax);
        else
            axis(ax, 'off');
            text(ax, 0.02, 0.5, 'Spectrum data unavailable in selected frame cache', 'FontSize', 10);
        end
    case 'Waterfall'
        show_waterfall_1d(state.waterfall, selected.frameIdx, ax);
    case 'Peak Trend'
        show_peak_trend_1d(state.peak_trend, selected.frameIdx, ax);
    case 'Compare'
        if isfield(selected.result, 'compare')
            show_compare_1d(selected.result.compare, selected.frameIdx, ax);
        else
            axis(ax, 'off');
            text(ax, 0.02, 0.5, 'Compare data unavailable in result cache', 'FontSize', 10);
        end
    case 'Frame Quality'
        if isfield(selected, 'quality') && ~isempty(selected.quality)
            q = selected.quality;
            bar(ax, [q.rms, q.peakAmplitude, q.clippingRatio]);
            set(ax, 'XTickLabel', {'RMS','PeakAmp','ClipRatio'});
            title(ax, sprintf('Frame Quality (%s)', q.qualityLabel)); grid(ax, 'on');
        else
            axis(ax, 'off');
            text(ax, 0.02, 0.5, 'Quality metrics unavailable in selected frame cache', 'FontSize', 10);
        end
    case 'Bearing Map'
        imagesc(ax, state.bearing.timeMap.magnitude);
        xlabel(ax, 'Bearing Bin'); ylabel(ax, 'Frame'); title(ax, 'Bearing Map (placeholder)'); colorbar(ax);
    case 'Bearing Frequency'
        show_bearing_frequency_placeholder(state.bearing, ax);
    case 'Bearing Time'
        show_bearing_time_placeholder(state.bearing, selected.frameIdx, ax);
        fftResult = struct('spectrum', selected.result.features.spectrum, 'peaks', selected.result.peaks);
        show_spectrum_1d(fftResult, ax);
    case 'Waterfall'
        imagesc(ax, state.waterfall.magnitudeMatrix);
        axis(ax, 'tight'); xlabel(ax, 'Frequency Bin'); ylabel(ax, 'Frame'); title(ax, 'Waterfall'); colorbar(ax);
        hold(ax, 'on');
        xLimits = xlim(ax);
        plot(ax, xLimits, [selected.frameIdx selected.frameIdx], '--w', 'LineWidth', 1.4);
        if state.waterfall.hold_enabled
            for h = 1:numel(state.waterfall.hold_frame_indices)
                idx = state.waterfall.hold_frame_indices(h);
                plot(ax, xLimits, [idx idx], ':y', 'LineWidth', 1.1);
            end
        end
        hold(ax, 'off');
    case 'Peak Trend'
        nFrames = numel(state.peak_trend);
        plot(ax, 1:nFrames, state.peak_trend, '-o'); hold(ax, 'on');
        plot(ax, selected.frameIdx, state.peak_trend(selected.frameIdx), 'sr', 'MarkerFaceColor', 'r');
        hold(ax, 'off');
        xlabel(ax, 'Frame'); ylabel(ax, 'Dominant Peak Magnitude'); title(ax, 'Peak Trend'); grid(ax, 'on');
    case 'Compare'
        x = selected.result.raw.data(:);
        p = selected.result.preprocessed.data(:);
        plot(ax, x, 'DisplayName', 'Raw'); hold(ax, 'on');
        plot(ax, p, 'DisplayName', 'Preprocessed'); hold(ax, 'off');
        legend(ax, 'show'); grid(ax, 'on'); title(ax, sprintf('Compare (Frame %d)', selected.frameIdx));
    case 'Frame Quality'
        q = selected.quality;
        bar(ax, [q.rms, q.peakAmplitude, q.clippingRatio]);
        set(ax, 'XTickLabel', {'RMS','PeakAmp','ClipRatio'});
        title(ax, sprintf('Frame Quality (%s)', q.qualityLabel)); grid(ax, 'on');
    case 'Bearing Map'
        imagesc(ax, state.bearing.timeMap.magnitude);
        xlabel(ax, 'Bearing Bin'); ylabel(ax, 'Frame'); title(ax, 'Bearing Map (placeholder)'); colorbar(ax);
end

if state.threshold_enabled && strcmp(viewName, 'Spectrum')
    hold(ax, 'on'); yline(ax, state.threshold_value, '--r', 'Threshold'); hold(ax, 'off');
end

if ~strcmp(viewName, 'Waterfall')
    title(ax, sprintf('Main View: %s (Frame %d)', viewName, selected.frameIdx));
end
title(ax, sprintf('Main View: %s (Frame %d)', viewName, selected.frameIdx));
end

function render_summary_card(ax, state, selected)
axis(ax, 'off');
det = selected.detection;
titleText = 'Summary';
if isfield(state, 'panel_emphasis') && isfield(state.panel_emphasis, 'summaryCard') && state.panel_emphasis.summaryCard
    titleText = 'Summary [focus]';
end
text(ax, 0.01, 0.92, titleText, 'FontWeight', 'bold');
text(ax, 0.01, 0.78, sprintf('State: %s / %s', state.current_preset, state.current_view));
text(ax, 0.01, 0.66, sprintf('Frame: %d (selected %d)', state.current_frame_idx, selected.frameIdx));
tcpStatus = 'n/a';
if isfield(state, 'tcp') && isfield(state.tcp, 'status')
    tcpStatus = state.tcp.status;
end
text(ax, 0.01, 0.60, sprintf('TCP: %s', tcpStatus));
text(ax, 0.01, 0.50, sprintf('Strongest Peak: %.3f Hz / %.4f', det.strongestPeakFrequencyHz, det.strongestPeakMagnitude));

topText = top3_to_text(det.top3Peaks);
text(ax, 0.01, 0.35, sprintf('Top-3: %s', topText));

if det.thresholdEnabled
    text(ax, 0.01, 0.21, sprintf('Threshold Margin: %.4f (thr=%.3f)', det.thresholdMargin, det.thresholdValue));
else
    text(ax, 0.01, 0.21, sprintf('Threshold: disabled (value=%.3f)', det.thresholdValue));
end

if ~isempty(state.event_log)
    e = state.event_log{end};
    text(ax, 0.01, 0.09, sprintf('Last Event: [%s] %s', e.level, e.message));
else
    text(ax, 0.01, 0.09, 'Last Event: none');
end
text(ax, 0.01, 0.9, 'Summary', 'FontWeight', 'bold');
text(ax, 0.01, 0.72, sprintf('Preset: %s', state.current_preset));
text(ax, 0.01, 0.56, sprintf('View: %s', state.current_view));
text(ax, 0.01, 0.40, sprintf('Current Frame: %d', state.current_frame_idx));
text(ax, 0.01, 0.24, sprintf('Selected Frame: %d', selected.frameIdx));
text(ax, 0.01, 0.08, sprintf('Threshold: %s (%.3f)', mat2str(state.threshold_enabled), state.threshold_value));
end

function render_quality_card(ax, selected)
q = selected.quality;
axis(ax, 'off');
titleText = 'Frame Quality';
if isfield(selected, 'panelEmphasisQuality') && selected.panelEmphasisQuality
    titleText = 'Frame Quality [focus]';
end
text(ax, 0.01, 0.92, titleText, 'FontWeight', 'bold');
text(ax, 0.01, 0.80, sprintf('Selected Frame: %d', selected.frameIdx));
text(ax, 0.01, 0.68, sprintf('NaN/Inf: %s', mat2str(q.nanOrInfPresent)));
text(ax, 0.01, 0.56, sprintf('Clipping: %s (ratio=%.4f)', mat2str(q.clippingDetected), q.clippingRatio));
text(ax, 0.01, 0.44, sprintf('DC offset: %.5f', q.dcOffset));
text(ax, 0.01, 0.32, sprintf('RMS/Energy: %.5f / %.5f', q.rms, q.energy));
text(ax, 0.01, 0.20, sprintf('Input length valid: %s (N=%d)', mat2str(q.inputLengthValid), q.inputLength));
text(ax, 0.01, 0.08, sprintf('Decode/Continuity: %s / %s', q.decodeStatus, q.continuityStatus));
end

function render_event_strip(ax, state, selected)
axis(ax, 'off');
titleText = 'Event / Status';
if isfield(state, 'panel_emphasis') && isfield(state.panel_emphasis, 'eventStrip') && state.panel_emphasis.eventStrip
    titleText = 'Event / Status [focus]';
end
text(ax, 0.01, 0.86, titleText, 'FontWeight', 'bold');

n = numel(state.event_log);
if n == 0
    text(ax, 0.01, 0.58, 'No events yet.');
else
    startIdx = max(1, n - 5);
    y = 0.70;
    for i = startIdx:n
        e = state.event_log{i};
        detailsText = '';
        if isfield(e, 'details') && isstruct(e.details) && ~isempty(fieldnames(e.details))
            detailsText = ' [details]';
        end
        text(ax, 0.01, y, sprintf('[%s] %-5s %s%s', datestr(e.time, 'HH:MM:SS'), e.level, e.message, detailsText));
        y = y - 0.12;
    end
end

if selected.frameIdx > 0
    selectedContext = sprintf('Selected Frame %d | Quality: %s | Peak: %.3f Hz / %.4f', ...
        selected.frameIdx, selected.quality.qualityLabel, ...
        selected.detection.strongestPeakFrequencyHz, selected.detection.strongestPeakMagnitude);
else
    selectedContext = 'Selected Frame: none';
end
text(ax, 0.40, 0.86, selectedContext, 'FontWeight', 'bold');

if ~isempty(state.last_error_or_warning.level)
    text(ax, 0.72, 0.12, sprintf('Last issue: %s - %s', ...
        state.last_error_or_warning.level, state.last_error_or_warning.message), 'Color', [0.8 0 0]);
else
    text(ax, 0.72, 0.12, sprintf('Last update: %s', format_time_safe(state.last_update_time)), 'Color', [0 0.5 0]);
end
end

function txt = top3_to_text(top3)
if isempty(top3)
    txt = 'none';
    return;
end
parts = cell(1, numel(top3));
for i = 1:numel(top3)
    parts{i} = sprintf('%.2fHz/%.3f', top3(i).frequencyHz, top3(i).magnitude);
end
txt = strjoin(parts, ', ');
end

text(ax, 0.01, 0.9, 'Frame Quality', 'FontWeight', 'bold');
text(ax, 0.01, 0.67, sprintf('Selected Frame: %d', selected.frameIdx));
text(ax, 0.01, 0.49, sprintf('RMS: %.4f', q.rms));
text(ax, 0.01, 0.31, sprintf('Peak |x|: %.4f', q.peakAmplitude));
text(ax, 0.01, 0.13, sprintf('Clipping Ratio: %.4f (%s)', q.clippingRatio, q.qualityLabel));
end

function render_event_strip(ax, state)
axis(ax, 'off');
text(ax, 0.01, 0.85, 'Event / Status', 'FontWeight', 'bold');

n = numel(state.event_log);
startIdx = max(1, n - 4);
y = 0.65;
for i = startIdx:n
    e = state.event_log{i};
    text(ax, 0.01, y, sprintf('[%s] %-5s %s', datestr(e.time, 'HH:MM:SS'), e.level, e.message));
    y = y - 0.16;
end

if ~isempty(state.last_issue.level)
    text(ax, 0.70, 0.2, sprintf('Last issue: %s - %s', state.last_issue.level, state.last_issue.message), 'Color', [0.8 0 0]);
else
    text(ax, 0.70, 0.2, sprintf('Last update: %s', format_time_safe(state.last_update_time)), 'Color', [0 0.5 0]);
end
end

function t = format_time_safe(dt)
if isdatetime(dt) && ~ismissing(dt)
    t = datestr(dt, 'HH:MM:SS');
else
    t = 'n/a';
end
end

function show_bearing_frequency_placeholder(bearing, ax)
if ~isfield(bearing, 'frequencyMap') || isempty(bearing.frequencyMap.magnitude)
    axis(ax, 'off');
    text(ax, 0.02, 0.5, 'Bearing Frequency view unavailable', 'FontSize', 10);
    return;
end

imagesc(ax, bearing.frequencyMap.frequencyHz, bearing.frequencyMap.bearingDeg, bearing.frequencyMap.magnitude);
set(ax, 'YDir', 'normal');
xlabel(ax, 'Frequency (Hz)');
ylabel(ax, 'Bearing (deg)');
title(ax, 'Bearing Frequency (placeholder)');
colorbar(ax);
end

function show_bearing_time_placeholder(bearing, selectedFrameIdx, ax)
if ~isfield(bearing, 'timeMap') || isempty(bearing.timeMap.magnitude)
    axis(ax, 'off');
    text(ax, 0.02, 0.5, 'Bearing Time view unavailable', 'FontSize', 10);
    return;
end

imagesc(ax, bearing.timeMap.bearingDeg, bearing.timeMap.frameIdx, bearing.timeMap.magnitude);
set(ax, 'YDir', 'normal');
xlabel(ax, 'Bearing (deg)');
ylabel(ax, 'Frame');
title(ax, 'Bearing Time (placeholder)');
colorbar(ax);

if nargin >= 2 && ~isempty(selectedFrameIdx) && selectedFrameIdx > 0
    hold(ax, 'on');
    xLimits = xlim(ax);
    plot(ax, xLimits, [selectedFrameIdx selectedFrameIdx], '--w', 'LineWidth', 1.4);
    hold(ax, 'off');
end
end
