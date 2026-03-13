function example_function_groups_usage()
%EXAMPLE_FUNCTION_GROUPS_USAGE 종류별 주요 함수 사용 예시 모음.
%   이 예시는 "실행 가능한 최소 흐름" 중심으로 구성되어 있으며,
%   실제 TCP 소켓을 열지 않고도 주요 API를 빠르게 익힐 수 있습니다.
%
%   category 1) app/session + pipeline
%   category 2) visualization + export
%   category 3) tcp metadata normalization
%   category 4) rx callback wrappers(save/log/plot/pipeline)
%   category 5) tcp server + schema registration(offline)

setup_project_paths();

fprintf('\n=== [Category 1] App/Session + Pipeline ===\n');
example_category_app_pipeline();

fprintf('\n=== [Category 2] Visualization + Export ===\n');
example_category_visualization_export();

fprintf('\n=== [Category 3] TCP Metadata Normalize ===\n');
example_category_tcp_metadata();

fprintf('\n=== [Category 4] RX Callback Wrappers ===\n');
example_category_rx_callbacks();

fprintf('\n=== [Category 5] EthTcpServer + Header Schema (offline) ===\n');
example_category_tcp_server_offline();

fprintf('\nAll grouped examples finished.\n');
end

function example_category_app_pipeline()
cfg = get_default_config();
state = create_app_state();
state = apply_preset(state, 'Quick Check');

for k = 1:3
    x = (0:255)';
    inputData = struct( ...
        'data', sin(2*pi*x/64 + 0.1*k) + 0.25*sin(2*pi*x/16), ...
        'fs', 1024, ...
        'timestamp', datetime(2024,1,1,0,0,k), ...
        'type', 'timeseries', ...
        'meta', struct('source', 'example_category_app_pipeline', 'frameId', k));

    state = update_app_state(state, inputData, cfg);
end

state = select_main_view(state, 'Peak Trend');
state = select_frame_idx(state, 2);
state = step_frame(state, +1);
state = configure_waterfall_hold(state, true, [1 3]);

fprintf('current=%d selected=%d view=%s preset=%s\n', ...
    state.current_frame_idx, state.selected_frame_idx, state.current_view, state.current_preset);
peakHz = get_detection_peak_hz_safe(state);
qualityLabel = get_quality_label_safe(state);
fprintf('peak(Hz)=%.3f quality=%s\n', peakHz, qualityLabel);
end

function example_category_visualization_export()
cfg = get_default_config();
state = create_app_state();
state = apply_preset(state, 'History');

x = (0:255)';
inputData = struct( ...
    'data', sin(2*pi*x/32) + 0.1*randn(size(x)), ...
    'fs', 2048, ...
    'timestamp', datetime('now'), ...
    'type', 'timeseries', ...
    'meta', struct('source', 'example_category_visualization_export'));
state = update_app_state(state, inputData, cfg);

fig = figure('Visible', 'off', 'Color', 'w');
cleanupFig = onCleanup(@() close(fig)); %#ok<NASGU>
uiState = render_dashboard(state, fig); %#ok<NASGU>

[state, artifacts] = export_session_artifacts(state, fig, fullfile('data', 'output'), 'example_grouped');
fprintf('exported figure=%s\n', artifacts.figurePng);
fprintf('exported result=%s\n', artifacts.resultMat);
end

function example_category_tcp_metadata()
% 수신 어댑터가 제공한 packet struct를 공통 메타 포맷으로 정규화하는 예시
rawPacket = struct( ...
    'sequence', 101, ...
    'arrivalTime', datetime('now'), ...
    'payloadBytes', 4096, ...
    'sampleRateHz', 48000, ...
    'channelCount', 2, ...
    'flags', struct('drop', false));

packetMeta = parse_tcp_packet_metadata(rawPacket);
contract = get_tcp_input_contract();

state = create_app_state();
state = update_tcp_packet_context(state, packetMeta);

fprintf('tcp.status=%s, sequence=%d\n', state.tcp.status, state.tcp.last_packet_meta.sequence);
fprintf('required packet fields: %s\n', strjoin(contract.packetRequiredFields, ', '));
end

function example_category_rx_callbacks()
% 실제 소켓 없이 synthetic msg/meta로 save/log/plot/pipeline 콜백 예시
msg = struct('a', single(sin(2*pi*(0:63)'/16)), 'label', 'synthetic');
meta = struct('topicId', 77, 'packetCount', 1, 'packetSize', 128);

eth_rx_save(msg, meta, 'Key', 'demo77', 'MatFile', fullfile('data', 'output', 'rx', 'demo77.mat'));
eth_rx_log(msg, meta, 'Key', 'demo77', 'LogFile', fullfile('data', 'output', 'logs', 'demo77.log'));
eth_rx_plot(msg, meta, 'Key', 'demo77', 'YField', 'a');

% 결합 래퍼(저장+로그+플롯)
eth_rx_pipeline(msg, meta, 'Save', true, 'Log', true, 'Plot', false, 'Key', 'demo77_pipe');

% persistent 리소스 정리
eth_rx_save('close');
eth_rx_log('close');
eth_rx_plot('close');
fprintf('rx callback wrappers executed with synthetic message.\n');
end

function example_category_tcp_server_offline()
% tcpserver.start()는 호출하지 않고, 헤더 기반 스키마 등록 흐름만 예시로 제공합니다.
headerPath = 'your_protocol_header.h';
structName = 'TestInputType';
topicId = 10;

srv = EthTcpServer('Port', 5000, 'ChecksumMode', 'byte');

fprintf(['offline usage template:\n', ...
    '  schema = EthTcpServer.schemaFromHeader(''%s'', ''%s'');\n', ...
    '  srv.registerTopic(%d, schema, @(msg,meta) eth_rx_pipeline(msg,meta));\n', ...
    'or\n', ...
    '  srv.registerFromHeader(%d, ''%s'', ''%s'');\n'], ...
    headerPath, structName, topicId, topicId, headerPath, structName);

% 위 경로가 실제로 존재하는 경우에만 registerFromHeader 예시를 실행
if exist(headerPath, 'file') == 2
    srv.registerFromHeader(topicId, headerPath, structName);
    fprintf('registerFromHeader executed with local header file.\n');
else
    fprintf('header file not found; skipped registerFromHeader execution.\n');
end
end

function hz = get_detection_peak_hz_safe(state)
hz = NaN;
if isstruct(state) && isfield(state, 'detection_summary') && isstruct(state.detection_summary) ...
        && isfield(state.detection_summary, 'strongestPeakFrequencyHz')
    hz = state.detection_summary.strongestPeakFrequencyHz;
    return;
end
if isstruct(state) && isfield(state, 'detection_history') && ~isempty(state.detection_history)
    last = state.detection_history{end};
    if isstruct(last) && isfield(last, 'strongestPeakFrequencyHz')
        hz = last.strongestPeakFrequencyHz;
    end
end
end

function label = get_quality_label_safe(state)
label = 'unknown';
if isstruct(state) && isfield(state, 'frame_quality_summary') && isstruct(state.frame_quality_summary) ...
        && isfield(state.frame_quality_summary, 'qualityLabel')
    label = state.frame_quality_summary.qualityLabel;
end
end
