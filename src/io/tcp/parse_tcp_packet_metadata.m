function packetMeta = parse_tcp_packet_metadata(packet)
%PARSE_TCP_PACKET_METADATA Extract standardized metadata from TCP packet-like struct.
%   Future TCP receiver should provide raw packet structs compatible with this contract.

if ~isstruct(packet)
    error('parse_tcp_packet_metadata:InvalidPacket', 'packet must be a struct.');
end

packetMeta = struct();
packetMeta.source = 'tcp';
packetMeta.sequence = get_or_default(packet, 'sequence', NaN);
packetMeta.arrivalTime = get_or_default(packet, 'arrivalTime', datetime('now'));
packetMeta.payloadBytes = get_or_default(packet, 'payloadBytes', NaN);
packetMeta.channelCount = get_or_default(packet, 'channelCount', NaN);
packetMeta.sampleRateHz = get_or_default(packet, 'sampleRateHz', NaN);
packetMeta.flags = get_or_default(packet, 'flags', struct());
end

function value = get_or_default(s, fieldName, defaultValue)
if isfield(s, fieldName)
    value = s.(fieldName);
else
    value = defaultValue;
end
end
