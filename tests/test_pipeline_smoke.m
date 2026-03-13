classdef test_pipeline_smoke < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addProjectPaths(~)
            thisFile = mfilename('fullpath');
            if isempty(thisFile)
                thisFile = which(mfilename('class'));
            end
            if isempty(thisFile)
                warning('TestPathSetup:UnableToResolveFile', 'Could not resolve test file path.');
                return;
            end
            repoRoot = fileparts(fileparts(thisFile));
            addpath(genpath(fullfile(repoRoot, 'src')));
            addpath(fullfile(repoRoot, 'tests'));
            addpath(fullfile(repoRoot, 'scripts'));
        end
    end

    methods (Test)
        function executePipelineReturnsStructuredResult(testCase)
            inputData = struct();
            inputData.data = (1:64)';
            inputData.fs = 8000;
            inputData.timestamp = datetime(2024, 1, 1);
            inputData.type = 'timeseries';
            inputData.meta = struct('source', 'unit-test');

            cfg = get_default_config();
            result = execute_pipeline(inputData, cfg);

            expectedFields = {'raw','preprocessed','features','peaks','compare','display','log','meta'};
            for i = 1:numel(expectedFields)
                testCase.verifyTrue(isfield(result, expectedFields{i}), ...
                    sprintf('Missing result.%s', expectedFields{i}));
            end

            rawFields = {'data','fs','timestamp','type','meta'};
            for i = 1:numel(rawFields)
                testCase.verifyTrue(isfield(result.raw, rawFields{i}), ...
                    sprintf('Missing result.raw.%s', rawFields{i}));
            end
            testCase.verifyTrue(isfield(result.features, 'spectrum'));
            testCase.verifyGreaterThanOrEqual(result.peaks.count, 1);

            testCase.verifyTrue(isfield(result.compare, 'signal'));
            testCase.verifyTrue(isfield(result.compare, 'spectrum'));
            testCase.verifyEqual(numel(result.compare.signal.raw), numel(result.compare.signal.processed));
            testCase.verifyFalse(result.compare.meta.thresholdComparisonAvailable);
        end

        function appStateContainsExpectedShellFields(testCase)
            state = create_app_state();
            expectedStateFields = {
                'current_view','current_preset','current_frame_idx','selected_frame_idx', ...
                'threshold_enabled','threshold_value','panel_emphasis','current_input','current_result','waterfall', ...
                'frame_history','quality_history','detection_history','peak_trend','bearing', ...
                'frame_quality_summary','detection_summary','event_log','last_update_time', ...
                'last_issue','last_error_or_warning','last_exports','tcp'};
            for i = 1:numel(expectedStateFields)
                testCase.verifyTrue(isfield(state, expectedStateFields{i}), ...
                    sprintf('Missing state.%s', expectedStateFields{i}));
            end
        end

        function supportsMainViews(testCase)
            state = create_app_state();
            state = select_main_view(state, 'Spectrum');
            testCase.verifyEqual(state.current_view, 'Spectrum');
            state = select_main_view(state, 'Bearing Map');
            testCase.verifyEqual(state.current_view, 'Bearing Map');
            state = select_main_view(state, 'Bearing Frequency');
            testCase.verifyEqual(state.current_view, 'Bearing Frequency');
            state = select_main_view(state, 'Bearing Time');
            testCase.verifyEqual(state.current_view, 'Bearing Time');
        end


        function presetsApplyExpectedDefaults(testCase)
            state = create_app_state();

            state = apply_preset(state, 'Quick Check');
            testCase.verifyEqual(state.current_view, 'Spectrum');
            testCase.verifyFalse(state.threshold_enabled);

            state = apply_preset(state, 'Detection');
            testCase.verifyEqual(state.current_view, 'Spectrum');
            testCase.verifyTrue(state.threshold_enabled);
            testCase.verifyEqual(state.threshold_value, 0.2);

            state = apply_preset(state, 'History');
            testCase.verifyEqual(state.current_view, 'Waterfall');
            testCase.verifyFalse(state.threshold_enabled);

            state = apply_preset(state, 'Debug');
            testCase.verifyEqual(state.current_view, 'Frame Quality');
            testCase.verifyTrue(state.threshold_enabled);
            testCase.verifyEqual(state.threshold_value, 0.1);
            testCase.verifyTrue(state.panel_emphasis.qualityCard);
        end

        function selectedFrameSyncsRenderedContext(testCase)
            cfg = get_default_config();
            state = create_app_state();

            for k = 1:3
                inputData = struct(...
                    'data', sin(2*pi*(0:63)'/16 + 0.1*k), ...
                    'fs', 1024, ...
                    'timestamp', datetime(2024,1,1,0,0,k), ...
                    'type', 'timeseries', ...
                    'meta', struct('frameId', k));
                state = update_app_state(state, inputData, cfg);
            end

            state = select_frame_idx(state, 2);
            state = step_frame(state, 1);
            state = configure_waterfall_hold(state, true, [1 3 9]);

            testCase.verifyEqual(state.selected_frame_idx, 3);
            testCase.verifyEqual(state.frame_history{2}.frameIdx, 2);
            testCase.verifyEqual(size(state.waterfall.magnitudeMatrix, 1), 3);
            testCase.verifyEqual(state.waterfall.frame_indices, [1 2 3]);
            testCase.verifyEqual(numel(state.peak_trend), 3);
            testCase.verifyEqual(state.peak_trend(3).frameIdx, 3);
            testCase.verifyTrue(isfield(state.peak_trend, 'strongestPeakFrequencyHz'));
            testCase.verifyTrue(isfield(state.peak_trend, 'strongestPeakMagnitude'));
            testCase.verifyTrue(state.waterfall.hold_enabled);
            testCase.verifyEqual(state.waterfall.hold_frame_indices, [1 3]);
            testCase.verifyEqual(numel(state.detection_history), 3);
            testCase.verifyEqual(state.frame_quality_summary.inputLength, 64);
            testCase.verifyFalse(state.frame_quality_summary.nanOrInfPresent);
        end


        function waterfallRollingHistoryKeepsLatestFrames(testCase)
            cfg = get_default_config();
            state = create_app_state();
            state.waterfall.max_history_frames = 2;

            for k = 1:4
                inputData = struct(...
                    'data', sin(2*pi*(0:63)'/16 + 0.05*k), ...
                    'fs', 1024, ...
                    'timestamp', datetime(2024,1,1,0,1,k), ...
                    'type', 'timeseries', ...
                    'meta', struct('frameId', k));
                state = update_app_state(state, inputData, cfg);
            end

            testCase.verifyEqual(size(state.waterfall.magnitudeMatrix, 1), 2);
            testCase.verifyEqual(state.waterfall.frame_indices, [3 4]);
            testCase.verifyEqual(state.selected_frame_idx, 4);
        end


        function tcpMetadataContextCanBeUpdated(testCase)
            state = create_app_state();
            packet = struct(...
                'sequence', 42, ...
                'arrivalTime', datetime(2024,1,1,0,0,1), ...
                'payloadBytes', 2048, ...
                'sampleRateHz', 96000, ...
                'channelCount', 4);

            state = update_tcp_packet_context(state, packet);

            testCase.verifyTrue(state.tcp.enabled);
            testCase.verifyEqual(state.tcp.last_packet_meta.sequence, 42);
            testCase.verifyEqual(numel(state.tcp.packet_meta_history), 1);
            testCase.verifyEqual(state.tcp.status, 'metadata-only');
        end

        function sessionExportCreatesExpectedArtifacts(testCase)
            cfg = get_default_config();
            state = create_app_state();
            inputData = struct(...
                'data', sin(2*pi*(0:63)'/16), ...
                'fs', 1024, ...
                'timestamp', datetime(2024,1,1), ...
                'type', 'timeseries', ...
                'meta', struct('frameId', 1));
            state = update_app_state(state, inputData, cfg);

            fig = figure('Visible', 'off');
            cleanupObj = onCleanup(@() close(fig));
            uiState = render_dashboard(state, fig); %#ok<NASGU>

            [state, artifacts] = export_session_artifacts(state, fig, fullfile('data', 'output'), 'unit_session');

            testCase.verifyTrue(exist(artifacts.resultMat, 'file') == 2);
            testCase.verifyTrue(exist(artifacts.snapshotMat, 'file') == 2);
            testCase.verifyTrue(exist(artifacts.summaryCsv, 'file') == 2);
            testCase.verifyTrue(exist(artifacts.figurePng, 'file') == 2);
            testCase.verifyGreaterThanOrEqual(numel(state.event_log), 4);
            testCase.verifyEqual(state.last_exports.summaryCsv, artifacts.summaryCsv);
        end
    end
end
