function example_rx_tools_usage()
%EXAMPLE_RX_TOOLS_USAGE save/log/plot 파이프라인 사용 예시.

headerPath = 'your_protocol_header.h';

srv = EthTcpServer('Port', 5000, 'ChecksumMode', 'byte');
schema = EthTcpServer.schemaFromHeader(headerPath, 'TestInputType');

srv.registerTopic(10, schema, @(msg,meta) eth_rx_pipeline(msg, meta, ...
    'Save', true, 'Log', true, 'Plot', true, 'Key', 'topic10'));

srv.start();

disp('RX pipeline started. 종료 시 아래 호출:');
disp('  eth_rx_save("close"); eth_rx_log("close"); eth_rx_plot("close"); srv.stop();');
end
