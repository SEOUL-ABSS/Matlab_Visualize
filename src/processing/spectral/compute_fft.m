function result = compute_fft(signal, fs, peakOpts)
%COMPUTE_FFT Compute one-sided FFT magnitude and dominant peaks.
%   result = COMPUTE_FFT(signal)
%   result = COMPUTE_FFT(signal, fs)
%   result = COMPUTE_FFT(signal, fs, peakOpts)
%
% Input
%   signal  : real-valued 1D vector
%   fs      : sample rate in Hz (default 1)
%   peakOpts: options forwarded to estimate_peak_1d
%
% Output
%   result.signal
%   result.spectrum
%   result.peaks
%   result.meta

if nargin < 2 || isempty(fs)
    fs = 1;
end
if nargin < 3
    peakOpts = struct();
end

validateattributes(signal, {'numeric'}, {'real', 'finite', 'vector', 'nonempty'}, mfilename, 'signal', 1);
validateattributes(fs, {'numeric'}, {'real', 'finite', 'scalar', 'positive'}, mfilename, 'fs', 2);

x = signal(:);
n = numel(x);

fftComplex = fft(x);
halfN = floor(n/2) + 1;
fftOneSided = fftComplex(1:halfN);

mag = abs(fftOneSided) / n;
if n > 1
    if rem(n, 2) == 0
        mag(2:end-1) = 2 * mag(2:end-1);
    else
        mag(2:end) = 2 * mag(2:end);
    end
end

freqHz = (0:halfN-1)' * (fs / n);

peaks = estimate_peak_1d(freqHz, mag, peakOpts);

result = struct();
result.signal = struct(...
    'data', x, ...
    'fs', fs, ...
    'length', n);

result.spectrum = struct(...
    'frequencyHz', freqHz, ...
    'magnitude', mag, ...
    'complex', fftOneSided, ...
    'axis', struct('name', 'frequency', 'unit', 'Hz'));

result.peaks = peaks;
result.meta = struct(...
    'algorithm', 'fft-onesided', ...
    'isDeterministic', true);
end
