classdef test_fft_processing < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addProjectPaths(~)
            testFile = which(mfilename('class'));
            if isempty(testFile)
                return;
            end
            repoRoot = fileparts(fileparts(testFile));
            addpath(genpath(fullfile(repoRoot, 'src')));
            addpath(fullfile(repoRoot, 'tests'));
            addpath(fullfile(repoRoot, 'scripts'));
        end
    end

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



        function estimatePeakAcceptsSpectrumStruct(testCase)
            x = (0:9)';
            y = [0 1 0 2 0 3 0 1 0 0]';
            spectrum = struct('frequencyHz', x, 'magnitude', y);

            peaks = estimate_peak_1d(spectrum, struct('numPeaks', 2));
            testCase.verifyEqual(peaks.count, 2);
            testCase.verifyEqual(peaks.items(1).x, 5);
            testCase.verifyEqual(peaks.items(1).y, 3);
        end

        function estimatePeakRejectsLengthMismatch(testCase)
            testCase.verifyError(@() estimate_peak_1d([1 2 3], [1 2], struct('numPeaks', 1)), ...
                'estimate_peak_1d:LengthMismatch');
        end
    end
end
