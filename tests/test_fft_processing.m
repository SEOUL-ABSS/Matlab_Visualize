classdef test_fft_processing < matlab.unittest.TestCase
    methods (Test)
        function computeFftFindsDominantFrequency(testCase)
            fs = 1000;
            n = 1000;
            t = (0:n-1)'/fs;
            f0 = 50;
            x = sin(2*pi*f0*t);

            result = compute_fft(x, fs, struct('numPeaks', 1));

            testCase.verifyTrue(isfield(result, 'spectrum'));
            testCase.verifyTrue(isfield(result, 'peaks'));
            testCase.verifyEqual(result.peaks.count, 1);
            testCase.verifyLessThan(abs(result.peaks.items(1).x - f0), 1.5);
        end

        function estimatePeakRejectsLengthMismatch(testCase)
            testCase.verifyError(@() estimate_peak_1d([1 2 3], [1 2], struct('numPeaks', 1)), ...
                'estimate_peak_1d:LengthMismatch');
        end
    end
end
