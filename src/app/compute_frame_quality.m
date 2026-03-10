function quality = compute_frame_quality(inputData, result)
%COMPUTE_FRAME_QUALITY Build deterministic frame-quality diagnostics.

x = result.raw.data(:);

quality = struct();
quality.nanOrInfPresent = any(~isfinite(x));
quality.inputLength = numel(x);
quality.inputLengthValid = quality.inputLength > 0;
quality.rms = sqrt(mean(x.^2));
quality.energy = sum(x.^2);
quality.dcOffset = mean(x);

peakAmp = max(abs(x));
quality.peakAmplitude = peakAmp;

if peakAmp <= eps
    quality.clippingRatio = 0;
    quality.clippingDetected = false;
else
    quality.clippingRatio = mean(abs(x) >= 0.98 * peakAmp);
    quality.clippingDetected = quality.clippingRatio > 0.02;
end

if isfield(inputData, 'meta') && isstruct(inputData.meta) && isfield(inputData.meta, 'decodeStatus')
    quality.decodeStatus = inputData.meta.decodeStatus;
else
    quality.decodeStatus = 'unknown';
end

if isfield(inputData, 'meta') && isstruct(inputData.meta) && isfield(inputData.meta, 'continuityStatus')
    quality.continuityStatus = inputData.meta.continuityStatus;
else
    quality.continuityStatus = 'unknown';
end

if quality.nanOrInfPresent || ~quality.inputLengthValid
    quality.qualityLabel = 'poor';
elseif quality.clippingRatio > 0.10
    quality.qualityLabel = 'poor';
elseif quality.clippingRatio > 0.02
    quality.qualityLabel = 'fair';
else
    quality.qualityLabel = 'good';
end
end
