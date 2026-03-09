function filePath = save_result_mat(result, outputDir, baseName)
%SAVE_RESULT_MAT Save result struct to a MAT file under output directory.
%   filePath = SAVE_RESULT_MAT(result)
%   filePath = SAVE_RESULT_MAT(result, outputDir, baseName)

if nargin < 2 || isempty(outputDir)
    outputDir = fullfile('data', 'output');
end
if nargin < 3 || isempty(baseName)
    baseName = 'result';
end

if ~isstruct(result)
    error('save_result_mat:InvalidResult', 'result must be a struct.');
end
validateattributes(outputDir, {'char', 'string'}, {'nonempty'}, mfilename, 'outputDir', 2);
validateattributes(baseName, {'char', 'string'}, {'nonempty'}, mfilename, 'baseName', 3);

outputDir = char(outputDir);
baseName = char(baseName);
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

ts = datestr(now, 'yyyymmdd_HHMMSS');
filePath = fullfile(outputDir, sprintf('%s_%s.mat', baseName, ts));

save(filePath, 'result');
end
