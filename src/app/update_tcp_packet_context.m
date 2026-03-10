function state = update_tcp_packet_context(state, packetLike)
%UPDATE_TCP_PACKET_CONTEXT Update app-state TCP packet metadata placeholders.
%   This function only updates metadata context; it does not decode payloads.

if nargin < 2 || isempty(packetLike)
    return;
end

packetMeta = parse_tcp_packet_metadata(packetLike);

if ~isfield(state, 'tcp') || ~isstruct(state.tcp)
    state.tcp = struct('contract', get_tcp_input_contract(), 'enabled', true, ...
        'last_packet_meta', struct(), 'packet_meta_history', {{}}, 'status', 'metadata-only');
end

state.tcp.enabled = true;
state.tcp.last_packet_meta = packetMeta;
state.tcp.packet_meta_history{end+1} = packetMeta;
state.tcp.status = 'metadata-only';

state = update_event_log(state, 'INFO', 'TCP packet metadata updated', struct(...
    'sequence', packetMeta.sequence, ...
    'sampleRateHz', packetMeta.sampleRateHz, ...
    'payloadBytes', packetMeta.payloadBytes));
end
