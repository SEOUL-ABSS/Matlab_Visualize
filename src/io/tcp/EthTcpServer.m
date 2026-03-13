classdef EthTcpServer < handle
    %ETHTCPSERVER TCP 수신 + 헤더/바디 디코딩 + 헤더 기반 스키마 생성 클래스.
    %   - TCP 바이트 스트림 버퍼링
    %   - StartCode 동기화
    %   - unPacketSize(전체 패킷 길이) 기준 프레이밍
    %   - 스키마 기반 바디 디코드
    %   - 포인터/중첩구조체/다차원배열/typedef alias 처리

    properties
        Port (1,1) double = 0
        ChecksumMode (1,:) char = 'byte'           % 'byte' | 'u32'
        PointerSizeBytes (1,1) double = 8
        PointerMatType (1,:) char = 'uint64'
        CharArrayNullTerminated (1,1) logical = true

        StripLeadingHeaderField (1,1) logical = true
        HeaderFieldName (1,:) char = 'header'
        HeaderTypeName (1,:) char = 'T_ETH_HEADER_TCP'
        FlattenStructs (1,1) logical = true

        % StartCode 2개 uint32(LE) 기본값: 0x55AA55AA, 0xAA55AA55
        StartCodeWords (1,2) uint32 = uint32([hex2dec('55AA55AA'), hex2dec('AA55AA55')])

        TcpServer = []
        Buffer (1,:) uint8 = uint8([])

        % topicId(double) -> struct('schema',schema,'callback',func)
        TopicRegistry
    end

    methods
        function obj = EthTcpServer(varargin)
            obj.TopicRegistry = containers.Map('KeyType', 'double', 'ValueType', 'any');
            obj = EthTcpServer.applyNameValue(obj, varargin{:});
            EthTcpServer.validatePointerConfig(obj.PointerSizeBytes, obj.PointerMatType);
        end

        function delete(obj)
            obj.stop();
        end

        function start(obj)
            if isempty(obj.Port) || obj.Port <= 0
                error('EthTcpServer:InvalidPort', 'Port must be a positive integer.');
            end
            if ~isempty(obj.TcpServer)
                return;
            end
            if exist('tcpserver', 'file') ~= 2
                error('EthTcpServer:NoTcpServer', 'tcpserver is not available in this MATLAB environment.');
            end

            obj.TcpServer = tcpserver("0.0.0.0", obj.Port, ...
                "ConnectionChangedFcn", @(src,evt) obj.onConnectionChanged(src,evt)); %#ok<NASGU>
            configureCallback(obj.TcpServer, 'byte', 1, @(src,evt) obj.onTcpBytes(src,evt));
        end

        function stop(obj)
            if ~isempty(obj.TcpServer)
                try
                    configureCallback(obj.TcpServer, 'off');
                catch
                end
                try
                    clear obj.TcpServer;
                catch
                end
                obj.TcpServer = [];
            end
        end

        function registerTopic(obj, topicId, schema, callbackFcn)
            validateattributes(topicId, {'numeric'}, {'scalar','integer','nonnegative'});
            if nargin < 4 || isempty(callbackFcn)
                callbackFcn = [];
            end
            entry = struct('schema', schema, 'callback', callbackFcn);
            obj.TopicRegistry(double(topicId)) = entry;
        end

        function registerFromHeader(obj, topicId, headerFiles, structName, varargin)
            schema = EthTcpServer.schemaFromHeader(headerFiles, structName, ...
                'StripLeadingHeaderField', obj.StripLeadingHeaderField, ...
                'HeaderFieldName', obj.HeaderFieldName, ...
                'HeaderTypeName', obj.HeaderTypeName, ...
                'CharArrayNullTerminated', obj.CharArrayNullTerminated, ...
                'FlattenStructs', obj.FlattenStructs, ...
                'PointerSizeBytes', obj.PointerSizeBytes, ...
                'PointerMatType', obj.PointerMatType, ...
                varargin{:});
            obj.registerTopic(topicId, schema, []);
        end

        function onBytes(obj, newBytes)
            % 테스트/오프라인 환경에서 직접 호출 가능한 바이트 입력 경로
            if isempty(newBytes)
                return;
            end
            newBytes = uint8(newBytes(:)');
            obj.Buffer = [obj.Buffer, newBytes]; %#ok<AGROW>
            obj.processBuffer();
        end
    end

    methods (Access = private)
        function onConnectionChanged(~, ~, ~)
            % no-op placeholder
        end

        function onTcpBytes(obj, src, ~)
            n = src.NumBytesAvailable;
            if n <= 0
                return;
            end
            bytes = read(src, n, 'uint8');
            obj.onBytes(bytes);
        end

        function processBuffer(obj)
            syncBytes = EthTcpServer.startWordsToBytes(obj.StartCodeWords);
            minHeaderBytes = 36; % T_ETH_HEADER_TCP 고정 길이 (StartCode~CheckSum)

            while true
                if numel(obj.Buffer) < minHeaderBytes
                    return;
                end

                idx = EthTcpServer.findSyncIndex(obj.Buffer, syncBytes);
                if isempty(idx)
                    % 마지막 sync 후보 길이만 남기고 버림
                    keep = min(numel(syncBytes)-1, numel(obj.Buffer));
                    obj.Buffer = obj.Buffer(end-keep+1:end);
                    return;
                end

                if idx > 1
                    obj.Buffer = obj.Buffer(idx:end);
                end

                if numel(obj.Buffer) < minHeaderBytes
                    return;
                end

                [hdr, okHdr] = EthTcpServer.decodeHeader(obj.Buffer(1:minHeaderBytes));
                if ~okHdr
                    obj.Buffer = obj.Buffer(2:end);
                    continue;
                end

                packetSize = double(hdr.unPacketSize);
                if packetSize < minHeaderBytes
                    obj.Buffer = obj.Buffer(2:end);
                    continue;
                end

                if numel(obj.Buffer) < packetSize
                    return;
                end

                frameBytes = obj.Buffer(1:packetSize);
                obj.Buffer = obj.Buffer(packetSize+1:end);

                body = frameBytes(minHeaderBytes+1:end);
                msg = struct();
                meta = struct();

                meta.packetBytes = frameBytes;
                meta.packetByteCount = double(numel(frameBytes));
                meta.packetSize = double(hdr.unPacketSize);
                meta.packetCount = double(hdr.unPacketCount);
                meta.topicId = double(hdr.usTopicID);
                meta.header = hdr;

                [csOk, csCalc, csExpected] = EthTcpServer.verifyChecksum(frameBytes, hdr.unCheckSum, obj.ChecksumMode);
                meta.checksumOk = csOk;
                meta.checksumMode = obj.ChecksumMode;
                meta.checksumCalculated = csCalc;
                meta.checksumExpected = csExpected;

                msg.rawBody = body(:)';
                msg._rawBody = msg.rawBody;

                topicId = double(hdr.usTopicID);
                if isKey(obj.TopicRegistry, topicId)
                    entry = obj.TopicRegistry(topicId);
                    if ~isempty(entry.schema)
                        decoded = EthTcpServer.decodeBody(body, entry.schema, ...
                            'CharArrayNullTerminated', obj.CharArrayNullTerminated, ...
                            'PointerSizeBytes', obj.PointerSizeBytes, ...
                            'PointerMatType', obj.PointerMatType);
                        msg = EthTcpServer.mergeStruct(msg, decoded);
                    end

                    if ~isempty(entry.callback)
                        try
                            entry.callback(msg, meta);
                        catch cbErr
                            warning('EthTcpServer:CallbackFailed', 'Topic callback failed: %s', cbErr.message);
                        end
                    end
                end
            end
        end
    end

    methods (Static)
        function schema = schemaFromHeader(headerFiles, structName, varargin)
            %SCHEMAFROMHEADER 헤더 파일에서 구조체 스키마 생성.
            %   schema = EthTcpServer.schemaFromHeader(headerFiles, structName, ...)

            p = inputParser;
            p.addParameter('StripLeadingHeaderField', true, @(x)islogical(x)||isnumeric(x));
            p.addParameter('HeaderFieldName', 'header', @(x)ischar(x)||isstring(x));
            p.addParameter('HeaderTypeName', 'T_ETH_HEADER_TCP', @(x)ischar(x)||isstring(x));
            p.addParameter('CharArrayNullTerminated', true, @(x)islogical(x)||isnumeric(x));
            p.addParameter('FlattenStructs', true, @(x)islogical(x)||isnumeric(x));
            p.addParameter('TypeMap', containers.Map('KeyType','char','ValueType','char'));
            p.addParameter('PointerSizeBytes', 8, @(x)isnumeric(x)&&isscalar(x)&&ismember(x,[4 8]));
            p.addParameter('PointerMatType', 'uint64', @(x)ischar(x)||isstring(x));
            p.parse(varargin{:});
            opts = p.Results;

            opts.HeaderFieldName = char(opts.HeaderFieldName);
            opts.HeaderTypeName = char(opts.HeaderTypeName);
            opts.PointerMatType = char(opts.PointerMatType);
            opts.FlattenStructs = logical(opts.FlattenStructs);
            opts.StripLeadingHeaderField = logical(opts.StripLeadingHeaderField);
            opts.CharArrayNullTerminated = logical(opts.CharArrayNullTerminated);

            EthTcpServer.validatePointerConfig(opts.PointerSizeBytes, opts.PointerMatType);

            if ischar(headerFiles) || isstring(headerFiles)
                headerFiles = cellstr(headerFiles);
            end

            rawText = EthTcpServer.readHeaders(headerFiles);
            noComments = EthTcpServer.stripCommentsPreserveDirectives(rawText);
            defineMap = EthTcpServer.parseNumericDefines(noComments);
            preprocessed = EthTcpServer.stripPreprocessorDirectives(noComments);

            [structDefs, structTagAlias] = EthTcpServer.parseStructDefinitions(preprocessed);
            typedefMap = EthTcpServer.parseTypedefAliases(preprocessed, defineMap);
            typedefMap = EthTcpServer.mergeMaps(typedefMap, structTagAlias);

            typeMap = EthTcpServer.defaultTypeMap();
            userTypeMap = opts.TypeMap;
            if ~isempty(userTypeMap)
                userKeys = userTypeMap.keys;
                for i = 1:numel(userKeys)
                    typeMap(userKeys{i}) = userTypeMap(userKeys{i});
                end
            end

            buildCtx = struct(...
                'defineMap', defineMap, ...
                'typedefMap', typedefMap, ...
                'structDefs', structDefs, ...
                'typeMap', typeMap, ...
                'opts', opts);

            targetName = char(structName);
            schema = EthTcpServer.buildSchemaForStruct(targetName, buildCtx, {});

            if opts.StripLeadingHeaderField && ~isempty(schema.fields)
                f1 = schema.fields(1);
                if strcmp(f1.name, opts.HeaderFieldName) || strcmp(f1.typeNameResolved, opts.HeaderTypeName)
                    schema.fields = schema.fields(2:end);
                    schema.byteSize = schema.byteSize - f1.byteSize;
                end
            end
        end

        function [msg, bytesUsed] = decodeBody(bodyBytes, schema, varargin)
            p = inputParser;
            p.addParameter('CharArrayNullTerminated', true, @(x)islogical(x)||isnumeric(x));
            p.addParameter('PointerSizeBytes', 8, @(x)isnumeric(x)&&isscalar(x)&&ismember(x,[4 8]));
            p.addParameter('PointerMatType', 'uint64', @(x)ischar(x)||isstring(x));
            p.parse(varargin{:});
            opts = p.Results;
            opts.PointerMatType = char(opts.PointerMatType);

            EthTcpServer.validatePointerConfig(opts.PointerSizeBytes, opts.PointerMatType);

            [msg, bytesUsed] = EthTcpServer.decodeSchemaStruct(uint8(bodyBytes(:)'), schema, opts);
            msg.rawBody = uint8(bodyBytes(:)');
            msg._rawBody = msg.rawBody;
        end

    end

    methods (Static, Access = private)
        function obj = applyNameValue(obj, varargin)
            if mod(numel(varargin),2) ~= 0
                error('EthTcpServer:InvalidNameValue', 'Name/value pairs are required.');
            end
            for i = 1:2:numel(varargin)
                name = char(varargin{i});
                val = varargin{i+1};
                if ~isprop(obj, name)
                    error('EthTcpServer:UnknownProperty', 'Unknown property: %s', name);
                end
                obj.(name) = val;
            end
        end

        function bytes = startWordsToBytes(words)
            bytes = reshape(typecast(uint32(words), 'uint8'), 1, []);
        end

        function idx = findSyncIndex(buf, syncBytes)
            idx = [];
            n = numel(buf);
            m = numel(syncBytes);
            if n < m
                return;
            end
            for i = 1:(n-m+1)
                if all(buf(i:i+m-1) == syncBytes)
                    idx = i;
                    return;
                end
            end
        end

        function [hdr, ok] = decodeHeader(bytes36)
            ok = false;
            hdr = struct();
            if numel(bytes36) < 36
                return;
            end
            b = uint8(bytes36(:)');
            hdr.unStartCode = typecast(b(1:8), 'uint32');
            hdr.usSendEquip = typecast(b(9:10), 'uint16');
            hdr.usRecvEquip = typecast(b(11:12), 'uint16');
            hdr.usSendCSCI = typecast(b(13:14), 'uint16');
            hdr.usTopicID = typecast(b(15:16), 'uint16');
            hdr.unPacketSize = typecast(b(17:20), 'uint32');
            hdr.unPacketCount = typecast(b(21:24), 'uint32');
            hdr.stSendTime = EthTcpServer.decodeTimeTcp(b(25:32));
            hdr.unCheckSum = typecast(b(33:36), 'uint32');
            ok = true;
        end

        function t = decodeTimeTcp(bytes8)
            b = uint8(bytes8(:)');
            if numel(b) < 8
                t = struct('year',uint16(0),'month',uint8(0),'day',uint8(0),'hour',uint8(0),'min',uint8(0),'msec',uint16(0));
                return;
            end
            t = struct();
            t.year = typecast(b(1:2), 'uint16');
            t.month = b(3);
            t.day = b(4);
            t.hour = b(5);
            t.min = b(6);
            t.msec = typecast(b(7:8), 'uint16');
        end

        function [ok, calc, expected] = verifyChecksum(packetBytes, expectedU32, mode)
            bytes = uint8(packetBytes(:)');
            expected = uint32(expectedU32);
            switch lower(mode)
                case 'byte'
                    calc = uint32(mod(sum(uint32(bytes)), 2^32));
                case 'u32'
                    pad = mod(4 - mod(numel(bytes), 4), 4);
                    if pad > 0
                        bytes = [bytes, zeros(1,pad,'uint8')]; %#ok<AGROW>
                    end
                    words = typecast(bytes, 'uint32');
                    calc = uint32(mod(sum(uint64(words)), 2^32));
                otherwise
                    error('EthTcpServer:UnsupportedChecksumMode', 'Unsupported checksum mode: %s', mode);
            end
            ok = isequal(calc, expected);
        end

        function out = mergeStruct(a, b)
            out = a;
            if isempty(b)
                return;
            end
            fn = fieldnames(b);
            for i = 1:numel(fn)
                out.(fn{i}) = b.(fn{i});
            end
        end

        function txt = readHeaders(headerFiles)
            parts = cell(1, numel(headerFiles));
            for i = 1:numel(headerFiles)
                f = headerFiles{i};
                if exist(f, 'file') ~= 2
                    error('EthTcpServer:HeaderNotFound', 'Header file not found: %s', f);
                end
                parts{i} = fileread(f);
            end
            txt = strjoin(parts, sprintf('\n'));
            txt = strrep(txt, sprintf('\r\n'), sprintf('\n'));
            txt = strrep(txt, sprintf('\r'), sprintf('\n'));
        end

        function out = stripCommentsPreserveDirectives(txt)
            % 문자열/문자 리터럴은 정교 처리하지 않고 C 헤더 일반 케이스 기준으로 처리.
            out = regexprep(txt, '/\*.*?\*/', '', 'dotexceptnewline');
            lines = regexp(out, '\n', 'split');
            for i = 1:numel(lines)
                line = lines{i};
                q = strfind(line, '//');
                if ~isempty(q)
                    lines{i} = line(1:q(1)-1);
                end
            end
            out = strjoin(lines, sprintf('\n'));
        end

        function defMap = parseNumericDefines(txt)
            defMap = containers.Map('KeyType','char','ValueType','double');
            lines = regexp(txt, '\n', 'split');
            for i = 1:numel(lines)
                line = strtrim(lines{i});
                tok = regexp(line, '^#\s*define\s+([A-Za-z_][A-Za-z0-9_]*)\s+(.+)$', 'tokens', 'once');
                if isempty(tok)
                    continue;
                end
                name = tok{1};
                expr = strtrim(tok{2});
                % 함수형 매크로 제외
                if contains(name, '(')
                    continue;
                end
                val = EthTcpServer.evalConstExpr(expr, defMap);
                if ~isnan(val)
                    defMap(name) = val;
                end
            end
        end

        function out = stripPreprocessorDirectives(txt)
            % 라인 스캔 방식으로만 제거. (#pragma once 회귀 방지)
            lines = regexp(txt, '\n', 'split');
            kept = {};
            i = 1;
            while i <= numel(lines)
                line = lines{i};
                s = strtrim(line);
                if startsWith(s, '#')
                    % continuation line skip
                    while ~isempty(line) && EthTcpServer.endsWithBackslash(line) && i < numel(lines)
                        i = i + 1;
                        line = lines{i};
                    end
                else
                    kept{end+1} = line; %#ok<AGROW>
                end
                i = i + 1;
            end
            out = strjoin(kept, sprintf('\n'));
        end

        function tf = endsWithBackslash(line)
            lt = strtrim(line);
            tf = ~isempty(lt) && lt(end) == '\\';
        end

        function [structDefs, structTagAlias] = parseStructDefinitions(txt)
            structDefs = containers.Map('KeyType','char','ValueType','any');
            structTagAlias = containers.Map('KeyType','char','ValueType','any');

            n = strlength(txt);
            pos = 1;
            raw = char(txt);
            while pos <= n
                [s, e, tok, match] = regexp(raw(pos:end), '(typedef\s+)?struct\s+([A-Za-z_][A-Za-z0-9_]*)?\s*\{', 'start', 'end', 'tokens', 'match', 'once'); %#ok<ASGLU>
                if isempty(s)
                    break;
                end
                sAbs = pos + s - 1;
                eAbs = pos + e - 1;

                [closeIdx, ok] = EthTcpServer.findMatchingBrace(raw, eAbs);
                if ~ok
                    error('EthTcpServer:StructParse', 'Unmatched brace in struct definition.');
                end

                body = raw(eAbs+1 : closeIdx-1);
                tail = raw(closeIdx+1:end);
                semi = strfind(tail, ';');
                if isempty(semi)
                    error('EthTcpServer:StructParse', 'Missing semicolon after struct definition.');
                end
                trailer = strtrim(tail(1:semi(1)-1));

                isTypedef = ~isempty(tok{1});
                tagName = strtrim(tok{2});
                typedefName = '';
                if isTypedef
                    t = regexp(trailer, '^([A-Za-z_][A-Za-z0-9_]*)', 'tokens', 'once');
                    if ~isempty(t)
                        typedefName = t{1};
                    end
                end

                canonical = '';
                if ~isempty(typedefName)
                    canonical = typedefName;
                elseif ~isempty(tagName)
                    canonical = tagName;
                end
                if isempty(canonical)
                    error('EthTcpServer:StructParse', 'Unable to infer struct canonical name.');
                end

                fields = EthTcpServer.parseStructFields(body);
                def = struct('name', canonical, 'tagName', tagName, 'fields', fields);
                structDefs(canonical) = def;

                if ~isempty(tagName) && ~strcmp(tagName, canonical)
                    structTagAlias(tagName) = struct('kind','alias','baseType',canonical,'pointerLevel',0,'arrayDims',[]);
                end

                pos = closeIdx + semi(1) + 1;
            end
        end

        function fields = parseStructFields(body)
            stmts = EthTcpServer.splitTopLevelStatements(body);
            fields = struct('name', {}, 'baseType', {}, 'pointerLevel', {}, 'arrayDimsExpr', {});
            for i = 1:numel(stmts)
                stmt = strtrim(stmts{i});
                if isempty(stmt)
                    continue;
                end
                if contains(stmt, ',')
                    error('EthTcpServer:UnsupportedDeclaration', 'Comma-separated declarations are unsupported: %s', stmt);
                end
                if contains(stmt, ':')
                    error('EthTcpServer:UnsupportedDeclaration', 'Bitfields are unsupported: %s', stmt);
                end
                if contains(stmt, '(') || contains(stmt, ')')
                    error('EthTcpServer:UnsupportedDeclaration', 'Complex/function-pointer declarators unsupported: %s', stmt);
                end

                [name, baseType, ptrLevel, arrDims] = EthTcpServer.parseSingleDeclarator(stmt);
                fields(end+1) = struct('name', name, 'baseType', baseType, 'pointerLevel', ptrLevel, 'arrayDimsExpr', {arrDims}); %#ok<AGROW>
            end
        end

        function [name, baseType, ptrLevel, arrDims] = parseSingleDeclarator(stmt)
            stmt = EthTcpServer.stripSalLikeTokens(stmt);
            dimsTok = regexp(stmt, '\[([^\]]+)\]', 'tokens');
            arrDims = cellfun(@(c)strtrim(c{1}), dimsTok, 'UniformOutput', false);
            stmtNoDims = regexprep(stmt, '\[[^\]]+\]', '');
            stmtNoDims = strtrim(stmtNoDims);

            tokName = regexp(stmtNoDims, '([A-Za-z_][A-Za-z0-9_]*)\s*$', 'tokens', 'once');
            if isempty(tokName)
                error('EthTcpServer:FieldParse', 'Cannot parse field name from declaration: %s', stmt);
            end
            name = tokName{1};

            prefix = strtrim(stmtNoDims(1:end-numel(name)));
            ptrLevel = count(prefix, '*');
            baseType = strtrim(strrep(prefix, '*', ''));

            if isempty(baseType)
                error('EthTcpServer:FieldParse', 'Cannot parse base type from declaration: %s', stmt);
            end
        end

        function parts = splitTopLevelStatements(body)
            parts = {};
            depth = 0;
            cur = '';
            for i = 1:numel(body)
                ch = body(i);
                if ch == '{'
                    depth = depth + 1;
                elseif ch == '}'
                    depth = max(0, depth - 1);
                end

                if ch == ';' && depth == 0
                    parts{end+1} = cur; %#ok<AGROW>
                    cur = '';
                else
                    cur = [cur, ch]; %#ok<AGROW>
                end
            end
            if ~isempty(strtrim(cur))
                parts{end+1} = cur;
            end
        end

        function [closeIdx, ok] = findMatchingBrace(txt, openBraceEndIdx)
            % openBraceEndIdx는 '{' 위치
            idxOpen = strfind(txt(openBraceEndIdx:end), '{');
            if isempty(idxOpen)
                closeIdx = -1; ok = false; return;
            end
            i0 = openBraceEndIdx + idxOpen(1) - 1;
            depth = 0;
            ok = false;
            closeIdx = -1;
            for i = i0:numel(txt)
                if txt(i) == '{'
                    depth = depth + 1;
                elseif txt(i) == '}'
                    depth = depth - 1;
                    if depth == 0
                        closeIdx = i;
                        ok = true;
                        return;
                    end
                end
            end
        end

        function typedefMap = parseTypedefAliases(txt, defineMap)
            typedefMap = containers.Map('KeyType','char','ValueType','any');
            stmts = EthTcpServer.collectTopLevelTypedefStatements(txt);
            for i = 1:numel(stmts)
                stmt = strtrim(stmts{i});
                if contains(stmt, '{') || contains(stmt, '}')
                    continue; % struct typedef는 별도 처리
                end

                body = strtrim(regexprep(stmt, '^typedef\s+', ''));
                body = EthTcpServer.stripSalLikeTokens(body);

                if contains(body, ',')
                    error('EthTcpServer:UnsupportedTypedef', 'Comma-separated typedef aliases are unsupported: %s', stmt);
                end

                [alias, baseType, ptrLevel, arrDimsExpr] = EthTcpServer.parseSingleDeclarator(body);
                arrDims = zeros(1, numel(arrDimsExpr));
                for k = 1:numel(arrDimsExpr)
                    val = EthTcpServer.evalConstExpr(arrDimsExpr{k}, defineMap);
                    if isnan(val)
                        error('EthTcpServer:TypedefArrayDim', 'Failed to evaluate typedef array dim: %s', arrDimsExpr{k});
                    end
                    arrDims(k) = val;
                end

                typedefMap(alias) = struct('kind','alias', ...
                    'baseType', baseType, ...
                    'pointerLevel', ptrLevel, ...
                    'arrayDims', arrDims);
            end
        end

        function stmts = collectTopLevelTypedefStatements(txt)
            stmts = {};
            depth = 0;
            cur = '';
            inTypedef = false;
            tokens = regexp(txt, '(\{|\}|;|\btypedef\b)', 'match', 'start', 'end'); %#ok<ASGLU>

            i = 1;
            while i <= numel(txt)
                ch = txt(i);
                if startsWith(txt(i:end), 'typedef') && (i==1 || ~isstrprop(txt(i-1), 'alphanum'))
                    inTypedef = true;
                end

                if inTypedef
                    cur = [cur, ch]; %#ok<AGROW>
                end

                if ch == '{'
                    depth = depth + 1;
                elseif ch == '}'
                    depth = max(0, depth - 1);
                elseif ch == ';' && inTypedef && depth == 0
                    stmts{end+1} = cur; %#ok<AGROW>
                    cur = '';
                    inTypedef = false;
                end
                i = i + 1;
            end
        end

        function out = stripSalLikeTokens(in)
            out = regexprep(in, '(^|\s)_[A-Za-z0-9_]+_?(?=\s)', ' ');
            out = regexprep(out, '\s+', ' ');
            out = strtrim(out);
        end

        function outMap = mergeMaps(a, b)
            outMap = containers.Map('KeyType','char','ValueType','any');
            ka = a.keys;
            for i = 1:numel(ka)
                outMap(ka{i}) = a(ka{i});
            end
            kb = b.keys;
            for i = 1:numel(kb)
                outMap(kb{i}) = b(kb{i});
            end
        end

        function schema = buildSchemaForStruct(structName, ctx, stack)
            if any(strcmp(stack, structName))
                error('EthTcpServer:StructCycle', 'Struct recursion cycle detected at %s', structName);
            end
            if ~isKey(ctx.structDefs, structName)
                error('EthTcpServer:UnknownStruct', 'Unknown struct: %s', structName);
            end

            def = ctx.structDefs(structName);
            fields = struct('name', {}, 'type', {}, 'shape', {}, 'byteSize', {}, ...
                'isPointer', {}, 'isStruct', {}, 'subschema', {}, ...
                'typeNameResolved', {}, 'nullTerminated', {});
            totalBytes = 0;

            for i = 1:numel(def.fields)
                f = def.fields(i);
                resolved = EthTcpServer.resolveTypedefType(f.baseType, ctx.typedefMap, 0, [], {}, 0);
                ptrTotal = f.pointerLevel + resolved.pointerLevel;

                shape = [resolved.arrayDims, EthTcpServer.evalDims(f.arrayDimsExpr, ctx.defineMap)];
                if isempty(shape)
                    shape = 1;
                end

                baseResolved = resolved.baseType;
                isStructType = isKey(ctx.structDefs, baseResolved);

                if ptrTotal > 0
                    byteSize = ctx.opts.PointerSizeBytes * prod(shape);
                    fields(end+1) = struct(...
                        'name', f.name, 'type', ctx.opts.PointerMatType, 'shape', shape, 'byteSize', byteSize, ...
                        'isPointer', true, 'isStruct', false, 'subschema', struct(), ...
                        'typeNameResolved', baseResolved, 'nullTerminated', false); %#ok<AGROW>
                    totalBytes = totalBytes + byteSize;
                    continue;
                end

                if isStructType
                    sub = EthTcpServer.buildSchemaForStruct(baseResolved, ctx, [stack, {structName}]);
                    if ctx.opts.FlattenStructs && prod(shape) == 1
                        subFields = sub.fields;
                        for sf = 1:numel(subFields)
                            ff = subFields(sf);
                            ff.name = [f.name, '_', ff.name];
                            fields(end+1) = ff; %#ok<AGROW>
                            totalBytes = totalBytes + ff.byteSize;
                        end
                    else
                        byteSize = sub.byteSize * prod(shape);
                        fields(end+1) = struct(...
                            'name', f.name, 'type', 'struct', 'shape', shape, 'byteSize', byteSize, ...
                            'isPointer', false, 'isStruct', true, 'subschema', sub, ...
                            'typeNameResolved', baseResolved, 'nullTerminated', false); %#ok<AGROW>
                        totalBytes = totalBytes + byteSize;
                    end
                    continue;
                end

                if ~isKey(ctx.typeMap, baseResolved)
                    error('EthTcpServer:UnknownType', 'Unknown primitive/alias type: %s', baseResolved);
                end
                matType = ctx.typeMap(baseResolved);
                elemBytes = EthTcpServer.typeBytes(matType);
                byteSize = elemBytes * prod(shape);
                isChar = strcmp(matType, 'char') || strcmp(matType, 'uint8');
                fields(end+1) = struct(...
                    'name', f.name, 'type', matType, 'shape', shape, 'byteSize', byteSize, ...
                    'isPointer', false, 'isStruct', false, 'subschema', struct(), ...
                    'typeNameResolved', baseResolved, 'nullTerminated', isChar && ctx.opts.CharArrayNullTerminated); %#ok<AGROW>
                totalBytes = totalBytes + byteSize;
            end

            schema = struct('name', structName, 'fields', fields, 'byteSize', totalBytes);
        end

        function resolved = resolveTypedefType(typeName, typedefMap, ptrAcc, arrAcc, seen, depth)
            if nargin < 7
                depth = 0;
            end
            if depth > 64
                error('EthTcpServer:TypedefDepth', 'Typedef resolution exceeded max depth.');
            end

            t = strtrim(typeName);
            if isKey(typedefMap, t)
                if any(strcmp(seen, t))
                    error('EthTcpServer:TypedefCycle', 'Typedef cycle detected at %s', t);
                end
                e = typedefMap(t);
                if isstruct(e) && isfield(e, 'kind') && strcmp(e.kind, 'alias')
                    ptrAcc = ptrAcc + e.pointerLevel;
                    arrAcc = [arrAcc, e.arrayDims]; %#ok<AGROW>
                    resolved = EthTcpServer.resolveTypedefType(e.baseType, typedefMap, ptrAcc, arrAcc, [seen, {t}], depth+1);
                    return;
                end
            end

            resolved = struct('baseType', t, 'pointerLevel', ptrAcc, 'arrayDims', arrAcc);
        end

        function dims = evalDims(dimExprs, defineMap)
            if isempty(dimExprs)
                dims = [];
                return;
            end
            dims = zeros(1, numel(dimExprs));
            for i = 1:numel(dimExprs)
                v = EthTcpServer.evalConstExpr(dimExprs{i}, defineMap);
                if isnan(v)
                    error('EthTcpServer:ArrayDimEval', 'Failed to evaluate array dimension: %s', dimExprs{i});
                end
                dims(i) = v;
            end
        end

        function val = evalConstExpr(expr, defineMap)
            val = NaN;
            if isempty(expr)
                return;
            end
            e = strtrim(char(expr));
            % U/L suffix 제거
            e = regexprep(e, '(?<=[0-9A-Fa-fxX])[uUlL]+\b', '');

            if nargin >= 2 && ~isempty(defineMap)
                keys = defineMap.keys;
                for i = 1:numel(keys)
                    k = keys{i};
                    e = regexprep(e, ['\<', k, '\>'], num2str(defineMap(k), '%.0f'));
                end
            end

            if isempty(regexp(e, '^[0-9xXa-fA-F\+\-\*\/\%\(\)\<\>\&\|\~\s]+$', 'once'))
                return;
            end
            try
                val = double(eval(e)); %#ok<EVLC>
            catch
                val = NaN;
            end
        end

        function m = defaultTypeMap()
            m = containers.Map('KeyType','char','ValueType','char');
            pairs = {
                'char','char';
                'signed char','int8';
                'unsigned char','uint8';
                'short','int16';
                'unsigned short','uint16';
                'int','int32';
                'unsigned int','uint32';
                'long','int32';
                'unsigned long','uint32';
                'long long','int64';
                'unsigned long long','uint64';
                'float','single';
                'double','double';
                'int8_t','int8';
                'uint8_t','uint8';
                'int16_t','int16';
                'uint16_t','uint16';
                'int32_t','int32';
                'uint32_t','uint32';
                'int64_t','int64';
                'uint64_t','uint64';
                'size_t','uint64'
                };
            for i = 1:size(pairs,1)
                m(pairs{i,1}) = pairs{i,2};
            end
        end

        function n = typeBytes(typeName)
            switch typeName
                case {'int8','uint8','char'}; n = 1;
                case {'int16','uint16'}; n = 2;
                case {'int32','uint32','single'}; n = 4;
                case {'int64','uint64','double'}; n = 8;
                otherwise
                    error('EthTcpServer:UnknownMatType', 'Unknown MATLAB type for byte size: %s', typeName);
            end
        end

        function validatePointerConfig(pointerSizeBytes, pointerMatType)
            switch char(pointerMatType)
                case {'uint32'}
                    msz = 4;
                case {'uint64'}
                    msz = 8;
                otherwise
                    error('EthTcpServer:PointerType', 'PointerMatType must be uint32 or uint64.');
            end
            if pointerSizeBytes ~= msz
                error('EthTcpServer:PointerConfigMismatch', ...
                    'PointerSizeBytes (%d) must match PointerMatType (%s => %d).', ...
                    pointerSizeBytes, pointerMatType, msz);
            end
        end

        function [out, bytesUsed] = decodeSchemaStruct(bytes, schema, opts)
            out = struct();
            offset = 1;
            for i = 1:numel(schema.fields)
                f = schema.fields(i);
                nBytes = f.byteSize;
                if offset + nBytes - 1 > numel(bytes)
                    error('EthTcpServer:DecodeSize', 'Insufficient bytes for field %s', f.name);
                end
                chunk = bytes(offset:offset+nBytes-1);

                if f.isStruct
                    val = EthTcpServer.decodeStructField(chunk, f, opts);
                else
                    val = EthTcpServer.decodePrimitiveField(chunk, f, opts);
                end
                out.(f.name) = val;
                offset = offset + nBytes;
            end
            bytesUsed = offset - 1;
        end

        function val = decodeStructField(bytes, field, opts)
            sub = field.subschema;
            shape = field.shape;
            count = prod(shape);
            elemBytes = sub.byteSize;
            elems = cell(1, count);
            off = 1;
            for i = 1:count
                c = bytes(off:off+elemBytes-1);
                [e, used] = EthTcpServer.decodeSchemaStruct(c, sub, opts);
                if used ~= elemBytes
                    error('EthTcpServer:StructDecodeSize', 'Struct element decode size mismatch for %s', field.name);
                end
                elems{i} = e;
                off = off + elemBytes;
            end

            if count == 1
                val = elems{1};
                return;
            end

            % dissimilar struct 할당 회피: 첫 원소 템플릿으로 복제
            val = repmat(elems{1}, fliplr(shape));
            for i = 1:count
                subs = EthTcpServer.linearIndexToSubscriptsC(shape, i);
                idx = num2cell(subs);
                val(idx{:}) = elems{i};
            end
        end

        function val = decodePrimitiveField(bytes, field, opts)
            shape = field.shape;
            count = prod(shape);

            if field.isPointer
                ptrType = char(opts.PointerMatType);
                raw = typecast(uint8(bytes), ptrType);
                val = EthTcpServer.reshapeCRowMajor(raw, shape);
                return;
            end

            t = field.type;
            if strcmp(t, 'char')
                raw = uint8(bytes);
                val = EthTcpServer.decodeCharArray(raw, shape, field.nullTerminated);
                return;
            end

            raw = typecast(uint8(bytes), t);
            if numel(raw) ~= count
                error('EthTcpServer:PrimitiveCount', 'Primitive count mismatch in field %s', field.name);
            end
            val = EthTcpServer.reshapeCRowMajor(raw, shape);
        end

        function out = decodeCharArray(raw, shape, nullTerminated)
            if numel(shape) == 1
                b = reshape(raw, 1, []);
                if nullTerminated
                    k = find(b == 0, 1, 'first');
                    if ~isempty(k)
                        b = b(1:k-1);
                    end
                end
                out = char(b);
                return;
            end

            if numel(shape) == 2
                mat = EthTcpServer.reshapeCRowMajor(raw, shape);
                % shape = [rows cols] (C row-major 기준)
                if nullTerminated
                    rows = size(mat,1);
                    strs = strings(rows,1);
                    for r = 1:rows
                        row = uint8(mat(r,:));
                        k = find(row == 0, 1, 'first');
                        if ~isempty(k)
                            row = row(1:k-1);
                        end
                        strs(r) = string(char(row));
                    end
                    out = strs;
                else
                    out = char(mat);
                end
                return;
            end

            % 3D+ char 배열은 uint8 유지(명시적 제한)
            out = EthTcpServer.reshapeCRowMajor(raw, shape);
        end

        function arr = reshapeCRowMajor(raw, shape)
            if isequal(shape, 1) || isempty(shape)
                arr = raw(1);
                return;
            end
            % C row-major -> MATLAB column-major 변환
            tmp = reshape(raw, fliplr(shape));
            arr = permute(tmp, numel(shape):-1:1);
        end

        function subs = linearIndexToSubscriptsC(shape, linearIdx1)
            % linearIdx1: 1-based, C row-major 기준 선형 인덱스
            idx0 = linearIdx1 - 1;
            subs0 = zeros(1, numel(shape));
            for d = numel(shape):-1:1
                if d == numel(shape)
                    stride = 1;
                else
                    stride = prod(shape(d+1:end));
                end
                subs0(d) = floor(idx0 / stride);
                idx0 = mod(idx0, stride);
            end
            subs = subs0 + 1;
        end
    end
end
