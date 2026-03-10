classdef EthTcpSimpleLogger < handle
    %ETHTCPSIMPLELOGGER 파일 + 콘솔 로깅 유틸(필드 dot-path 추출 지원).

    properties
        FilePath (1,:) char
        EnableConsole (1,1) logical = true
        ConsoleEvery (1,1) double = 1
        FlushEvery (1,1) double = 1
        FieldPaths cell = {'meta.topicId', 'meta.packetCount'}
    end

    properties (Access = private)
        fid (1,1) double = -1
        count (1,1) double = 0
        closed (1,1) logical = false
    end

    methods
        function obj = EthTcpSimpleLogger(filePath, varargin)
            if nargin < 1 || isempty(filePath)
                error('EthTcpSimpleLogger:InvalidPath', 'filePath is required.');
            end
            obj.FilePath = char(filePath);
            obj = EthTcpSimpleLogger.applyNameValue(obj, varargin{:});
            obj.ensureOpen();
        end

        function delete(obj)
            obj.close();
        end

        function log(obj, msg, meta)
            if nargin < 3
                meta = struct();
            end
            obj.ensureOpen();
            obj.count = obj.count + 1;

            ts = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
            parts = cell(1, numel(obj.FieldPaths));
            for i = 1:numel(obj.FieldPaths)
                p = obj.FieldPaths{i};
                v = EthTcpSimpleLogger.getByPath(struct('msg',msg,'meta',meta), p);
                parts{i} = sprintf('%s=%s', p, EthTcpSimpleLogger.toString(v));
            end
            line = sprintf('[%s] %s\n', ts, strjoin(parts, ', '));
            fwrite(obj.fid, line, 'char');

            if obj.EnableConsole && mod(obj.count, obj.ConsoleEvery) == 0
                fprintf('%s', line);
            end
            if mod(obj.count, obj.FlushEvery) == 0
                fflush(obj.fid);
            end
        end

        function close(obj)
            if obj.closed
                return;
            end
            if obj.fid > 0
                fflush(obj.fid);
                fclose(obj.fid);
            end
            obj.fid = -1;
            obj.closed = true;
        end
    end

    methods (Access = private)
        function ensureOpen(obj)
            if ~obj.closed
                return;
            end
            obj.closed = false;
            [d,~,~] = fileparts(obj.FilePath);
            if ~isempty(d) && exist(d,'dir')~=7
                mkdir(d);
            end
            obj.fid = fopen(obj.FilePath, 'a');
            if obj.fid < 0
                error('EthTcpSimpleLogger:OpenFailed', 'Failed to open log file: %s', obj.FilePath);
            end
        end
    end

    methods (Static)
        function v = getByPath(s, pathExpr)
            v = [];
            if ~isstruct(s)
                return;
            end
            parts = regexp(pathExpr, '\.', 'split');
            cur = s;
            for i = 1:numel(parts)
                k = parts{i};
                if ~isstruct(cur) || ~isfield(cur, k)
                    v = [];
                    return;
                end
                cur = cur.(k);
            end
            v = cur;
        end

        function s = toString(v)
            if ischar(v)
                s = v;
            elseif isstring(v) && isscalar(v)
                s = char(v);
            elseif isnumeric(v) || islogical(v)
                if isscalar(v)
                    s = num2str(v);
                else
                    s = sprintf('[%s]', strjoin(arrayfun(@num2str, v(:)', 'UniformOutput', false), ' '));
                end
            elseif isdatetime(v)
                s = char(string(v));
            elseif isempty(v)
                s = '[]';
            elseif isstruct(v)
                s = '<struct>';
            else
                s = sprintf('<%s>', class(v));
            end
        end

        function obj = applyNameValue(obj, varargin)
            if mod(numel(varargin),2) ~= 0
                error('EthTcpSimpleLogger:InvalidNameValue', 'Name/value pairs are required.');
            end
            for i = 1:2:numel(varargin)
                name = char(varargin{i});
                value = varargin{i+1};
                if ~isprop(obj, name)
                    error('EthTcpSimpleLogger:UnknownOption', 'Unknown option: %s', name);
                end
                obj.(name) = value;
            end
        end
    end
end
