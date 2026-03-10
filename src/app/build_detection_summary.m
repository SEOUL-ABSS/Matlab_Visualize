function summary = build_detection_summary(result, thresholdEnabled, thresholdValue)
%BUILD_DETECTION_SUMMARY Build compact detection summary from cached result.

summary = struct(...
    'strongestPeakFrequencyHz', NaN, ...
    'strongestPeakMagnitude', NaN, ...
    'top3Peaks', struct('frequencyHz', {}, 'magnitude', {}), ...
    'thresholdEnabled', logical(thresholdEnabled), ...
    'thresholdValue', thresholdValue, ...
    'thresholdMargin', NaN);

if ~isfield(result, 'peaks') || ~isfield(result.peaks, 'count') || result.peaks.count == 0
    return;
end

items = result.peaks.items;
count = min(3, numel(items));

summary.strongestPeakFrequencyHz = items(1).x;
summary.strongestPeakMagnitude = items(1).y;

top3 = repmat(struct('frequencyHz', NaN, 'magnitude', NaN), 1, count);
for i = 1:count
    top3(i).frequencyHz = items(i).x;
    top3(i).magnitude = items(i).y;
end
summary.top3Peaks = top3;

if thresholdEnabled
    summary.thresholdMargin = summary.strongestPeakMagnitude - thresholdValue;
end
end
