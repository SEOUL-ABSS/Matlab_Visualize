classdef EthTcpStructRecorder < handle
    %ETHTCPSTRUCTRECORDER 콜백에서 받은 msg/meta/raw를 MAT/BIN으로 누적 저장.

    properties
        MatFilePath (1,:) char
        BinFilePath (1,:) char = ''

        StructName (1,:) char = ''
        VarName (1,:) char = 'records'
        MetaVarName (1,:) char = 'metaRecords'
        RawVarName (1,:) char = 'rawRecords'

        EnableMat (1,1) logical = true
        EnableBin (1,1) logical = false
        SaveRawToMat (1,1) logical = true
        RawMode (1,:) char = 'frame'   % 'frame' | 'body'
        FlushEvery (1,1) double = 1
    end

    properties (Access = private)
        matRecords cell = {}
        metaRecords cell = {}
        rawRecords cell = {}
        appendCount (1,1) double = 0
        binFid (1,1) double = -1
        closed (1,1) logical = false
    end

    methods
        function obj = EthTcpStructRecorder(matFilePath, varargin)
            if nargin < 1 || isempty(matFilePath)
                error('EthTcpStructRecorder:InvalidPath', 'matFilePath is required.');
            end
            obj.MatFilePath = char(matFilePath);
            obj = EthTcpStructRecorder.applyNameValue(obj, varargin{:});
            obj.ensureOpen();
        end

        function delete(obj)
            obj.close();
        end

        function append(obj, msg, meta)
            if nargin < 3 || isempty(meta)
                meta = struct();
            end
            obj.ensureOpen();

            obj.appendCount = obj.appendCount + 1;
            if obj.EnableMat
                obj.matRecords{end+1} = msg; %#ok<AGROW>
                obj.metaRecords{end+1} = EthTcpStructRecorder.normalizeMeta(meta); %#ok<AGROW>
                if obj.SaveRawToMat
                    obj.rawRecords{end+1} = EthTcpStructRecorder.extractRawBytes(msg, meta, obj.RawMode); %#ok<AGROW>
                end
            end

            if obj.EnableBin
                raw = EthTcpStructRecorder.extractRawBytes(msg, meta, obj.RawMode);
                EthTcpStructRecorder.writeLenPrefixed(obj.binFid, raw);
            end

            if mod(obj.appendCount, obj.FlushEvery) == 0
                obj.flush();
            end
        end

        function flush(obj)
            if obj.EnableMat
                records = obj.matRecords; %#ok<NASGU>
                metaRecords = obj.metaRecords; %#ok<NASGU>
                rawRecords = obj.rawRecords; %#ok<NASGU>
                save(obj.MatFilePath, 'records', 'metaRecords', 'rawRecords', '-v7.3');
            end
            if obj.EnableBin && obj.binFid > 0
                fflush(obj.binFid);
            end
        end

        function close(obj)
            if obj.closed
                return;
            end
            try
                obj.flush();
            catch
            end
            if obj.binFid > 0
                fclose(obj.binFid);
            end
            obj.binFid = -1;
            obj.closed = true;
        end
    end

    methods (Access = private)
        function ensureOpen(obj)
            if ~obj.closed
                return;
            end
            obj.closed = false;
            if obj.EnableBin
                obj.openBin();
            end
        end

        function openBin(obj)
            if isempty(obj.BinFilePath)
                [p,n,~] = fileparts(obj.MatFilePath);
                obj.BinFilePath = fullfile(p, [n '.bin']);
            end
            [d,~,~] = fileparts(obj.BinFilePath);
            if ~isempty(d) && exist(d,'dir')~=7
                mkdir(d);
            end
            obj.binFid = fopen(obj.BinFilePath, 'a');
            if obj.binFid < 0
                error('EthTcpStructRecorder:BinOpenFailed', 'Failed to open bin file: %s', obj.BinFilePath);
            end
        end
    end

    methods (Static)
        function metaOut = normalizeMeta(meta)
            metaOut = struct();
            if ~isstruct(meta)
                return;
            end
            fields = {'packetByteCount','packetSize','packetCount','topicId','checksumOk','checksumMode'};
            for i = 1:numel(fields)
                f = fields{i};
                if isfield(meta, f)
                    metaOut.(f) = meta.(f);
                end
            end
            if isfield(meta, 'header')
                metaOut.header = meta.header;
            end
        end

        function raw = extractRawBytes(msg, meta, rawMode)
            if nargin < 3 || isempty(rawMode)
                rawMode = 'frame';
            end

            raw = uint8([]);
            if strcmpi(rawMode, 'frame')
                if isstruct(meta) && isfield(meta, 'packetBytes') && isa(meta.packetBytes, 'uint8')
                    raw = meta.packetBytes(:)';
                    return;
                end
            end

            if isstruct(msg)
                if isfield(msg, 'rawBody') && isa(msg.rawBody, 'uint8')
                    raw = msg.rawBody(:)';
                    return;
                end
                if isfield(msg, '_rawBody') && isa(msg._rawBody, 'uint8')
                    raw = msg._rawBody(:)';
                    return;
                end
            end
        end

        function writeLenPrefixed(fid, raw)
            raw = uint8(raw(:)');
            len = uint32(numel(raw));
            fwrite(fid, len, 'uint32');
            if len > 0
                fwrite(fid, raw, 'uint8');
            end
        end

        function obj = applyNameValue(obj, varargin)
            if mod(numel(varargin),2) ~= 0
                error('EthTcpStructRecorder:InvalidNameValue', 'Name/value pairs are required.');
            end
            for i = 1:2:numel(varargin)
                name = char(varargin{i});
                value = varargin{i+1};
                if ~isprop(obj, name)
                    error('EthTcpStructRecorder:UnknownOption', 'Unknown option: %s', name);
                end
                obj.(name) = value;
            end
        end
    end
end
