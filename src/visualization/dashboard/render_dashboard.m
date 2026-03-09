function uiState = render_dashboard(state, fig)
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

title(ax, sprintf('Main View: %s (Frame %d)', viewName, selected.frameIdx));
end

function render_summary_card(ax, state, selected)
axis(ax, 'off');
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
