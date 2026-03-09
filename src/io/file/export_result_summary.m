function filePath = export_result_summary(state, outputDir, baseName)
%EXPORT_RESULT_SUMMARY Export lightweight frame/result summary as CSV.

if nargin < 2 || isempty(outputDir)
    outputDir = fullfile('data', 'output', 'summaries');
end
if nargin < 3 || isempty(baseName)
    baseName = 'result_summary';
end

if ~isstruct(state)
    error('export_result_summary:InvalidState', 'state must be a struct.');
end

outputDir = char(outputDir);
baseName = char(baseName);
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

ts = datestr(now, 'yyyymmdd_HHMMSS');
filePath = fullfile(outputDir, sprintf('%s_%s.csv', baseName, ts));

n = numel(state.frame_history);
frameIdx = (1:n)';
rmsVals = nan(n,1);
peakAmpVals = nan(n,1);
clipVals = nan(n,1);
peakMagVals = nan(n,1);
peakFreqVals = nan(n,1);

for i = 1:n
    snap = state.frame_history{i};
    q = snap.quality;
    rmsVals(i) = q.rms;
    peakAmpVals(i) = q.peakAmplitude;
    clipVals(i) = q.clippingRatio;

    if isfield(snap.result, 'peaks') && isfield(snap.result.peaks, 'count') && snap.result.peaks.count > 0
        peakMagVals(i) = snap.result.peaks.items(1).y;
        peakFreqVals(i) = snap.result.peaks.items(1).x;
    end
end

T = table(frameIdx, rmsVals, peakAmpVals, clipVals, peakMagVals, peakFreqVals, ...
    'VariableNames', {'frame_idx','rms','peak_amplitude','clipping_ratio','dominant_peak_mag','dominant_peak_hz'});
writetable(T, filePath);
end
