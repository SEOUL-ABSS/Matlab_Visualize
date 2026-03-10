function peaks = estimate_peak_1d(xAxis, yAxis, opts)
%ESTIMATE_PEAK_1D Estimate dominant peaks for a 1D curve.
%   peaks = ESTIMATE_PEAK_1D(xAxis, yAxis)
%   peaks = ESTIMATE_PEAK_1D(xAxis, yAxis, opts)
%
% Inputs
%   xAxis : numeric vector (x-coordinate, e.g., frequency)
%   yAxis : numeric vector (y-coordinate, e.g., magnitude)
%   opts.numPeaks : max number of dominant peaks to return (default 3)
%
% Output struct fields
%   peaks.items(k).index
%   peaks.items(k).x
%   peaks.items(k).y
%   peaks.count
%   peaks.meta

if nargin < 3 || isempty(opts)
    opts = struct();
end

if ~isfield(opts, 'numPeaks') || isempty(opts.numPeaks)
    opts.numPeaks = 3;
end

validateattributes(xAxis, {'numeric'}, {'real', 'finite', 'vector', 'nonempty'}, mfilename, 'xAxis', 1);
validateattributes(yAxis, {'numeric'}, {'real', 'finite', 'vector', 'nonempty'}, mfilename, 'yAxis', 2);
validateattributes(opts.numPeaks, {'numeric'}, {'real', 'finite', 'scalar', 'integer', 'positive'}, mfilename, 'opts.numPeaks');

xAxis = xAxis(:);
yAxis = yAxis(:);

if numel(xAxis) ~= numel(yAxis)
    error('estimate_peak_1d:LengthMismatch', 'xAxis and yAxis must have the same length.');
end

n = numel(yAxis);
if n == 1
    candidateIdx = 1;
else
    candidateIdx = find(yAxis(2:end-1) > yAxis(1:end-2) & yAxis(2:end-1) >= yAxis(3:end)) + 1;

    if yAxis(1) > yAxis(2)
        candidateIdx = [1; candidateIdx]; %#ok<AGROW>
    end
    if yAxis(end) > yAxis(end-1)
        candidateIdx = [candidateIdx; n]; %#ok<AGROW>
    end

    if isempty(candidateIdx)
        [~, idxMax] = max(yAxis);
        candidateIdx = idxMax;
    end
end

% Rank by dominant amplitude.
[~, order] = sort(yAxis(candidateIdx), 'descend');
candidateIdx = candidateIdx(order);

keepN = min(opts.numPeaks, numel(candidateIdx));
selected = candidateIdx(1:keepN);

items = repmat(struct('index', [], 'x', [], 'y', []), 1, keepN);
for i = 1:keepN
    idx = selected(i);
    items(i) = struct('index', idx, 'x', xAxis(idx), 'y', yAxis(idx));
end

peaks = struct();
peaks.items = items;
peaks.count = keepN;
peaks.meta = struct(...
    'method', 'local-maxima', ...
    'requestedNumPeaks', opts.numPeaks, ...
    'signalLength', n);
end
