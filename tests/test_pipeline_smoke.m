classdef test_pipeline_smoke < matlab.unittest.TestCase
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

            expectedFields = {'raw','preprocessed','features','peaks','display','log','meta'};
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
        end

        function appStateContainsExpectedShellFields(testCase)
            state = create_app_state();
            expectedStateFields = {
                'current_view','current_preset','current_frame_idx','selected_frame_idx', ...
                'threshold_enabled','threshold_value','current_input','current_result','waterfall', ...
                'frame_history','quality_history','peak_trend','bearing', ...
                'frame_quality_summary','event_log','last_update_time','last_issue'};
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
            testCase.verifyEqual(numel(state.peak_trend), 3);
            testCase.verifyTrue(state.waterfall.hold_enabled);
            testCase.verifyEqual(state.waterfall.hold_frame_indices, [1 3]);
        end

        function summaryAndSnapshotExportCreateFiles(testCase)
            cfg = get_default_config();
            state = create_app_state();
            inputData = struct(...
                'data', sin(2*pi*(0:63)'/16), ...
                'fs', 1024, ...
                'timestamp', datetime(2024,1,1), ...
                'type', 'timeseries', ...
                'meta', struct('frameId', 1));
            state = update_app_state(state, inputData, cfg);

            snapshotFile = export_state_snapshot(state, fullfile('data', 'output', 'snapshots'), 'unit_snapshot');
            summaryFile = export_result_summary(state, fullfile('data', 'output', 'summaries'), 'unit_summary');

            testCase.verifyTrue(exist(snapshotFile, 'file') == 2);
            testCase.verifyTrue(exist(summaryFile, 'file') == 2);
        end
    end
end
