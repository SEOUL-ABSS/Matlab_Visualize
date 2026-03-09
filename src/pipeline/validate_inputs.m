function validate_inputs(inputData)
%VALIDATE_INPUTS Validate pipeline input structure contract.
%   Required fields:
%   inputData.data
%   inputData.fs
%   inputData.timestamp
%   inputData.type
%   inputData.meta

requiredFields = {'data', 'fs', 'timestamp', 'type', 'meta'};

if ~isstruct(inputData)
    error('validate_inputs:InvalidType', 'inputData must be a struct.');
end

for i = 1:numel(requiredFields)
    f = requiredFields{i};
    if ~isfield(inputData, f)
        error('validate_inputs:MissingField', 'Missing required field: inputData.%s', f);
    end
end

if isempty(inputData.data)
    error('validate_inputs:EmptyData', 'inputData.data must not be empty.');
end

if ~isscalar(inputData.fs) || ~isnumeric(inputData.fs) || inputData.fs <= 0
    error('validate_inputs:InvalidFs', 'inputData.fs must be a positive numeric scalar.');
end

if ~(ischar(inputData.type) || isstring(inputData.type))
    error('validate_inputs:InvalidTypeField', 'inputData.type must be char or string.');
end
end
