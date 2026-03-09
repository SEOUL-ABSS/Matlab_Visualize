function result = execute_pipeline(inputData, cfg)
%EXECUTE_PIPELINE Minimal executable pipeline skeleton.
%   This function orchestrates stages only and keeps contracts stable.

if nargin < 2 || isempty(cfg)
    cfg = get_default_config();
end

validate_inputs(inputData);

% Keep outputs structured for extensibility and testability.
result = struct();
result.raw = struct(...
    'data', inputData.data, ...
    'fs', inputData.fs, ...
    'timestamp', inputData.timestamp, ...
    'type', inputData.type, ...
    'meta', inputData.meta);

% Placeholder pre-processing stage (pass-through for MVP).
result.preprocessed = struct('data', inputData.data, 'meta', struct('status', 'pass-through'));

if cfg.pipeline.enableFeatureExtraction
    fftResult = compute_fft(result.preprocessed.data, result.raw.fs);
    result.features = struct('spectrum', fftResult.spectrum, 'meta', struct('status', 'computed-fft'));
    result.peaks = fftResult.peaks;
else
    result.features = struct('items', [], 'meta', struct('status', 'disabled'));
    result.peaks = struct('items', [], 'count', 0, 'meta', struct('status', 'disabled'));
end

result.display = struct('series', [], 'axes', struct(), 'meta', struct('status', 'prepared-by-visualization-layer'));

result.log = struct(...
    'messages', {{'execute_pipeline completed run'}}, ...
    'warnings', {{}}, ...
    'errors', {{}});

result.meta = struct(...
    'pipelineVersion', cfg.meta.version, ...
    'runtimeMode', cfg.runtime.mode, ...
    'completedAt', datetime('now', 'TimeZone', 'local'));
end
