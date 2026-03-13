function state = example_underwater_exhibition_scenario()
%EXAMPLE_UNDERWATER_EXHIBITION_SCENARIO 수중 탐지 전시용 시나리오 예제.
%   - 임의 소나/수중음향 탐지 환경을 가정한 프레임 기반 시뮬레이션
%   - 파이프라인(분석)과 대시보드 렌더링(표시)을 분리해 사용
%   - 프레임 처리 중 주기적으로 스냅샷 산출물을 생성
%
%   출력:
%     state : 마지막 프레임 반영 후 앱 상태

setup_project_paths();
rng(42); % deterministic demo

cfg = get_default_config();
state = create_app_state();
state = apply_preset(state, 'Detection');
state = select_main_view(state, 'Spectrum');
state.waterfall.max_history_frames = 50;

scenario = create_exhibition_scenario_config();
logger = create_logger(fullfile('data', 'output', 'logs'), 'underwater_exhibition');
log_event(logger, 'INFO', 'Underwater exhibition scenario started', scenario);

fig = figure('Visible', 'off', 'Color', 'w');
cleanupFig = onCleanup(@() close(fig)); %#ok<NASGU>

for k = 1:scenario.nFrames
    inputData = synthesize_underwater_frame(scenario, k);
    inputData.meta.packet = parse_tcp_packet_metadata(inputData.meta.packet);

    state = update_app_state(state, inputData, cfg);

    % 전시 연출용 뷰 전환: 탐색 -> 추이 -> 폭포
    if k == floor(scenario.nFrames * 0.35)
        state = select_main_view(state, 'Peak Trend');
    elseif k == floor(scenario.nFrames * 0.7)
        state = select_main_view(state, 'Waterfall');
    end

    if mod(k, 15) == 0
        uiState = render_dashboard(state, fig); %#ok<NASGU>
        tag = sprintf('underwater_demo_f%03d', k);
        [state, artifacts] = export_session_artifacts(state, fig, fullfile('data', 'output'), tag);
        log_event(logger, 'INFO', 'Interim export completed', struct('frameIdx', k, 'artifacts', artifacts));
    end
end

% 마지막 프레임 기준 최종 내보내기
uiState = render_dashboard(state, fig); %#ok<NASGU>
[state, artifacts] = export_session_artifacts(state, fig, fullfile('data', 'output'), 'underwater_demo_final');
log_event(logger, 'INFO', 'Final export completed', artifacts);

fprintf('[underwater_demo] frames=%d, strongestPeak=%.2f Hz, quality=%s\n', ...
    state.current_frame_idx, state.detection_summary.strongestPeakFrequencyHz, state.frame_quality_summary.qualityLabel);
end

function scenario = create_exhibition_scenario_config()
scenario = struct();
scenario.fs = 4096;
scenario.nSamples = 2048;
scenario.nFrames = 60;
scenario.baseToneHz = 190;
scenario.secondaryToneHz = 420;
scenario.propellerBandHz = [70 130];
scenario.chirpHzStart = 260;
scenario.chirpHzStop = 560;
scenario.noiseStd = 0.08;
scenario.demoName = 'Underwater Detection Exhibit';
scenario.taskId = 'EXHIBIT_UW_001';
scenario.channelCount = 8;
end

function inputData = synthesize_underwater_frame(scenario, frameIdx)
fs = scenario.fs;
n = scenario.nSamples;
t = (0:n-1)'/fs;

% phase 1: 탐색 배경(저주파 추진기 + 약한 고정톤)
phase1 = 0.2*sin(2*pi*scenario.baseToneHz*t + 0.03*frameIdx);
propeller = 0.15*sin(2*pi*(scenario.propellerBandHz(1) + 8*sin(0.04*frameIdx))*t);

% phase 2: 대상 접근(보조 톤 강화)
secondaryGain = min(1, max(0, (frameIdx-18)/18));
phase2 = secondaryGain * 0.25*sin(2*pi*scenario.secondaryToneHz*t + 0.06*frameIdx);

% phase 3: 분류 구간(짧은 chirp 이벤트)
chirpGain = double(frameIdx >= 35 && frameIdx <= 48);
chirpSig = chirpGain * 0.3 * synth_lfm_chirp(t, scenario.chirpHzStart, scenario.chirpHzStop);

noise = scenario.noiseStd * randn(n,1);
x = phase1 + propeller + phase2 + chirpSig + noise;

packet = struct( ...
    'sequence', frameIdx, ...
    'arrivalTime', datetime(2024,1,1,0,0,0) + seconds(frameIdx-1), ...
    'payloadBytes', n*4, ...
    'sampleRateHz', fs, ...
    'channelCount', scenario.channelCount, ...
    'flags', struct('phase2Active', secondaryGain > 0.1, 'chirpActive', logical(chirpGain)));

inputData = struct();
inputData.data = x;
inputData.fs = fs;
inputData.timestamp = packet.arrivalTime;
inputData.type = 'timeseries';
inputData.meta = struct( ...
    'source', 'simulated-underwater-array', ...
    'taskId', scenario.taskId, ...
    'phaseLabel', phase_label(frameIdx), ...
    'packet', packet, ...
    'axisMeta', struct('time', struct('name', 'time', 'unit', 's'), 'amplitude', struct('name', 'pressure', 'unit', 'norm')), ...
    'expectedPeakMeta', struct('primaryHz', scenario.baseToneHz, 'secondaryHz', scenario.secondaryToneHz));
end

function label = phase_label(frameIdx)
if frameIdx < 20
    label = 'search';
elseif frameIdx < 40
    label = 'approach';
else
    label = 'classify';
end
end

function y = synth_lfm_chirp(t, f0, f1)
% toolbox-free linear-FM chirp
T = t(end) - t(1);
if T <= 0
    y = sin(2*pi*f0*t);
    return;
end
k = (f1 - f0) / T;
phase = 2*pi*(f0*t + 0.5*k*t.^2);
y = sin(phase);
end
