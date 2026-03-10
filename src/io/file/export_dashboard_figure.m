function filePath = export_dashboard_figure(fig, outputDir, baseName)
%EXPORT_DASHBOARD_FIGURE Export dashboard figure as PNG.

if nargin < 2 || isempty(outputDir)
    outputDir = fullfile('data', 'output', 'figures');
end
if nargin < 3 || isempty(baseName)
    baseName = 'dashboard';
end

validateattributes(outputDir, {'char', 'string'}, {'nonempty'}, mfilename, 'outputDir', 2);
validateattributes(baseName, {'char', 'string'}, {'nonempty'}, mfilename, 'baseName', 3);

if isempty(fig) || ~ishandle(fig)
    error('export_dashboard_figure:InvalidFigure', 'fig must be a valid figure handle.');
end

outputDir = char(outputDir);
baseName = char(baseName);
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

ts = datestr(now, 'yyyymmdd_HHMMSS');
filePath = fullfile(outputDir, sprintf('%s_%s.png', baseName, ts));

if exist('exportgraphics', 'file') == 2
    exportgraphics(fig, filePath, 'Resolution', 150);
else
    saveas(fig, filePath);
end
end
