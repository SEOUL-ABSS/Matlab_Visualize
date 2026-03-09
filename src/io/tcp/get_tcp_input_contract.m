function contract = get_tcp_input_contract()
%GET_TCP_INPUT_CONTRACT Return future-ready TCP frame contract descriptor.

contract = struct();
contract.packetRequiredFields = {'sequence','arrivalTime','payloadBytes','sampleRateHz'};
contract.normalizedInputFields = {'data','fs','timestamp','type','meta'};
contract.metaFields = {'packet','source','channelMap','taskId'};
contract.notes = 'TCP adapters should normalize to inputData contract before pipeline execution.';
end
